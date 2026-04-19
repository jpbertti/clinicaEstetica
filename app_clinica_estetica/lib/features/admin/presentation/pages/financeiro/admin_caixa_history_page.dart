import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_caixa_repository.dart';
import 'package:app_clinica_estetica/core/services/pdf_service.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '0,00');
    }
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (newText.isEmpty) newText = '0';
    double value = double.parse(newText) / 100;
    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: '');
    String formatted = formatter.format(value).trim();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class AdminCaixaHistoryPage extends StatefulWidget {
  const AdminCaixaHistoryPage({super.key});

  @override
  State<AdminCaixaHistoryPage> createState() => _AdminCaixaHistoryPageState();
}

class _AdminCaixaHistoryPageState extends State<AdminCaixaHistoryPage> {
  final _caixaRepo = SupabaseCaixaRepository();
  bool _isLoading = true;
  bool _hasOpenCaixa = false;
  List<Map<String, dynamic>> _history = [];
  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  DateTime? _selectedDate;
  static final primaryColor = AppColors.primary;
  static final accentColor = AppColors.accent;
  static final bgColor = AppColors.background;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final history = await _caixaRepo.getCaixaHistory();
      final hasOpen = history.any((c) => c['status'] == 'aberto');
      setState(() {
        _history = history;
        _hasOpenCaixa = hasOpen;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar histórico: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredHistory {
    if (_selectedDate == null) return _history;
    return _history.where((c) {
      final date = DateTime.parse(c['aberto_em']).toLocal();
      return date.year == _selectedDate!.year &&
             date.month == _selectedDate!.month &&
             date.day == _selectedDate!.day;
    }).toList();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _editCaixa(Map<String, dynamic> caixa) async {
    final saldoController = TextEditingController(text: caixa['saldo_final_real'].toString());
    final obsController = TextEditingController(text: caixa['observacoes'] ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar Registro de Caixa', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: saldoController,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Saldo Final Real',
                prefixText: 'R\$ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: obsController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Observações',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() => _isLoading = true);
      try {
        final cleanText = saldoController.text.replaceAll('.', '').replaceAll(',', '.');
        final double novoSaldo = double.tryParse(cleanText) ?? 0;
        
        await _caixaRepo.updateCaixa(caixa['id'], {
          'saldo_final_real': novoSaldo,
          'observacoes': obsController.text,
        });
        await _loadHistory();
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao atualizar: $e')),
          );
        }
      }
    }
  }

  Future<void> _reopenCaixa(Map<String, dynamic> caixa) async {
    // 1. Verificar se já existe um caixa aberto
    if (_hasOpenCaixa) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Já existe um caixa aberto. Feche-o antes de reabrir outro.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reabrir Caixa'),
        content: const Text('Deseja realmente reabrir este caixa? Isso permitirá editar pagamentos vinculados a ele.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reabrir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _caixaRepo.reopenCaixa(caixa['id']);
        await _loadHistory();
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao reabrir: $e')),
          );
        }
      }
    }
  }

  void _showCaixaDetails(Map<String, dynamic> caixa) async {
    setState(() => _isLoading = true);
    try {
      final stats = await _caixaRepo.getDetailedStats(caixa['id']);
      setState(() => _isLoading = false);

      if (!mounted) return;

      final saldoInicial = (caixa['saldo_inicial'] as num?)?.toDouble() ?? 0.0;
      final entradas = (stats['total_entradas'] as num?)?.toDouble() ?? 0.0;
      final saidas = (stats['total_apenas_saidas'] as num?)?.toDouble() ?? 0.0;
      final sangrias = (stats['total_sangrias'] as num?)?.toDouble() ?? 0.0;
      final saldoFinalSistemo = saldoInicial + entradas - saidas - sangrias;
      final saldoFinalReal = (caixa['saldo_final_real'] as num?)?.toDouble() ?? 0.0;

      // Preparar lista unificada de movimentos
      List<Map<String, dynamic>> todosMovimentos = [];
      
      // Adicionar Entradas
      if (stats['por_meio_pagamento'] != null) {
        (stats['por_meio_pagamento'] as Map).forEach((meio, data) {
          final transacoes = data['transacoes'] as List;
          for (var t in transacoes) {
            final isConta = t.containsKey('titulo');
            final dataStr = isConta ? (t['data_pagamento'] ?? t['created_at']) : (t['data'] ?? t['data_hora']);
            
            todosMovimentos.add({
              'id': t['id'],
              'tipo': 'entrada',
              'item_tipo': isConta ? 'produto' : 'servico',
              'titulo': isConta ? t['titulo'] : (t['servicos']?['nome'] ?? 'Serviço'),
              'infos': isConta 
                  ? '${t['descricao'] ?? 'Venda de Produto'} (${meio.toString().toUpperCase()})'
                  : 'Cliente: ${t['cliente']?['nome_completo'] ?? t['cliente_nome'] ?? 'N/A'} (${meio.toString().toUpperCase()})',
              'valor': ( (isConta ? t['valor'] : t['valor_total']) as num?)?.toDouble() ?? 0.0,
              'data': dataStr != null ? DateTime.parse(dataStr) : DateTime.now(),
            });
          }
        });
      }

      // Adicionar Saídas
      final saidasLista = stats['saidas_detalhes'] as List;
      for (var s in saidasLista) {
        final dataStr = s['data_pagamento'] ?? s['created_at'];
        todosMovimentos.add({
          'id': s['id'],
          'tipo': 'saida',
          'titulo': s['titulo'] ?? 'Despesa',
          'infos': s['categoria']?.toString().toUpperCase() ?? 'GERAL',
          'valor': -( (s['valor'] as num?)?.toDouble() ?? 0.0 ),
          'data': dataStr != null ? DateTime.parse(dataStr) : DateTime.now(),
        });
      }

      // Adicionar Sangrias
      final sangriasLista = stats['sangrias_detalhes'] as List;
      for (var s in sangriasLista) {
        final dataStr = s['data_pagamento'] ?? s['created_at'];
        todosMovimentos.add({
          'id': s['id'],
          'tipo': 'sangria',
          'titulo': 'Sangria/Retirada',
          'infos': s['titulo']?.toString().replaceFirst('Sangria: ', '') ?? 'N/A',
          'valor': -( (s['valor'] as num?)?.toDouble() ?? 0.0 ),
          'data': dataStr != null ? DateTime.parse(dataStr) : DateTime.now(),
        });
      }

      // Ordenar por data
      todosMovimentos.sort((a, b) => (b['data'] as DateTime).compareTo(a['data'] as DateTime));

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Relatório Detalhado', style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  IconButton(
                    onPressed: () => PdfService.generateCaixaReport(
                      caixa: caixa,
                      stats: stats,
                      movimentos: todosMovimentos,
                    ),
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                    tooltip: 'Gerar PDF',
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryItem('Saldo Inicial', _currencyFormat.format(saldoInicial)),
                        _buildSummaryItem('Total Entradas (+)', _currencyFormat.format(entradas), color: Colors.green),
                        _buildSummaryItem('Total Saídas (-)', _currencyFormat.format(saidas + sangrias), color: Colors.red),
                        const Divider(),
                        _buildSummaryItem('Saldo Final (Sistemo)', _currencyFormat.format(saldoFinalSistemo), isBold: true),
                        _buildSummaryItem('Saldo Final (Real)', _currencyFormat.format(saldoFinalReal), isBold: true, color: Colors.blue),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Movimentações', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                  const SizedBox(height: 12),
                  if (todosMovimentos.isEmpty)
                    const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('Nenhuma movimentação registrada.')))
                  else
                    ...todosMovimentos.map((m) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(left: BorderSide(
                          color: m['tipo'] == 'entrada' ? Colors.green : (m['tipo'] == 'sangria' ? Colors.orange : Colors.red),
                          width: 4,
                        )),
                        color: Colors.white,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            m['tipo'] == 'entrada' ? Icons.add_circle_outline : (m['tipo'] == 'sangria' ? Icons.outbox : Icons.remove_circle_outline),
                            color: m['tipo'] == 'entrada' ? Colors.green : (m['tipo'] == 'sangria' ? Colors.orange : Colors.red),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m['titulo'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(m['infos'], style: TextStyle(fontSize: 11, color: Colors.black54)),
                              ],
                            ),
                          ),
                          Text(
                            _currencyFormat.format(m['valor']),
                            style: TextStyle(fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: m['valor'] >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    )),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar detalhes: $e')));
      }
    }
  }

  Widget _buildSummaryItem(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13)),
          Text(
            value,
            style: TextStyle(fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Histórico de Caixas',
          style: TextStyle(fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        actions: [
          if (_selectedDate != null)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () => setState(() => _selectedDate = null),
              tooltip: 'Limpar Filtro',
            ),
          IconButton(
            icon: Icon(Icons.calendar_month, color: primaryColor),
            onPressed: _selectDate,
            tooltip: 'Filtrar por data',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredHistory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off, size: 64, color: Colors.black12),
                      const SizedBox(height: 16),
                      Text(
                        _selectedDate == null 
                          ? 'Nenhum registro encontrado.'
                          : 'Nenhum registro em ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}',
                        style: TextStyle(color: Colors.black45),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredHistory.length,
                  itemBuilder: (context, index) {
                    final caixa = _filteredHistory[index];
                    final abertoEm = DateTime.parse(caixa['aberto_em']);
                    final fechadoEm = caixa['fechado_em'] != null ? DateTime.parse(caixa['fechado_em']) : null;
                    final isAberto = caixa['status'] == 'aberto';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ExpansionTile(
                          shape: const RoundedRectangleBorder(side: BorderSide.none),
                          collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                          leading: CircleAvatar(
                            backgroundColor: isAberto ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                            child: Icon(
                              isAberto ? Icons.lock_open : Icons.lock,
                              color: isAberto ? Colors.green : Colors.blue,
                              size: 20,
                            ),
                          ),
                        title: Text(
                          DateFormat('dd/MM/yyyy').format(abertoEm.toLocal()),
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          isAberto ? 'Aberto às ${DateFormat('HH:mm').format(abertoEm.toLocal())}' : 'Fechado às ${DateFormat('HH:mm').format(fechadoEm!.toLocal())}',
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _editCaixa(caixa),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildDetailRow('Status', caixa['status'].toUpperCase()),
                                _buildDetailRow('Operador', (caixa['usuario_id'] ?? 'N/A').toString().substring(0, 8)),
                                _buildDetailRow('Saldo Inicial', _currencyFormat.format(caixa['saldo_inicial'] ?? 0)),
                                _buildDetailRow('Total Entradas', _currencyFormat.format(caixa['total_entradas'] ?? 0)),
                                _buildDetailRow('Total Saídas', _currencyFormat.format(caixa['total_saidas'] ?? 0)),
                                _buildDetailRow('Saldo Final (Sistemo)', _currencyFormat.format( (caixa['saldo_inicial'] ?? 0) + (caixa['total_entradas'] ?? 0) - (caixa['total_saidas'] ?? 0) )),
                                _buildDetailRow('Saldo Final (Físico)', _currencyFormat.format(caixa['saldo_final_real'] ?? 0), isBold: true),
                                if (caixa['observacoes'] != null && caixa['observacoes'].toString().isNotEmpty)
                                  _buildDetailRow('Observações', caixa['observacoes']),
                                const SizedBox(height: 16),
                                Center(
                                  child: TextButton.icon(
                                    onPressed: () => _showCaixaDetails(caixa),
                                    icon: const Icon(Icons.analytics_outlined),
                                    label: const Text('Ver Detalhes do Caixa'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: primaryColor,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                    ),
                                  ),
                                ),
                                if (!isAberto) ...[
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () => _reopenCaixa(caixa),
                                        icon: const Icon(Icons.lock_open, size: 18),
                                        label: const Text('Reabrir Caixa'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(color: Colors.red),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.black54, fontSize: 13)),
          Text(
            value,
            style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

