// Refresh compiler summary
import 'package:app_clinica_estetica/core/data/models/appointment_model.dart';
import 'package:app_clinica_estetica/core/data/models/evaluation_model.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_appointment_repository.dart';
import 'package:app_clinica_estetica/features/auth/data/auth_service.dart';
import 'package:app_clinica_estetica/core/widgets/app_bottom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  int _selectedTab = 0; // 0 for Próximos, 1 for Histórico
  bool _isLoading = true;
  List<AppointmentModel> _upcomingList = [];
  List<AppointmentModel> _historyList = [];
  final _appointmentRepo = SupabaseAppointmentRepository();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_BR', null);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userId = AuthService.currentUserId;
      if (userId != null) {
        // Auto-concluir agendamentos passados antes de carregar
        await _appointmentRepo.autoCompletePastAppointments(userId);
        
        final upcoming = await _appointmentRepo.getUpcomingAppointments(userId);
        final history = await _appointmentRepo.getPastAppointments(userId);
        if (mounted) {
          setState(() {
            _upcomingList = upcoming;
            _historyList = history;
            _isLoading = false;
          });
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Erro ao carregar agenda: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatarDataGroup(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final checkDate = DateTime(date.year, date.month, date.day);

    if (checkDate == today) {
      return "Hoje, ${DateFormat('EEEE', 'pt_BR').format(date)}";
    } else if (checkDate == tomorrow) {
      return "Amanhã, ${DateFormat('EEEE', 'pt_BR').format(date)}";
    } else {
      return DateFormat("dd' de 'MMMM', 'EEEE", 'pt_BR').format(date);
    }
  }

  Map<String, List<AppointmentModel>> _agruparPorData(
    List<AppointmentModel> appointments,
  ) {
    final map = <String, List<AppointmentModel>>{};
    for (var app in appointments) {
      final key = _formatarDataGroup(app.dataHora);
      if (!map.containsKey(key)) {
        map[key] = [];
      }
      map[key]!.add(app);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 24,
                    bottom: 8,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => context.go('/inicio'),
                            child: const Icon(
                              Icons.arrow_back,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Minha Agenda',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                fontFamily: 'Playfair Display',
                                color: AppColors.primary,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 40),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(
                        color: AppColors.accent.withOpacity(0.2),
                        thickness: 1,
                      ),
                    ],
                  ),
                ),

                // Custom Tabs - Underline Style & Centralized
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ItemAba(
                        label: 'Próximos',
                        isSelected: _selectedTab == 0,
                        onTap: () => setState(() => _selectedTab = 0),
                      ),
                      const SizedBox(width: 32),
                      _ItemAba(
                        label: 'Histórico',
                        isSelected: _selectedTab == 1,
                        onTap: () => setState(() => _selectedTab = 1),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                  )
                else if (_selectedTab == 0) ...[
                  // Section: Próximos
                  if (_upcomingList.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40.0),
                        child: Text(
                          'Nenhum agendamento próximo.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primary.withOpacity(0.5),
                          ),
                        ),
                      ),
                    )
                  else
                    ..._agruparPorData(_upcomingList).entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CabecalhoData(label: entry.key),
                          ...entry.value.map(
                            (app) => _CardAgendamento(
                                appointment: app,
                                title: app.serviceName ?? 'Serviço',
                                date: DateFormat('dd/MM').format(app.dataHora),
                                time: DateFormat('HH:mm').format(app.dataHora),
                                professional:
                                    app.professionalName ?? 'Profissional',
                                isCompleted: false,
                                status: app.status,
                                isEvaluated: app.evaluation != null,
                                onStatusChanged: _loadData,
                                onTap: () => context.push(
                                  '/detalhes-agendamento',
                                  extra: app,
                                ),
                              ),
                          ),
                            const SizedBox(height: 24),
                        ],
                      );
                    }),
                ] else if (_selectedTab == 1) ...[
                  // Section: Histórico
                  if (_historyList.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40.0),
                        child: Text(
                          'Nenhum agendamento no histórico.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primary.withOpacity(0.5),
                          ),
                        ),
                      ),
                    )
                  else
                    ..._agruparPorData(_historyList).entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CabecalhoData(label: entry.key),
                          ...entry.value.map(
                            (app) => _CardAgendamento(
                                appointment: app,
                                title: app.serviceName ?? 'Serviço',
                                date: DateFormat('dd/MM').format(app.dataHora),
                                time: DateFormat('HH:mm').format(app.dataHora),
                                professional:
                                    app.professionalName ?? 'Profissional',
                                isCompleted: app.status == 'concluido',
                                status: app.status,
                                isEvaluated: app.evaluation != null,
                                onStatusChanged: _loadData,
                                onTap: () => context.push(
                                  '/detalhes-agendamento',
                                  extra: app,
                                ),
                              ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    }),
                ],

                const SizedBox(height: 48),

                // Section: Baseado no seu perfil (The one user liked and want to keep)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    'Baseado no seu perfil',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontFamily: 'Playfair Display',
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: _BannerRecomendacao(),
                ),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavigationBar(activeIndex: 2),
    );
  }
}

class _CabecalhoData extends StatelessWidget {
  final String label;

  const _CabecalhoData({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.manrope(
          fontWeight: FontWeight.w800,
          color: AppColors.accent,
          fontSize: 12,
          letterSpacing: 2.0,
        ),
      ),
    );
  }
}

class _ItemAba extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ItemAba({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontFamily: 'Playfair Display',
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? AppColors.primary
                  : AppColors.primary.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 3,
            width: 80, // Reduced for 3 tabs
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardAgendamento extends StatelessWidget {
  final AppointmentModel appointment;
  final String title;
  final String date;
  final String time;
  final String professional;
  final bool isCompleted;
  final bool isEvaluated;
  final String? status;
  final VoidCallback? onTap;
  final VoidCallback? onStatusChanged;

  const _CardAgendamento({
    required this.appointment,
    required this.title,
    required this.date,
    required this.time,
    required this.professional,
    this.isCompleted = false,
    this.isEvaluated = false,
    this.status,
    this.onTap,
    this.onStatusChanged,
  });

  Widget _buildStatusTag({
    required BuildContext context,
    required String? status,
    required bool isCompleted,
    required Color primaryColor,
    required Color accentColor,
  }) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String label;

    if (status == 'concluido' || isCompleted) {
      bgColor = primaryColor.withOpacity(0.1);
      textColor = primaryColor;
      icon = Icons.check_circle_rounded;
      label = 'FINALIZADO';
    } else if (status == 'confirmado') {
      bgColor = primaryColor.withOpacity(0.1);
      textColor = primaryColor;
      icon = Icons.check_circle_rounded;
      label = 'CONFIRMADO';
    } else if (status == 'pendente') {
      bgColor = accentColor.withOpacity(0.1);
      textColor = accentColor;
      icon = Icons.schedule_rounded;
      label = 'AGUARDANDO';
    } else if (status == 'cancelado') {
      bgColor = Colors.red.withOpacity(0.1);
      textColor = Colors.red[800]!;
      icon = Icons.cancel_rounded;
      label = 'CANCELADO';
    } else if (status == 'ausente' || status == 'no_show') {
      bgColor = Colors.blue.withOpacity(0.1);
      textColor = Colors.blue[800]!;
      icon = Icons.person_off_rounded;
      label = 'NÃO COMPARECEU';
    } else {
      bgColor = primaryColor.withOpacity(0.1);
      textColor = primaryColor;
      icon = Icons.info_rounded;
      label = (status ?? 'STATUS').toUpperCase();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: textColor, size: 10),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: textColor,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isProfissional = AuthService.currentUserTipo == 'profissional' || 
                          AuthService.isAdmin;
    
    // Calcular horário de término (estimado)
    final duracao = appointment.serviceDuration ?? 60;
    final timeEnd = DateFormat('HH:mm').format(
      appointment.dataHora.add(Duration(minutes: duracao)),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: onTap,
            splashColor: AppColors.accent.withOpacity(0.05),
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatusTag(
                        context: context,
                        status: status,
                        isCompleted: isCompleted,
                        primaryColor: AppColors.primary,
                        accentColor: AppColors.accent,
                      ),
                      const SizedBox.shrink(), // Removido a data do canto superior direito
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Premium Icon
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('dd').format(appointment.dataHora),
                              style: GoogleFonts.manrope(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.0,
                              ),
                            ),
                            Text(
                              DateFormat('MMM', 'pt_BR').format(appointment.dataHora).toUpperCase().replaceAll('.', ''),
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withOpacity(0.9),
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appointment.sessaoNumero != null
                                  ? '$title - Sessão ${appointment.sessaoNumero}'
                                  : title,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Professional Row
                            Row(
                              children: [
                                const Icon(
                                  Icons.person_rounded,
                                  size: 12,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    professional,
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.primary.withOpacity(0.6),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Time Row
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time_filled_rounded,
                                  size: 12,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$time - $timeEnd',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.accent,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                            if (appointment.pacoteNome != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.inventory_2_rounded,
                                      size: 11,
                                      color: AppColors.primary.withOpacity(0.4),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Plano: ${appointment.pacoteNome}',
                                        style: GoogleFonts.manrope(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          fontStyle: FontStyle.italic,
                                          color: AppColors.primary.withOpacity(0.4),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  // Action Buttons Section
                  if (status == 'confirmado' && isProfissional) ...[
                    const SizedBox(height: 16),
                    Divider(color: AppColors.primary.withOpacity(0.05)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _BotaoStatus(
                            label: 'Compareceu',
                            color: Colors.green,
                            onPressed: () => _atualizarStatus(context, 'concluido'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BotaoStatus(
                            label: 'Faltou',
                            color: Colors.blue,
                            onPressed: () => _atualizarStatus(context, 'ausente'),
                          ),
                        ),
                      ],
                    ),
                  ] else if (!isCompleted && status != 'cancelado' && status != 'ausente' && status != 'no_show' && !isProfissional) ...[
                    const SizedBox(height: 16),
                    Divider(color: AppColors.primary.withOpacity(0.05)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Ver detalhes',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ] else if (status == 'cancelado' || status == 'ausente' || status == 'no_show') ...[
                    const SizedBox(height: 16),
                    Divider(color: AppColors.primary.withOpacity(0.05)),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => context.go('/servicos'),
                      child: Text(
                        'Agendar novamente',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ] else if (status == 'concluido' && !isProfissional) ...[
                    const SizedBox(height: 16),
                    Divider(color: AppColors.primary.withOpacity(0.05)),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: isEvaluated && appointment.evaluation != null
                          ? () => _mostrarResumoAvaliacao(context, appointment.evaluation!)
                          : () => context.push('/avaliar-atendimento', extra: {'appointment': appointment}),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isEvaluated ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 14,
                            color: isEvaluated ? AppColors.primary : AppColors.accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isEvaluated
                                ? 'Atendimento avaliado'
                                : 'Avaliar atendimento',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isEvaluated
                                  ? AppColors.primary
                                  : AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _atualizarStatus(BuildContext context, String novoStatus) async {
    try {
      final repo = SupabaseAppointmentRepository();
      await repo.updateAppointmentStatus(appointment.id, novoStatus);
      if (onStatusChanged != null) {
        onStatusChanged!();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar status: $e')),
        );
      }
    }
  }
}

class _BotaoStatus extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _BotaoStatus({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _BannerRecomendacao extends StatelessWidget {
  const _BannerRecomendacao();

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2F5E46);
    const accentColor = Color(0xFFC7A36B);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Sugestão Especial',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Minha Agenda',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Com base nas suas últimas visitas, este tratamento é o ideal para manter seus resultados.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.7),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {},
            child: Text(
              'CONHECER MAIS',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
            ),
          ),
        ],
      ),
    );
  }
}

void _mostrarResumoAvaliacao(BuildContext context, EvaluationModel evaluation) {
  const primaryColor = Color(0xFF2F5E46);
  const goldColor = Color(0xFFC7A36B);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: const BoxDecoration(
        color: Color(0xFFF6F4EF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sua Avaliação',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(
              5,
              (index) => Icon(
                Icons.star,
                color: index < evaluation.nota ? goldColor : goldColor.withOpacity(0.2),
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'COMENTÁRIO',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: primaryColor.withOpacity(0.5),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: goldColor.withOpacity(0.1)),
            ),
            child: Text(
              evaluation.comentario ?? 'Sem comentário escrito.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: primaryColor.withOpacity(0.8),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (evaluation.fotos.isNotEmpty) ...[
            Text(
              'FOTOS COMPARTILHADAS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: primaryColor.withOpacity(0.5),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: evaluation.fotos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) => Container(
                  width: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    image: DecorationImage(
                      image: NetworkImage(evaluation.fotos[index]),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ],
          const Spacer(),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'FECHAR',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}




