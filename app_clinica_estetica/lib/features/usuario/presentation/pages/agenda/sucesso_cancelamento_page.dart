import 'package:app_clinica_estetica/core/app_config.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_clinica_estetica/core/widgets/app_bottom_nav_bar.dart';

class SucessoCancelamentoPage extends StatelessWidget {
  const SucessoCancelamentoPage({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2F5E46);
    const accentColor = Color(0xFFC7A36B);
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
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(
                        width: 48,
                      ), // Spacer to balance the close button
                      Text(
                        'CANCELAMENTO',
                        style: TextStyle(fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                      IconButton(
                        onPressed: () => context.go('/agenda'),
                        icon: const Icon(
                          Icons.close,
                          size: 24,
                          color: primaryColor,
                        ),
                      ),
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
                          color: accentColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: accentColor,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Title
                      Text(
                        'Cancelamento\nRealizado',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Playfair Display', 
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Divider
                      Container(
                        width: 40,
                        height: 2,
                        color: accentColor.withOpacity(0.5),
                      ),
                      const SizedBox(height: 24),
                      // Description
                      Text(
                        'Seu agendamento foi cancelado com sucesso. Sentiremos sua falta e esperamos vê-la em breve para um novo momento de cuidado.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14,
                          color: primaryColor.withOpacity(0.7),
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 48),
                      // Aesthetic image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.network(
                          'https://images.unsplash.com/photo-1544161515-4ab6ce6db874?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80', // Spa stones and candle image
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                height: 220,
                                width: double.infinity,
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.image_outlined,
                                  size: 40,
                                ),
                              ),
                        ),
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
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavigationBar(activeIndex: 2),
      // Linked to Agenda index
    );
  }
}

