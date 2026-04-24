import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';
import 'package:app_clinica_estetica/features/auth/data/auth_service.dart';
import 'package:app_clinica_estetica/features/admin/data/models/report_models.dart';
import 'package:app_clinica_estetica/features/admin/data/repositories/report_repository.dart';
import 'package:app_clinica_estetica/features/admin/data/repositories/supabase_report_repository.dart';
import 'package:app_clinica_estetica/features/profissional/presentation/widgets/profissional_app_bar.dart';
import 'package:app_clinica_estetica/features/profissional/presentation/widgets/profissional_bottom_nav_bar.dart';

class ProfissionalRelatoriosPage extends StatefulWidget {
  const ProfissionalRelatoriosPage({super.key});

  @override
  State<ProfissionalRelatoriosPage> createState() =>
      _ProfissionalRelatoriosPageState();
}

class _ProfissionalRelatoriosPageState
    extends State<ProfissionalRelatoriosPage> {
  final IReportRepository _repo = SupabaseReportRepository();
  late DateTimeRange _range;
  String _selectedPeriod = 'Mês atual';

  bool _isLoading = true;
  FinancialReport? _financial;
  PatientReport? _patients;
  OperationalReport? _operational;
  FinancialStatement? _statement;

  String? get _professionalId => AuthService.currentUserId;

  @override
  void initState() {
    super.initState();
    _onPeriodSelected(_selectedPeriod);
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
        final yesterday = now.subtract(const Duration(days: 1));
        start = DateTime(yesterday.year, yesterday.month, yesterday.day);
        end = DateTime(
            yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
        break;
      case 'Semana atual':
        final thisMon = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(thisMon.year, thisMon.month, thisMon.day);
        break;
      case 'Última semana':
        final lastMon = now.subtract(Duration(days: now.weekday + 6));
        final lastSun = lastMon.add(const Duration(days: 6));
        start = DateTime(lastMon.year, lastMon.month, lastMon.day);
        end = DateTime(lastSun.year, lastSun.month, lastSun.day, 23, 59, 59);
        break;
      case 'Mês atual':
        start = DateTime(now.year, now.month, 1);
        break;
      case 'Mês passado':
        start = DateTime(now.year, now.month - 1, 1);
        end = DateTime(now.year, now.month, 0, 23, 59, 59);
        break;
      case 'Ano atual':
        start = DateTime(now.year, 1, 1);
        break;
      default:
        start = DateTime(now.year, now.month, 1);
    }

    setState(() {
      _range = DateTimeRange(start: start, end: end);
      _selectedPeriod = period;
    });
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoading = true);
    try {
      final profId = _professionalId;
      final results = await Future.wait([
        _repo.getFinancialReport(_range, professionalId: profId),
        _repo.getPatientReport(_range, professionalId: profId),
        _repo.getOperationalReport(_range, professionalId: profId),
        _repo.getFinancialStatement(_range, professionalId: profId),
      ]);
      _financial = results[0] as FinancialReport;
      _patients = results[1] as PatientReport;
      _operational = results[2] as OperationalReport;
      _statement = results[3] as FinancialStatement;
    } catch (e) {
      debugPrint('Erro ao carregar relatórios do profissional: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryGreen = AppColors.primary;
    final accent = AppColors.accent;
    final bgColor = AppColors.background;
    final currencyFormat =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      backgroundColor: bgColor,
      appBar: const ProfissionalAppBar(title: 'Relatórios'),
      bottomNavigationBar:
          const ProfissionalBottomNavigationBar(activeIndex: 1),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSummary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Cabeçalho ---
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Meu Desempenho',
                            style: TextStyle(
                              fontFamily: 'Playfair Display',
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: primaryGreen,
                            ),
                          ),
                          Text(
                            'Seus indicadores e relatórios detalhados',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.6,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // --- Filtro de Período ---
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterMenu(
                              label: 'Período',
                              currentValue: _selectedPeriod,
                              options: [
                                'Hoje',
                                'Ontem',
                                'Semana atual',
                                'Última semana',
                                'Mês atual',
                                'Mês passado',
                                'Ano atual',
                              ],
                              onSelected: _onPeriodSelected,
                              primaryColor: primaryGreen,
                              labelColor: accent,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // --- Cards de Resumo ---
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        child: Row(
                          children: [
                            _buildSummaryCard(
                              title: 'Faturamento',
                              value: currencyFormat
                                  .format(_financial?.totalRevenue ?? 0),
                              icon: Icons.payments_outlined,
                              trendLabel: 'receita no período',
                              growth: _financial?.revenueGrowth ?? 0,
                              showTrend: false,
                              primaryGreen: primaryGreen,
                              accent: accent,
                            ),
                            const SizedBox(width: 12),
                            _buildSummaryCard(
                              title: 'Agendamentos',
                              value:
                                  '${_operational?.totalAgendamentos ?? 0}',
                              icon: Icons.calendar_month_outlined,
                              trendLabel: 'atendimentos',
                              growth: (_operational?.totalAgendamentos
                                      .toDouble() ??
                                  0),
                              showTrend: false,
                              primaryGreen: primaryGreen,
                              accent: AppColors.info,
                            ),
                            const SizedBox(width: 12),
                            _buildSummaryCard(
                              title: 'Ticket médio',
                              value: currencyFormat
                                  .format(_financial?.averageTicket ?? 0),
                              icon: Icons.confirmation_number_outlined,
                              trendLabel: 'por atendimento',
                              growth: 0,
                              showTrend: false,
                              primaryGreen: primaryGreen,
                              accent: accent,
                            ),
                            const SizedBox(width: 12),
                            _buildSummaryCard(
                              title: 'Comissões',
                              value: currencyFormat
                                  .format(_financial?.totalCommissions ?? 0),
                              icon: Icons.account_balance_outlined,
                              trendLabel: 'a receber',
                              growth: 0,
                              showTrend: false,
                              primaryGreen: primaryGreen,
                              accent: AppColors.success,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // --- Título Relatórios Detalhados ---
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Relatórios detalhados',
                            style: TextStyle(
                              fontFamily: 'Playfair Display',
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: primaryGreen,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Selecione uma área para visualizar métricas avançadas.',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // --- Lista de Relatórios ---
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Financeiro', accent),
                          const SizedBox(height: 12),
                          _buildReportCard(
                            title: 'Relatório Financeiro',
                            description:
                                'Detalhamento de faturamento e margens no período.',
                            icon: Icons.account_balance_wallet_outlined,
                            onPressed: () =>
                                _navigateToDetail('financeiro'),
                          ),
                          const SizedBox(height: 16),
                          _buildReportCard(
                            title: 'Relatório de Comissões',
                            description:
                                'Cálculo detalhado das suas comissões no período.',
                            icon: Icons.monetization_on_outlined,
                            onPressed: () =>
                                _navigateToDetail('comissoes'),
                          ),
                          const SizedBox(height: 32),
                          _buildSectionHeader('Operacional', accent),
                          const SizedBox(height: 12),
                          _buildReportCard(
                            title: 'Performance Operacional',
                            description:
                                'Taxa de ocupação, cancelamentos e no-shows.',
                            icon: Icons.analytics_outlined,
                            onPressed: () =>
                                _navigateToDetail('operacional'),
                          ),
                          const SizedBox(height: 16),
                          _buildReportCard(
                            title: 'Horário de Pico',
                            description:
                                'Seus horários e dias com maior volume de atendimentos.',
                            icon: Icons.access_time_outlined,
                            onPressed: () => _navigateToDetail('pico'),
                          ),
                          const SizedBox(height: 32),
                          _buildSectionHeader('Vendas', accent),
                          const SizedBox(height: 12),
                          _buildReportCard(
                            title: 'Vendas de Produtos',
                            description:
                                'Produtos vendidos por você no período selecionado.',
                            icon: Icons.shopping_bag_outlined,
                            onPressed: () =>
                                _navigateToDetail('vendas_produtos'),
                          ),
                          const SizedBox(height: 16),
                          _buildReportCard(
                            title: 'Vendas de Serviços',
                            description:
                                'Serviços realizados e faturamento por atendimento.',
                            icon: Icons.content_paste_outlined,
                            onPressed: () =>
                                _navigateToDetail('vendas_servicos'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  void _navigateToDetail(String category) {
    context.push(
      '/profissional/relatorios/detalhes/$category',
      extra: {
        'range': _range,
        'professionalId': _professionalId,
      },
    );
  }

  Widget _buildSectionHeader(String title, Color primaryColor) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: primaryColor.withOpacity(0.6),
        letterSpacing: 1.6,
      ),
    );
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
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
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
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryColor.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
                color: AppColors.shadow.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: labelColor ?? AppColors.textLight,
              ),
            ),
            Text(
              currentValue,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down,
                size: 18, color: primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required String trendLabel,
    required double growth,
    bool showTrend = true,
    required Color primaryGreen,
    required Color accent,
  }) {
    final isPositive = growth >= 0;
    return Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryGreen.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: AppColors.textLight,
                  ),
                ),
              ),
              Icon(icon, color: accent, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: primaryGreen,
              ),
            ),
          ),
          Row(
            children: [
              if (showTrend) ...[
                Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  size: 14,
                  color: isPositive ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 4),
                Text(
                  '${growth.toStringAsFixed(1)}% $trendLabel',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isPositive
                        ? AppColors.success
                        : AppColors.error,
                  ),
                ),
              ] else ...[
                Text(
                  trendLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final primaryGreen = AppColors.primary;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryGreen.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: primaryGreen, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'Playfair Display',
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textLight,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.shadow),
          ],
        ),
      ),
    );
  }
}
