import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_clinica_estetica/features/auth/data/auth_service.dart';

class ProfissionalConfirmacaoLogoutPage extends StatelessWidget {
  const ProfissionalConfirmacaoLogoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2F5E46);
    const backgroundColor = Color(0xFFF6F4EF);
    const softGreen = Color(0xFF6E8F7B);
    const premiumGray = Color(0xFF2B2B2B);
    const goldColor = Color(0xFFC7A36B);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Simulated Background (Dimmed)
          Container(
            width: double.infinity,
            height: double.infinity,
            color: backgroundColor.withOpacity(0.98),
            child: SafeArea(
              child: Opacity(
                opacity: 0.1,
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    Container(
                      width: 120,
                      height: 120,
                      decoration: const BoxDecoration(
                        color: Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Profissional',
                      style: TextStyle(fontFamily: 'Playfair Display', 
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: premiumGray,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Dark Overlay
          Container(color: Colors.black.withOpacity(0.4)),

          // Dismiss area
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(color: Colors.transparent),
          ),

          // Bottom Sheet Content
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 32.0,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Logout Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      size: 32,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Title
                  Text(
                    'Deseja sair da conta?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Playfair Display', 
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: premiumGray,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Description
                  Text(
                    'Tem certeza que deseja encerrar sua sessão no painel profissional?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16,
                      color: softGreen,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Action Buttons
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        AuthService.logout();
                        context.go('/login');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Sair da conta',
                        style: TextStyle(fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => context.pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(color: primaryColor.withOpacity(0.1)),
                        ),
                      ),
                      child: Text(
                        'Continuar no painel',
                        style: TextStyle(fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

