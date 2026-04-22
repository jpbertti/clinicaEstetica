import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_clinica_estetica/core/data/models/caixa_model.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_caixa_repository.dart';
import 'package:flutter/services.dart';
import 'admin_caixa_history_page.dart';
import 'package:app_clinica_estetica/core/services/pdf_service.dart';
import 'package:app_clinica_estetica/core/services/report_app_bar_service.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';
import 'package:app_clinica_estetica/core/theme/app_button_styles.dart';
import 'package:app_clinica_estetica/core/utils/string_utils.dart';
import 'package:app_clinica_estetica/core/theme/app_text_styles.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '0,00');
    }

    // Remove tudo que não for dígito
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Se for vazio após remover não-dígitos, retorna zeros
    if (newText.isEmpty) newText = '0';
    
    // Converte para valor decimal
    double value = double.parse(newText) / 100;
    
    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: '');
    String formatted = formatter.format(value).trim();
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class AdminCaixaPage extends StatefulWidget {
  const AdminCaixaPage({super.key});

  @override
  State<AdminCaixaPage> createState() => _AdminCaixaPageState();
}

class _AdminCaixaPageState extends State<AdminCaixaPage> {
  final _caixaRepo = SupabaseCaixaRepository();
  bool _isLoading = true;
  CaixaModel? _activeCaixa;
  Map<String, dynamic>? _detailedStats;
  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final primaryColor = AppColors.primary;
  final accentColor = AppColors.accent;

  @override
  void initState() {
    super.initState();
    _loadCaixaStatus();
  }

  Future<void> _loadCaixaStatus() async {
    setState(() => _isLoading = true);
    try {
      final caixa = await _caixaRepo.getActiveCaixa();
      Map<String, dynamic>? stats;
      if (caixa != null) {
        stats = await _caixaRepo.getDetailedStats(caixa.id);
      }
      
      setState(() {
        _activeCaixa = caixa;
        _detailedStats = stats;
        _isLoading = false;
        
        // Configura ações no AppBar da Shell
        if (caixa != null) {
          ReportAppBarService().setActions(
            title: 'Fluxo de caixa',
            onPdf: _gerarPdfCaixaAtual,
          );
        } else {
          ReportAppBarService().reset();
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar status do caixa: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    ReportAppBarService().reset();
    super.dispose();
  }

  Future<void> _abrirCaixa() async {
    final controller = TextEditingController(text: '0,00');
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Abrir caixa', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Informe o saldo inicial em dinheiro no caixa'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Saldo inicial',
                prefixText: 'R\$ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(StringUtils.toTitleCase('Cancelar'), style: AppButtonStyles.cancelTextStyle()),
          ),
          ElevatedButton(
            onPressed: () {
              // Limpa a formatação de moeda antes de converter
              final cleanText = controller.text.replaceAll('.', '').replaceAll(',', '.');
              final val = double.tryParse(cleanText) ?? 0;
              Navigator.pop(context, val);
            },
            style: AppButtonStyles.primary(),
            child: Text(StringUtils.toTitleCase('Abrir caixa')),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        final userId = Supabase.instance.client.auth.currentUser!.id;
        await _caixaRepo.abrirCaixa(result, userId);
        await _loadCaixaStatus();
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao abrir caixa: $e')),
          );
        }
      }
    }
  }

  Future<void> _fecharCaixa() async {
    if (_activeCaixa == null) return;

    final entradas = (_detailedStats?['total_entradas'] as num?)?.toDouble() ?? 0;
    final saidas = (_detailedStats?['total_saidas'] as num?)?.toDouble() ?? 0;
    final expectedBalance = _activeCaixa!.saldoInicial + entradas - saidas;

    final controller = TextEditingController(
      text: _currencyFormat.format(expectedBalance).replaceAll('R\$\u{00A0}', ''),
    );
    final obsController = TextEditingController();
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fluxo de caixa',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Informe o valor total REAL encontrado no caixa (dinheiro + comprovantes)'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Valor em caixa',
                prefixText: 'R\$ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: obsController,
              decoration: const InputDecoration(
                labelText: 'Observações (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(StringUtils.toTitleCase('Cancelar'), style: AppButtonStyles.cancelTextStyle()),
          ),
          ElevatedButton(
            style: AppButtonStyles.primary(backgroundColor: Colors.red),
            onPressed: () {
              // Limpa a formatação de moeda antes de converter
              final cleanText = controller.text.replaceAll('.', '').replaceAll(',', '.');
              final val = double.tryParse(cleanText) ?? 0;
              Navigator.pop(context, {'valor': val, 'obs': obsController.text});
            },
            child: Text(StringUtils.toTitleCase('Confirmar fechamento')),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        await _caixaRepo.fecharCaixa(_activeCaixa!.id, result['valor'], result['obs']);
        await _loadCaixaStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Caixa fechado com sucesso!'), backgroundColor: AppColors.primary),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao fechar caixa: $e')),
          );
        }
      }
    }
  }

  void _gerarPdfCaixaAtual() {
    if (_activeCaixa == null || _detailedStats == null) return;

    // Preparar lista unificada de movimentos
    List<Map<String, dynamic>> todosMovimentos = [];
    final stats = _detailedStats!;
    
    // Adicionar Entradas do breakdown (Agendamentos e Vendas por Meio)
    if (stats['por_meio_pagamento'] != null) {
      (stats['por_meio_pagamento'] as Map).forEach((meio, data) {
        final transacoes = data['transacoes'] as List;
        for (var t in transacoes) {
          final isConta = t.containsKey('titulo');
          final titulo = isConta ? '[Venda] ${t['titulo']}' : '[Agenda] ${t['servicos']?['nome'] ?? 'Serviço'}';
          final subTitle = isConta ? (t['descricao'] ?? 'N/A') : 'Cli: ${t['cliente']?['nome_completo'] ?? 'N/A'}';
          
          final dataStr = isConta ? (t['data_pagamento'] ?? t['created_at']) : t['data_hora'];
          final data = dataStr != null ? DateTime.parse(dataStr) : DateTime.now();
          final valor = ((isConta ? t['valor'] : t['valor_total']) as num?)?.toDouble() ?? 0.0;

          todosMovimentos.add({
            'tipo': 'entrada',
            'titulo': titulo,
            'infos': '$subTitle (${meio.toString()})',
            'valor': valor,
            'data': data,
          });
        }
      });
    }

    // Adicionar Saídas
    final saidasLista = stats['saidas_detalhes'] as List;
    for (var s in saidasLista) {
      todosMovimentos.add({
        'tipo': 'saida',
        'titulo': s['titulo'] ?? 'Despesa',
        'infos': s['categoria']?.toString() ?? 'Geral',
        'valor': -( (s['valor'] as num?)?.toDouble() ?? 0.0 ),
        'data': DateTime.parse(s['data_pagamento']),
      });
    }

    // Adicionar Sangrias
    final sangriasLista = stats['sangrias_detalhes'] as List;
    for (var s in sangriasLista) {
      todosMovimentos.add({
        'tipo': 'sangria',
        'titulo': 'Sangria/Retirada',
        'infos': s['titulo']?.toString().replaceFirst('Sangria: ', '') ?? 'N/A',
        'valor': -( (s['valor'] as num?)?.toDouble() ?? 0.0 ),
        'data': DateTime.parse(s['data_pagamento']),
      });
    }

    // Ordenar por data
    todosMovimentos.sort((a, b) => (b['data'] as DateTime).compareTo(a['data'] as DateTime));

    PdfService.generateCaixaReport(
      caixa: _activeCaixa!.toMap()..['id'] = _activeCaixa!.id, // Converte modelo para mapa compatível
      stats: stats,
      movimentos: todosMovimentos,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activeCaixa == null
              ? _buildClosedState(AppColors.primary, AppColors.accent)
              : _buildOpenState(AppColors.primary, AppColors.accent),
    );
  }

  Widget _buildClosedState(Color primaryColor, Color accentColor) {
    return RefreshIndicator(
      onRefresh: _loadCaixaStatus,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.no_accounts_outlined, size: 80, color: primaryColor.withOpacity(0.3)),
                const SizedBox(height: 24),
                const Text(
                  'O caixa está fechado',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Abra o caixa para começar a registrar movimentações.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 32),
                SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _abrirCaixa,
                        icon: const Icon(Icons.lock_open),
                        label: Text(StringUtils.toTitleCase('Abrir caixa hoje')),
                        style: AppButtonStyles.primary(),
                      ),
                    ),
                const SizedBox(height: 12),
                SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AdminCaixaHistoryPage()),
                          );
                        },
                        icon: const Icon(Icons.history),
                        label: Text(StringUtils.toTitleCase('Acessar caixas anteriores')),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildOpenState(Color primaryColor, Color accentColor) {
    final entradas = (_detailedStats?['total_entradas'] as num?)?.toDouble() ?? 0;
    final saidas = (_detailedStats?['total_saidas'] as num?)?.toDouble() ?? 0;
    final movs = _detailedStats?['num_movimentacoes'] ?? 0;
    final expectedBalance = _activeCaixa!.saldoInicial + entradas - saidas;

    return RefreshIndicator(
      onRefresh: _loadCaixaStatus,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: primaryColor.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Caixa aberto', style: TextStyle(color: accentColor, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.2)),
                          const SizedBox(height: 4),
                          Text(
                            'Iniciado em ${DateFormat('dd/MM HH:mm').format(_activeCaixa!.abertoEm.toLocal())}',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                      const Icon(Icons.check_circle, color: Colors.greenAccent, size: 28),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Saldo em caixa', style: TextStyle(color: Colors.white60, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(
                    _currencyFormat.format(expectedBalance),
                    style: const TextStyle(fontFamily: 'Inter', color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(child: _buildSmallMetricCard('Saldo inicial', _currencyFormat.format(_activeCaixa?.saldoInicial ?? 0), Icons.login, Colors.blue)),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      final allTrans = <dynamic>[];
                      final porMeio = _detailedStats?['por_meio_pagamento'] as Map?;
                      if (porMeio != null) {
                        porMeio.forEach((_, data) {
                          allTrans.addAll(data['transacoes'] as List);
                        });
                      }
                      
                      // Adicionar vendas de produtos (da tabela contas)
                      // Nota: Já estão incluídos no breakdown se tiverem forma_pagamento, mas adicionamos
                      // apenas se houver algo exclusivo em entradas_outras_detalhes que não esteja na lista.
                      final otherEntries = _detailedStats?['entradas_outras_detalhes'] as List?;
                      if (otherEntries != null) {
                        for (var entry in otherEntries) {
                          if (!allTrans.any((t) => t['id'] == entry['id'])) {
                            allTrans.add(entry);
                          }
                        }
                      }
                      
                      // Ordenar por data (mais recente primeiro)
                      allTrans.sort((a, b) {
                        final dateAStr = a['data_hora'] ?? a['data_pagamento'] ?? a['criado_em'] ?? a['created_at'];
                        final dateBStr = b['data_hora'] ?? b['data_pagamento'] ?? b['criado_em'] ?? b['created_at'];
                        final dateA = dateAStr != null ? DateTime.parse(dateAStr) : DateTime.fromMillisecondsSinceEpoch(0);
                        final dateB = dateBStr != null ? DateTime.parse(dateBStr) : DateTime.fromMillisecondsSinceEpoch(0);
                        return dateB.compareTo(dateA);
                      });
                      
                      _showTransactionDetailsDialog('Todas as entradas', allTrans);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: _buildSmallMetricCard('Entradas', _currencyFormat.format(entradas), Icons.trending_up, Colors.green),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _showExpenseDetailsDialog(_detailedStats?['saidas_detalhes'] ?? []),
                    borderRadius: BorderRadius.circular(16),
                    child: _buildSmallMetricCard('Saídas', _currencyFormat.format(saidas - ( (_detailedStats?['total_sangrias'] as num?)?.toDouble() ?? 0 )), Icons.trending_down, Colors.red),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _showSangriaDetailsDialog(_detailedStats?['sangrias_detalhes'] ?? []),
                    borderRadius: BorderRadius.circular(16),
                    child: _buildSmallMetricCard('Retiradas', _currencyFormat.format((_detailedStats?['total_sangrias'] as num?)?.toDouble() ?? 0), Icons.outbox, Colors.orange),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildSmallMetricCard('Movimentações', movs.toString(), Icons.swap_horiz, accentColor)),
                const SizedBox(width: 12),
                const Spacer(),
              ],
            ),
  
            const SizedBox(height: 32),
            
            if (_detailedStats != null) ...[
              Text(
                'Entradas por meio de pagamento',
                style: TextStyle(fontFamily: 'Playfair Display', fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor),
              ),
              const SizedBox(height: 16),
              _buildPaymentBreakdown(),
              const SizedBox(height: 32),
            ],
            
            Text(
              'Ações',
              style: TextStyle(fontFamily: 'Playfair Display', fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor),
            ),
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showSangriaDialog,
                icon: const Icon(Icons.outbox),
                label: Text(StringUtils.toTitleCase('Registrar retirada (sangria)')),
                style: AppButtonStyles.primary(backgroundColor: accentColor),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _fecharCaixa,
                icon: const Icon(Icons.lock),
                label: Text(StringUtils.toTitleCase('Realizar fechamento do caixa')),
                style: AppButtonStyles.primary(backgroundColor: Colors.red),
              ),
            ),

            const SizedBox(height: 32),
            
            // Instruction Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Os pagamentos de agendamentos concluídos, pré-pagamentos e vendas de produtos são vinculados a este caixa em tempo real.',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentBreakdown() {
    final porMeio = _detailedStats!['por_meio_pagamento'] as Map<String, dynamic>;
    
    return Column(
      children: porMeio.entries.map((e) {
        final data = e.value as Map<String, dynamic>;
        final valorTotal = (data['valor_total'] ?? 0.0).toDouble();
        final transacoes = data['transacoes'] as List;
        
        if (valorTotal == 0 && transacoes.isEmpty) return const SizedBox.shrink();
        
        String label = e.key;
        switch(e.key) {
          case 'dinheiro': label = 'Dinheiro'; break;
          case 'pix': label = 'PIX'; break;
          case 'cartao_credito': label = 'Cartão de crédito'; break;
          case 'cartao_debito': label = 'Cartão de débito'; break;
          case 'transferencia': label = 'Transferência'; break;
          case 'convenio': label = 'Convênio'; break;
          case 'outro': label = 'Outro'; break;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$label (${transacoes.length})',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      _currencyFormat.format(valorTotal),
                      style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _showTransactionDetailsDialog(label, transacoes),
                child: Text(
                  StringUtils.toTitleCase('Ver detalhes'),
                  style: TextStyle(color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showTransactionDetailsDialog(String title, List transacoes) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Vendas - $title', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
        content: SizedBox(
          width: double.maxFinite,
          child: transacoes.isEmpty 
            ? const Center(child: Text('Nenhuma transação encontrada.'))
            : ListView.separated(
                shrinkWrap: true,
                itemCount: transacoes.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final t = transacoes[index];
                  final isConta = t.containsKey('titulo');
                  final servico = isConta ? t['titulo'] : (t['servicos']?['nome'] ?? 'Serviço');
                  final subTitle = isConta ? t['descricao'] : 'Cli: ${t['cliente']?['nome_completo'] ?? 'N/A'}';
                  final detailInfo = isConta ? 'Venda de produto' : 'Prof: ${t['profissional']?['nome_completo'] ?? 'N/A'}';
                  
                  final dataStr = isConta ? (t['data_pagamento'] ?? t['created_at']) : t['data_hora'];
                  final data = dataStr != null ? DateTime.parse(dataStr).toLocal() : DateTime.now();
                  final valor = ((isConta ? t['valor'] : t['valor_total']) as num?)?.toDouble() ?? 0.0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isConta ? Colors.orange.shade100 : Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isConta ? 'Venda' : 'Agenda',
                                      style: TextStyle(fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: isConta ? Colors.orange.shade900 : Colors.blue.shade900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      servico.toString(),
                                      style: TextStyle(fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppColors.primary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                detailInfo,
                                style: TextStyle(fontSize: 11, color: Colors.black87),
                              ),
                              Text(
                                subTitle.toString(),
                                style: TextStyle(fontSize: 11, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _currencyFormat.format(valor),
                              style: TextStyle(fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              DateFormat('dd/MM/yy').format(data),
                              style: TextStyle(fontSize: 10, color: Colors.black45),
                            ),
                            Text(
                              DateFormat('HH:mm').format(data),
                              style: TextStyle(fontSize: 10, color: Colors.black45),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(Icons.edit_outlined, size: 20, color: AppColors.accent),
                          onPressed: () {
                            Navigator.pop(context);
                            _editTransaction(t);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: AppButtonStyles.primary(),
            child: Text(StringUtils.toTitleCase('Fechar')),
          ),
        ],
      ),
    );
  }

  Future<void> _editTransaction(Map<String, dynamic> transaction) async {
    final id = transaction['id'];
    final isConta = transaction.containsKey('titulo');
    double currentValor = ( (isConta ? transaction['valor'] : transaction['valor_total']) as num).toDouble();
    String currentMeio = transaction['forma_pagamento'] ?? 'dinheiro';
    int currentParcelas = transaction['parcelas'] ?? 1;

    final valorController = TextEditingController(text: _currencyFormat.format(currentValor).replaceAll('R\$\u{00A0}', ''));
    String selectedMeio = currentMeio;
    int selectedParcelas = currentParcelas;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Editar pagamento', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: valorController,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Valor total',
                  prefixText: 'R\$ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedMeio,
                decoration: const InputDecoration(labelText: 'Forma de pagamento', border: OutlineInputBorder()),
                items: [
                  DropdownMenuItem(value: 'dinheiro', child: Text(StringUtils.toTitleCase('Dinheiro'))),
                  DropdownMenuItem(value: 'pix', child: Text(StringUtils.toTitleCase('PIX'))),
                  DropdownMenuItem(value: 'cartao_credito', child: Text(StringUtils.toTitleCase('Cartão de crédito'))),
                  DropdownMenuItem(value: 'cartao_debito', child: Text(StringUtils.toTitleCase('Cartão de débito'))),
                  DropdownMenuItem(value: 'convenio', child: Text(StringUtils.toTitleCase('Convênio'))),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => selectedMeio = v);
                },
              ),
              if (selectedMeio == 'cartao_credito') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedParcelas,
                  decoration: const InputDecoration(labelText: 'Parcelas', border: OutlineInputBorder()),
                  items: List.generate(18, (i) => i + 1)
                      .map((p) => DropdownMenuItem(
                          value: p, child: Text(StringUtils.toTitleCase('$p x'))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedParcelas = v);
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: Text(StringUtils.toTitleCase('Cancelar'), style: AppButtonStyles.cancelTextStyle())
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: AppButtonStyles.primary(),
              child: Text(StringUtils.toTitleCase('Salvar alterações')),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      setState(() => _isLoading = true);
      try {
        final newVal = double.tryParse(valorController.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0;
        
        if (isConta) {
          await _caixaRepo.updateTransaction(id, {
            'valor': newVal,
            'forma_pagamento': selectedMeio,
          }, false);
        } else {
          await _caixaRepo.updateTransaction(id, {
            'valor_total': newVal,
            'forma_pagamento': selectedMeio,
            'parcelas': selectedMeio == 'cartao_credito' ? selectedParcelas : 1,
          }, true);
        }
        await _loadCaixaStatus(); // Atualiza tudo
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao atualizar: $e')));
        }
      }
    }
  }

  void _showExpenseDetailsDialog(List details) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Saídas (despesas)', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
        content: SizedBox(
          width: double.maxFinite,
          child: details.isEmpty
            ? const Center(child: Text('Nenhuma saída registrada.'))
            : ListView.separated(
                shrinkWrap: true,
                itemCount: details.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final d = details[index];
                  final desc = d['descricao'] ?? 'Despesa';
                  final profissional = (d['criado_por'] ?? 'Clínica').toString().substring(0, 8);
                  final valor = (d['valor'] as num).toDouble();

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(desc, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('Pago a: $profissional', style: TextStyle(fontSize: 12)),
                    trailing: Text(
                      _currencyFormat.format(valor),
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  );
                },
              ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(StringUtils.toTitleCase('Fechar')),
          ),
        ],
      ),
    );
  }

  void _showSangriaDetailsDialog(List details) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Retiradas (sangrias)', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
        content: SizedBox(
          width: double.maxFinite,
          child: details.isEmpty
            ? const Center(child: Text('Nenhuma retirada registrada.'))
            : ListView.separated(
                shrinkWrap: true,
                itemCount: details.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final d = details[index];
                  final desc = d['titulo']?.replaceAll('Sangria: ', '') ?? 'Retirada';
                  final meio = d['descricao']?.replaceAll('Retirada de caixa (', '').replaceAll(')', '') ?? 'Dinheiro';
                  final valor = (d['valor'] as num).toDouble();

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(desc, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('Meio: $meio | ID: ${(d['criado_por'] ?? 'N/A').toString().substring(0, 8)}', style: TextStyle(fontSize: 12)),
                    trailing: Text(
                      _currencyFormat.format(valor),
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                    ),
                  );
                },
              ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(StringUtils.toTitleCase('Fechar')),
          ),
        ],
      ),
    );
  }

  Future<void> _showSangriaDialog() async {
    if (_activeCaixa == null) return;

    final valorController = TextEditingController(text: '0,00');
    final motivoController = TextEditingController();
    String selectedMeio = 'dinheiro';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Registrar retirada', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: valorController,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Valor da retirada',
                  prefixText: 'R\$ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedMeio,
                decoration: const InputDecoration(labelText: 'Meio de retirada', border: OutlineInputBorder()),
                items: [
                  DropdownMenuItem(value: 'dinheiro', child: Text(StringUtils.toTitleCase('Dinheiro'))),
                  DropdownMenuItem(value: 'pix', child: Text(StringUtils.toTitleCase('PIX transferência'))),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => selectedMeio = v);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: motivoController,
                decoration: const InputDecoration(
                  labelText: 'Motivo/descrição',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(StringUtils.toTitleCase('Cancelar'), style: AppButtonStyles.cancelTextStyle()),
            ),
            ElevatedButton(
              style: AppButtonStyles.primary(backgroundColor: AppColors.primary),
              onPressed: () => Navigator.pop(context, true),
              child: Text(StringUtils.toTitleCase('Confirmar retirada')),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      setState(() => _isLoading = true);
      try {
        final val = double.tryParse(valorController.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0;
        final userId = Supabase.instance.client.auth.currentUser!.id;
        
        await _caixaRepo.registrarSangria(
          caixaId: _activeCaixa!.id,
          valor: val,
          motivo: motivoController.text,
          meio: selectedMeio,
          usuarioId: userId,
        );
        
        await _loadCaixaStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Retirada registrada com sucesso!'), backgroundColor: Colors.orange),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao registrar retirada: $e')));
        }
      }
    }
  }

  Widget _buildSmallMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.black38,
                      letterSpacing: 0.5,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

