import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:app_clinica_estetica/core/data/models/appointment_model.dart';

class ReagendamentoSucessoPage extends StatelessWidget {
  final AppointmentModel appointment;
  final DateTime newDateTime;

  const ReagendamentoSucessoPage({
    super.key,
    required this.appointment,
    required this.newDateTime,
  });

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
            // Header
            _construirCabecalho(context, primaryColor),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
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
                    const SizedBox(height: 24),
                    // Success Text
                    Text(
                      'Reagendamento Realizado!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Playfair Display', 
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sua solicitação de alteração foi processada com sucesso. Mal podemos esperar por esse novo momento!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14,
                        color: primaryColor.withOpacity(0.6),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(height: 1, thickness: 0.5),
                    const SizedBox(height: 40),
                    // Appointment Card
                    _construirCardAgendamento(primaryColor, accentColor),
                    const SizedBox(height: 48),
                    // Action Buttons
                    _construirBotoesAcao(context, primaryColor, accentColor),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirCabecalho(BuildContext context, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => context.go('/agenda'),
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: primaryColor,
          ),
          Text(
            'CONFIRMAÇÃO',
            style: TextStyle(fontSize: 14,
              fontWeight: FontWeight.bold,
              color: primaryColor,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(width: 48), // Spacer
        ],
      ),
    );
  }

  Widget _construirCardAgendamento(Color primaryColor, Color accentColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: appointment.serviceImageUrl != null
                ? Image.network(
                    appointment.serviceImageUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 180,
                    width: double.infinity,
                    color: primaryColor.withOpacity(0.1),
                    child: Icon(Icons.spa, color: primaryColor, size: 48),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'NOVO HORÁRIO',
                      style: TextStyle(fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4F2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'CONFIRMADO',
                        style: TextStyle(fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 16),
                Text(
                  appointment.serviceName ?? 'Serviço',
                  style: TextStyle(fontFamily: 'Playfair Display', 
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 20),
                _construirItemInfo(
                  Icons.calendar_today_outlined,
                  DateFormat(
                    "dd' de 'MMMM', 'yyyy",
                    'pt_BR',
                  ).format(newDateTime),
                  primaryColor,
                ),
                const SizedBox(height: 12),
                _construirItemInfo(
                  Icons.access_time,
                  DateFormat('HH:mm').format(newDateTime),
                  primaryColor,
                ),
                const SizedBox(height: 12),
                _construirItemInfo(
                  Icons.person_outline,
                  appointment.professionalName ?? 'Profissional',
                  primaryColor,
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirItemInfo(IconData icon, String text, Color primaryColor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: primaryColor.withOpacity(0.4)),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(fontSize: 14,
            fontWeight: FontWeight.w500,
            color: primaryColor.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _construirBotoesAcao(
    BuildContext context,
    Color primaryColor,
    Color accentColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
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
              ),
              child: Text(
                'VOLTAR PARA O INÍCIO',
                style: TextStyle(fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: const Icon(Icons.calendar_month, size: 20, color: Colors.white),
              label: Text(
                'ADICIONAR AO GOOGLE AGENDA',
                style: TextStyle(fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

