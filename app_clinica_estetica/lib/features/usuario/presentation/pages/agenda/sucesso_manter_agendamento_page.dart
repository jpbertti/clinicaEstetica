import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_clinica_estetica/core/widgets/app_bottom_nav_bar.dart';

class SucessoManterAgendamentoPage extends StatelessWidget {
  const SucessoManterAgendamentoPage({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2F5E46);
    const backgroundColor = Color(0xFFF6F4EF);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.go('/agenda'),
                        icon: const Icon(
                          Icons.arrow_back,
                          size: 24,
                          color: primaryColor,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Confirmação',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // Spacer to center title
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: primaryColor.withOpacity(0.05),
                ),
              ],
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      // Success Icon Circle
                      Container(
                        height: 70,
                        width: 70,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Title
                      Text(
                        'Agendamento\nMantido!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Playfair Display', 
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Description
                      Text(
                        'Seu horário continua reservado com carinho. Estamos ansiosos pelo seu momento de cuidado.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14,
                          color: primaryColor.withOpacity(0.7),
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Image
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.network(
                              'https://images.unsplash.com/photo-1519494026892-80bbd2d6fd0d?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80', // Working clinic/medical interior
                              height: 240,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    height: 240,
                                    width: double.infinity,
                                    color: primaryColor.withOpacity(0.1),
                                    child: const Icon(
                                      Icons.image_outlined,
                                      size: 40,
                                      color: primaryColor,
                                    ),
                                  ),
                            ),
                          ),
                          Positioned(
                            left: 16,
                            bottom: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.spa,
                                    size: 14,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'PREMIUM CARE',
                                    style: TextStyle(fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),
                      // Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => context.go('/agenda'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Voltar para Início',
                            style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Help text
                      Text(
                        'Precisa de ajuda? Fale conosco',
                        style: TextStyle(fontSize: 13,
                          color: primaryColor.withOpacity(0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavigationBar(
        activeIndex: 2,
      ), // Agenda index
    );
  }
}

