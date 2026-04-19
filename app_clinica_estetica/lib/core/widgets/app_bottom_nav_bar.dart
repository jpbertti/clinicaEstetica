import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppBottomNavigationBar extends StatelessWidget {
  final int activeIndex;

  const AppBottomNavigationBar({super.key, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2F5E46);

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
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: 'INÍCIO',
            route: '/inicio',
            primaryColor: primaryColor,
          ),
          _construirItemNavegacao(
            context,
            index: 1,
            icon: Icons.spa_outlined,
            activeIcon: Icons.spa,
            label: 'SERVIÇOS',
            route: '/servicos',
            primaryColor: primaryColor,
          ),
          _construirItemNavegacao(
            context,
            index: 2,
            icon: Icons.calendar_month_outlined,
            activeIcon: Icons.calendar_month,
            label: 'AGENDA',
            route: '/agenda',
            primaryColor: primaryColor,
          ),
          _construirItemNavegacao(
            context,
            index: 3,
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: 'PERFIL',
            route: '/perfil',
            primaryColor: primaryColor,
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
  }) {
    final isActive = activeIndex == index;

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
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color: isActive ? primaryColor : Colors.black26,
                ),
          ),
        ],
      ),
    );
  }
}
