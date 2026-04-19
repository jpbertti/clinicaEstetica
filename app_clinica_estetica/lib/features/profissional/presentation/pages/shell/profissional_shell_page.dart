import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_clinica_estetica/features/auth/data/auth_service.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_notification_repository.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';


class ProfissionalShellPage extends StatefulWidget {
  final Widget child;
  final String currentPath;

  const ProfissionalShellPage({
    super.key,
    required this.child,
    required this.currentPath,
  });

  @override
  State<ProfissionalShellPage> createState() => _ProfissionalShellPageState();
}

class _ProfissionalShellPageState extends State<ProfissionalShellPage> {
  final _notificationRepo = SupabaseNotificationRepository();

  int _calculateSelectedIndex(String path) {
    if (path.startsWith('/profissional/agenda')) return 0;
    if (path.startsWith('/profissional/relatorios')) return 1;
    if (path.startsWith('/profissional/perfil')) return 2;
    return 0;
  }

  String _getPageTitle(String path) {
    if (path.startsWith('/profissional/agenda')) return 'AGENDA';
    if (path.startsWith('/profissional/relatorios')) return 'RELATÓRIOS';
    if (path.startsWith('/profissional/perfil')) return 'PERFIL';
    if (path.startsWith('/profissional/notificacoes')) return 'NOTIFICAÇÕES';
    return 'ESTÉTICA';
  }

  @override
  Widget build(BuildContext context) {
    final primaryGreen = AppColors.primary;
    final accent = AppColors.accent;
    final bgColor = AppColors.background;

    final activeIndex = _calculateSelectedIndex(widget.currentPath);
    final isNotificationPage = widget.currentPath == '/profissional/notificacoes';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        leading: isNotificationPage 
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: primaryGreen, size: 20),
                onPressed: () => context.pop(),
              )
            : null,
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          _getPageTitle(widget.currentPath),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
        ),

        actions: [
          StreamBuilder<int>(
            stream: _getUnreadCountStream(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              final hasUnread = count > 0;
              final notificationGreen = AppColors.primary;
              final secondaryGold = AppColors.accent;


              return IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      hasUnread ? Icons.notifications_rounded : Icons.notifications_none_rounded,
                      color: notificationGreen,
                      size: 26,
                    ),
                    if (hasUnread)
                      Positioned(
                        right: -1,
                        top: -1,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: secondaryGold,
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
                onPressed: () {
                  if (!isNotificationPage) {
                    context.push('/profissional/notificacoes');
                  }
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: widget.child,
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _construirItemNavegacao(
              context,
              index: 0,
              icon: Icons.calendar_month_outlined,
              activeIcon: Icons.calendar_month,
              label: 'AGENDA',
              route: '/profissional/agenda',
              primaryColor: AppColors.primary,
              isActive: activeIndex == 0,

            ),
            _construirItemNavegacao(
              context,
              index: 1,
              icon: Icons.bar_chart_outlined,
              activeIcon: Icons.bar_chart,
              label: 'RELATÓRIOS',
              route: '/profissional/relatorios',
              primaryColor: AppColors.primary,
              isActive: activeIndex == 1,
            ),
            _construirItemNavegacao(
              context,
              index: 2,
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'PERFIL',
              route: '/profissional/perfil',
              primaryColor: AppColors.primary,
              isActive: activeIndex == 2,
            ),
          ],
        ),
      ),
    );
  }

  Stream<int> _getUnreadCountStream() {
    final userId = AuthService.currentUserId;
    if (userId == null) return Stream.value(0);
    
    // Emite o valor inicial imediatamente e depois a cada 30 segundos
    return (() async* {
      yield await _notificationRepo.getUnreadCount(userId);
      yield* Stream.periodic(const Duration(seconds: 30)).asyncMap((_) async {
        return await _notificationRepo.getUnreadCount(userId);
      });
    })().asBroadcastStream();
  }

  Widget _construirItemNavegacao(
    BuildContext context, {
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String route,
    required Color primaryColor,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () {
        if (!isActive) {
          context.go(route);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? activeIcon : icon,
            color: isActive ? primaryColor : Colors.black26,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 9,
              fontWeight: FontWeight.bold,
              color: isActive ? primaryColor : Colors.black26,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

