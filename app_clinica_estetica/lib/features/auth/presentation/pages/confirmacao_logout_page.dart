import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_clinica_estetica/features/auth/data/auth_service.dart';

class ConfirmacaoLogoutPage extends StatelessWidget {
  const ConfirmacaoLogoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2F5E46);
    const backgroundColor = Color(0xFFF6F4EF);
    const softGreen = Color(0xFF6E8F7B);
    const premiumGray = Color(0xFF2B2B2B);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Simulated Profile Background (Dimmed)
          Container(
            width: double.infinity,
            height: double.infinity,
            color: backgroundColor.withOpacity(0.95), // Slight tint
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.arrow_back, color: premiumGray),
                        Text(
                          'Perfil',
                          style: TextStyle(fontFamily: 'Playfair Display', 
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: premiumGray,
                          ),
                        ),
                        const SizedBox(width: 24),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AuthService.currentUserNome ?? 'Usuário',
                    style: TextStyle(fontFamily: 'Playfair Display', 
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black.withOpacity(0.05),
                    ),
                  ),
                  Text(
                    AuthService.currentUserEmail ?? 'premium_member@email.com',
                    style: TextStyle(fontSize: 14,
                      color: softGreen.withOpacity(0.5),
                    ),
                  ),
                ],
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

                  // Logout Icon in Circle
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      size: 32,
                      color: Color(0xFF2E7D32),
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
                    'Sentiremos sua falta! Tem certeza que deseja encerrar sua sessão no momento?',
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
                        'Continuar no app',
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

