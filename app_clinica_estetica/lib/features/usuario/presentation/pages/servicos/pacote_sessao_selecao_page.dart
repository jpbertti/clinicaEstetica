import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_clinica_estetica/core/data/models/pacote_template_model.dart';
import 'package:app_clinica_estetica/core/data/models/pacote_contratado_model.dart';
import 'package:app_clinica_estetica/core/data/models/appointment_model.dart';
import 'package:app_clinica_estetica/core/data/models/profile_model.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_package_repository.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_appointment_repository.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';

class PacoteSessaoSelecaoPage extends StatefulWidget {
  final PacoteTemplateModel pacote;
  final ProfileModel profissional;
  final String? contratoId;

  const PacoteSessaoSelecaoPage({
    super.key,
    required this.pacote,
    required this.profissional,
    this.contratoId,
  });

  @override
  State<PacoteSessaoSelecaoPage> createState() => _PacoteSessaoSelecaoPageState();
}

class _PacoteSessaoSelecaoPageState extends State<PacoteSessaoSelecaoPage> {
  bool isLoading = true;
  List<AppointmentModel> appointments = [];
  PacoteContratadoModel? contrato;
  final _appointmentRepo = SupabaseAppointmentRepository();
  final _packageRepo = SupabasePackageRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      if (widget.contratoId != null) {
        final results = await Future.wait([
          _packageRepo.getContratadoById(widget.contratoId!),
          _appointmentRepo.getAppointmentsByPackageId(widget.contratoId!),
        ]);
        
        if (mounted) {
          setState(() {
            contrato = results[0] as PacoteContratadoModel;
            appointments = results[1] as List<AppointmentModel>;
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar sessões: $e')),
        );
      }
    }
  }

  Future<void> _confirmarCancelamentoPacote() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Cancelar Pacote', 
          style: TextStyle(fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        content: const Text('Deseja realmente cancelar este pacote? Todos os agendamentos reservados serão cancelados.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
            ),
            child: const Text('Não'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Confirmar Cancelamento'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        setState(() => isLoading = true);
        await _packageRepo.cancelContract(contrato!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pacote cancelado com sucesso.')),
          );
          context.pop(); // Go back after cancellation
        }
      } catch (e) {
        if (mounted) {
          setState(() => isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao cancelar pacote: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppColors.primary;
    final backgroundColor = AppColors.background;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header - Matching PacoteConfirmacaoPage style
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => context.pop(),
                      icon: Icon(
                        Icons.chevron_left,
                        color: primaryColor,
                        size: 24,
                      ),
                    ),
                  ),
                  Text(
                    'Suas Sessões',
                    style: TextStyle(fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  if (contrato != null && contrato!.sessoesRealizadas == 0 && contrato!.status != 'cancelado')
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _confirmarCancelamentoPacote,
                        child: Text(
                          'Cancelar',
                          style: TextStyle(fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[400],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            if (isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      children: [
                        // Package Info Header inside the card
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Icon(Icons.inventory_2_outlined, color: primaryColor, size: 22),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.pacote.titulo,
                                    style: TextStyle(fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                  Text(
                                    '${widget.pacote.quantidadeSessoes} Sessões Totais',
                                    style: TextStyle(fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black38,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Divider(color: Color(0xFFF9F9F9), thickness: 1),
                        ..._buildSessionGroups(),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSessionGroups() {
    final List<Widget> widgets = [];

    if (widget.pacote.servicos == null || widget.pacote.servicos!.isEmpty) {
      widgets.add(_buildHeader('Sessões do Pacote'));
      for (int i = 1; i <= widget.pacote.quantidadeSessoes; i++) {
        widgets.add(_buildSessionCard(null, i));
      }
    } else {
      for (final service in widget.pacote.servicos!) {
        widgets.add(_buildHeader(service.nomeServico ?? 'Serviço'));
        for (int i = 1; i <= service.quantidadeSessoes; i++) {
          widgets.add(_buildSessionCard(service, i));
        }
        widgets.add(const SizedBox(height: 12));
      }
    }

    return widgets;
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12),
      child: Text(
        title,
        style: TextStyle(fontSize: 19,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF2F5E46),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSessionCard(PacoteServicoItem? service, int sessaoNumero) {
    final primaryColor = AppColors.primary;
    final accentColor = AppColors.accent;

    // Find if this session is already scheduled
    final appointment = appointments.firstWhere(
      (a) => a.sessaoNumero == sessaoNumero && (service == null || a.servicoId == service.servicoId),
      orElse: () => AppointmentModel(
        id: '', 
        clienteId: '', 
        profissionalId: '', 
        servicoId: '', 
        dataHora: DateTime.now(), 
        status: '', 
        criadoEm: DateTime.now()
      ),
    );

    final isScheduled = appointment.id.isNotEmpty;
    final isPast = isScheduled && (appointment.dataHora.isBefore(DateTime.now()) || appointment.status == 'finalizado');
    
    // Sequential scheduling logic: Can only schedule if it's the 1st session OR the previous session is already scheduled and NOT cancelled
    final bool canSchedule = sessaoNumero == 1 || appointments.any((a) => 
      a.sessaoNumero == sessaoNumero - 1 && 
      a.status != 'cancelado' && // Se foi cancelado, precisa agendar de novo o anterior primeiro
      (service == null || a.servicoId == service.servicoId)
    );

    String title;
    String subtitle;
    IconData icon;
    Color iconColor;
    bool isLocked = false;

    if (isScheduled) {
      final df = DateFormat('dd/MM/yyyy', 'pt_BR');
      final tf = DateFormat('HH:mm', 'pt_BR');
      title = 'Sessão $sessaoNumero';
      
      final statusStr = _translateStatus(appointment.status);
      final profName = appointment.professionalName ?? widget.profissional.nomeCompleto;
      
      subtitle = 'Data: ${df.format(appointment.dataHora)} às ${tf.format(appointment.dataHora)}\nProfissional: $profName\nStatus: $statusStr';
      
      icon = isPast ? Icons.lock_clock : Icons.event_available_outlined;
      iconColor = isPast ? Colors.black38 : accentColor;
    } else if (!canSchedule) {
      title = 'Sessão $sessaoNumero';
      subtitle = 'Aguardando sessão anterior';
      icon = Icons.lock_outline;
      iconColor = Colors.black12;
      isLocked = true;
    } else {
      title = 'Sessão $sessaoNumero';
      subtitle = 'Disponível para agendamento';
      icon = Icons.calendar_month_outlined;
      iconColor = primaryColor.withOpacity(0.3);
    }

    // Price info removed from list as per request (should show in details only)
    String? priceTag;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isScheduled && !isPast ? accentColor.withOpacity(0.4) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ListTile(
        onTap: (isPast || isLocked) ? null : () => _onSessionTap(service, sessaoNumero, appointment),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isPast ? Colors.black12 : iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(fontSize: 14,
            fontWeight: FontWeight.bold,
            color: (isPast || isLocked) ? Colors.black38 : (isScheduled ? accentColor : primaryColor),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 12,
                color: (isPast || isLocked) ? Colors.black26 : Colors.black45,
                height: 1.5,
              ),
              children: [
                TextSpan(text: subtitle.split('\nStatus:').first),
                if (isScheduled) ...[
                  const TextSpan(text: '\nStatus: '),
                  TextSpan(
                    text: _translateStatus(appointment.status),
                    style: TextStyle(fontWeight: FontWeight.bold,
                      color: _getStatusColor(appointment.status),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            (isPast || isLocked)
              ? const Icon(Icons.lock_outline, color: Colors.black12, size: 18)
              : Icon(Icons.chevron_right, color: isScheduled ? accentColor : Colors.black12, size: 20),
          ],
        ),
      ),
    );
  }

  String _translateStatus(String status) {
    switch (status.toLowerCase()) {
      case 'reservado': return 'RESERVADO';
      case 'confirmado': return 'CONFIRMADO';
      case 'finalizado': return 'FINALIZADO';
      case 'cancelado': return 'CANCELADO';
      case 'falta': return 'FALTA';
      default: return status.toUpperCase();
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'reservado': return AppColors.accent;
      case 'confirmado': return Colors.blue;
      case 'finalizado': return Colors.green;
      case 'cancelado': return Colors.red;
      case 'falta': return Colors.orange;
      default: return Colors.black54;
    }
  }

  void _onSessionTap(PacoteServicoItem? service, int sessaoNumero, AppointmentModel appointment) {
    if (appointment.id.isNotEmpty) {
      context.push('/detalhes-agendamento', extra: appointment);
    } else {
      context.push('/agendamento', extra: {
        'pacote': widget.pacote,
        'profissional': widget.profissional,
        'sessaoNumero': sessaoNumero,
        'serviceId': service?.servicoId,
        'serviceName': service?.nomeServico,
        'contratoId': widget.contratoId,
      });
    }
  }
}

