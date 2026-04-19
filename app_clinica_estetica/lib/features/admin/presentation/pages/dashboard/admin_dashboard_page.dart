import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:app_clinica_estetica/core/data/repositories/dashboard_repository.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';
import 'admin_atividades_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _repository = SupabaseDashboardRepository();
  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  
  bool _isLoading = true;
  String _selectedFilter = 'Hoje';
  DashboardStats? _stats;
  List<DashboardAtividade> _activities = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      DateTime start;
      DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

      switch (_selectedFilter) {
        case 'Hoje':
          start = DateTime(now.year, now.month, now.day);
          break;
        case 'Últimos 7 dias':
          start = now.subtract(const Duration(days: 7));
          break;
        case 'Últimos 30 dias':
          start = now.subtract(const Duration(days: 30));
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
        case 'Todo o período':
          start = DateTime(2000, 1, 1);
          break;
        default:
          start = DateTime(now.year, now.month, now.day);
      }

      final stats = await _repository.getStats(start, end);
      final activities = await _repository.getRecentActivities(limit: 5);

      setState(() {
        _stats = stats;
        _activities = activities;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = AppColors.primary;
    const accentColor = AppColors.accent;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Filter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dashboard',
                  style: TextStyle(fontFamily: 'Playfair Display', 
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                _buildFilterDropdown(primaryColor),
              ],
            ),
            const SizedBox(height: 20),

            if (_isLoading)
              const Center(child: Padding(
                padding: EdgeInsets.all(40.0),
                child: CircularProgressIndicator(),
              ))
            else ...[
              // TOP CARDS (Green) - Principais
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Faturamento',
                      value: _currencyFormat.format(_stats?.faturamento ?? 0),
                      isGreen: true,
                      primaryColor: primaryColor,
                      accentColor: accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Quant. Atendimentos',
                      value: '${_stats?.totalAtendimentos ?? 0}',
                      isGreen: true,
                      primaryColor: primaryColor,
                      accentColor: accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // LIST STATS (Secondary)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    _buildListStat('Total de Clientes:', '${_stats?.totalClientes ?? 0}', primaryColor),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),
                    _buildListStat('Quant. de Procedimentos:', '${_stats?.totalProcedimentos ?? 0}', primaryColor),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),
                    _buildListStat('Total de Avaliações:', '${_stats?.totalAvaliacoes ?? 0}', primaryColor),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Quick Actions
              Text(
                'Ações Rápidas',
                style: TextStyle(fontFamily: 'Playfair Display', 
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              _buildQuickActionsList(primaryColor, accentColor),

              const SizedBox(height: 32),

              // Recent Activities
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Atividades Recentes',
                    style: TextStyle(fontFamily: 'Playfair Display', 
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminAtividadesPage()),
                    ).then((_) => _loadData()),
                    child: Text(
                      'Ver todas',
                      style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_activities.isEmpty)
                const Center(child: Text('Nenhuma atividade recente.'))
              else
                ..._activities.map((act) => _buildActivityItem(act, primaryColor, accentColor)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(Color primaryColor) {
    return PopupMenuButton<String>(
      tooltip: '',
      onSelected: (val) {
        setState(() => _selectedFilter = val);
        _loadData();
      },
      itemBuilder: (context) => [
        'Hoje',
        'Últimos 7 dias',
        'Últimos 30 dias',
        'Mês Atual',
        'Mês Passado',
        'Ano Atual',
        'Todo o período',
      ].map((f) => PopupMenuItem(value: f, child: Text(f))).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Text(
              _selectedFilter,
              style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required bool isGreen,
    required Color primaryColor,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isGreen ? primaryColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isGreen ? null : [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isGreen ? accentColor : accentColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: value.length > 8 ? 18 : 22,
              fontWeight: FontWeight.w800,
              color: isGreen ? AppColors.white : primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListStat(String label, String value, Color primary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsList(Color primaryColor, Color accentColor) {
    return Column(
      children: [
        _buildActionListItem(
          icon: Icons.person_add_outlined,
          title: 'Novo Profissional',
          onTap: () => context.go('/admin/profissionais/novo'),
          primaryColor: primaryColor,
        ),
        _buildActionListItem(
          icon: Icons.medical_services_outlined,
          title: 'Novo Procedimento',
          onTap: () => context.go('/admin/servicos/novo'),
          primaryColor: primaryColor,
        ),
        _buildActionListItem(
          icon: Icons.calendar_month_outlined,
          title: 'Novo Agendamento',
          onTap: () => context.go('/admin/agendamentos'),
          primaryColor: primaryColor,
        ),
        _buildActionListItem(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Visualizar Caixa',
          onTap: () => context.go('/admin/caixa'),
          primaryColor: primaryColor,
        ),
        _buildActionListItem(
          icon: Icons.assessment_outlined,
          title: 'Visualizar Relatórios',
          onTap: () => context.go('/admin/reports-admin'),
          primaryColor: primaryColor,
        ),
      ],
    );
  }

  Widget _buildActionListItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color primaryColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: primaryColor, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.accent, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(DashboardAtividade act, Color primaryColor, Color accentColor) {
    IconData icon;
    switch (act.tipo) {
      case 'agendamento':
        icon = Icons.calendar_today_outlined;
        break;
      case 'cliente':
        icon = Icons.person_outline;
        break;
      case 'configuracao':
        icon = Icons.settings_outlined;
        break;
      default:
        icon = Icons.notifications_none;
    }

    final diff = DateTime.now().difference(act.criadoEm);
    String timeStr;
    if (diff.inMinutes < 60) {
      timeStr = '${diff.inMinutes}m atrás';
    } else if (diff.inHours < 24) {
      timeStr = '${diff.inHours}h atrás';
    } else {
      timeStr = DateFormat('dd/MM HH:mm').format(act.criadoEm);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  act.titulo,
                  style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                Text(
                  act.displayDescription,
                  style: const TextStyle(fontSize: 11,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
          Text(
            timeStr,
            style: const TextStyle(fontSize: 10,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }
}

