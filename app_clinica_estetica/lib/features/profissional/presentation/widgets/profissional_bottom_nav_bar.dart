import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';

class ProfissionalBottomNavigationBar extends StatelessWidget {
  final int activeIndex;

  const ProfissionalBottomNavigationBar({
    super.key,
    required this.activeIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
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
            style: TextStyle(
              fontSize: 9,
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
