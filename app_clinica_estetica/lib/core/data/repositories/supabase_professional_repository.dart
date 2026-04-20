import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_clinica_estetica/core/data/models/professional_model.dart';
import 'package:intl/intl.dart';

class SupabaseProfessionalRepository {
  final _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getProfessionals({bool excludeAdmins = true}) async {
    try {
      var query = _supabase
          .from('perfis')
          .select('id, nome_completo, email, telefone, avatar_url, cargo, tipo');

      if (excludeAdmins) {
        query = query.or('tipo.is.null,tipo.eq.profissional,tipo.eq.parceiro');
      }

      final response = await query.order('nome_completo');
      
      final List<Map<String, dynamic>> profs = List<Map<String, dynamic>>.from(response);
      
      if (excludeAdmins) {
        return profs.where((p) {
          final String name = (p['nome_completo'] ?? '').toLowerCase();
          return !name.contains('administrador');
        }).toList();
      }
      return profs;
    } catch (e) {
      debugPrint('SUPABASE_ERROR: getProfessionals failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getProfessionalWorkingHours(String professionalId) async {
    try {
      final response = await _supabase
          .from('horarios_trabalho_profissional')
          .select()
          .eq('profissional_id', professionalId)
          .order('dia_semana', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('SUPABASE_ERROR: getProfessionalWorkingHours failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getProfessionalLunchHours(String professionalId) async {
    try {
      final response = await _supabase
          .from('horarios_almoco_profissional')
          .select()
          .eq('profissional_id', professionalId)
          .order('dia_semana', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('SUPABASE_ERROR: getProfessionalLunchHours failed: $e');
      return [];
    }
  }

  Future<void> updateProfessionalWorkingHour({
    required String professionalId,
    required int diaSemana,
    required String horaInicio,
    required String horaFim,
    required bool fechado,
  }) async {
    try {
      await _supabase.from('horarios_trabalho_profissional').upsert({
        'profissional_id': professionalId,
        'dia_semana': diaSemana,
        'hora_inicio': horaInicio,
        'hora_fim': horaFim,
        'fechado': fechado,
      }, onConflict: 'profissional_id, dia_semana');
    } catch (e) {
      throw Exception('Falha ao atualizar horário de trabalho');
    }
  }

  Future<void> updateProfessionalLunchHour({
    required String professionalId,
    required int diaSemana,
    required String horaInicio,
    required String horaFim,
    bool ativo = true,
  }) async {
    try {
      await _supabase.from('horarios_almoco_profissional').upsert({
        'profissional_id': professionalId,
        'dia_semana': diaSemana,
        'hora_inicio': horaInicio,
        'hora_fim': horaFim,
        'ativo': ativo,
      }, onConflict: 'profissional_id, dia_semana');
    } catch (e) {
      throw Exception('Falha ao atualizar horário de almoço');
    }
  }

  String? get currentUserId => _supabase.auth.currentUser?.id;

  Future<List<Map<String, dynamic>>> getMonthlyBlocks(String? profId, int year, int month) async {
    try {
      final start = DateTime(year, month, 1);
      final nextMonth = month == 12 ? 1 : month + 1;
      final nextYear = month == 12 ? year + 1 : year;
      final end = DateTime(nextYear, nextMonth, 0);
      
      var query = _supabase.from('bloqueios_agenda')
          .select()
          .gte('data', DateFormat('yyyy-MM-dd').format(start))
          .lte('data', DateFormat('yyyy-MM-dd').format(end));
          
      if (profId != null) {
        query = query.or('profissional_id.eq.$profId,profissional_id.is.null');
      }
      
      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getMonthlyBlocks: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getProfessionalBlocksAndLunch(String profId, DateTime date) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final dayOfWeek = date.weekday == 7 ? 0 : date.weekday;

      final blocks = await getAgendaBlocks(profId: profId, date: date);
      
      final work = await _supabase.from('horarios_trabalho_profissional')
          .select()
          .eq('profissional_id', profId)
          .eq('dia_semana', dayOfWeek)
          .maybeSingle();

      final lunch = await _supabase.from('horarios_almoco_profissional')
          .select()
          .eq('profissional_id', profId)
          .eq('dia_semana', dayOfWeek)
          .eq('ativo', true)
          .maybeSingle();

      return {
        'blocks': blocks,
        'lunch': lunch,
        'work': work,
      };
    } catch (e) {
      debugPrint('Error getProfessionalBlocksAndLunch: $e');
      return {'blocks': [], 'lunch': null, 'work': null};
    }
  }

  Future<List<int>> getClinicAvailabilityDays() async {
    // Retorna dias da semana (1-6 para Seg-Sab)
    return [1, 2, 3, 4, 5, 6];
  }

  Future<Map<String, dynamic>> getClinicHours(int dayOfWeek) async {
    // Horário padrão da clínica
    return {
      'hora_inicio': '08:00',
      'hora_fim': '18:00',
    };
  }

  Future<List<Map<String, dynamic>>> getAnyOccupiedTimes(DateTime date, {String? excludeId}) async {
    try {
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));
      
      var query = _supabase.from('agendamentos')
          .select('data_hora, servicos(duracao_minutos)')
          .gte('data_hora', start.toIso8601String())
          .lt('data_hora', end.toIso8601String())
          .neq('status', 'cancelado');
          
      if (excludeId != null) {
        query = query.neq('id', excludeId);
      }
      
      final response = await query;
      return (response as List).map((occ) => {
        'dateTime': DateTime.parse(occ['data_hora']).toLocal(),
        'duration': occ['servicos']?['duracao_minutos'] ?? 60,
      }).toList();
    } catch (e) {
      debugPrint('Error getAnyOccupiedTimes: $e');
      return [];
    }
  }

  Future<void> updateProfessional({
    required String id,
    required String nome,
    String? email,
    required String cargo,
    String? telefone,
    String? avatarUrl,
    String? tipo,
    String? observacoesInternas,
    double? comissaoProdutosPercentual,
    double? comissaoAgendamentosPercentual,
    bool? ativo,
  }) async {
    final updates = {
      'nome_completo': nome,
      if (email != null) 'email': email,
      'cargo': cargo,
      if (telefone != null) 'telefone': telefone,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (tipo != null) 'tipo': tipo,
      if (observacoesInternas != null) 'observacoes_internas': observacoesInternas,
      if (comissaoProdutosPercentual != null) 'comissao_produtos_percentual': comissaoProdutosPercentual,
      if (comissaoAgendamentosPercentual != null) 'comissao_agendamentos_percentual': comissaoAgendamentosPercentual,
      if (ativo != null) 'ativo': ativo,
    };
    await _supabase.from('perfis').update(updates).eq('id', id);
  }

  Future<List<String>> getLinkedServiceIds(String profId) async {
    final res = await _supabase.from('profissional_servicos').select('servico_id').eq('profissional_id', profId);
    return (res as List).map((e) => e['servico_id'].toString()).toList();
  }

  Future<void> saveLinkedServices(String profId, List<String> serviceIds) async {
    await _supabase.from('profissional_servicos').delete().eq('profissional_id', profId);
    if (serviceIds.isNotEmpty) {
      final inserts = serviceIds.map((sid) => {'profissional_id': profId, 'servico_id': sid}).toList();
      await _supabase.from('profissional_servicos').insert(inserts);
    }
  }

  Future<List<String>> getLinkedPackageIds(String profId) async {
    final res = await _supabase.from('profissional_pacotes').select('pacote_id').eq('profissional_id', profId);
    return (res as List).map((e) => e['pacote_id'].toString()).toList();
  }

  Future<void> saveLinkedPackages(String profId, List<String> packageIds) async {
    await _supabase.from('profissional_pacotes').delete().eq('profissional_id', profId);
    if (packageIds.isNotEmpty) {
      final inserts = packageIds.map((pid) => {'profissional_id': profId, 'pacote_id': pid}).toList();
      await _supabase.from('profissional_pacotes').insert(inserts);
    }
  }

  Future<void> addAgendaBlock({
    required String professionalId,
    required String data,
    String? horaInicio,
    String? horaFim,
    bool diaTodo = false,
    String? motivo,
  }) async {
    await _supabase.from('bloqueios_agenda').insert({
      'profissional_id': professionalId,
      'data': data,
      'hora_inicio': horaInicio,
      'hora_fim': horaFim,
      'dia_todo': diaTodo,
      'motivo': motivo,
    });
  }

  Future<void> removeAgendaBlock(String id) async {
    await _supabase.from('bloqueios_agenda').delete().eq('id', id);
  }

  Future<List<ProfessionalModel>> getProfessionalsByService(String serviceId, {bool excludeAdmins = true}) async {
    try {
      debugPrint('SUPABASE_DEBUG: getProfessionalsByService for serviceId=$serviceId');
      
      final linksResponse = await _supabase
          .from('profissional_servicos')
          .select('profissional_id')
          .eq('servico_id', serviceId);
      
      final List<dynamic> data = linksResponse as List<dynamic>;
      debugPrint('SUPABASE_DEBUG: Found ids in profissional_servicos: $data');

      if (data.isEmpty) {
        debugPrint('SUPABASE_DEBUG: No specific links found for serviceId=$serviceId. Returning empty list.');
        return [];
      }

      final List<String> profIds = data.map((item) => item['profissional_id'].toString()).toList();
      
      var query = _supabase
          .from('perfis')
          .select('id, nome_completo, email, telefone, avatar_url, cargo, tipo')
          .filter('id', 'in', profIds);

      if (excludeAdmins) {
        query = query.or('tipo.is.null,tipo.eq.profissional,tipo.eq.parceiro');
      }

      final profsResponse = await query.order('nome_completo');
      
      final List<Map<String, dynamic>> profs = List<Map<String, dynamic>>.from(profsResponse);
      
      final List<Map<String, dynamic>> filtered = excludeAdmins 
        ? profs.where((p) {
            final String name = (p['nome_completo'] ?? '').toLowerCase();
            return !name.contains('administrador');
          }).toList()
        : profs;

      return filtered.map((m) => ProfessionalModel.fromMap(m)).toList();
    } catch (e) {
      debugPrint('SUPABASE_ERROR: getProfessionalsByService failed: $e');
      return [];
    }
  }

  Future<List<ProfessionalModel>> getProfessionalsByPackage(String packageId, {bool excludeAdmins = true}) async {
    try {
      debugPrint('SUPABASE_DEBUG: getProfessionalsByPackage for packageId=$packageId');
      
      final linksResponse = await _supabase
          .from('profissional_pacotes')
          .select('profissional_id')
          .eq('pacote_id', packageId);
      
      final List<dynamic> data = linksResponse as List<dynamic>;
      debugPrint('SUPABASE_DEBUG: Found ids in profissional_pacotes: $data');

      if (data.isEmpty) {
        debugPrint('SUPABASE_DEBUG: No specific links found for packageId=$packageId. Returning empty list.');
        return [];
      }

      final List<String> profIds = data.map((item) => item['profissional_id'].toString()).toList();
      
      var query = _supabase
          .from('perfis')
          .select('id, nome_completo, email, telefone, avatar_url, cargo, tipo')
          .filter('id', 'in', profIds);

      if (excludeAdmins) {
        query = query.or('tipo.is.null,tipo.eq.profissional,tipo.eq.parceiro');
      }

      final profsResponse = await query.order('nome_completo');
      
      final List<Map<String, dynamic>> profs = List<Map<String, dynamic>>.from(profsResponse);
      
      final List<Map<String, dynamic>> filtered = excludeAdmins 
        ? profs.where((p) {
            final String name = (p['nome_completo'] ?? '').toLowerCase();
            return !name.contains('administrador');
          }).toList()
        : profs;

      return filtered.map((m) => ProfessionalModel.fromMap(m)).toList();
    } catch (e) {
      debugPrint('SUPABASE_ERROR: getProfessionalsByPackage failed: $e');
      return [];
    }
  }

  // Preserve existing helper methods
  Future<bool> checkProfessionalAvailability({
    required String profId,
    required DateTime startDateTime,
    required int durationMinutes,
    String? excludeAppointmentId,
  }) async {
    try {
      final endDateTime = startDateTime.add(Duration(minutes: durationMinutes));
      final dateStr = DateFormat('yyyy-MM-dd').format(startDateTime);
      final dayOfWeek = startDateTime.weekday == 7 ? 0 : startDateTime.weekday;

      if (await isDateBlocked(profId, startDateTime)) return false;

      final workingHours = await getProfessionalWorkingHours(profId);
      final dayWork = workingHours.firstWhere(
        (h) => h['dia_semana'] == dayOfWeek,
        orElse: () => {'fechado': true},
      );
      if (dayWork['fechado'] == true) return false;

      final workStart = _parseTimeOfDay(dayWork['hora_inicio'], startDateTime);
      final workEnd = _parseTimeOfDay(dayWork['hora_fim'], startDateTime);
      if (startDateTime.isBefore(workStart) || endDateTime.isAfter(workEnd)) return false;

      final lunchHours = await getProfessionalLunchHours(profId);
      final dayLunch = lunchHours.firstWhere(
        (h) => h['dia_semana'] == dayOfWeek,
        orElse: () => {'ativo': false},
      );
      if (dayLunch['ativo'] == true) {
        final lunchStart = _parseTimeOfDay(dayLunch['hora_inicio'], startDateTime);
        final lunchEnd = _parseTimeOfDay(dayLunch['hora_fim'], startDateTime);
        if (startDateTime.isBefore(lunchEnd) && endDateTime.isAfter(lunchStart)) return false;
      }

      final blocks = await getAgendaBlocks(profId: profId);
      for (var block in blocks) {
        if (block['data'] != dateStr) continue;
        if (block['dia_todo'] == true) return false;
        if (block['hora_inicio'] != null && block['hora_fim'] != null) {
          final blockStart = _parseTimeOfDay(block['hora_inicio'], startDateTime);
          final blockEnd = _parseTimeOfDay(block['hora_fim'], startDateTime);
          if (startDateTime.isBefore(blockEnd) && endDateTime.isAfter(blockStart)) return false;
        }
      }

      final occupied = await getOccupiedTimes(
        profId: profId,
        date: startDateTime,
        excludeId: excludeAppointmentId,
      );
      for (var occ in occupied) {
        final occStart = occ['dateTime'] as DateTime;
        final occEnd = occStart.add(Duration(minutes: occ['duration'] as int));
        if (startDateTime.isBefore(occEnd) && endDateTime.isAfter(occStart)) return false;
      }

      return true;
    } catch (e) {
      debugPrint('Erro ao verificar disponibilidade: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getOccupiedTimes({
    required String profId,
    required DateTime date,
    String? excludeId,
    String? clientId,
  }) async {
    try {
      final start = DateTime(date.year, date.month, date.day, 0, 0, 0);
      final end = DateTime(date.year, date.month, date.day, 23, 59, 59);

      var profQuery = _supabase
          .from('agendamentos')
          .select('data_hora, servicos(duracao_minutos)')
          .eq('profissional_id', profId)
          .gte('data_hora', start.toUtc().toIso8601String())
          .lt('data_hora', end.toUtc().toIso8601String())
          .neq('status', 'cancelado');
          
      if (excludeId != null) {
        profQuery = profQuery.neq('id', excludeId);
      }
      
      final profResponse = await profQuery;
      final List<Map<String, dynamic>> results = (profResponse as List).map((occ) => {
        'dateTime': DateTime.parse(occ['data_hora']).toLocal(),
        'duration': occ['servicos']?['duracao_minutos'] ?? 60,
      }).toList();

      // 2. Ocupação do Cliente (se fornecido) para evitar conflitos de horário do mesmo cliente
      if (clientId != null) {
        var clientQuery = _supabase
            .from('agendamentos')
            .select('data_hora, servicos(duracao_minutos)')
            .eq('cliente_id', clientId)
            .gte('data_hora', start.toUtc().toIso8601String())
            .lt('data_hora', end.toUtc().toIso8601String())
            .neq('status', 'cancelado');

        if (excludeId != null) {
          clientQuery = clientQuery.neq('id', excludeId);
        }

        final clientResponse = await clientQuery;
        for (var occ in (clientResponse as List)) {
          final dt = DateTime.parse(occ['data_hora']).toLocal();
          // Evita duplicidade se o cliente estiver agendado com o MESMO profissional (já pego acima)
          if (!results.any((r) => r['dateTime'] == dt)) {
            results.add({
              'dateTime': dt,
              'duration': occ['servicos']?['duracao_minutos'] ?? 60,
            });
          }
        }
      }
      
      return results;
    } catch (e) {
      debugPrint('Erro ao carregar horários ocupados: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAgendaBlocks({String? profId, DateTime? date}) async {
    try {
      var query = _supabase.from('bloqueios_agenda').select();
      if (profId != null) {
        query = query.or('profissional_id.eq.$profId,profissional_id.is.null');
      }
      if (date != null) {
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        query = query.eq('data', dateStr);
      }
      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Erro ao carregar bloqueios: $e');
      return [];
    }
  }

  Future<bool> isDateBlocked(String profId, DateTime date) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final response = await _supabase
          .from('bloqueios_agenda')
          .select()
          .eq('profissional_id', profId)
          .eq('data', dateStr)
          .eq('dia_todo', true);
      return (response as List).isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  DateTime _parseTimeOfDay(String time, DateTime baseDate) {
    final parts = time.split(':');
    return DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }
}
