import 'package:app_clinica_estetica/core/theme/app_colors.dart';
import 'package:app_clinica_estetica/core/data/models/appointment_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_professional_repository.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_appointment_repository.dart';
import 'package:app_clinica_estetica/core/app_config.dart';
import 'package:url_launcher/url_launcher.dart';

class DetalhesAgendamentoPage extends StatelessWidget {
  final AppointmentModel appointment;
  const DetalhesAgendamentoPage({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _construirCabecalho(context),
            Divider(
              color: AppColors.accent.withValues(alpha: 0.2),
              height: 1,
              thickness: 1,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    // Service Card with Image
                    _construirCardServico(context),
                    const SizedBox(height: 32),
                    // Information Section
                    _construirSecaoInfo(context),
                    const SizedBox(height: 48),
                    // Action Buttons
                    _construirBotoesAcao(context),
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

  Widget _construirCabecalho(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: AppColors.primary,
          ),
          Expanded(
            child: Text(
              'Detalhes do Agendamento',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFamily: 'Playfair Display',
                    fontSize: 24,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(width: 48), // Spacer to balance back button
        ],
      ),
    );
  }

  Widget _construirCardServico(BuildContext context) {
    final status = appointment.status.toLowerCase();
    final bool isPendente = status == 'pendente';
    final bool isConfirmado = status == 'confirmado' || status == 'confirmada';
    final bool isCancelado = status == 'cancelado';
    final bool isFinalizado = status == 'concluido' || status == 'finalizado';

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (isCancelado) {
      statusColor = AppColors.error;
      statusLabel = 'CANCELADO';
      statusIcon = Icons.close;
    } else if (isFinalizado) {
      statusColor = Colors.blue[700]!;
      statusLabel = 'FINALIZADO';
      statusIcon = Icons.history;
    } else if (isConfirmado) {
      statusColor = AppColors.primary;
      statusLabel = 'CONFIRMADO';
      statusIcon = Icons.check_circle_outline;
    } else {
      // Pendente ou default
      statusColor = AppColors.accent;
      statusLabel = 'PENDENTE';
      statusIcon = Icons.hourglass_empty;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: AppColors.accent.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: appointment.serviceImageUrl != null
                ? Image.network(
                    appointment.serviceImageUrl!,
                    height: 200,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 200,
                    color: AppColors.primary.withOpacity(0.1),
                    child: Icon(Icons.spa, color: AppColors.primary, size: 48),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Badge acima do título
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        statusLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                              letterSpacing: 0.5,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  appointment.sessaoNumero != null
                      ? '${appointment.serviceName ?? 'Serviço'} - Sessão ${appointment.sessaoNumero}'
                      : appointment.serviceName ?? 'Serviço',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontFamily: 'Playfair Display',
                        fontSize: 24,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                if (appointment.sessaoNumero == null || appointment.sessaoNumero == 1)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        appointment.valorTotal != null
                            ? NumberFormat.currency(
                                locale: 'pt_BR',
                                symbol: 'R\$',
                              ).format(appointment.valorTotal)
                            : 'Preço sob consulta',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 16,
                            color: AppColors.primary.withOpacity(0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${appointment.serviceDuration ?? 60} min',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accent,
                                ),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: AppColors.primary.withOpacity(0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${appointment.serviceDuration ?? 60} min',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
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

  Widget _construirSecaoInfo(BuildContext context) {
    final startTime = DateFormat('HH:mm').format(appointment.dataHora);
    final endTime = DateFormat('HH:mm')
        .format(appointment.dataHora.add(Duration(minutes: appointment.serviceDuration ?? 60)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informações Adicionais',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontFamily: 'Playfair Display',
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontSize: 22,
              ),
        ),
        const SizedBox(height: 16),
        Column(
          children: [
            _construirItemInfo(
              context,
              icon: Icons.calendar_today_outlined,
              label: 'DATA E HORÁRIO',
              title: DateFormat(
                "dd' de 'MMMM', 'yyyy",
                'pt_BR',
              ).format(appointment.dataHora),
              subtitle: 'Das $startTime às $endTime',
            ),
            const SizedBox(height: 16),
            if (appointment.sessaoNumero != null) ...[
              _construirItemInfo(
                context,
                icon: Icons.format_list_numbered,
                label: 'SESSÃO',
                title: 'Sessão ${appointment.sessaoNumero}',
                subtitle: 'Parte de um pacote contratado',
              ),
              const SizedBox(height: 16),
            ],
            _construirItemInfoComImagem(
              context,
              imageUrl:
                  appointment.professionalAvatarUrl ??
                  'https://images.unsplash.com/photo-1559599101-f09722fb4948?auto=format&fit=crop&w=200&q=80',
              label: 'PROFISSIONAL',
              title: appointment.professionalName ?? 'Profissional',
              subtitle: toBeginningOfSentenceCase(appointment.professionalCargo ?? 'Especialista')!,
            ),
            const SizedBox(height: 16),
            _construirItemInfo(
              context,
              icon: Icons.location_on_outlined,
              label: 'LOCAL',
              title: AppConfig.nomeComercial,
              subtitle: AppConfig.endereco,
            ),
          ],
        ),
      ],
    );
  }

  Widget _construirItemInfo(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: AppColors.accent.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary.withOpacity(0.6),
                        letterSpacing: 1,
                        fontSize: 10,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 16,
                      ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirItemInfoComImagem(
    BuildContext context, {
    required String imageUrl,
    required String label,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: AppColors.accent.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              shape: BoxShape.circle,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.network(imageUrl, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary.withOpacity(0.6),
                        letterSpacing: 1,
                        fontSize: 10,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 18,
                      ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                        fontSize: 13,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirBotoesAcao(BuildContext context) {
    if (appointment.status == 'concluido') {
      if (appointment.evaluation != null) {
        return Center(
          child: Text(
            'Atendimento Avaliado',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary.withOpacity(0.5),
                ),
          ),
        );
      }
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          onPressed: () => context.push('/avaliar-atendimento', extra: appointment),
          icon: const Icon(Icons.star_outline),
          label: Text(
            'Avaliar Atendimento',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: AppColors.white,
                ),
          ),
        ),
      );
    }

    if (appointment.status == 'cancelado') return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            onPressed: () =>
                _mostrarPainelReagendamento(context),
            child: Center(
              child: Text(
                'Reagendar Horário',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: AppColors.white,
                    ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            final agora = DateTime.now();
            final diferenca = appointment.dataHora.difference(agora);
            final restrito = diferenca.inHours < 24;

            if (restrito) {
              _mostrarPainelReagendamento(context);
            } else {
              context.push('/cancelar-agendamento', extra: appointment);
            }
          },
          child: Text(
            'Cancelar Agendamento',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
          ),
        ),
      ],
    );
  }

  void _mostrarPainelReagendamento(BuildContext context) {
    // Verificar restrição de 24h
    final agora = DateTime.now();
    final diferenca = appointment.dataHora.difference(agora);
    final restrito = diferenca.inHours < 24;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => restrito
          ? _PainelRestricaoReagendamento(
              appointment: appointment,
            )
          : _PainelReagendamento(
              appointment: appointment,
            ),
    );
  }
}

class _PainelRestricaoReagendamento extends StatelessWidget {
  final AppointmentModel appointment;

  const _PainelRestricaoReagendamento({
    required this.appointment,
  });

  Future<void> _abrirWhatsApp() async {
    final phone = AppConfig.whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
    final message = "Olá, gostaria de tratar sobre o meu agendamento de ${appointment.serviceName} no dia ${DateFormat('dd/MM').format(appointment.dataHora)}.";
    final url = Uri.parse("https://wa.me/55$phone?text=${Uri.encodeComponent(message)}");
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.info_outline, color: Colors.amber[800], size: 40),
          ),
          const SizedBox(height: 24),
          Text(
            'Ação Indisponível',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Por política da clínica, alterações ou cancelamentos só podem ser feitos com no mínimo 24h de antecedência.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.primary.withOpacity(0.7),
                  height: 1.5,
                  fontSize: 15,
                ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _abrirWhatsApp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            icon: const Icon(Icons.chat, size: 20, color: AppColors.white),
            label: Text(
              'FALAR NO WHATSAPP',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: AppColors.white,
                  ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              'Voltar',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: AppColors.accent,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PainelReagendamento extends StatefulWidget {
  final AppointmentModel appointment;

  const _PainelReagendamento({
    required this.appointment,
  });

  @override
  State<_PainelReagendamento> createState() => _PainelReagendamentoState();
}

class _PainelReagendamentoState extends State<_PainelReagendamento> {
  final _profRepo = SupabaseProfessionalRepository();
  final _appointmentRepo = SupabaseAppointmentRepository();

  DateTime _selectedDate = DateTime.now();
  String? _selectedStartTime;
  bool _isLoadingTimes = false;
  bool _isConfirming = false;
  bool _isUpdating = false;
  List<Map<String, dynamic>> _timeSlots = [];
  Set<int> _availableDayOfWeek = {};
  Set<String> _blockedDates = {}; // datas bloqueadas no formato 'yyyy-MM-dd'
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Inicia no próximo dia se for hoje, ou mantém a data atual se for futura
    if (_selectedDate.day == DateTime.now().day && _selectedDate.month == DateTime.now().month) {
       _selectedDate = _selectedDate.add(const Duration(days: 1));
    }
    _loadClinicAvailability();
    _loadBlockedDates();
    _updateTimeSlots();
  }

  Future<void> _loadClinicAvailability() async {
    try {
      final days = await _profRepo.getClinicAvailabilityDays();
      if (mounted) {
        setState(() {
          _availableDayOfWeek = days.toSet();
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar disponibilidade da clínica: $e');
    }
  }

  Future<void> _loadBlockedDates() async {
    try {
      final profId = widget.appointment.profissionalId;
      // Busca todos os bloqueios de dia inteiro do profissional
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('bloqueios_agenda')
          .select('data, dia_todo, hora_inicio')
          .eq('profissional_id', profId);
      
      final Set<String> blocked = {};
      for (final b in response as List) {
        // Considera bloqueio de dia inteiro se dia_todo=true ou se hora_inicio é null
        if (b['dia_todo'] == true || b['hora_inicio'] == null) {
          blocked.add(b['data'].toString());
        }
      }
      if (mounted) {
        setState(() => _blockedDates = blocked);
      }
    } catch (e) {
      debugPrint('Erro ao carregar datas bloqueadas: $e');
    }
  }

  Future<void> _handleConfirm() async {
    if (_selectedStartTime == null || _isUpdating) return;

    setState(() => _isUpdating = true);

    try {
      final timeParts = _selectedStartTime!.split(':');
      final newDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );

      await _appointmentRepo.rescheduleAppointment(
        widget.appointment.id,
        newDateTime,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agendamento reagendado com sucesso!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao reagendar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _isConfirming ? _buildConfirmationView() : _buildSelectionView(),
      ),
    );
  }

  Widget _buildSelectionView() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle + botão X
          Row(
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 22),
                color: Colors.grey[500],
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Novo Horário',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Escolha uma nova data e horário para seu atendimento.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.primary.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),

          // Calendar Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    int newDay;
                    if (_selectedDate.day == 1) {
                      newDay = DateTime(_selectedDate.year, _selectedDate.month, 0).day;
                    } else {
                      final targetMonth = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
                      final daysInTargetMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
                      newDay = _selectedDate.day > daysInTargetMonth ? daysInTargetMonth : _selectedDate.day;
                    }
                    _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, newDay);
                  });
                  _updateTimeSlots();
                },
                icon: const Icon(Icons.chevron_left, color: AppColors.primary),
              ),
              Text(
                '${_getNomeMes(_selectedDate.month)} ${_selectedDate.year}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    final lastDayThisMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
                    int newDay;
                    if (_selectedDate.day == lastDayThisMonth) {
                      newDay = 1;
                    } else {
                      final targetMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
                      final daysInTargetMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
                      newDay = _selectedDate.day > daysInTargetMonth ? daysInTargetMonth : _selectedDate.day;
                    }
                    _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, newDay);
                  });
                  _updateTimeSlots();
                },
                icon: const Icon(Icons.chevron_right, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _construirGradeCalendario(),

          const SizedBox(height: 24),
          _buildTimeSlots(),

          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _selectedStartTime == null
                ? null
                : () => setState(() => _isConfirming = true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              disabledBackgroundColor: Colors.grey[200],
            ),
            child: Text(
              'REVISAR ALTERAÇÃO',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationView() {
    final originalDate = widget.appointment.dataHora;
    final timeParts = _selectedStartTime!.split(':');
    final newDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHandle(),
          const SizedBox(height: 32),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.swap_horiz, color: AppColors.primary, size: 32),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Confirmar Reagendamento',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Revise as informações antes de confirmar.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.primary.withOpacity(0.6),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              _buildDateInfo('ANTERIOR', originalDate, AppColors.primary.withOpacity(0.5)),
              const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.primary),
              _buildDateInfo('NOVO', newDate, AppColors.accent),
            ],
          ),
          const SizedBox(height: 48),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => _isConfirming = false),
                  child: Text(
                    'VOLTAR',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isUpdating ? null : _handleConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isUpdating
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2))
                      : Text(
                          'CONFIRMAR TROCA',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateInfo(String label, DateTime date, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.7),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('dd/MM', 'pt_BR').format(date),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            DateFormat('HH:mm').format(date),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _construirGradeCalendario() {
    final firstDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final lastDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);

    // Weekday in Dart: 1 (Mon) - 7 (Sun)
    int firstDayWeekday = firstDayOfMonth.weekday;
    // Adjust to: 0 (Sun) - 6 (Sat)
    int offset = firstDayWeekday % 7;

    final List<DateTime?> days = [];
    // Padding from previous month
    for (int i = 0; i < offset; i++) {
       days.add(null);
    }
    // Days of current month
    for (int i = 1; i <= lastDayOfMonth.day; i++) {
      days.add(DateTime(_selectedDate.year, _selectedDate.month, i));
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB'].map((d) {
              return Text(
                d,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary.withOpacity(0.4),
                ),
              );
            }).toList(),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemCount: days.length,
          itemBuilder: (context, index) {
            final date = days[index];
            if (date == null) return const SizedBox.shrink();

            final isSelected = DateUtils.isSameDay(date, _selectedDate);
            final isPast = date.isBefore(today);
            final int dayOfWeek = date.weekday == 7 ? 0 : date.weekday;
            final isClinicClosed = _availableDayOfWeek.isNotEmpty && !_availableDayOfWeek.contains(dayOfWeek);
            final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            final isBlocked = _blockedDates.contains(dateStr);
            final isUnavailable = isPast || isClinicClosed || isBlocked;
            final isRed = isClinicClosed || isBlocked;

            return GestureDetector(
              onTap: isUnavailable
                  ? null
                  : () {
                      setState(() => _selectedDate = date);
                      _updateTimeSlots();
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accent
                      : (isRed
                          ? AppColors.error.withOpacity(0.08)
                          : Colors.transparent),
                  shape: BoxShape.circle,
                  border: isUnavailable || isSelected
                    ? null
                    : Border.all(
                        color: AppColors.primary.withOpacity(0.08),
                      ),
                ),
                child: Center(
                  child: Text(
                    date.day.toString(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                        ? AppColors.white
                        : (isRed
                            ? AppColors.error
                            : (isPast
                                ? AppColors.primary.withOpacity(0.2)
                                : AppColors.primary)),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTimeSlots() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HORÁRIOS DISPONÍVEIS',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.accent,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoadingTimes)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        else if (_timeSlots.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.02),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Não há horários disponíveis para esta data.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.8,
            ),
            itemCount: _timeSlots.length,
            itemBuilder: (context, index) {
              final slot = _timeSlots[index];
              final startTime = slot['start'] as String;
              final endTime = slot['end'] as String;
              final duration = slot['duration'] as int;
              final isSelected = _selectedStartTime == startTime;

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedStartTime = startTime);
                  // Auto scroll to confirm button
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accent : AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.accent
                          : AppColors.primary.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_filled,
                              size: 14,
                              color: isSelected ? AppColors.white : AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "$startTime - $endTime",
                               style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? AppColors.white : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Padding(
                          padding: const EdgeInsets.only(left: 20),
                          child: Text(
                            "$duration min",
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? AppColors.white.withValues(alpha: 0.8)
                                  : AppColors.primary.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _updateTimeSlots() async {
    if (!mounted) return;
    setState(() {
      _isLoadingTimes = true;
      _selectedStartTime = null;
      _timeSlots = [];
    });

    try {
      final profId = widget.appointment.profissionalId;
      
      // 1. Verifica se o dia está bloqueado
      final isBlocked = await _profRepo.isDateBlocked(profId, _selectedDate);
      if (isBlocked) {
        if (mounted) {
          setState(() {
            _timeSlots = [];
            _isLoadingTimes = false;
          });
        }
        return;
      }

      // 2. Busca horários base na configuração da clínica
      int dayOfWeek = _selectedDate.weekday == 7 ? 0 : _selectedDate.weekday;
      final clinicHours = await _profRepo.getClinicHours(dayOfWeek);
      
      if (clinicHours == null || clinicHours['fechado'] == true) {
        if (mounted) {
          setState(() {
            _timeSlots = [];
            _isLoadingTimes = false;
          });
        }
        return;
      }

      // 3. Busca horários ocupados da clínica (excluindo este agendamento)
      final List<Map<String, dynamic>> allOccupied = List<Map<String, dynamic>>.from(await _profRepo.getAnyOccupiedTimes(_selectedDate, excludeId: widget.appointment.id));
      
      final profBlocks = await _profRepo.getProfessionalBlocksAndLunch(profId, _selectedDate);
      final List<dynamic> blocksList = profBlocks['blocks'] ?? [];
      allOccupied.addAll(blocksList.map((e) => Map<String, dynamic>.from(e)));

      List<Map<String, dynamic>> slots = [];
      final now = DateTime.now();
      final isToday = DateUtils.isSameDay(_selectedDate, now);

      final serviceDuration = widget.appointment.serviceDuration ?? 60; 

      String startStr = clinicHours['hora_inicio'];
      String endStr = clinicHours['hora_fim'];

      int startHour = int.parse(startStr.split(':')[0]);
      int startMinute = int.parse(startStr.split(':')[1]);
      int endHour = int.parse(endStr.split(':')[0]);
      int endMinute = int.parse(endStr.split(':')[1]);

      DateTime startTime = DateTime(_selectedDate.year, _selectedDate.month,
          _selectedDate.day, startHour, startMinute);
      DateTime endTime = DateTime(_selectedDate.year, _selectedDate.month,
          _selectedDate.day, endHour, endMinute);

      // Loop de 30 em 30 minutos
      for (DateTime current = startTime;
          current.isBefore(endTime);
          current = current.add(const Duration(minutes: 30))) {
        
        final slotStart = current;
        final slotEnd = current.add(Duration(minutes: serviceDuration));

        if (slotEnd.isAfter(endTime)) continue;

        bool isOccupied = false;
        for (var occ in allOccupied) {
          final occStart = occ['dateTime'] as DateTime;
          final occDuration = (occ['duration'] ?? 0) as int;
          final occEnd = occStart.add(Duration(minutes: occDuration));

          if (slotStart.isBefore(occEnd) && slotEnd.isAfter(occStart)) {
            isOccupied = true;
            break;
          }
        }

        if (!isOccupied) {
          if (isToday) {
            if (current.isAfter(now)) {
              slots.add({
                'start': "${slotStart.hour.toString().padLeft(2, '0')}:${slotStart.minute.toString().padLeft(2, '0')}",
                'end': "${slotEnd.hour.toString().padLeft(2, '0')}:${slotEnd.minute.toString().padLeft(2, '0')}",
                'duration': serviceDuration,
              });
            }
          } else {
            slots.add({
              'start': "${slotStart.hour.toString().padLeft(2, '0')}:${slotStart.minute.toString().padLeft(2, '0')}",
              'end': "${slotEnd.hour.toString().padLeft(2, '0')}:${slotEnd.minute.toString().padLeft(2, '0')}",
              'duration': serviceDuration,
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _timeSlots = slots;
          _isLoadingTimes = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingTimes = false);
      debugPrint('Error loading times: $e');
    }
  }

  String _getNomeMes(int month) {
    const months = [
      '',
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    return months[month];
  }
}

