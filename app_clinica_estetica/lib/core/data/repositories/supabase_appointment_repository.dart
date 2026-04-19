import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:app_clinica_estetica/core/data/models/appointment_model.dart';
import 'package:app_clinica_estetica/core/data/models/evaluation_model.dart';
import 'package:app_clinica_estetica/core/data/repositories/appointment_repository.dart';
import 'package:app_clinica_estetica/core/data/repositories/dashboard_repository.dart';

class SupabaseAppointmentRepository implements IAppointmentRepository {
  final _supabase = Supabase.instance.client;

  @override
  Future<List<AppointmentModel>> getUserAppointments(String userId) async {
    try {
      final response = await _supabase
          .from('agendamentos')
          .select('''
            *,
            servicos:servico_id (nome, imagem_url, duracao_minutos),
            profissional:profissional_id (nome_completo, avatar_url, cargo),
            evaluation:avaliacoes!agendamento_id (*),
            pacotes_contratados:pacote_contratado_id (pacotes_templates!template_id (titulo))
          ''')
          .or('cliente_id.eq.$userId,profissional_id.eq.$userId')
          .neq('status', 'cancelado')
          .order('data_hora', ascending: true);

      return (response as List)
          .map((data) => AppointmentModel.fromJson(data))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<AppointmentModel>> getUpcomingAppointments(String userId) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final response = await _supabase
          .from('agendamentos')
          .select('''
            *,
            servicos:servico_id (nome, imagem_url, duracao_minutos),
            profissional:profissional_id (nome_completo, avatar_url, cargo),
            evaluation:avaliacoes!agendamento_id (*),
            pacotes_contratados:pacote_contratado_id (pacotes_templates!template_id (titulo))
          ''')
          .or('cliente_id.eq.$userId,profissional_id.eq.$userId')
          .gte('data_hora', now)
          .neq('status', 'cancelado')
          .neq('status', 'concluido')
          .neq('status', 'ausente')
          .order('data_hora', ascending: true);

      return (response as List)
          .map((data) => AppointmentModel.fromJson(data))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<AppointmentModel>> getPastAppointments(String userId) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      // Histórico inclui passados OU cancelados OU concluídos
      final response = await _supabase
          .from('agendamentos')
          .select('''
            *,
            servicos:servico_id (nome, imagem_url, duracao_minutos),
            profissional:profissional_id (nome_completo, avatar_url, cargo),
            evaluation:avaliacoes!agendamento_id (*),
            pacotes_contratados:pacote_contratado_id (pacotes_templates!template_id (titulo))
          ''')
          .or('cliente_id.eq.$userId,profissional_id.eq.$userId')
          .or('status.eq.cancelado,status.eq.concluido,status.eq.ausente,and(data_hora.lt.$now,status.neq.confirmado)')
          .order('data_hora', ascending: false);

      return (response as List)
          .map((data) => AppointmentModel.fromJson(data))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> cancelAppointment(String appointmentId) async {
    try {
      final info = await _getAppointmentInfo(appointmentId);
      final response = await _supabase
          .from('agendamentos')
          .update({'status': 'cancelado'})
          .eq('id', appointmentId)
          .select();
          
      if ((response as List).isEmpty) {
        throw Exception('Não foi possível cancelar o agendamento. Verifique as permissões.');
      }

      if (info != null) {
        // Obsolete manual log: now handled internally by PostgreSQL trigger on 'agendamentos' update
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> rescheduleAppointment(String id, DateTime newDateTime) async {
    try {
      final info = await _getAppointmentInfo(id);
      final response = await _supabase
          .from('agendamentos')
          .update({
            'data_hora': newDateTime.toUtc().toIso8601String(),
            'status': 'confirmado',
          })
          .eq('id', id)
          .select();

      if ((response as List).isEmpty) {
        throw Exception('Não foi possível reagendar. Verifique as permissões de acesso.');
      }

      if (info != null) {
        // Obsolete manual log: now handled internally by PostgreSQL trigger on 'agendamentos' updates
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> saveEvaluation(EvaluationModel evaluation) async {
    try {
      await _supabase.from('avaliacoes').insert(evaluation.toMap());
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateEvaluation(EvaluationModel evaluation) async {
    try {
      if (evaluation.id == null) throw Exception('ID da avaliação nulo');
      final data = evaluation.toMap();
      data.remove('id'); // Não se deve atualizar a PK no corpo do update
      
      await _supabase
          .from('avaliacoes')
          .update(data)
          .eq('id', evaluation.id!);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<EvaluationModel>> getUserEvaluations(String userId) async {
    try {
      final response = await _supabase
          .from('avaliacoes')
          .select('''
            *,
            agendamentos:agendamento_id (
              data_hora,
              servicos (nome)
            ),
            profissional:profissional_id (nome_completo)
          ''')
          .eq('cliente_id', userId)
          .order('criado_em', ascending: false);

      return (response as List)
          .map((data) => EvaluationModel.fromMap(data))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<String>> uploadEvaluationPhotos(List<XFile> files) async {
    try {
      final List<String> urls = [];
      for (final xFile in files) {
        final bytes = await xFile.readAsBytes();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${xFile.name}';
        final storagePath = 'public/$fileName';

        await _supabase.storage.from('avaliacoes').uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );

        final url = _supabase.storage.from('avaliacoes').getPublicUrl(storagePath);
        urls.add(url);
      }
      return urls;
    } catch (e) {
      rethrow;
    }
  }
  @override
  Future<void> autoCompletePastAppointments(String userId) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _supabase
          .from('agendamentos')
          .update({'status': 'concluido'})
          .or('cliente_id.eq.$userId,profissional_id.eq.$userId')
          .eq('status', 'confirmado')
          .lt('data_hora', now);
    } catch (e) {
      // Falha silenciosa para não quebrar o carregamento da agenda
      debugPrint('Erro ao auto-concluir agendamentos: $e');
    }
  }
  @override
  Future<void> updateAppointmentStatus(String id, String status) async {
    try {
      final info = await _getAppointmentInfo(id);
      final response = await _supabase
          .from('agendamentos')
          .update({'status': status})
          .eq('id', id)
          .select();
          
      if ((response as List).isEmpty) {
        throw Exception('Não foi possível atualizar o status.');
      }

      if (info != null && status == 'confirmado') {
        final df = DateFormat('dd/MM/yyyy \'às\' HH:mm');
        final dataAgenda = DateTime.parse(info['data_hora']).toLocal();
        final clienteNome = _getName(info['cliente']);
        final profissionalNome = _getName(info['profissional']);
        final servicoNome = _getName(info['servicos']);
        
        // Obter duração do serviço via join se possível ou usar default
        int duracao = 60;
        final servicosData = info['servicos'];
        if (servicosData is Map && servicosData.containsKey('duracao_minutos')) {
          duracao = servicosData['duracao_minutos'] as int? ?? 60;
        } else if (servicosData is List && servicosData.isNotEmpty) {
           final first = servicosData.first;
           if (first is Map && first.containsKey('duracao_minutos')) {
             duracao = first['duracao_minutos'] as int? ?? 60;
           }
        }

        final end = dataAgenda.add(Duration(minutes: duracao));
        final interval = "${DateFormat('HH:mm').format(dataAgenda)} - ${DateFormat('HH:mm').format(end)}";

        await SupabaseDashboardRepository().logActivity(
          tipo: 'confirmacao',
          titulo: 'Agendamento Confirmado',
          descricao: '$clienteNome confirmou $servicoNome com $profissionalNome para às $interval no dia ${DateFormat('dd/MM').format(dataAgenda)}.',
          metadata: {
            'appointment_id': id,
            'cliente': clienteNome,
            'profissional': profissionalNome,
            'procedimento': servicoNome,
            'data_hora': dataAgenda.toIso8601String(),
            'duracao_minutos': duracao,
            'status': status,
          },
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> getClientConflictAtTime({
    required String clientId,
    required DateTime dateTime,
    required String? excludedAppointmentId,
  }) async {
    try {
      final isoString = dateTime.toUtc().toIso8601String();
      
      // Busca agendamento no mesmo horário exato, excluindo o atual
      var query = _supabase
          .from('agendamentos')
          .select('id, profissional:perfis!profissional_id(nome_completo)')
          .eq('cliente_id', clientId)
          .eq('data_hora', isoString)
          .neq('status', 'cancelado');

      if (excludedAppointmentId != null) {
        query = query.neq('id', excludedAppointmentId);
      }

      final response = await query.maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Erro ao buscar conflito de horário: $e');
      return null;
    }
  }

  @override
  Future<bool> checkClientHasOtherAppOnDate({
    required String clientId,
    required DateTime date,
    required String? excludedAppointmentId,
  }) async {
    try {
      final dateString = date.toUtc().toIso8601String().split('T')[0];
      
      // Busca todos os agendamentos do cliente na data, excluindo o atual se fornecido
      var query = _supabase
          .from('agendamentos')
          .select()
          .eq('cliente_id', clientId)
          .like('data_hora', '$dateString%')
          .neq('status', 'cancelado');

      if (excludedAppointmentId != null) {
        query = query.neq('id', excludedAppointmentId);
      }

      final response = await query;
      final appointments = response as List;

      return appointments.isNotEmpty;
    } catch (e) {
      debugPrint('Erro ao verificar conflitos do cliente: $e');
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>?> getProfessionalConflictAtTime({
    required String professionalId,
    required DateTime dateTime,
    required String? excludedAppointmentId,
  }) async {
    try {
      final isoString = dateTime.toUtc().toIso8601String();
      
      var query = _supabase
          .from('agendamentos')
          .select('id, cliente:perfis!cliente_id(nome_completo)')
          .eq('profissional_id', professionalId)
          .eq('data_hora', isoString)
          .neq('status', 'cancelado');

      if (excludedAppointmentId != null) {
        query = query.neq('id', excludedAppointmentId);
      }

      final response = await query.maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Erro ao buscar conflito de profissional: $e');
      return null;
    }
  }

  @override
  Future<List<AppointmentModel>> getAppointmentsByPackageId(String packageId) async {
    try {
      final response = await _supabase
          .from('agendamentos')
          .select('''
            *,
            servicos:servico_id (nome, imagem_url, duracao_minutos),
            profissional:profissional_id (nome_completo, avatar_url, cargo),
            pacotes_contratados:pacote_contratado_id (pacotes_templates!template_id (titulo))
          ''')
          .eq('pacote_contratado_id', packageId)
          .neq('status', 'cancelado')
          .order('data_hora', ascending: true);

      return (response as List)
          .map((data) => AppointmentModel.fromJson(data))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _getAppointmentInfo(String id) async {
    try {
      return await _supabase
          .from('agendamentos')
          .select('''
            id, 
            data_hora,
            cliente:perfis!cliente_id(nome_completo),
            profissional:perfis!profissional_id(nome_completo),
            servicos(nome, duracao_minutos)
          ''')
          .eq('id', id)
          .maybeSingle();
    } catch (e) {
      return null;
    }
  }

  String _getName(dynamic data) {
    if (data == null) return 'N/A';
    if (data is List) {
      if (data.isEmpty) return 'N/A';
      return _getName(data.first);
    }
    if (data is Map) {
      return (data['nome_completo'] ?? data['nome'] ?? 'N/A').toString();
    }
    return data.toString();
  }
}

