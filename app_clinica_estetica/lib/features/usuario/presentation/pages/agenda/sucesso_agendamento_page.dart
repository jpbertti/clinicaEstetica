import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_clinica_estetica/features/auth/data/auth_service.dart';


class SucessoAgendamentoPage extends StatelessWidget {
  const SucessoAgendamentoPage({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2F5E46);
    const backgroundColor = Color(0xFFF6F4EF);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header with brand and close button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                   Text(
                    'SUCESSO',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      fontFamily: 'Playfair Display',
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () {
                        if (AuthService.isAdmin) {
                          debugPrint('Botão fechar (Header): Redirecionando Admin para /admin/agendamentos');
                          context.go('/admin/agendamentos');
                        } else {
                          context.go('/inicio');
                        }
                      },
                      icon: const Icon(Icons.close, color: primaryColor),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Success Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Success Message
                  Text(
                    'Agendamento Realizado!',
                    style: TextStyle(fontFamily: 'Playfair Display', 
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      'Sua reserva foi confirmada com sucesso. Você receberá um lembrete em breve.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Action
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: () {
                    final isAdmin = AuthService.isAdmin;
                    debugPrint('Encerrando agendamento. isAdmin: $isAdmin');
                    if (isAdmin) {
                      context.go('/admin/agendamentos');
                    } else {
                      context.go('/inicio');
                    }
                  },
                  child: Text(
                    AuthService.isAdmin ? 'Voltar para Agenda' : 'Voltar para o Início',
                    style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

