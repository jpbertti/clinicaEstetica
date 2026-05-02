import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';
import 'package:app_clinica_estetica/features/auth/data/auth_service.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_notification_repository.dart';

class ProfissionalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final List<Widget>? actions;

  const ProfissionalAppBar({
    super.key,
    required this.title,
    this.showBackButton = false,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  String _formatTitle(String text) {
    if (text.isEmpty) return text;
    final words = text.toLowerCase().split(' ');
    final exceptions = {'de', 'da', 'do', 'das', 'dos', 'a', 'e', 'o', 'as', 'os', 'um', 'uma', 'uns', 'umas'};
    
    for (int i = 0; i < words.length; i++) {
      if (i == 0 || !exceptions.contains(words[i])) {
        if (words[i].isNotEmpty) {
          words[i] = words[i][0].toUpperCase() + words[i].substring(1);
        }
      }
    }
    return words.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final primaryGreen = AppColors.primary;
    final bgColor = AppColors.background;
    final _notificationRepo = SupabaseNotificationRepository();

    return AppBar(
      leading: showBackButton
          ? IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: primaryGreen, size: 20),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/profissional/agenda');
                }
              },
            )
          : null,
      backgroundColor: bgColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      title: Text(
        _formatTitle(title),
        style: GoogleFonts.playfairDisplay(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: 1.2,
        ),
      ),
      actions: [
        if (actions != null) ...actions!,
        StreamBuilder<int>(
          stream: _getUnreadCountStream(_notificationRepo),
          builder: (context, snapshot) {
            final count = snapshot.data ?? 0;
            final hasUnread = count > 0;
            final notificationGreen = AppColors.primary;
            final secondaryGold = AppColors.accent;

            return IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
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
                context.push('/profissional/notificacoes');
              },
            );
          },
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Stream<int> _getUnreadCountStream(SupabaseNotificationRepository repo) {
    final userId = AuthService.currentUserId;
    if (userId == null) return Stream.value(0);

    return (() async* {
      yield await repo.getUnreadCount(userId);
      yield* Stream.periodic(const Duration(seconds: 30)).asyncMap((_) async {
        return await repo.getUnreadCount(userId);
      });
    })().asBroadcastStream();
  }
}
