import 'package:app_clinica_estetica/core/data/models/notification_model.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_appointment_repository.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_notification_repository.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_professional_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminReagendamentoModal extends StatefulWidget {
  final Map<String, dynamic> appointment;
  final VoidCallback? onReagendado;

  const AdminReagendamentoModal({
    super.key,
    required this.appointment,
    this.onReagendado,
  });

  @override
  State<AdminReagendamentoModal> createState() => _AdminReagendamentoModalState();
}

class _AdminReagendamentoModalState extends State<AdminReagendamentoModal> {
  final _profRepo = SupabaseProfessionalRepository();
  final _appointmentRepo = SupabaseAppointmentRepository();
  final _notificationRepo = SupabaseNotificationRepository();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedTime;
  String? _conflictProfessionalName;
  String? _conflictClientName;
  bool _isLoadingTimes = false;
  bool _isConfirming = false;
  bool _isUpdating = false;
  List<Map<String, dynamic>> _timeSlots = [];
  String? _selectedStartTime;
  Set<int> _availableDayOfWeek = {};
  List<DateTime> _blockedDates = [];

  final Color primaryGreen = const Color(0xFF2F5E46);
  final Color accent = const Color(0xFFC7A36B);

  // Focus month for the grid calendar
  late DateTime _focusedMonth;

  final _scrollController = ScrollController();
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    // Initialize with a future date
    final appointmentDate = DateTime.parse(widget.appointment['data_hora']);
    if (appointmentDate.isAfter(DateTime.now())) {
        _selectedDate = appointmentDate;
    }
    _loadClinicAvailability();
    _loadBlockedDates();
    _updateTimeSlots();
  }

  Future<void> _loadBlockedDates() async {
    try {
      final profId = widget.appointment['profissional_id'];
      final blocks = await _profRepo.getAgendaBlocks(profId: profId);
      final List<DateTime> blocked = [];
      for (var b in blocks) {
        if (b['hora_inicio'] == null && b['hora_fim'] == null) {
          blocked.add(DateTime.parse(b['data']));
        }
      }
      if (mounted) {
        setState(() {
          _blockedDates = blocked;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar datas bloqueadas: $e');
    }
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

  Future<void> _updateTimeSlots() async {
    setState(() {
      _isLoadingTimes = true;
      _selectedStartTime = null;
      _timeSlots = [];
      _conflictProfessionalName = null;
      _conflictClientName = null;
    });

    try {
      final profId = widget.appointment['profissional_id'];
      
      // 1. Verifica se o dia está bloqueado (Global ou do Profissional)
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

      // 2. Busca horários base na configuração da clínica (Admin define isso)
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

      // 3. Busca todos os horários ocupados (Agendas + Bloqueios + Almoço)
      final allOccupied = await _profRepo.getAnyOccupiedTimes(_selectedDate, excludeId: widget.appointment['id']);
      final profData = await _profRepo.getProfessionalBlocksAndLunch(profId, _selectedDate);
      
      final work = profData['work'] as Map<String, dynamic>?;
      final lunch = profData['lunch'] as Map<String, TimeOfDay>?;
      final blocks = (profData['blocks'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      // Adiciona Bloqueios Parciais
      for (var block in blocks) {
        if (block['dia_todo'] == true) continue;
        if (block['hora_inicio'] != null && block['hora_fim'] != null) {
          final startParts = block['hora_inicio'].split(':');
          final endParts = block['hora_fim'].split(':');
          
          final blockStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, int.parse(startParts[0]), int.parse(startParts[1]));
          final blockEnd = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, int.parse(endParts[0]), int.parse(endParts[1]));

          allOccupied.add(<String, dynamic>{
            'dateTime': blockStart,
            'duration': blockEnd.difference(blockStart).inMinutes,
            'type': 'block',
          });
        }
      }

      // Adiciona o Almoço como tempo ocupado
      if (lunch != null) {
        final lunchStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, lunch['inicio']!.hour, lunch['inicio']!.minute);
        final lunchEnd = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, lunch['fim']!.hour, lunch['fim']!.minute);
        
        if (lunchEnd.isAfter(lunchStart)) {
          allOccupied.add(<String, dynamic>{
            'dateTime': lunchStart,
            'duration': lunchEnd.difference(lunchStart).inMinutes,
            'type': 'lunch',
          });
        }
      }

      List<Map<String, dynamic>> slots = [];
      final now = DateTime.now();
      final isToday = DateUtils.isSameDay(_selectedDate, now);

      final serviceDuration = widget.appointment['servicos']['duracao_minutos'] ?? 60;

      // 4. Determina a janela de atendimento base (Profissional ou Clínica)
      String? baseStartTime;
      String? baseEndTime;

      if (work != null && work['fechado'] == false) {
        baseStartTime = work['hora_inicio'];
        baseEndTime = work['hora_fim'];
      } else if (work == null) {
        // Fallback para horário da clínica se o profissional não tiver configuração específica
        baseStartTime = clinicHours['hora_inicio'];
        baseEndTime = clinicHours['hora_fim'];
      }

      if (baseStartTime == null || baseEndTime == null) {
        if (mounted) {
          setState(() {
            _timeSlots = [];
            _isLoadingTimes = false;
          });
        }
        return;
      }

      // 5. Determina a janela final (Interseção com a clínica SE o profissional tiver horário próprio)
      String finalStartTime = baseStartTime;
      String finalEndTime = baseEndTime;

      if (work != null) {
        final String clinicStart = clinicHours['hora_inicio'];
        final String clinicEnd = clinicHours['hora_fim'];

        if (clinicStart.compareTo(finalStartTime) > 0) {
          finalStartTime = clinicStart;
        }
        if (clinicEnd.compareTo(finalEndTime) < 0) {
          finalEndTime = clinicEnd;
        }
      }

      if (finalStartTime.compareTo(finalEndTime) >= 0) {
        if (mounted) {
          setState(() {
            _timeSlots = [];
            _isLoadingTimes = false;
          });
        }
        return;
      }

      int startHour = int.parse(finalStartTime.split(':')[0]);
      int startMinute = int.parse(finalStartTime.split(':')[1]);
      int endHour = int.parse(finalEndTime.split(':')[0]);
      int endMinute = int.parse(finalEndTime.split(':')[1]);

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

        // Se o fim do serviço ultrapassa o horário de funcionamento, remove o slot
        if (slotEnd.isAfter(endTime)) {
          continue;
        }

        bool isOccupied = false;
        for (var occ in allOccupied) {
          final occStart = occ['dateTime'] as DateTime;
          final occDuration = (occ['duration'] ?? 0) as int;
          final occEnd = occStart.add(Duration(minutes: occDuration));

          // Checa sobreposição de intervalos: (StartA < EndB) && (EndA > StartB)
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

  Future<void> _checkConflictForTime(String time) async {
    setState(() {
      _selectedTime = time;
      _conflictProfessionalName = null;
      _conflictClientName = null;
    });

    try {
      final timeParts = time.split(':');
      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );

      // No modo admin, a verificação manual de conflito precisa ser MAIS robusta que um simples .eq
      // Pois o Admin pode estar forçando um agendamento ou fazendo verificações extras.
      // No entanto, para exibir os alertas de "Já possui agendamento", vamos usar a mesma lógica de intervalo.
      
      final serviceDuration = widget.appointment['servicos']['duracao_minutos'] ?? 60;
      final slotEnd = dateTime.add(Duration(minutes: serviceDuration));

      // Buscar agendamentos do dia para verificar sobreposição manual
      final startOfDay = DateTime(dateTime.year, dateTime.month, dateTime.day).toUtc().toIso8601String();
      final endOfDay = DateTime(dateTime.year, dateTime.month, dateTime.day, 23, 59, 59).toUtc().toIso8601String();

      final supabase = Supabase.instance.client;
      final occupied = await supabase
          .from('agendamentos')
          .select('data_hora, cliente_id, profissional_id, perfis:cliente_id(nome_completo), profissional:profissional_id(nome_completo), servicos(duracao_minutos)')
          .eq('status', 'pendente') // Ou confirmado/atendido
          .neq('id', widget.appointment['id'])
          .gte('data_hora', startOfDay)
          .lte('data_hora', endOfDay)
          .or('status.eq.pendente,status.eq.confirmado,status.eq.concluido');

      for (var occ in occupied) {
        final occStart = DateTime.parse(occ['data_hora']).toLocal();
        final occDuration = (occ['servicos']?['duracao_minutos'] ?? 0) as int;
        final occEnd = occStart.add(Duration(minutes: occDuration));

        // Sobreposição: (StartA < EndB) && (EndA > StartB)
        if (dateTime.isBefore(occEnd) && slotEnd.isAfter(occStart)) {
          if (occ['cliente_id'] == widget.appointment['cliente_id']) {
            _conflictProfessionalName = occ['profissional']['nome_completo'];
          }
          if (occ['profissional_id'] == widget.appointment['profissional_id']) {
            _conflictClientName = occ['perfis']['nome_completo'];
          }
        }
      }

      if (mounted && _selectedTime == time) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error checking conflict: $e');
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

      // Update appointment
      await _appointmentRepo.rescheduleAppointment(
        widget.appointment['id'],
        newDateTime,
      );

      // Send notification to user
      final clienteId = widget.appointment['cliente_id'];
      
      final notification = NotificationModel(
        userId: clienteId,
        titulo: 'Agendamento Reagendado',
        mensagem: 'Seu agendamento de ${widget.appointment['servicos']['nome']} foi alterado para ${DateFormat('dd/MM', 'pt_BR').format(newDateTime)} às ${DateFormat('HH:mm', 'pt_BR').format(newDateTime)}.',
        tipo: 'reagendamento',
        isLida: false,
        dataCriacao: DateTime.now(),
      );
      
      await _notificationRepo.saveNotification(notification);

      // Notificar Profissional (ele mesmo ou o designado)
      final profId = widget.appointment['profissional_id'];
      await _notificationRepo.saveNotification(NotificationModel(
        userId: profId,
        titulo: 'Agendamento Reagendado (Prof)',
        mensagem: 'O agendamento de ${widget.appointment['servicos']['nome']} (${widget.appointment['perfis']['nome_completo']}) foi alterado para ${DateFormat('dd/MM', 'pt_BR').format(newDateTime)} às ${DateFormat('HH:mm', 'pt_BR').format(newDateTime)}.',
        tipo: 'reagendamento',
        isLida: false,
        dataCriacao: DateTime.now(),
      ));

      if (mounted) {
        widget.onReagendado?.call();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agendamento reagendado com sucesso!'),
            backgroundColor: Color(0xFF2F5E46),
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
        color: Colors.white,
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
      key: const ValueKey('selection'),
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _buildHandle()),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: primaryGreen, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Reagendar Atendimento',
            style: TextStyle(fontFamily: 'Playfair Display', 
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: primaryGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Selecione a nova data e horário para este agendamento.',
            style: TextStyle(fontSize: 14,
              color: primaryGreen.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          _buildCalendar(),
          const SizedBox(height: 24),
          _buildTimeSlots(),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: (_selectedStartTime != null) 
                ? () => setState(() => _isConfirming = true) 
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              disabledBackgroundColor: Colors.grey[200],
            ),
            child: Text(
              'REVISAR ALTERAÇÃO',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationView() {
    final originalDate = DateTime.parse(widget.appointment['data_hora']);
    final timeParts = _selectedStartTime!.split(':');
    final newDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
    );

    return Padding(
      key: const ValueKey('confirmation'),
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
                color: primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.swap_horiz, color: primaryGreen, size: 32),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Confirmar Reagendamento',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Playfair Display', 
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: primaryGreen,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Revise as informações antes de confirmar. O cliente receberá uma notificação sobre esta mudança.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14,
              color: primaryGreen.withOpacity(0.6),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              _buildDateInfo('Anterior', originalDate, Colors.grey),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              _buildDateInfo('Novo', newDate, accent),
            ],
          ),
          const SizedBox(height: 48),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => _isConfirming = false),
                  child: Text(
                    'Voltar',
                    style: TextStyle(fontWeight: FontWeight.bold,
                      color: Colors.grey,
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
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isUpdating
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          'Confirmar Troca',
                          style: TextStyle(fontWeight: FontWeight.bold),
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
            style: TextStyle(fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.7),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('dd/MM', 'pt_BR').format(date),
            style: TextStyle(fontFamily: 'Playfair Display', 
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: primaryGreen,
            ),
          ),
          Text(
            DateFormat('HH:mm').format(date),
            style: TextStyle(fontSize: 14,
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

  Widget _buildCalendar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selecione a Data',
          style: TextStyle(fontSize: 10,
            fontWeight: FontWeight.bold,
            color: accent,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        // Month Navigation
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
                  _focusedMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
                });
                _updateTimeSlots();
              },
              icon: Icon(Icons.chevron_left, color: primaryGreen),
            ),
            Text(
              DateFormat('MMMM yyyy', 'pt_BR').format(_selectedDate).toUpperCase(),
              style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryGreen,
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
                  _focusedMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
                });
                _updateTimeSlots();
              },
              icon: Icon(Icons.chevron_right, color: primaryGreen),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildCalendarGrid(),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final lastDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    
    int firstDayWeekday = firstDayOfMonth.weekday;
    int offset = firstDayWeekday % 7;

    final List<DateTime?> days = [];
    for (int i = 0; i < offset; i++) {
      days.add(null);
    }
    for (int i = 1; i <= lastDayOfMonth.day; i++) {
      days.add(DateTime(_selectedDate.year, _selectedDate.month, i));
    }

    final today = DateUtils.dateOnly(DateTime.now());

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB'].map((d) {
            return Text(
              d,
              style: TextStyle(fontSize: 10,
                fontWeight: FontWeight.bold,
                color: primaryGreen.withOpacity(0.3),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: days.length,
          itemBuilder: (context, index) {
            final date = days[index];
            if (date == null) return const SizedBox.shrink();

            final isSelected = DateUtils.isSameDay(date, _selectedDate);
            final isPast = date.isBefore(today);
            final int dayOfWeek = date.weekday == 7 ? 0 : date.weekday;
            final isClosedClinic = _availableDayOfWeek.isNotEmpty && !_availableDayOfWeek.contains(dayOfWeek);
            final isProfBlocked = _blockedDates.any((d) => DateUtils.isSameDay(d, date));
            final isClosed = isClosedClinic || isProfBlocked;
            final isTappable = !isPast && !isClosed;

            return GestureDetector(
              onTap: isTappable ? () {
                setState(() => _selectedDate = date);
                _updateTimeSlots();
              } : null,
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected 
                    ? accent 
                    : (isClosed 
                        ? Colors.red.withOpacity(0.05) 
                        : Colors.transparent),
                  borderRadius: BorderRadius.circular(100),
                  border: isPast || isClosed 
                    ? (isClosed ? Border.all(color: Colors.red.withOpacity(0.1)) : null)
                    : Border.all(
                        color: isSelected ? accent : primaryGreen.withOpacity(0.05),
                      ),
                ),
                child: Center(
                  child: Text(
                    date.day.toString(),
                    style: TextStyle(fontSize: 14,
                      fontWeight: (isSelected || isClosed) ? FontWeight.bold : FontWeight.normal,
                      color: isSelected 
                          ? Colors.white 
                          : (isPast 
                              ? Colors.black12 
                              : (isClosed 
                                  ? Colors.red[700] 
                                  : Colors.black87)),
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
          style: TextStyle(fontSize: 10,
            fontWeight: FontWeight.bold,
            color: accent,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoadingTimes)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        else if (_timeSlots.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Não há horários disponíveis para esta data.',
                    style: TextStyle(color: Colors.grey[600]),
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
                    color: isSelected ? accent : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? accent
                          : Colors.black.withOpacity(0.05),
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
                              color: isSelected ? Colors.white : primaryGreen,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "$startTime - $endTime",
                              style: TextStyle(fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Padding(
                          padding: const EdgeInsets.only(left: 20),
                          child: Text(
                            "$duration min",
                            style: TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? Colors.white.withOpacity(0.8)
                                  : Colors.black54,
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
}

