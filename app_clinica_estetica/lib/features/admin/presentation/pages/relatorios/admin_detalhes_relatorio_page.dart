
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_clinica_estetica/features/admin/data/models/report_models.dart';
import 'package:app_clinica_estetica/features/admin/data/repositories/report_repository.dart';
import 'package:app_clinica_estetica/features/admin/data/repositories/supabase_report_repository.dart';
import 'package:app_clinica_estetica/features/admin/presentation/pages/relatorios/widgets/report_charts.dart';
import 'package:pdf/pdf.dart' as pw_pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';
import 'package:app_clinica_estetica/core/services/report_app_bar_service.dart';

class AdminDetalhesRelatorioPage extends StatefulWidget {
  final String reportCategory;
  final DateTimeRange? initialRange;

  const AdminDetalhesRelatorioPage({
    super.key,
    required this.reportCategory,
    this.initialRange,
  });

  @override
  State<AdminDetalhesRelatorioPage> createState() => _AdminDetalhesRelatorioPageState();
}

class _AdminDetalhesRelatorioPageState extends State<AdminDetalhesRelatorioPage> {
  late DateTimeRange _range;
  final IReportRepository _repo = SupabaseReportRepository();
  bool _isLoading = true;
  
  dynamic _data;
  String? _selectedProfessionalId;
  List<Map<String, dynamic>> _professionals = [];
  bool _isBarChart = false;
  String _selectedPeriod = 'MÊS ATUAL';

  void _onPeriodSelected(String period) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (period) {
      case 'Hoje':
        start = DateTime(now.year, now.month, now.day);
        break;
      case 'Ontem':
        final yesterday = now.subtract(const Duration(days: 1));
        start = DateTime(yesterday.year, yesterday.month, yesterday.day);
        end = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
        break;
      case 'Semana Atual':
        final thisMon = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(thisMon.year, thisMon.month, thisMon.day);
        break;
      case 'Última Semana':
        final lastMon = now.subtract(Duration(days: now.weekday + 6));
        final lastSun = lastMon.add(const Duration(days: 6));
        start = DateTime(lastMon.year, lastMon.month, lastMon.day);
        end = DateTime(lastSun.year, lastSun.month, lastSun.day, 23, 59, 59);
        break;
      case 'Mês Atual':
        start = DateTime(now.year, now.month, 1);
        break;
      case 'Mês Passado':
        start = DateTime(now.year, now.month - 1, 1);
        end = DateTime(now.year, now.month, 0, 23, 59, 59);
        break;
      case 'Ano Atual':
        start = DateTime(now.year, 1, 1);
        break;
      case 'Todas as Opções':
        start = DateTime(2023, 1, 1);
        break;
      case 'Personalizado':
        // Se já for personalizado, não alteramos start/end
        return;
      default:
        start = DateTime(now.year, now.month, 1);
    }

    setState(() {
      _range = DateTimeRange(start: start, end: end);
      _selectedPeriod = period;
    });
    _loadData();
  }


  @override
  void initState() {
    super.initState();
    _range = widget.initialRange ?? 
             DateTimeRange(
               start: DateTime(DateTime.now().year, DateTime.now().month, 1),
               end: DateTime.now()
             );
    _loadInitialData();
    
    // Register AppBar actions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateAppBar();
    });
  }

  @override
  void dispose() {
    // Reset AppBar when leaving
    ReportAppBarService().reset();
    super.dispose();
  }

  void _updateAppBar() {
    String title = 'Relatório';
    if (widget.reportCategory == 'financeiro') title = 'Relatório Financeiro';
    if (widget.reportCategory == 'pacientes') title = 'Gestão de Pacientes';
    if (widget.reportCategory == 'operacional') title = 'Relatório Operacional';
    if (widget.reportCategory == 'estoque') title = 'Estoque e Vendas';
    if (widget.reportCategory == 'pico') title = 'Horários de Pico';
    if (widget.reportCategory == 'vendas_produtos') title = 'Vendas de Produtos';
    if (widget.reportCategory == 'vendas_servicos') title = 'Vendas de Serviços';
    if (widget.reportCategory == 'comissoes') title = 'Relatório de Comissões';

    ReportAppBarService().setActions(
      title: title.toUpperCase(),
      onPdf: _generatePdfAndPrint,
      onCalendar: _showDateRangePicker,
    );
  }

  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _range = picked;
        _selectedPeriod = 'Personalizado';
      });
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      if (widget.reportCategory == 'financeiro') {
        final results = await Future.wait([
          _repo.getFinancialReport(_range),
          _repo.getFinancialStatement(_range),
        ]);
        _data = {
          'report': results[0] as FinancialReport,
          'statement': results[1] as FinancialStatement,
        };
      } else if (widget.reportCategory == 'pacientes') {
        _data = await _repo.getPatientReport(_range);
      } else if (widget.reportCategory == 'operacional') {
        _data = await _repo.getOperationalReport(_range);
      } else if (widget.reportCategory == 'estoque') {
        _data = await _repo.getStockReport(_range);
      } else if (widget.reportCategory == 'pico') {
        _data = await _repo.getPeakTimeReport(_range);
      } else if (widget.reportCategory == 'vendas_produtos') {
        _data = await _repo.getProductSales(_range, professionalId: _selectedProfessionalId);
      } else if (widget.reportCategory == 'vendas_servicos') {
        _data = await _repo.getServiceSales(_range, professionalId: _selectedProfessionalId);
      } else if (widget.reportCategory == 'comissoes') {
        _data = await _repo.getCommissionsReport(_range);
      }

    } catch (e) {
      debugPrint('Erro ao carregar relatório: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadInitialData() async {
    _loadProfessionals();
    _loadData();
  }

  Future<void> _loadProfessionals() async {
    try {
      final profs = await _repo.getProfessionals();
      if (mounted) {
        setState(() {
          _professionals = profs;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar profissionais: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryGreen = AppColors.primary;
    final accent = AppColors.accent;
    final bgColor = AppColors.background;

    String title = 'Relatório';
    if (widget.reportCategory == 'financeiro') title = 'Relatório Financeiro';
    if (widget.reportCategory == 'pacientes') title = 'Gestão de Pacientes';
    if (widget.reportCategory == 'operacional') title = 'Relatório Operacional';
    if (widget.reportCategory == 'estoque') title = 'Estoque e Vendas';
    if (widget.reportCategory == 'pico') title = 'Horários de Pico';
    if (widget.reportCategory == 'vendas_produtos') title = 'Vendas de Produtos';
    if (widget.reportCategory == 'vendas_servicos') title = 'Vendas de Serviços';
    if (widget.reportCategory == 'comissoes') title = 'Relatório de Comissões';


    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho Padrão
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontFamily: 'Playfair Display', 
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: primaryGreen,
                  ),
                ),
                Text(
                  'Visualize os dados detalhados do relatório',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
          // --- Filtros Diretos na Tela (Standardized Dropdowns) ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildFilterMenu(
                  label: 'Período',
                  currentValue: _selectedPeriod.toUpperCase(),
                  options: [
                    'Hoje',
                    'Ontem',
                    'Semana Atual',
                    'Última Semana',
                    'Mês Atual',
                    'Mês Passado',
                    'Ano Atual',
                    'Todas as Opções',
                  ],
                  onSelected: (option) {
                    String logicString = option;
                    if (option == 'Semana Atual') logicString = 'Semana Atual';
                    if (option == 'Última Semana') logicString = 'Última Semana';
                    if (option == 'Mês Atual') logicString = 'Mês Atual';
                    if (option == 'Mês Passado') logicString = 'Mês Passado';
                    if (option == 'Ano Atual') logicString = 'Ano Atual';
                    if (option == 'Todas as Opções') logicString = 'Todas as Opções';
                    if (option == 'Hoje') logicString = 'Hoje';
                    if (option == 'Ontem') logicString = 'Ontem';
                    
                    _onPeriodSelected(logicString);
                  },
                  primaryColor: primaryGreen,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildCategoryView(primaryGreen, accent),
                ),
        ],
      ),
    );
  }

  Widget _buildCategoryView(Color primaryGreen, Color accent) {
    // Guard: data failed to load (exception was caught and _data remains null)
    if (_data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.error.withOpacity(0.7)),
              const SizedBox(height: 16),
              Text(
                'Erro ao carregar o relatório.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Verifique sua conexão ou o banco de dados e tente novamente.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.reportCategory == 'financeiro') {
      final map = _data as Map<String, dynamic>;
      return _buildFinancialView(map['report'] as FinancialReport, map['statement'] as FinancialStatement, primaryGreen, accent);
    }
    if (widget.reportCategory == 'pacientes') return _buildPatientView(_data as PatientReport, primaryGreen, accent);
    if (widget.reportCategory == 'operacional') return _buildOperationalView(_data as OperationalReport, primaryGreen, accent);
    if (widget.reportCategory == 'estoque') return _buildStockView(_data as StockReport, primaryGreen, accent);
    if (widget.reportCategory == 'pico') return _buildPeakTimeView(_data as PeakTimeReport, primaryGreen, accent);
    if (widget.reportCategory == 'vendas_produtos') return _buildProductSalesView(_data as List<ProductSale>, primaryGreen, accent);
    if (widget.reportCategory == 'vendas_servicos') return _buildServiceSalesView(_data as List<ServiceSale>, primaryGreen, accent);
    if (widget.reportCategory == 'comissoes') return _buildCommissionsView(_data as CommissionReport, primaryGreen, accent);

    return const Center(child: Text('Categoria não encontrada'));
  }

  Widget _buildStockView(StockReport data, Color primaryGreen, Color accent) {
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Resumo de Vendas', primaryGreen),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2,
          children: [
            _buildCompactIndicator('Total de Vendas', '${data.totalSalesCount}', primaryGreen),
            _buildCompactIndicator('Receita Total', currencyFormat.format(data.totalRevenue), AppColors.success),
            _buildCompactIndicator('Comissões Total', currencyFormat.format(data.totalCommissions), AppColors.warning),
            _buildCompactIndicator('Alertas Estoque', '${data.lowStockProducts.length}', AppColors.error),
          ],
        ),
        
        const SizedBox(height: 32),
        _buildSectionTitle('Distribuição e Alertas', primaryGreen),
        const SizedBox(height: 16),
        Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [Tab(text: 'Vendas Produto'), Tab(text: 'Comissões')],
                  labelColor: AppColors.textPrimary,
                  indicatorColor: AppColors.accent,
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      DistributionPieChart(data: data.salesByProduct, colors: [AppColors.primary, AppColors.accent, AppColors.textSecondary, AppColors.softGold]),
                      DistributionPieChart(data: data.commissionsByProfessional, colors: [AppColors.accent, AppColors.primary, AppColors.warning, AppColors.softGold]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        if (data.lowStockProducts.isNotEmpty) ...[
          const SizedBox(height: 32),
          _buildSectionTitle('Reposição Necessária', AppColors.error),
          const SizedBox(height: 16),
          ...data.lowStockProducts.map((p) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: _cardDecoration(),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: AppColors.errorLight, child: const Icon(Icons.warning_amber, color: AppColors.error)),
              title: Text(p.name, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('Estoque Atual: ${p.currentStock} | Mínimo: ${p.minStock}', style: const TextStyle(fontFamily: 'Inter', fontSize: 12)),
              trailing: const Icon(Icons.shopping_cart_outlined, color: AppColors.info),
            ),
          )),
        ],

        const SizedBox(height: 32),
        _buildSectionTitle('Histórico de Movimentações', primaryGreen),
        const SizedBox(height: 16),
        ...data.movements.map((m) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: _cardDecoration(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(m.productName, style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: primaryGreen)),
                    Text(DateFormat('dd/MM HH:mm').format(m.date), style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textLight)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text('Venda', style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppColors.success, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Text('${m.quantity} unidades', style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
                    const Spacer(),
                    if (m.value != null) Text(currencyFormat.format(m.value), style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                  ],
                ),
                if (m.professionalName != null || m.clientName != null) ...[
                  const Divider(height: 20),
                  Row(
                    children: [
                      if (m.professionalName != null) ...[
                        const Icon(Icons.badge_outlined, size: 14, color: AppColors.textLight),
                        const SizedBox(width: 4),
                        Text(m.professionalName!, style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textLight)),
                      ],
                      const SizedBox(width: 16),
                      if (m.clientName != null) ...[
                        const Icon(Icons.person_outline, size: 14, color: AppColors.textLight),
                        const SizedBox(width: 4),
                        Text(m.clientName!, style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textLight)),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        )),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildFinancialView(FinancialReport report, FinancialStatement statement, Color primaryGreen, Color accent) {
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Resumo de Resultados', primaryGreen),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: [
            _buildCompactIndicator('Faturamento Bruto', currencyFormat.format(report.totalRevenue), AppColors.success),
            _buildCompactIndicator('Taxas de Cartão', currencyFormat.format(report.totalTaxes), AppColors.error),
            _buildCompactIndicator('Comissões', currencyFormat.format(report.totalCommissions), AppColors.warning),
            _buildCompactIndicator('Lucro Operacional', currencyFormat.format(report.operatingProfit), primaryGreen),
          ],
        ),
        const SizedBox(height: 32),
        _buildSectionTitle('Fluxo de Caixa', primaryGreen),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildCompactIndicator('Faturamento', currencyFormat.format(statement.income), AppColors.success)),
            const SizedBox(width: 12),
            Expanded(child: _buildCompactIndicator('Despesas Totais', currencyFormat.format(statement.expenses), AppColors.error)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 250,
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Column(
            children: [
              Expanded(child: CashFlowBarChart(data: statement.cashFlow, incomeColor: AppColors.success, expenseColor: AppColors.error)),
              const SizedBox(height: 8),
              ChartLegend(items: [LegendItem('Entradas', AppColors.success), LegendItem('Saídas', AppColors.error)]),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        _buildSectionTitle('Distribuição de Receita', primaryGreen),
        const SizedBox(height: 16),
        Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                const TabBar(
                  tabs: [Tab(text: 'Profissional'), Tab(text: 'Serviço'), Tab(text: 'Pagamento')],
                  labelColor: AppColors.textPrimary,
                  indicatorColor: AppColors.accent,
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      DistributionPieChart(data: report.revenueByProfessional, colors: [AppColors.primary, AppColors.accent, AppColors.textSecondary, AppColors.softGold]),
                      DistributionPieChart(data: report.revenueByService, colors: [AppColors.primary, AppColors.accent, AppColors.textLight, AppColors.warning]),
                      DistributionPieChart(data: report.revenueByPaymentMethod, colors: [AppColors.primary, AppColors.accent, AppColors.info, AppColors.softGold]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPatientView(PatientReport data, Color primaryGreen, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Indicadores de Pacientes', primaryGreen),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildCompactIndicator('Retenção', '${data.retentionRate.toStringAsFixed(1)}%', AppColors.success)),
            const SizedBox(width: 12),
            Expanded(child: _buildCompactIndicator('Inativos', '${data.inactivePatients}', AppColors.error)),
          ],
        ),
        const SizedBox(height: 32),
        _buildSectionTitle('Novos Clientes por Dia', primaryGreen),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: RevenueLineChart(data: data.newPatientsByDay, primaryColor: accent),
        ),
      ],
    );
  }

  Widget _buildOperationalView(OperationalReport data, Color primaryGreen, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Performance Operacional', primaryGreen),
        const SizedBox(height: 16),
        _buildOperationalGrid(data, primaryGreen, accent),
        const SizedBox(height: 32),
        _buildSectionTitle('Agendamentos Diários', primaryGreen),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: RevenueLineChart(data: data.appointmentsByDay, primaryColor: primaryGreen),
        ),
      ],
    );
  }

  Widget _buildOperationalGrid(OperationalReport data, Color green, Color gold) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2,
      children: [
        _buildCompactIndicator('Concluídos', '${data.concluidos}', AppColors.success),
        _buildCompactIndicator('Cancelados', '${data.cancelados}', AppColors.warning),
        _buildCompactIndicator('Ausentes', '${data.ausentes}', AppColors.error),
        _buildCompactIndicator('No-Show', '${data.noShowRate.toStringAsFixed(1)}%', AppColors.textLight),
      ],
    );
  }

  Widget _buildPeakTimeView(PeakTimeReport data, Color primaryGreen, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: AppColors.shadow.withOpacity(0.05), blurRadius: 10)],
                ),
                child: TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textLight,
                  indicatorColor: AppColors.accent,
                  indicatorWeight: 3,
                  indicatorPadding: const EdgeInsets.symmetric(horizontal: 16),
                  tabs: const [
                    Tab(text: 'Por Horário'),
                    Tab(text: 'Dias da Semana'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 1000, 
                child: TabBarView(
                  physics: const NeverScrollableScrollPhysics(), // Scroll global cuida disso
                  children: [
                    _buildPeakContent(data.hourlyData, 'Horários de Atendimento', primaryGreen, accent),
                    _buildPeakContent(data.dailyData, 'Dias da Semana', primaryGreen, accent),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPeakContent(List<PeakTimeData> list, String label, Color primaryGreen, Color accent) {
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Distribuição: $label', primaryGreen),
        const SizedBox(height: 16),
        Container(
          height: 260,
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Column(
            children: [
              Expanded(child: PeakBarChart(data: list, color: primaryGreen)),
              const SizedBox(height: 12),
              Text(
                'Volume de Agendamentos',
                style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppColors.textLight, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildSectionTitle('Métricas Detalhadas', primaryGreen),
        const SizedBox(height: 16),
        Container(
          decoration: _cardDecoration(),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(primaryGreen.withOpacity(0.05)),
              columnSpacing: 24,
              columns: [
                DataColumn(label: Text(label.contains('Horários') ? 'Hora' : 'Dia', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Agend.', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Ticket Méd.', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Faturamento', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Lucro Bruto', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 12))),
              ],
              rows: list.map((item) => DataRow(
                cells: [
                  DataCell(Text(item.label, style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 12))),
                  DataCell(Text('${item.appointmentsCount}', style: TextStyle(fontFamily: 'Inter', fontSize: 12))),
                  DataCell(Text(currencyFormat.format(item.averageTicket), style: TextStyle(fontFamily: 'Inter', fontSize: 12))),
                  DataCell(Text(currencyFormat.format(item.totalRevenue), style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.success, fontWeight: FontWeight.bold))),
                  DataCell(Text(currencyFormat.format(item.grossProfit), style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: primaryGreen, fontWeight: FontWeight.bold))),
                ],
              )).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        textAlign: TextAlign.left,
        style: TextStyle(fontFamily: 'Playfair Display', 
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildCompactIndicator(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppColors.textLight, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildProductSalesView(List<ProductSale> data, Color primaryGreen, Color accent) {
    if (data.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVendasHeader(primaryGreen),
          const SizedBox(height: 16),
          _buildProfessionalFilter(primaryGreen, accent),
          const SizedBox(height: 64),
          const Center(child: Text('Nenhuma venda de produto encontrada.', style: TextStyle(fontFamily: 'Inter'))),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildVendasHeader(primaryGreen),
        const SizedBox(height: 16),
        _buildProfessionalFilter(primaryGreen, accent),
        const SizedBox(height: 24),
        _buildTableContainer(
          DataTable(
            headingRowColor: WidgetStateProperty.all(primaryGreen.withOpacity(0.05)),
            columnSpacing: 16,
            columns: [
              DataColumn(label: _tableHeader('Data')),
              DataColumn(label: _tableHeader('Produto')),
              DataColumn(label: _tableHeader('Profissional')),
              DataColumn(label: _tableHeader('Qtd')),
              DataColumn(label: _tableHeader('Total')),
            ],
            rows: data.map((sale) => DataRow(
              cells: [
                DataCell(_tableCell(DateFormat('dd/MM/yy').format(sale.date))),
                DataCell(_tableCell(sale.productName)),
                DataCell(_tableCell(sale.professionalName)),
                DataCell(_tableCell('${sale.quantity}')),
                DataCell(_tableCell(NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(sale.totalPrice), isBold: true, color: AppColors.success)),
              ],
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceSalesView(List<ServiceSale> data, Color primaryGreen, Color accent) {
    if (data.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVendasHeader(primaryGreen),
          const SizedBox(height: 16),
          _buildProfessionalFilter(primaryGreen, accent),
          const SizedBox(height: 64),
          const Center(child: Text('Nenhuma venda de serviço encontrada.', style: TextStyle(fontFamily: 'Inter'))),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildVendasHeader(primaryGreen),
        const SizedBox(height: 16),
        _buildProfessionalFilter(primaryGreen, accent),
        const SizedBox(height: 24),
        _buildTableContainer(
          DataTable(
            headingRowColor: WidgetStateProperty.all(primaryGreen.withOpacity(0.05)),
            columnSpacing: 16,
            columns: [
              DataColumn(label: _tableHeader('Data')),
              DataColumn(label: _tableHeader('Serviço')),
              DataColumn(label: _tableHeader('Profissional')),
              DataColumn(label: _tableHeader('Total')),
            ],
            rows: data.map((sale) => DataRow(
              cells: [
                DataCell(_tableCell(DateFormat('dd/MM/yy').format(sale.date))),
                DataCell(_tableCell(sale.serviceName)),
                DataCell(_tableCell(sale.professionalName)),
                DataCell(_tableCell(NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(sale.price), isBold: true, color: AppColors.success)),
              ],
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCommissionsView(CommissionReport data, Color primaryGreen, Color accent) {
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Resumo de Comissões', primaryGreen),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildCompactIndicator('Base Comissionável', currencyFormat.format(data.totalCommissionedRevenue), primaryGreen)),
            const SizedBox(width: 12),
            Expanded(child: _buildCompactIndicator('Total a Pagar', currencyFormat.format(data.totalCommissionPayout), AppColors.warning)),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle('Distribuição por Profissional', primaryGreen),
            IconButton(
              icon: Icon(_isBarChart ? Icons.pie_chart_outline : Icons.bar_chart),
              onPressed: () => setState(() => _isBarChart = !_isBarChart),
              tooltip: 'Alterar visualização',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: _isBarChart
            ? CommissionBarChart(
                data: {for (var p in data.professionals) p.professionalName: p.commissionAmount},
                color: AppColors.accent,
              )
            : DistributionPieChart(
                data: {for (var p in data.professionals) p.professionalName: p.commissionAmount},
                colors: [AppColors.primary, AppColors.accent, AppColors.textSecondary, AppColors.softGold, AppColors.textLight],
              ),
        ),
        const SizedBox(height: 32),
        _buildSectionTitle('Pagamentos por Dia', primaryGreen),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: RevenueLineChart(data: data.payoutsByDay, primaryColor: AppColors.warning),
        ),
        const SizedBox(height: 32),
        _buildSectionTitle('Detalhamento Profissional', primaryGreen),
        const SizedBox(height: 16),
        _buildTableContainer(
          DataTable(
            headingRowColor: WidgetStateProperty.all(primaryGreen.withOpacity(0.05)),
            columnSpacing: 16,
            columns: [
              DataColumn(label: _tableHeader('Profissional')),
              DataColumn(label: _tableHeader('Agend.')),
              DataColumn(label: _tableHeader('Prod.')),
              DataColumn(label: _tableHeader('Faturam.')),
              DataColumn(label: _tableHeader('Base')),
              DataColumn(label: _tableHeader('Comis. Brut.')),
              DataColumn(label: _tableHeader('Comis. Liq.')),
            ],
            rows: data.professionals.map((p) => DataRow(
              cells: [
                DataCell(_tableCell(p.professionalName, isBold: true)),
                DataCell(_tableCell('${p.appointmentsCount}')),
                DataCell(_tableCell('${p.productsCount}')),
                DataCell(_tableCell(currencyFormat.format(p.totalRevenue))),
                DataCell(_tableCell(currencyFormat.format(p.commissionBase))),
                DataCell(_tableCell(currencyFormat.format(p.commissionAmountBruta), color: AppColors.textLight)),
                DataCell(_tableCell(currencyFormat.format(p.commissionAmount), isBold: true, color: AppColors.warning)),
              ],
            )).toList(),
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildVendasHeader(Color primaryGreen) {
    return Text(
      'Vendas',
      style: TextStyle(fontFamily: 'Playfair Display', 
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildProfessionalFilter(Color primaryGreen, Color accent) {
    String currentValueLabel = 'Todos os Profissionais';
    if (_selectedProfessionalId != null) {
      final prof = _professionals.firstWhere((p) => p['id'].toString() == _selectedProfessionalId, orElse: () => {});
      if (prof.isNotEmpty) currentValueLabel = prof['nome_completo'].toString();
    }

    return _buildFilterMenu(
      label: 'Profissional',
      currentValue: currentValueLabel,
      options: ['Todos os Profissionais', ..._professionals.map((p) => p['nome_completo'].toString())],
      onSelected: (val) {
        if (val == 'Todos os Profissionais') {
          setState(() => _selectedProfessionalId = null);
        } else {
          final prof = _professionals.firstWhere((p) => p['nome_completo'].toString() == val);
          setState(() => _selectedProfessionalId = prof['id'].toString());
        }
        _loadData();
      },
      primaryColor: accent,
    );
  }

  Widget _buildTableContainer(Widget child) {
    return Container(
      width: double.infinity,
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: child,
      ),
    );
  }

  Widget _tableHeader(String text) {
    return Text(text, style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 12));
  }

  Widget _tableCell(String text, {bool isBold = false, Color? color}) {
    return Text(
      text,
      style: TextStyle(fontFamily: 'Inter', fontSize: 12,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        color: color,
      ),
    );
  }

  Future<void> _generatePdfAndPrint() async {
    final pdf = pw.Document();
    String title = 'Relatório';
    if (widget.reportCategory == 'financeiro') title = 'Relatório Financeiro';
    if (widget.reportCategory == 'pacientes') title = 'Gestão de Pacientes';
    if (widget.reportCategory == 'operacional') title = 'Relatório Operacional';
    if (widget.reportCategory == 'estoque') title = 'Estoque e Vendas';
    if (widget.reportCategory == 'pico') title = 'Horários de Pico';
    if (widget.reportCategory == 'vendas_produtos') title = 'Vendas de Produtos';
    if (widget.reportCategory == 'vendas_servicos') title = 'Vendas de Serviços';
    if (widget.reportCategory == 'comissoes') title = 'Relatório de Comissões';

    final rangeStr = '${DateFormat('dd/MM/yyyy').format(_range.start)} - ${DateFormat('dd/MM/yyyy').format(_range.end)}';
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pw_pdf.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0, 
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20)),
                  pw.Text(rangeStr, style: const pw.TextStyle(fontSize: 12)),
                ]
              )
            ),
            pw.SizedBox(height: 20),

            if (widget.reportCategory == 'financeiro') ...[
              pw.Text('Resumo Financeiro', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                context: context,
                data: <List<String>>[
                  ['Métrica', 'Valor'],
                  ['Faturamento Bruto', currencyFormat.format((_data['report'] as FinancialReport).totalRevenue)],
                  ['Taxas de Cartão', currencyFormat.format((_data['report'] as FinancialReport).totalTaxes)],
                  ['Comissões', currencyFormat.format((_data['report'] as FinancialReport).totalCommissions)],
                  ['Lucro Operacional', currencyFormat.format((_data['report'] as FinancialReport).operatingProfit)],
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text('Fluxo de Caixa Diário', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                context: context,
                data: <List<String>>[
                  ['Data', 'Entradas', 'Saídas', 'Saldo'],
                  ...(_data['statement'] as FinancialStatement).cashFlow.map((cf) => [
                    DateFormat('dd/MM/yyyy').format(cf.date),
                    currencyFormat.format(cf.income),
                    currencyFormat.format(cf.expenses),
                    currencyFormat.format(cf.income - cf.expenses),
                  ]),
                ],
              ),
            ] else if (widget.reportCategory == 'pacientes') ...[
              pw.Text('Indicadores de Pacientes', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                context: context,
                data: <List<String>>[
                  ['Métrica', 'Valor'],
                  ['Total de Pacientes', (_data as PatientReport).totalPatients.toString()],
                  ['Novos Pacientes', (_data as PatientReport).newPatients.toString()],
                  ['Pacientes Inativos', (_data as PatientReport).inactivePatients.toString()],
                  ['Taxa de Retenção', '${(_data as PatientReport).retentionRate.toStringAsFixed(1)}%'],
                ],
              ),
            ] else if (widget.reportCategory == 'operacional') ...[
              pw.Text('Performance Operacional', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                context: context,
                data: <List<String>>[
                  ['Métrica', 'Valor'],
                  ['Total de Agendamentos', (_data as OperationalReport).totalAgendamentos.toString()],
                  ['Concluídos', (_data as OperationalReport).concluidos.toString()],
                  ['Cancelados', (_data as OperationalReport).cancelados.toString()],
                  ['Ausentes', (_data as OperationalReport).ausentes.toString()],
                  ['Taxa de No-Show', '${(_data as OperationalReport).noShowRate.toStringAsFixed(1)}%'],
                ],
              ),
            ] else if (widget.reportCategory == 'estoque') ...[
              pw.Text('Resumo de Estoque', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                context: context,
                data: <List<String>>[
                  ['Métrica', 'Valor'],
                  ['Total de Vendas', (_data as StockReport).totalSalesCount.toString()],
                  ['Receita de Produtos', currencyFormat.format((_data as StockReport).totalRevenue)],
                  ['Comissões de Produtos', currencyFormat.format((_data as StockReport).totalCommissions)],
                  ['Alertas de Estoque', (_data as StockReport).lowStockProducts.length.toString()],
                ],
              ),
              if ((_data as StockReport).lowStockProducts.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text('Produtos com Estoque Baixo', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: pw_pdf.PdfColors.red)),
                pw.SizedBox(height: 10),
                pw.TableHelper.fromTextArray(
                  context: context,
                  data: <List<String>>[
                    ['Produto', 'Atual', 'Mínimo'],
                    ...(_data as StockReport).lowStockProducts.map((p) => [p.name, p.currentStock.toString(), p.minStock.toString()]),
                  ],
                ),
              ],
              pw.SizedBox(height: 20),
              pw.Text('Histórico de Movimentações (Vendas)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                context: context,
                data: <List<String>>[
                  ['Data', 'Produto', 'Qtd', 'Profissional', 'Valor'],
                  ...(_data as StockReport).movements.map((m) => [
                    DateFormat('dd/MM/yy HH:mm').format(m.date),
                    m.productName,
                    m.quantity.toString(),
                    m.professionalName ?? '-',
                    m.value != null ? currencyFormat.format(m.value) : '-',
                  ]),
                ],
              ),
            ] else if (widget.reportCategory == 'pico') ...[
              pw.Text('Horários de Maior Movimento', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                context: context,
                data: <List<String>>[
                  ['Hora', 'Agendamentos', 'Faturamento', 'Ticket Médio'],
                  ...(_data as PeakTimeReport).hourlyData.map((h) => [
                    h.label,
                    h.appointmentsCount.toString(),
                    currencyFormat.format(h.totalRevenue),
                    currencyFormat.format(h.averageTicket),
                  ]),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text('Dias da Semana', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                context: context,
                data: <List<String>>[
                  ['Dia', 'Agendamentos', 'Faturamento', 'Ticket Médio'],
                  ...(_data as PeakTimeReport).dailyData.map((d) => [
                    d.label,
                    d.appointmentsCount.toString(),
                    currencyFormat.format(d.totalRevenue),
                    currencyFormat.format(d.averageTicket),
                  ]),
                ],
              ),
            ] else if (widget.reportCategory == 'vendas_produtos') ...[
               pw.TableHelper.fromTextArray(
                headers: ['Data', 'Produto', 'Profissional', 'Qtd', 'Total'],
                data: (_data as List<ProductSale>).map((s) => [
                  DateFormat('dd/MM/yy').format(s.date),
                  s.productName,
                  s.professionalName,
                  s.quantity.toString(),
                  currencyFormat.format(s.totalPrice)
                ]).toList(),
              )
            ] else if (widget.reportCategory == 'vendas_servicos') ...[
              pw.TableHelper.fromTextArray(
                headers: ['Data', 'Serviço', 'Profissional', 'Valor'],
                data: (_data as List<ServiceSale>).map((s) => [
                  DateFormat('dd/MM/yy').format(s.date),
                  s.serviceName,
                  s.professionalName,
                  currencyFormat.format(s.price)
                ]).toList(),
              )
            ] else if (widget.reportCategory == 'comissoes') ...[
              pw.TableHelper.fromTextArray(
                headers: ['Profissional', 'Agend.', 'Prod.', 'Faturam.', 'Base', 'Comis. Brut.', 'Comis. Liq.'],
                data: (_data as CommissionReport).professionals.map((p) => [
                  p.professionalName,
                  p.appointmentsCount.toString(),
                  p.productsCount.toString(),
                  currencyFormat.format(p.totalRevenue),
                  currencyFormat.format(p.commissionBase),
                  currencyFormat.format(p.commissionAmountBruta),
                  currencyFormat.format(p.commissionAmount)
                ]).toList(),
              ),
            ],
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (pw_pdf.PdfPageFormat format) async => pdf.save());
  }

  Widget _buildFilterMenu({
    required String label,
    required String currentValue,
    required List<String> options,
    required Function(String) onSelected,
    required Color primaryColor,
    Color? labelColor,
  }) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => options.map((option) {
        final bool isSelected = currentValue == option;
        return PopupMenuItem<String>(
          value: option,
          child: Row(
            children: [
              Text(
                option,
                style: TextStyle(fontFamily: 'Inter', fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? primaryColor : AppColors.textPrimary,
                ),
              ),
              if (isSelected) ...[
                const Spacer(),
                Icon(Icons.check, size: 16, color: primaryColor),
              ],
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryColor.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13,
                fontWeight: FontWeight.w600,
                color: labelColor ?? AppColors.textLight,
              ),
            ),
            Text(
              currentValue,
              style: TextStyle(fontFamily: 'Inter', fontSize: 13,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 18, color: primaryColor),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(color: AppColors.shadow.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
      ],
    );
  }
}

