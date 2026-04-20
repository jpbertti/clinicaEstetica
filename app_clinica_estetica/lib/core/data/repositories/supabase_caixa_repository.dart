import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/caixa_model.dart';

class SupabaseCaixaRepository {
  final _supabase = Supabase.instance.client;

  Future<CaixaModel?> getActiveCaixa() async {
    try {
      final response = await _supabase
          .from('caixas')
          .select()
          .eq('status', 'aberto')
          .maybeSingle();

      if (response == null) return null;
      return CaixaModel.fromMap(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<CaixaModel> abrirCaixa(double saldoInicial, String usuarioId) async {
    try {
      final response = await _supabase
          .from('caixas')
          .insert({
            'usuario_id': usuarioId,
            'saldo_inicial': saldoInicial,
            'status': 'aberto',
          })
          .select()
          .single();

      return CaixaModel.fromMap(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getDetailedStats(String caixaId) async {
    try {
      // 1. Buscar Agendamentos (Usados para o histórico detalhado e metadata de serviços)
      final entriesRes = await _supabase
          .from('agendamentos')
          .select('*, servicos(nome), cliente:cliente_id(nome_completo), profissional:profissional_id(nome_completo)')
          .eq('caixa_id', caixaId)
          .eq('pago', true);
      
      // 2. Buscar Contas (Centraliza tudo o que é financeiro: Vendas de Produtos, Despesas, Agendamentos duplicados via trigger)
      final expensesRes = await _supabase
          .from('contas')
          .select('*, criado_por(nome_completo), cliente:cliente_id(nome_completo), profissional:profissional_id(nome_completo)')
          .eq('caixa_id', caixaId)
          .eq('status_pagamento', 'pago');

      Map<String, Map<String, dynamic>> porMeio = {
        'dinheiro': {'valor_total': 0.0, 'transacoes': []},
        'pix': {'valor_total': 0.0, 'transacoes': []},
        'cartao_credito': {'valor_total': 0.0, 'transacoes': []},
        'cartao_debito': {'valor_total': 0.0, 'transacoes': []},
        'transferencia': {'valor_total': 0.0, 'transacoes': []},
        'convenio': {'valor_total': 0.0, 'transacoes': []},
        'outro': {'valor_total': 0.0, 'transacoes': []},
      };

      double totalEntradas = 0;
      double totalSaidas = 0;
      double totalSangrias = 0;
      int numMovimentacoes = 0;
      
      List transactionExits = [];
      List transactionOtherEntries = [];
      List sangrias = [];

      // Processar Agendamentos primeiro (para ter o label 'Agenda' no UI)
      final entriesData = entriesRes as List? ?? [];
      for (var row in entriesData) {
        final valor = (row['valor_total'] as num?)?.toDouble() ?? 0.0;
        final meio = (row['forma_pagamento']?.toString() ?? 'outro').toLowerCase();
        
        totalEntradas += valor;
        numMovimentacoes++;
        
        final key = porMeio.containsKey(meio) ? meio : 'outro';
        porMeio[key]!['valor_total'] = (porMeio[key]!['valor_total'] as double) + valor;
        (porMeio[key]!['transacoes'] as List).add(row);
      }

      // Processar Contas
      final expensesData = expensesRes as List? ?? [];
      for (var row in expensesData) {
        final valor = (row['valor'] as num?)?.toDouble() ?? 0.0;
        final categoria = (row['categoria']?.toString() ?? '').toLowerCase();
        final tipo = (row['tipo_conta']?.toString() ?? '').toLowerCase();
        final meio = (row['forma_pagamento']?.toString() ?? 'outro').toLowerCase();

        // EVITAR DUPLICIDADE: Se a categoria for 'procedimento', ela já veio do loop de agendamentos acima
        if (categoria == 'procedimento') {
          continue;
        }

        if (tipo == 'receber') {
          totalEntradas += valor;
          numMovimentacoes++;
          transactionOtherEntries.add(row);
          
          final key = porMeio.containsKey(meio) ? meio : 'outro';
          porMeio[key]!['valor_total'] = (porMeio[key]!['valor_total'] as double) + valor;
          (porMeio[key]!['transacoes'] as List).add(row);
        } else if (categoria == 'sangria' || categoria == 'retirada') {
          totalSangrias += valor;
          numMovimentacoes++;
          sangrias.add(row);
        } else {
          // Despesas normais
          totalSaidas += valor;
          numMovimentacoes++;
          transactionExits.add(row);
        }
      }

      return {
        'total_entradas': totalEntradas,
        'total_saidas': totalSaidas + totalSangrias,
        'total_apenas_saidas': totalSaidas,
        'total_sangrias': totalSangrias,
        'por_meio_pagamento': porMeio,
        'num_movimentacoes': numMovimentacoes,
        'saidas_detalhes': transactionExits,
        'sangrias_detalhes': sangrias,
        'entradas_outras_detalhes': transactionOtherEntries,
      };
    } catch (e) {
      rethrow;
    }
  }

  Future<void> registrarSangria({
    required String caixaId,
    required double valor,
    required String motivo,
    required String meio,
    required String usuarioId,
  }) async {
    try {
      await _supabase.from('contas').insert({
        'titulo': 'Sangria: $motivo',
        'descricao': 'Retirada de caixa ($meio)',
        'valor': valor,
        'tipo_conta': 'pagar',
        'status_pagamento': 'pago',
        'categoria': 'sangria',
        'data_vencimento': DateTime.now().toIso8601String(),
        'data_pagamento': DateTime.now().toIso8601String(),
        'caixa_id': caixaId,
        'criado_por': usuarioId,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> fecharCaixa(String id, double saldoFinalReal, String observacoes) async {
    try {
      // 1. Obter estatísticas detalhadas do caixa
      await _supabase.from('caixas').update({
        'status': 'fechado',
        'fechado_em': DateTime.now().toIso8601String(),
        'saldo_final_real': saldoFinalReal,
        'observacoes': observacoes,
      }).eq('id', id);
    } catch (e) {
      rethrow;
    }
  }

  /// Reabre um caixa fechado, desde que não haja outro aberto
  Future<void> reopenCaixa(String id) async {
    try {
      // 1. Verificar se já existe um caixa aberto
      final active = await getActiveCaixa();
      if (active != null) {
        throw 'Já existe um caixa aberto. Feche o caixa atual antes de reabrir um antigo.';
      }

      // 2. Reabrir o caixa
      await _supabase.from('caixas').update({
        'status': 'aberto',
        'fechado_em': null,
      }).eq('id', id);
    } catch (e) {
      rethrow;
    }
  }

  /// Atualiza dados de uma transação (Agendamento ou Conta/Produto)
  Future<void> updateTransaction(String id, Map<String, dynamic> updates, bool isAgendamento) async {
    try {
      if (isAgendamento) {
        await _supabase.from('agendamentos').update(updates).eq('id', id);
      } else {
        await _supabase.from('contas').update(updates).eq('id', id);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getCaixaHistory() async {
    try {
      final res = await _supabase
          .from('caixas')
          .select('id, aberto_em, fechado_em, saldo_inicial, total_entradas, total_saidas, saldo_final_real, status, usuario_id')
          .order('aberto_em', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateCaixa(String id, Map<String, dynamic> updates) async {
    try {
      await _supabase.from('caixas').update(updates).eq('id', id);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateAgendamentoPagamento(String id, Map<String, dynamic> updates) async {
    try {
      await _supabase.from('agendamentos').update(updates).eq('id', id);
    } catch (e) {
      rethrow;
    }
  }
}

