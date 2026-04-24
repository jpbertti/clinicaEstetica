import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';
import 'package:app_clinica_estetica/features/admin/data/models/report_models.dart';
import 'package:app_clinica_estetica/features/admin/data/repositories/report_repository.dart';
import 'package:app_clinica_estetica/features/admin/data/repositories/supabase_report_repository.dart';
import 'package:app_clinica_estetica/features/admin/presentation/pages/relatorios/widgets/report_charts.dart';
import 'package:app_clinica_estetica/features/profissional/presentation/widgets/profissional_app_bar.dart';

class ProfissionalDetalhesRelatorioPage extends StatefulWidget {
  final String reportCategory;
  final DateTimeRange? initialRange;
  final String? professionalId;

  const ProfissionalDetalhesRelatorioPage({
    super.key,
    required this.reportCategory,
    this.initialRange,
    this.professionalId,
  });

  @override
  State<ProfissionalDetalhesRelatorioPage> createState() =>
      _ProfissionalDetalhesRelatorioPageState();
}

class _ProfissionalDetalhesRelatorioPageState
    extends State<ProfissionalDetalhesRelatorioPage> {
  late DateTimeRange _range;
  final IReportRepository _repo = SupabaseReportRepository();
  bool _isLoading = true;
  dynamic _data;
  String _selectedPeriod = 'Mês Atual';
  bool _isBarChart = false;

  @override
  void initState() {
    super.initState();
    _range = widget.initialRange ??
        DateTimeRange(
          start: DateTime(DateTime.now().year, DateTime.now().month, 1),
          end: DateTime.now(),
        );
    _loadData();
  }

  void _onPeriodSelected(String period) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    switch (period) {
      case 'Hoje':
        start = DateTime(now.year, now.month, now.day);
        break;
      case 'Ontem':
        final y = now.subtract(const Duration(days: 1));
        start = DateTime(y.year, y.month, y.day);
        end = DateTime(y.year, y.month, y.day, 23, 59, 59);
        break;
      case 'Semana Atual':
        final m = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(m.year, m.month, m.day);
        break;
      case 'Última Semana':
        final lm = now.subtract(Duration(days: now.weekday + 6));
        final ls = lm.add(const Duration(days: 6));
        start = DateTime(lm.year, lm.month, lm.day);
        end = DateTime(ls.year, ls.month, ls.day, 23, 59, 59);
        break;
      case 'Mês Passado':
        start = DateTime(now.year, now.month - 1, 1);
        end = DateTime(now.year, now.month, 0, 23, 59, 59);
        break;
      case 'Ano Atual':
        start = DateTime(now.year, 1, 1);
        break;
      default:
        start = DateTime(now.year, now.month, 1);
    }
    setState(() {
      _range = DateTimeRange(start: start, end: end);
      _selectedPeriod = period;
    });
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final profId = widget.professionalId;
    try {
      if (widget.reportCategory == 'financeiro') {
        final r = await Future.wait([
          _repo.getFinancialReport(_range, professionalId: profId),
          _repo.getFinancialStatement(_range, professionalId: profId),
        ]);
        _data = {'report': r[0] as FinancialReport, 'statement': r[1] as FinancialStatement};
      } else if (widget.reportCategory == 'operacional') {
        _data = await _repo.getOperationalReport(_range, professionalId: profId);
      } else if (widget.reportCategory == 'pico') {
        _data = await _repo.getPeakTimeReport(_range, professionalId: profId);
      } else if (widget.reportCategory == 'vendas_produtos') {
        _data = await _repo.getProductSales(_range, professionalId: profId);
      } else if (widget.reportCategory == 'vendas_servicos') {
        _data = await _repo.getServiceSales(_range, professionalId: profId);
      } else if (widget.reportCategory == 'comissoes') {
        _data = await _repo.getCommissionsReport(_range, professionalId: profId);
      }
    } catch (e) {
      debugPrint('Erro relatório profissional: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _title {
    switch (widget.reportCategory) {
      case 'financeiro': return 'Relatório Financeiro';
      case 'operacional': return 'Performance Operacional';
      case 'pico': return 'Horário de Pico';
      case 'vendas_produtos': return 'Vendas de Produtos';
      case 'vendas_servicos': return 'Vendas de Serviços';
      case 'comissoes': return 'Relatório de Comissões';
      default: return 'Relatório';
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryGreen = AppColors.primary;
    final accent = AppColors.accent;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ProfissionalAppBar(title: _title, showBackButton: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Filtro de período
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _buildFilterMenu(
                          label: 'Período',
                          currentValue: _selectedPeriod,
                          options: ['Hoje','Ontem','Semana Atual','Última Semana','Mês Atual','Mês Passado','Ano Atual'],
                          onSelected: _onPeriodSelected,
                          primaryColor: primaryGreen,
                          labelColor: accent,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    if (_data == null)
                      _buildError()
                    else
                      _buildBody(primaryGreen, accent),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error.withOpacity(0.7)),
            const SizedBox(height: 16),
            const Text('Erro ao carregar o relatório.', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ElevatedButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(Color primaryGreen, Color accent) {
    final cat = widget.reportCategory;
    if (cat == 'financeiro') {
      final map = _data as Map<String, dynamic>;
      return _buildFinancialView(map['report'] as FinancialReport, map['statement'] as FinancialStatement, primaryGreen, accent);
    }
    if (cat == 'operacional') return _buildOperationalView(_data as OperationalReport, primaryGreen, accent);
    if (cat == 'pico') return _buildPeakTimeView(_data as PeakTimeReport, primaryGreen, accent);
    if (cat == 'vendas_produtos') return _buildProductSalesView(_data as List<ProductSale>, primaryGreen, accent);
    if (cat == 'vendas_servicos') return _buildServiceSalesView(_data as List<ServiceSale>, primaryGreen, accent);
    if (cat == 'comissoes') return _buildCommissionsView(_data as CommissionReport, primaryGreen, accent);
    return const Center(child: Text('Categoria não encontrada'));
  }

  // ── Financial ──────────────────────────────────────────────────────────────

  Widget _buildFinancialView(FinancialReport report, FinancialStatement statement, Color green, Color gold) {
    final cf = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Resumo de Resultados', green),
      const SizedBox(height: 16),
      GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2.2, children: [
        _indicator('Faturamento Bruto', cf.format(report.totalRevenue), AppColors.success),
        _indicator('Taxas de Cartão', cf.format(report.totalTaxes), AppColors.error),
        _indicator('Comissões', cf.format(report.totalCommissions), AppColors.warning),
        _indicator('Lucro Operacional', cf.format(report.operatingProfit), green),
      ]),
      const SizedBox(height: 32),
      _sectionTitle('Fluxo de Caixa', green),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _indicator('Faturamento', cf.format(statement.income), AppColors.success)),
        const SizedBox(width: 12),
        Expanded(child: _indicator('Despesas', cf.format(statement.expenses), AppColors.error)),
      ]),
      const SizedBox(height: 16),
      Container(height: 250, padding: const EdgeInsets.all(16), decoration: _card(),
        child: Column(children: [
          Expanded(child: CashFlowBarChart(data: statement.cashFlow, incomeColor: AppColors.success, expenseColor: AppColors.error)),
          const SizedBox(height: 8),
          ChartLegend(items: [LegendItem('Entradas', AppColors.success), LegendItem('Saídas', AppColors.error)]),
        ]),
      ),
    ]);
  }

  // ── Operational ────────────────────────────────────────────────────────────

  Widget _buildOperationalView(OperationalReport data, Color green, Color gold) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Performance Operacional', green),
      const SizedBox(height: 16),
      GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2, children: [
        _indicator('Concluídos', '${data.concluidos}', AppColors.success),
        _indicator('Cancelados', '${data.cancelados}', AppColors.warning),
        _indicator('Ausentes', '${data.ausentes}', AppColors.error),
        _indicator('No-Show', '${data.noShowRate.toStringAsFixed(1)}%', AppColors.textLight),
      ]),
      const SizedBox(height: 32),
      _sectionTitle('Agendamentos Diários', green),
      const SizedBox(height: 16),
      Container(height: 200, padding: const EdgeInsets.all(16), decoration: _card(),
        child: RevenueLineChart(data: data.appointmentsByDay, primaryColor: green),
      ),
    ]);
  }

  // ── Peak time ──────────────────────────────────────────────────────────────

  Widget _buildPeakTimeView(PeakTimeReport data, Color green, Color gold) {
    return DefaultTabController(length: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: AppColors.shadow.withOpacity(0.05), blurRadius: 10)]),
        child: TabBar(labelColor: AppColors.primary, unselectedLabelColor: AppColors.textLight, indicatorColor: AppColors.accent, indicatorWeight: 3,
          tabs: const [Tab(text: 'Por Horário'), Tab(text: 'Dias da Semana')]),
      ),
      const SizedBox(height: 24),
      SizedBox(height: 900, child: TabBarView(physics: const NeverScrollableScrollPhysics(), children: [
        _buildPeakContent(data.hourlyData, 'Horários de Atendimento', green, gold),
        _buildPeakContent(data.dailyData, 'Dias da Semana', green, gold),
      ])),
    ]));
  }

  Widget _buildPeakContent(List<PeakTimeData> list, String label, Color green, Color gold) {
    final cf = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle(label, green),
      const SizedBox(height: 16),
      Container(height: 260, padding: const EdgeInsets.all(16), decoration: _card(),
        child: PeakBarChart(data: list, color: green),
      ),
      const SizedBox(height: 24),
      Container(decoration: _card(), clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(green.withOpacity(0.05)),
            columns: ['Hora/Dia','Agend.','Ticket Méd.','Faturamento'].map((h) => DataColumn(label: Text(h, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))).toList(),
            rows: list.map((item) => DataRow(cells: [
              DataCell(Text(item.label, style: const TextStyle(fontSize: 12))),
              DataCell(Text('${item.appointmentsCount}', style: const TextStyle(fontSize: 12))),
              DataCell(Text(cf.format(item.averageTicket), style: const TextStyle(fontSize: 12))),
              DataCell(Text(cf.format(item.totalRevenue), style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.bold))),
            ])).toList(),
          ),
        ),
      ),
    ]);
  }

  // ── Product sales ──────────────────────────────────────────────────────────

  Widget _buildProductSalesView(List<ProductSale> data, Color green, Color gold) {
    final cf = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    if (data.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('Nenhuma venda de produto encontrada.')));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Vendas de Produtos', green),
      const SizedBox(height: 16),
      _tableContainer(DataTable(
        headingRowColor: WidgetStateProperty.all(green.withOpacity(0.05)),
        columnSpacing: 16,
        columns: ['Data','Produto','Qtd','Total'].map((h) => DataColumn(label: Text(h, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))).toList(),
        rows: data.map((s) => DataRow(cells: [
          DataCell(Text(DateFormat('dd/MM/yy').format(s.date), style: const TextStyle(fontSize: 12))),
          DataCell(Text(s.productName, style: const TextStyle(fontSize: 12))),
          DataCell(Text('${s.quantity}', style: const TextStyle(fontSize: 12))),
          DataCell(Text(cf.format(s.totalPrice), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success))),
        ])).toList(),
      )),
    ]);
  }

  // ── Service sales ──────────────────────────────────────────────────────────

  Widget _buildServiceSalesView(List<ServiceSale> data, Color green, Color gold) {
    final cf = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    if (data.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('Nenhuma venda de serviço encontrada.')));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Vendas de Serviços', green),
      const SizedBox(height: 16),
      _tableContainer(DataTable(
        headingRowColor: WidgetStateProperty.all(green.withOpacity(0.05)),
        columnSpacing: 16,
        columns: ['Data','Serviço','Total'].map((h) => DataColumn(label: Text(h, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))).toList(),
        rows: data.map((s) => DataRow(cells: [
          DataCell(Text(DateFormat('dd/MM/yy').format(s.date), style: const TextStyle(fontSize: 12))),
          DataCell(Text(s.serviceName, style: const TextStyle(fontSize: 12))),
          DataCell(Text(cf.format(s.price), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success))),
        ])).toList(),
      )),
    ]);
  }

  // ── Commissions ────────────────────────────────────────────────────────────

  Widget _buildCommissionsView(CommissionReport data, Color green, Color gold) {
    final cf = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Resumo de Comissões', green),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _indicator('Base Comissionável', cf.format(data.totalCommissionedRevenue), green)),
        const SizedBox(width: 12),
        Expanded(child: _indicator('Total a Receber', cf.format(data.totalCommissionPayout), AppColors.warning)),
      ]),
      const SizedBox(height: 32),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _sectionTitle('Distribuição', green),
        IconButton(icon: Icon(_isBarChart ? Icons.pie_chart_outline : Icons.bar_chart), onPressed: () => setState(() => _isBarChart = !_isBarChart)),
      ]),
      const SizedBox(height: 16),
      Container(height: 280, padding: const EdgeInsets.all(16), decoration: _card(),
        child: _isBarChart
          ? CommissionBarChart(data: {for (var p in data.professionals) p.professionalName: p.commissionAmount}, color: AppColors.accent)
          : DistributionPieChart(data: {for (var p in data.professionals) p.professionalName: p.commissionAmount}, colors: [AppColors.primary, AppColors.accent, AppColors.textSecondary, AppColors.softGold]),
      ),
      const SizedBox(height: 32),
      _sectionTitle('Pagamentos por Dia', green),
      const SizedBox(height: 16),
      Container(height: 200, padding: const EdgeInsets.all(16), decoration: _card(),
        child: RevenueLineChart(data: data.payoutsByDay, primaryColor: AppColors.warning),
      ),
      const SizedBox(height: 32),
      _sectionTitle('Detalhamento', green),
      const SizedBox(height: 16),
      _tableContainer(DataTable(
        headingRowColor: WidgetStateProperty.all(green.withOpacity(0.05)),
        columnSpacing: 16,
        columns: ['Agend.','Prod.','Faturam.','Comis. Liq.'].map((h) => DataColumn(label: Text(h, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))).toList(),
        rows: data.professionals.map((p) => DataRow(cells: [
          DataCell(Text('${p.appointmentsCount}', style: const TextStyle(fontSize: 12))),
          DataCell(Text('${p.productsCount}', style: const TextStyle(fontSize: 12))),
          DataCell(Text(cf.format(p.totalRevenue), style: const TextStyle(fontSize: 12))),
          DataCell(Text(cf.format(p.commissionAmount), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.warning))),
        ])).toList(),
      )),
    ]);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _sectionTitle(String title, Color color) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(title, style: TextStyle(fontFamily: 'Playfair Display', fontSize: 20, fontWeight: FontWeight.bold, color: color)),
  );

  Widget _indicator(String label, String value, Color color) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _card(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 10, color: AppColors.textLight, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
    ]),
  );

  Widget _tableContainer(Widget child) => Container(
    width: double.infinity,
    decoration: _card(),
    clipBehavior: Clip.antiAlias,
    child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: child),
  );

  BoxDecoration _card() => BoxDecoration(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [BoxShadow(color: AppColors.shadow.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
  );

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
          child: Row(children: [
            Text(option, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? primaryColor : AppColors.textPrimary)),
            if (isSelected) ...[const Spacer(), Icon(Icons.check, size: 16, color: primaryColor)],
          ]),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryColor.withOpacity(0.1)),
          boxShadow: [BoxShadow(color: AppColors.shadow.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$label: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: labelColor ?? AppColors.textLight)),
          Text(currentValue, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryColor)),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, size: 18, color: primaryColor),
        ]),
      ),
    );
  }
}
