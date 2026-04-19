import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

class DashboardStats {
  final double faturamento;
  final int totalAtendimentos;
  final int totalClientes;
  final int totalProcedimentos;
  final int totalAvaliacoes;

  DashboardStats({
    required this.faturamento,
    required this.totalAtendimentos,
    required this.totalClientes,
    required this.totalProcedimentos,
    required this.totalAvaliacoes,
  });
}

class DashboardAtividade {
  final String id;
  final String tipo;
  final String titulo;
  final String descricao;
  final DateTime criadoEm;
  final bool isLida;
  final Map<String, dynamic>? metadata;
  final String? actorName; // NOVO: Nome de quem realizou a ação

  DashboardAtividade({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.descricao,
    required this.criadoEm,
    this.isLida = false,
    this.metadata,
    this.actorName,
  });

  String get formattedTime => DateFormat('HH:mm').format(criadoEm);

  String get displayDescription {
    if (tipo == 'agendamento' || tipo == 'confirmacao' || tipo == 'reagendamento') {
      try {
        if (metadata != null && metadata!.containsKey('data_hora')) {
          final dt = DateTime.parse(metadata!['data_hora']).toLocal();
          final df = DateFormat('dd/MM/yyyy \'às\' HH:mm');
          
          String base = descricao;
          // Se a descrição original tiver um horário UTC (ex: 17:00), vamos tentar substituir pelo local
          // Mas como a descrição pode variar, o ideal é reconstruir ou apenas garantir o intervalo se tivermos duração.
          
          if (metadata!.containsKey('duracao_minutos')) {
            final dur = metadata!['duracao_minutos'] as int;
            final end = dt.add(Duration(minutes: dur));
            final interval = "${DateFormat('HH:mm').format(dt)} - ${DateFormat('HH:mm').format(end)}";
            
            final cliente = metadata!['cliente'] ?? 'Cliente';
            final prof = metadata!['profissional'] ?? 'Profissional';
            final proc = metadata!['procedimento'] ?? 'Procedimento';
            
            if (tipo == 'agendamento') {
              return "Novo agendamento: $proc com $prof às $interval no dia ${DateFormat('dd/MM').format(dt)}.";
            } else if (tipo == 'confirmacao') {
              return "$cliente confirmou $proc com $prof para $interval no dia ${DateFormat('dd/MM').format(dt)}.";
            }
          }
        }
      } catch (e) {
        debugPrint('Erro ao formatar displayDescription: $e');
      }
    }
    return descricao;
  }

  String get fullDateLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final activityDate = DateTime(criadoEm.year, criadoEm.month, criadoEm.day);

    if (activityDate == today) return 'HOJE';
    if (activityDate == yesterday) return 'ONTEM';
    
    String formatted = DateFormat('EEEE, d \'de\' MMMM \'de\' y', 'pt_BR').format(criadoEm);
    List<String> parts = formatted.split(',');
    if (parts.length > 1) {
      String dayOfWeek = parts[0];
      dayOfWeek = dayOfWeek.split('-').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w).join('-');
      return '$dayOfWeek,${parts[1]}';
    }
    return formatted;
  }

  factory DashboardAtividade.fromMap(Map<String, dynamic> map) {
    return DashboardAtividade(
      id: map['id'],
      tipo: map['tipo'],
      titulo: map['titulo'],
      descricao: map['descricao'],
      criadoEm: DateTime.parse(map['criado_em'] ?? DateTime.now().toIso8601String()).toLocal(),
      isLida: map.containsKey('is_lida') ? (map['is_lida'] ?? false) : false,
      metadata: _parseMetadata(map['metadata']),
      actorName: map['actor'] != null ? map['actor']['nome_completo'] : null,
    );
  }

  static Map<String, dynamic>? _parseMetadata(dynamic metadata) {
    if (metadata == null) return null;
    if (metadata is Map<String, dynamic>) return metadata;
    if (metadata is Map) return Map<String, dynamic>.from(metadata);
    if (metadata is String) {
      try {
        return jsonDecode(metadata) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

class SupabaseDashboardRepository {
  final _supabase = Supabase.instance.client;

  Future<DashboardStats> getStats(DateTime start, DateTime end) async {
    try {
      final startStr = start.toIso8601String();
      final endStr = end.toIso8601String();

      // 1. Faturamento (Agendamentos)
      final faturamentoRes = await _supabase
          .from('agendamentos')
          .select('valor_total')
          .filter('status', 'in', '("concluido", "confirmado")')
          // .filter('pago', 'eq', true) // Removido para bater com o caixa que considera confirmados
          .gte('data_hora', startStr)
          .lte('data_hora', endStr);

      double faturamentoAgendamentos = 0;
      for (var item in (faturamentoRes as List)) {
        faturamentoAgendamentos += (item['valor_total'] ?? 0).toDouble();
      }

      // 1.2 Faturamento (Produtos) - da tabela contas
      final faturamentoProdutosRes = await _supabase
          .from('contas')
          .select('valor')
          .eq('categoria', 'venda_produto')
          .gte('data_pagamento', startStr)
          .lte('data_pagamento', endStr);

      double faturamentoProdutos = 0;
      for (var item in (faturamentoProdutosRes as List)) {
        faturamentoProdutos += (item['valor'] ?? 0).toDouble();
      }

      double faturamento = faturamentoAgendamentos + faturamentoProdutos;

      // 2. Total Atendimentos (Fallback to .length)
      final atendimentosRes = await _supabase
          .from('agendamentos')
          .select('id')
          .gte('data_hora', startStr)
          .lte('data_hora', endStr);

      // 3. Total Clientes
      final clientesRes = await _supabase
          .from('perfis')
          .select('id')
          .eq('tipo', 'cliente');

      // 5. Total Avaliações
      final avaliacoesRes = await _supabase
          .from('avaliacoes')
          .select('id');

      // 6. Total Procedimentos (Serviços concluídos no período)
      final procedimentosRes = await _supabase
          .from('agendamentos')
          .select('id')
          .eq('status', 'concluido')
          .gte('data_hora', startStr)
          .lte('data_hora', endStr);

      return DashboardStats(
        faturamento: faturamento,
        totalAtendimentos: (atendimentosRes as List).length,
        totalClientes: (clientesRes as List).length,
        totalProcedimentos: (procedimentosRes as List).length,
        totalAvaliacoes: (avaliacoesRes as List).length,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<List<DashboardAtividade>> getRecentActivities({int limit = 5}) async {
    try {
      final response = await _supabase
          .from('dashboard_atividades')
          .select()
          .order('criado_em', ascending: false)
          .limit(limit);

      return (response as List)
          .map((data) => DashboardAtividade.fromMap(data))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<DashboardAtividade>> getAllActivities({
    DateTime? start,
    DateTime? end,
    String? userId,
    bool newestFirst = true,
  }) async {
    try {
      var query = _supabase
          .from('dashboard_atividades')
          .select('*, actor:perfis(nome_completo)');

      if (start != null) {
        query = query.gte('criado_em', start.toIso8601String());
      }
      if (end != null) {
        query = query.lte('criado_em', end.toIso8601String());
      }
      if (userId != null && userId.isNotEmpty) {
        query = query.eq('user_id', userId);
      }

      final response = await query.order('criado_em', ascending: !newestFirst);

      return (response as List)
          .map((data) => DashboardAtividade.fromMap(data))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> markAsRead(String id) async {
    await _supabase.from('dashboard_atividades').update({'is_lida': true}).eq('id', id);
  }

  Future<void> markAllAsRead() async {
    await _supabase.from('dashboard_atividades').update({'is_lida': true}).eq('is_lida', false);
  }

  Future<int> countUnread() async {
    final res = await _supabase
        .from('dashboard_atividades')
        .select('id')
        .eq('is_lida', false);
    return (res as List).length;
  }

  Future<void> logActivity({
    required String tipo,
    required String titulo,
    required String descricao,
    String? userId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Usamos RPC (registrar_atividade_dashboard) em vez de insert direto para evitar erros de RLS.
      // A função no banco possui SECURITY DEFINER, permitindo que qualquer usuário autenticado
      // registre atividades (ex: novo cadastro, login) com as permissões do sistema.
      await _supabase.rpc('registrar_atividade_dashboard', params: {
        'p_tipo': tipo,
        'p_titulo': titulo,
        'p_descricao': descricao,
        'p_metadata': metadata ?? {},
        'p_user_id': userId,
      });
    } catch (e) {
      debugPrint('Erro ao logar atividade via RPC: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAdminUsers() async {
    try {
      final response = await _supabase
          .from('perfis')
          .select('id, nome_completo, tipo, email')
          .inFilter('tipo', ['admin', 'profissional'])
          .order('nome_completo');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Erro ao buscar usuários admin: $e');
      return [];
    }
  }
}

