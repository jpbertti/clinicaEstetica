import 'package:app_clinica_estetica/features/auth/data/auth_service.dart';
import 'package:app_clinica_estetica/core/services/report_app_bar_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_clinica_estetica/core/app_config.dart';
import 'package:app_clinica_estetica/features/admin/presentation/pages/dashboard/admin_atividades_page.dart';
import 'package:app_clinica_estetica/core/data/repositories/dashboard_repository.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';
import 'package:app_clinica_estetica/core/theme/app_text_styles.dart';

class AdminShellPage extends StatefulWidget {
  final Widget child;
  final String currentPath;
  final Object? extra;

  const AdminShellPage({
    super.key,
    required this.child,
    required this.currentPath,
    this.extra,
  });

  @override
  State<AdminShellPage> createState() => _AdminShellPageState();
}

class _AdminShellPageState extends State<AdminShellPage> {
  final _reportAppBarService = ReportAppBarService();

  @override
  void initState() {
    super.initState();
    _reportAppBarService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _reportAppBarService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) {
      // Usamos addPostFrameCallback para evitar o erro de setState durante o build/dispose
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = AppColors.primary;
    const primaryRed = AppColors.error;
    const secondaryGold = AppColors.accent;
    const bgColor = AppColors.background;

    String getPageTitle(String path) {
      // Prioritize service title if available
      if (_reportAppBarService.customTitle != null) {
        return _reportAppBarService.customTitle!;
      }

      if (path == '/admin') return 'Painel Administrativo';
      if (path == '/admin/clientes') return 'Gestão de Clientes';
      
      // Dynamic Title for Client Details
      if (path.startsWith('/admin/clientes/') && path != '/admin/clientes') {
        return 'Dados do Cliente';
      }

      if (path == '/admin/usuarios') return 'Gerenciamento de Usuários';

      // Rotas Mais Específicas Primeiro
      if (path.contains('/vincular-pacotes')) return 'Vincular Projetos';
      if (path.contains('/vincular')) return 'Vincular Serviços';
      
      if (path == '/admin/servicos/pacotes/novo') return 'Adicionar Pacote';
      if (path == '/admin/servicos/pacotes/editar') return 'Editar Pacote';

      if (path.startsWith('/admin/financeiro')) return 'Financeiro';
      if (path.startsWith('/admin/profissionais')) return 'Profissionais';
      if (path.startsWith('/admin/servicos')) return 'Serviços';
      if (path == '/admin/agendamentos') return 'Agendamentos';
      if (path == '/admin/reports-admin') return 'Relatórios';
      if (path == '/admin/configuracoes') return 'Configurações';
      if (path == '/admin/caixa') return 'Fluxo de Caixa';
      if (path == '/admin/produtos') return 'Estoque de Produtos';
      if (path == '/admin/produtos/novo') return 'Cadastrar Produto';
      if (path == '/admin/produtos/editar') return 'Editar Produto';
      if (path == '/admin/horarios') return 'Funcionamento';
      if (path == '/admin/promocoes') return 'Gerenciar Promoções';
      if (path == '/admin/configuracoes/taxas') return 'Taxas do cartão';
      return 'Painel';
    }

    final bool isReportDetail = widget.currentPath.startsWith('/admin/reports-admin/detalhes');
    final bool isVincular = widget.currentPath.contains('/vincular');
    final bool isClientDetail = widget.currentPath.startsWith('/admin/clientes/');
    // Vincular pages should always be centered per user request
    final bool shouldLeftAlign = (isReportDetail || _reportAppBarService.showActions) && !isVincular && !isClientDetail;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        leading: Builder(
          builder: (context) {
            // Se o serviço indicar que o leading deve ser ocultado (ex: passos específicos)
            if (_reportAppBarService.hideLeading) {
              return const SizedBox.shrink();
            }

            // Se estivermos em uma rota de detalhes ou se o serviço indicar ações ativas (como nos relatórios),
            // mostramos o botão de voltar.
            bool canPop = context.canPop();
            if (canPop || isReportDetail || isVincular) {
              return IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: primaryGreen, size: 24),
                onPressed: () {
                  if (canPop) {
                    context.pop();
                  } else if (isVincular) {
                    context.go('/admin/profissionais');
                  } else {
                    context.go('/admin/reports-admin');
                  }
                  // Reset actions when moving back
                  _reportAppBarService.reset();
                },
              );
            }

            return IconButton(
              icon: const Icon(Icons.menu, color: primaryGreen, size: 28),
              onPressed: () => Scaffold.of(context).openDrawer(),
            );
          },
        ),
        title: Text(
          getPageTitle(widget.currentPath),
          style: const TextStyle(
            fontFamily: 'Playfair Display',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: primaryGreen,
          ),
        ),
        centerTitle: !shouldLeftAlign,
        titleSpacing: shouldLeftAlign ? 0 : null,
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (_reportAppBarService.showActions) ...[
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded, color: primaryRed, size: 24),
              onPressed: _reportAppBarService.onPdfPressed,
            ),
            IconButton(
              icon: const Icon(Icons.calendar_month_rounded, color: primaryGreen, size: 24),
              onPressed: _reportAppBarService.onCalendarPressed,
            ),
          ],

          _NotificationBell(primaryGreen: AppColors.primary),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _AdminDrawer(currentPath: widget.currentPath),
      body: widget.child,
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  final String currentPath;

  const _AdminDrawer({required this.currentPath});

  @override
  Widget build(BuildContext context) {
    const primaryGreen = AppColors.primary;
    const secondaryGold = AppColors.accent;
    const bgColor = AppColors.background;
    const activeItemBg = AppColors.primary;

    final String userName = AuthService.currentUserNome ?? 'Dr. Julianne Smith';

    return Drawer(
      width: 300,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: primaryGreen, width: 1.5),
                        image: AppConfig.logoUrl != null
                            ? DecorationImage(
                                image: NetworkImage(AppConfig.logoUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      padding: AppConfig.logoUrl == null ? const EdgeInsets.all(4) : EdgeInsets.zero,
                      child: AppConfig.logoUrl == null
                          ? Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary,
                              ),
                              child: const Center(
                                child: Icon(Icons.spa_rounded, color: Colors.white, size: 28),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Clinica Estética',
                            style: AppTextStyles.playfairTitle,
                          ),
                          const Text(
                            'Painel Administrativo',
                            style: AppTextStyles.interSub,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(color: AppColors.divider, thickness: 1),
              ],
            ),
          ),

          // ── Nav Items ───────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _NavItem(
                  icon: Icons.grid_view_rounded,
                  label: 'Painel',
                  path: '/admin',
                  currentPath: currentPath,
                  activeBg: activeItemBg,
                  activeIcon: Colors.white,
                  activeText: Colors.white,
                  inactiveColor: primaryGreen.withOpacity(0.7),
                ),
                _NavItem(
                  icon: Icons.point_of_sale_outlined,
                  label: 'Caixa',
                  path: '/admin/caixa',
                  currentPath: currentPath,
                  activeBg: activeItemBg,
                  activeIcon: Colors.white,
                  activeText: Colors.white,
                  inactiveColor: primaryGreen.withOpacity(0.7),
                ),
                _NavItem(
                  icon: Icons.badge_outlined,
                  label: 'Profissionais',
                  path: '/admin/profissionais',
                  currentPath: currentPath,
                  activeBg: activeItemBg,
                  activeIcon: Colors.white,
                  activeText: Colors.white,
                  inactiveColor: primaryGreen.withOpacity(0.7),
                ),
                _NavItem(
                  icon: Icons.auto_awesome_outlined,
                  label: 'Procedimentos',
                  path: '/admin/servicos',
                  currentPath: currentPath,
                  activeBg: activeItemBg,
                  activeIcon: Colors.white,
                  activeText: Colors.white,
                  inactiveColor: primaryGreen.withOpacity(0.7),
                ),
                _NavItem(
                  icon: Icons.payments_outlined,
                  label: 'Agendamentos',
                  path: '/admin/agendamentos', // Placeholder path
                  currentPath: currentPath,
                  activeBg: activeItemBg,
                  activeIcon: Colors.white,
                  activeText: Colors.white,
                  inactiveColor: primaryGreen.withOpacity(0.7),
                ),
                _NavItem(
                  icon: Icons.group_outlined,
                  label: 'Clientes',
                  path: '/admin/clientes',
                  currentPath: currentPath,
                  activeBg: activeItemBg,
                  activeIcon: Colors.white,
                  activeText: Colors.white,
                  inactiveColor: primaryGreen.withOpacity(0.7),
                ),
                _NavItem(
                  icon: Icons.inventory_2_outlined,
                  label: 'Produtos',
                  path: '/admin/produtos',
                  currentPath: currentPath,
                  activeBg: activeItemBg,
                  activeIcon: Colors.white,
                  activeText: Colors.white,
                  inactiveColor: primaryGreen.withOpacity(0.7),
                ),
                _NavItem(
                  icon: Icons.analytics_outlined,
                  label: 'Relatórios',
                  path: '/admin/reports-admin',
                  currentPath: currentPath,
                  activeBg: activeItemBg,
                  activeIcon: Colors.white,
                  activeText: Colors.white,
                  inactiveColor: primaryGreen.withOpacity(0.7),
                ),
                _NavItem(
                  icon: Icons.settings_outlined,
                  label: 'Configurações',
                  path: '/admin/configuracoes',
                  currentPath: currentPath,
                  activeBg: activeItemBg,
                  activeIcon: Colors.white,
                  activeText: Colors.white,
                  inactiveColor: primaryGreen.withOpacity(0.7),
                ),
              ],
            ),
          ),

          // ── Footer ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            child: Column(
              children: [
                // Current Session Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sessão Atual',
                        style: TextStyle(color: secondaryGold,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        userName,
                        style: TextStyle(color: primaryGreen,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Logout Button
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/admin/confirmacao-logout');
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.logout_rounded, color: primaryGreen, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          'Sair',
                          style: TextStyle(color: primaryGreen,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.chevron_right_rounded, color: secondaryGold, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String path;
  final String currentPath;
  final Color activeBg;
  final Color activeIcon;
  final Color activeText;
  final Color inactiveColor;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.path,
    required this.currentPath,
    required this.activeBg,
    required this.activeIcon,
    required this.activeText,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = currentPath == path;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          context.go(path);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeBg.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? activeIcon : inactiveColor,
                size: 22,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: isSelected ? activeText : inactiveColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _NotificationBell extends StatefulWidget {
  final Color primaryGreen;
  const _NotificationBell({required this.primaryGreen});

  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  bool _hasUnread = false;

  @override
  void initState() {
    super.initState();
    _checkUnread();
  }

  Future<void> _checkUnread() async {
    try {
      final repo = SupabaseDashboardRepository();
      final count = await repo.countUnread();
      
      if (mounted) {
        setState(() => _hasUnread = count > 0);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    const secondaryGold = AppColors.accent;
    const notificationGreen = AppColors.primary;

    return IconButton(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            _hasUnread ? Icons.notifications_rounded : Icons.notifications_none_rounded,
            color: _hasUnread ? notificationGreen : secondaryGold,
            size: 26,
          ),
          if (_hasUnread)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: secondaryGold, // Golden detail as requested
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AdminAtividadesPage()),
      ).then((_) => _checkUnread()),
    );
  }
}

