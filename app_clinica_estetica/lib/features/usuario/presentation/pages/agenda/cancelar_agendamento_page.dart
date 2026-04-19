import 'package:app_clinica_estetica/core/data/models/appointment_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_appointment_repository.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_notification_repository.dart';

class CancelarAgendamentoPage extends StatefulWidget {
  final AppointmentModel appointment;
  const CancelarAgendamentoPage({super.key, required this.appointment});

  @override
  State<CancelarAgendamentoPage> createState() =>
      _CancelarAgendamentoPageState();
}

class _CancelarAgendamentoPageState extends State<CancelarAgendamentoPage> {
  final _appointmentRepo = SupabaseAppointmentRepository();
  final _notificationRepo = SupabaseNotificationRepository();
  String? _selectedReason;
  final TextEditingController _commentController = TextEditingController();

  final List<String> _reasons = [
    'Imprevisto pessoal',
    'Problema de saúde',
    'Mudei de ideia',
    'Outro',
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2F5E46);
    const accentColor = Color(0xFFC7A36B);
    const backgroundColor = Color(0xFFFBF9F6); // Soft off-white

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _construirCabecalho(context, primaryColor),

            Divider(
              color: accentColor.withOpacity(0.1),
              height: 1,
              thickness: 1,
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Warning Text
                    Text(
                      'Você tem certeza que deseja cancelar seu agendamento?',
                      style: TextStyle(fontFamily: 'Playfair Display', 
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sentiremos sua falta! Se houver algo que possamos fazer para manter seu horário, entre em contato.',
                      style: TextStyle(fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Appointment Card (Compact)
                    _construirCardAgendamento(primaryColor, accentColor),

                    const SizedBox(height: 32),

                    // Reason Label
                    Text(
                      'Motivo do Cancelamento',
                      style: TextStyle(fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Reasons List
                    ..._reasons.map(
                      (reason) => _construirOpcaoMotivo(reason, primaryColor),
                    ),

                    const SizedBox(height: 32),

                    // Comments Label
                    Text(
                      'Comentários adicionais (opcional)',
                      style: TextStyle(fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _commentController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Conte-nos um pouco mais...',
                        hintStyle: TextStyle(color: Colors.grey[400],
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: accentColor.withOpacity(0.1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: accentColor.withOpacity(0.1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: accentColor),
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Action Buttons
                    _construirBotoesAcao(context, primaryColor, accentColor),
                    const SizedBox(height: 24),
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
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: primaryColor,
          ),
          Expanded(
            child: Text(
              'Cancelar Agendamento',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Playfair Display', 
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _construirCardAgendamento(Color primaryColor, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: accentColor.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: widget.appointment.serviceImageUrl != null
                ? Image.network(
                    widget.appointment.serviceImageUrl!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 60,
                    height: 60,
                    color: accentColor.withOpacity(0.1),
                    child: Icon(Icons.spa, color: accentColor),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.appointment.serviceName ?? 'Serviço',
                  style: TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 12,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat(
                        "dd 'de' MMMM",
                        'pt_BR',
                      ).format(widget.appointment.dataHora),
                      style: TextStyle(fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('HH:mm').format(widget.appointment.dataHora),
                      style: TextStyle(fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirOpcaoMotivo(String reason, Color primaryColor) {
    bool isSelected = _selectedReason == reason;

    return GestureDetector(
      onTap: () => setState(() => _selectedReason = reason),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? primaryColor : Colors.grey[400]!,
                  width: 2,
                ),
                color: isSelected ? primaryColor : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              reason,
              style: TextStyle(fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? primaryColor : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirBotoesAcao(
    BuildContext context,
    Color primaryColor,
    Color accentColor,
  ) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => context.push(
              '/sucesso-manter-agendamento',
            ),
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
              'Manter Agendamento',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextButton(
            onPressed: _selectedReason == null
                ? null
                : () async {
                    try {
                      await _appointmentRepo.cancelAppointment(
                        widget.appointment.id,
                      );
                      await _notificationRepo.notifyAllAdmins(
                        titulo: 'Agendamento Cancelado',
                        mensagem:
                            'O agendamento de ${widget.appointment.serviceName} com ${widget.appointment.professionalName} no dia ${DateFormat('dd/MM', 'pt_BR').format(widget.appointment.dataHora)} às ${DateFormat('HH:mm').format(widget.appointment.dataHora)} foi cancelado.',
                        tipo: 'cancelamento',
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Agendamento cancelado com sucesso.'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        context.push('/sucesso-cancelamento');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro ao cancelar: $e')),
                        );
                      }
                    }
                  },
            style: TextButton.styleFrom(
              foregroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: primaryColor.withOpacity(0.1)),
              ),
            ),
            child: Text(
              'Confirmar Cancelamento',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

