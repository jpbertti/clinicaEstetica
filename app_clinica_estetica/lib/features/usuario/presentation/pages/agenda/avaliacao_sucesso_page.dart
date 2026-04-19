import 'package:app_clinica_estetica/core/app_config.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_clinica_estetica/core/data/models/appointment_model.dart';

class AvaliacaoSucessoPage extends StatelessWidget {
  final AppointmentModel appointment;

  const AvaliacaoSucessoPage({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2F5E46);
    const accentColor = Color(0xFFC7A36B);
    const backgroundColor = Color(0xFFF6F4EF);
    const softGreen = Color(0xFF6E8F7B);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _construirCabecalho(context, primaryColor),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const SizedBox(height: 48),

                    // Success Icon/Illustration
                    _construirIconeSucesso(primaryColor, accentColor),

                    const SizedBox(height: 40),

                    // Headlines
                    Text(
                      'Avaliação Enviada!',
                      style: TextStyle(fontFamily: 'Playfair Display', 
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sua opinião é muito importante para nós. Agradecemos por compartilhar sua experiência na ${AppConfig.nomeComercial}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14,
                        color: softGreen,
                        height: 1.6,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Summary Card
                    _construirCardResumo(
                      context,
                      primaryColor,
                      accentColor,
                      softGreen,
                    ),

                    const SizedBox(height: 40),

                    // Aesthetic Decor
                    _construirDecoracao(accentColor),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // Footer Actions
            _construirBotoesRodape(context, primaryColor, softGreen),
          ],
        ),
      ),
    );
  }

  Widget _construirCabecalho(BuildContext context, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => context.go('/inicio'),
            icon: const Icon(Icons.close, size: 24),
            color: primaryColor,
            style: IconButton.styleFrom(
              splashFactory: NoSplash.splashFactory,
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              overlayColor: Colors.transparent,
            ),
          ),
          Text(
            'FEEDBACK',
            style: TextStyle(fontSize: 12,
              fontWeight: FontWeight.w800,
              color: primaryColor,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _construirIconeSucesso(Color primaryColor, Color accentColor) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: primaryColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(Icons.check, size: 64, color: Colors.white),
    );
  }

  Widget _construirCardResumo(
    BuildContext context,
    Color primaryColor,
    Color accentColor,
    Color softGreen,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RESUMO DO ATENDIMENTO',
                style: TextStyle(fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                  letterSpacing: 1.5,
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(Icons.star, size: 14, color: accentColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            appointment.serviceName ?? 'Procedimento',
            style: TextStyle(fontFamily: 'Playfair Display', 
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (appointment.professionalAvatarUrl != null)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: NetworkImage(appointment.professionalAvatarUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person, color: primaryColor, size: 18),
                ),
              const SizedBox(width: 12),
              Text(
                appointment.professionalName ?? 'Profissional',
                style: TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  color: softGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirDecoracao(Color accentColor) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  accentColor.withOpacity(0.4),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Icon(Icons.auto_awesome, color: accentColor, size: 20),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentColor.withOpacity(0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _construirBotoesRodape(
    BuildContext context,
    Color primaryColor,
    Color softGreen,
  ) {
    const accentColor = Color(0xFFC7A36B);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: () => context.go('/inicio'),
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
              'VOLTAR PARA O INÍCIO',
              style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.push('/historico-avaliacoes'),
            style: TextButton.styleFrom(
              splashFactory: NoSplash.splashFactory,
              foregroundColor: accentColor,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(
              'Ver minhas avaliações',
              style: TextStyle(fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

