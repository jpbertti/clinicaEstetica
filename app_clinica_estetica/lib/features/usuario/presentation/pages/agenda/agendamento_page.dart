import 'package:app_clinica_estetica/core/data/models/professional_model.dart';
import 'package:app_clinica_estetica/core/data/models/service_model.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_professional_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:app_clinica_estetica/core/data/models/pacote_template_model.dart';
import 'package:app_clinica_estetica/core/data/models/profile_model.dart';

class AgendamentoPage extends StatefulWidget {
  final ServiceModel? service;
  final PacoteTemplateModel? pacote;
  final ProfileModel? profissional;
  final int? sessaoNumero;
  final String? serviceId;
  final String? serviceName;
  final String? clientId;
  final String? clientName;

  const AgendamentoPage({
    super.key,
    this.service,
    this.pacote,
    this.profissional,
    this.sessaoNumero,
    this.serviceId,
    this.serviceName,
    this.clientId,
    this.clientName,
  });

  @override
  State<AgendamentoPage> createState() => _AgendamentoPageState();
}

class _AgendamentoPageState extends State<AgendamentoPage> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _profRepo = SupabaseProfessionalRepository();

  ProfessionalModel? _selectedProfessional;
  DateTime _selectedDate = DateTime.now();
  String? _selectedTime;
  bool _isLoadingProfs = true;
  bool _isLoadingTimes = false;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _attentionController;
  late Animation<double> _shakeAnimation;

  List<ProfessionalModel> _professionals = [];
  List<Map<String, dynamic>> _timeSlots = [];
  
  bool _clinicHasConfig = false;
  Set<int> _availableDayOfWeek = {}; 
  Map<int, Map<String, dynamic>> _clinicWorkingHoursMap = {};

  bool _profHasConfig = false;
  Set<int> _profAvailableDays = {}; 

  Set<int> _blockedDaysInMonth = {};

  @override
  void initState() {
    super.initState();
    // O profissional não vem mais pré-selecionado por padrão, forçando a seleção manual.

    _loadProfessionals().then((_) {
      _loadProfessionalAvailability();
      _loadMonthlyBlocks();
      _updateTimeSlots();
    });
    _loadClinicAvailability();
    
    debugPrint('AGENDAMENTO_DEBUG: Initialized.');
    debugPrint('AGENDAMENTO_DEBUG: widget.clientId = ${widget.clientId}');
    debugPrint('AGENDAMENTO_DEBUG: widget.clientName = ${widget.clientName}');

    _attentionController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _attentionController,
      curve: Curves.easeInOut,
    ));
  }

  void _triggerAttentionEffect() {
    _attentionController.forward(from: 0);
  }

  Future<void> _loadClinicAvailability() async {
    try {
      final response = await _supabase.from('horarios_clinica').select();
      final clinicMap = <int, Map<String, dynamic>>{};
      final availableDays = <int>{};
      
      for (var row in response) {
        final int dia = row['dia_semana'] as int;
        clinicMap[dia] = row;
        if (row['fechado'] == false) {
           availableDays.add(dia);
        }
      }
      
      if (mounted) {
        setState(() {
          _clinicHasConfig = clinicMap.isNotEmpty;
          _clinicWorkingHoursMap = clinicMap;
          _availableDayOfWeek = availableDays;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar disponibilidade da clínica: $e');
    }
  }

  Future<void> _loadProfessionalAvailability() async {
    if (_selectedProfessional == null) return;
    try {
      final workHours = await _profRepo.getProfessionalWorkingHours(_selectedProfessional!.id);
      final profMap = <int, Map<String, dynamic>>{};
      final Set<int> profDays = {};
      
      for (var h in workHours) {
        final int dia = h['dia_semana'] as int;
        profMap[dia] = h;
        if (h['fechado'] == false) {
          profDays.add(dia);
        }
      }
      if (mounted) {
        setState(() {
          _profHasConfig = profMap.isNotEmpty;
          _profAvailableDays = profDays;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar disponibilidade do profissional: $e');
    }
  }

  Future<void> _loadMonthlyBlocks() async {
    if (_selectedProfessional == null) return;
    
    try {
      final blocks = await _profRepo.getMonthlyBlocks(
        _selectedProfessional!.id,
        _selectedDate.year,
        _selectedDate.month,
      );
      
      final Set<int> daySet = {};
      for (var block in blocks) {
        final date = DateTime.parse(block['data']);
        daySet.add(date.day);
      }
      
      setState(() {
        _blockedDaysInMonth = daySet;
      });
    } catch (e) {
      debugPrint('Erro ao carregar bloqueios mensais: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _attentionController.dispose();
    super.dispose();
  }

  Future<void> _loadProfessionals() async {
    try {
      final String? targetServiceId = widget.service?.id ?? widget.serviceId;
      final String? targetPackageId = widget.pacote?.id;
      
      debugPrint('AGENDAMENTO_DEBUG: targetServiceId=$targetServiceId, targetPackageId=$targetPackageId');

      List<ProfessionalModel> profs = [];
      
      if (targetServiceId != null) {
        profs = await _profRepo.getProfessionalsByService(targetServiceId);
      } else if (targetPackageId != null) {
        profs = await _profRepo.getProfessionalsByPackage(targetPackageId);
      } else {
        // Fallback apenas se não houver NADA selecionado (improvável no fluxo atual)
        final maps = await _profRepo.getProfessionals();
        profs = maps.map((m) => ProfessionalModel.fromMap(m)).toList();
      }

      debugPrint('AGENDAMENTO_DEBUG: found ${profs.length} professionals');

      setState(() {
        _professionals = profs;
        _isLoadingProfs = false;
      });
    } catch (e) {
      setState(() => _isLoadingProfs = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar profissionais: $e')),
        );
      }
    }
  }

  Future<void> _updateTimeSlots() async {
    if (_selectedProfessional == null) {
      setState(() => _timeSlots = []);
      return;
    }

    setState(() => _isLoadingTimes = true);
    try {
      final int dayOfWeek = _selectedDate.weekday == 7 ? 0 : _selectedDate.weekday;
      
      // 1. Busca Horário de Trabalho, Almoço e Bloqueios do profissional
      final profData = await _profRepo.getProfessionalBlocksAndLunch(_selectedProfessional!.id, _selectedDate);
      
      final work = profData['work'] as Map<String, dynamic>?;
      final lunch = profData['lunch'] as Map<String, TimeOfDay>?;
      final blocks = (profData['blocks'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      // 2. Determina a janela de atendimento base (Profissional ou Clínica)
      String? baseStartTime;
      String? baseEndTime;

      if (work != null && work['fechado'] == false) {
        baseStartTime = work['hora_inicio'];
        baseEndTime = work['hora_fim'];
      } else if (work == null) {
        // Fallback para horário da clínica se o profissional não tiver configuração específica
        if (_clinicHasConfig && _clinicWorkingHoursMap.containsKey(dayOfWeek)) {
          final clinicHours = _clinicWorkingHoursMap[dayOfWeek]!;
          if (clinicHours['fechado'] == false) {
            baseStartTime = clinicHours['hora_inicio'];
            baseEndTime = clinicHours['hora_fim'];
          }
        }
      }

      // Se não houver horário base (fechado ou sem config), não há slots
      if (baseStartTime == null || baseEndTime == null) {
        setState(() {
          _timeSlots = [];
          _isLoadingTimes = false;
        });
        return;
      }

      // 3. Valida se a clínica está aberta neste dia (Garantia adicional)
      if (_clinicHasConfig && !_availableDayOfWeek.contains(dayOfWeek)) {
        setState(() {
          _timeSlots = [];
          _isLoadingTimes = false;
        });
        return;
      }

      // 4. Determina a janela final (Interseção com a clínica SE o profissional tiver horário próprio)
      String finalStartTime = baseStartTime;
      String finalEndTime = baseEndTime;

      if (work != null && _clinicHasConfig && _clinicWorkingHoursMap.containsKey(dayOfWeek)) {
        final clinicHours = _clinicWorkingHoursMap[dayOfWeek]!;
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
        setState(() {
          _timeSlots = [];
          _isLoadingTimes = false;
        });
        return;
      }

      // 5. Verifica se o dia está totalmente bloqueado
      if (_blockedDaysInMonth.contains(_selectedDate.day)) {
        setState(() {
          _timeSlots = [];
          _isLoadingTimes = false;
        });
        return;
      }

      // 6. Prepara lista de ocupação (Agendamentos + Bloqueios Parciais + Almoço)
      final allOccupied = await _profRepo.getOccupiedTimes(_selectedProfessional!.id, _selectedDate);
      
      // Bloqueios parciais do profissional/clínica
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

      // Almoço configurado para o profissional
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

      // 7. Geração de Slots (Intervalos de 30 minutos)
      List<Map<String, dynamic>> slots = [];
      final now = DateTime.now();
      final isToday = _selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day;
      final serviceDuration = widget.service?.duracaoMinutos ?? 60;

      final startTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, int.parse(finalStartTime.split(':')[0]), int.parse(finalStartTime.split(':')[1]));
      final endTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, int.parse(finalEndTime.split(':')[0]), int.parse(finalEndTime.split(':')[1]));

      for (DateTime current = startTime; current.isBefore(endTime); current = current.add(const Duration(minutes: 30))) {
        final slotStart = current;
        final slotEnd = current.add(Duration(minutes: serviceDuration));

        // Não pode extrapolar o horário de fechamento
        if (slotEnd.isAfter(endTime)) continue;

        // Não pode estar no passado se for hoje
        if (isToday && slotStart.isBefore(now)) continue;

        // Verifica sobreposição com QUALQUER item ocupado (Agendamento, Bloco ou Almoço)
        bool isOccupied = false;
        for (var occ in allOccupied) {
          final occStart = occ['dateTime'] as DateTime;
          final occDuration = occ['duration'] as int;
          final occEnd = occStart.add(Duration(minutes: occDuration));

          // Interseção: (StartA < EndB) && (EndA > StartB)
          if (slotStart.isBefore(occEnd) && slotEnd.isAfter(occStart)) {
            isOccupied = true;
            break;
          }
        }

        if (!isOccupied) {
          slots.add({
            'start': "${slotStart.hour.toString().padLeft(2, '0')}:${slotStart.minute.toString().padLeft(2, '0')}",
            'end': "${slotEnd.hour.toString().padLeft(2, '0')}:${slotEnd.minute.toString().padLeft(2, '0')}",
            'duration': serviceDuration,
          });
        }
      }

      setState(() {
        _timeSlots = slots;
        _isLoadingTimes = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTimes = false);
      }
      debugPrint('Erro ao atualizar slots: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Reservar ${widget.service?.nome ?? widget.serviceName ?? 'Serviço'}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // Spacer to balance the IconButton
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.accent),

            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _construirTituloSecao(
                      'Selecione o Profissional',
                      AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    _buildProfessionalSelectionHorizontal(),
                    
                    const SizedBox(height: 32),
                    
                    // Month Selector Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
                              _selectedTime = null;
                            });
                            _loadMonthlyBlocks();
                            _updateTimeSlots();
                          },
                          icon: const Icon(Icons.chevron_left, color: AppColors.primary, size: 32),
                        ),
                        Text(
                          '${_getNomeMes(_selectedDate.month)} ${_selectedDate.year}',
                          style: GoogleFonts.playfairDisplay(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                            fontSize: 24,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
                              _selectedTime = null;
                            });
                            _loadMonthlyBlocks();
                            _updateTimeSlots();
                          },
                          icon: const Icon(Icons.chevron_right, color: AppColors.primary, size: 32),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _construirGradeCalendario(),

                    const SizedBox(height: 32),
                    _construirTituloSecao('Horários', AppColors.primary),
                    const SizedBox(height: 16),
                    _isLoadingTimes
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(color: AppColors.accent),
                            ),
                          )
                        : _timeSlots.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                                  child: Text(
                                    _selectedProfessional == null
                                        ? 'Selecione um profissional para ver horários'
                                        : 'Nenhum horário disponível para esta data.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.manrope(
                                      fontSize: 16,
                                      color: Colors.grey.withOpacity(0.5),
                                    ),
                                  ),
                                ),
                              )
                            : GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 2.2,
                                ),
                                itemCount: _timeSlots.length,
                                itemBuilder: (context, index) {
                                  return _buildTimeSlotCard(_timeSlots[index]);
                                },
                              ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_selectedProfessional != null && _selectedTime != null)
                            ? () {
                                final extraData = {
                                  'serviceId': widget.service?.id ?? widget.serviceId,
                                  'serviceName': widget.pacote != null 
                                      ? '${widget.pacote!.titulo} (Sessão ${widget.sessaoNumero})'
                                      : widget.service?.nome ?? widget.serviceName ?? 'Serviço Personalizado',
                                  'pacoteNome': widget.pacote?.titulo,
                                  'procedimentoNome': widget.service?.nome ?? widget.serviceName,
                                  'price': widget.pacote != null 
                                      ? 'Incluso no Pacote' 
                                      : (widget.service != null 
                                          ? (widget.service!.isPromocao 
                                              ? widget.service!.formattedPromotionalPrice 
                                              : widget.service!.formattedPrice)
                                          : 'A consultar'),
                                  'priceValue': widget.pacote != null 
                                      ? 0.0 
                                      : (widget.service != null 
                                          ? (widget.service!.isPromocao 
                                              ? widget.service!.precoPromocional! 
                                              : widget.service!.preco)
                                          : 0.0),
                                  'serviceImage': widget.pacote?.imagemUrl ?? widget.service?.imagemUrl,
                                  'professionalId': _selectedProfessional!.id,
                                  'professional': _selectedProfessional!.nome,
                                  'professionalImage': _selectedProfessional!.avatarUrl,
                                  'date': _selectedDate,
                                  'time': _selectedTime,
                                  'duracaoMinutos': widget.service?.duracaoMinutos ?? 60,
                                  'pacote': widget.pacote,
                                  'sessaoNumero': widget.sessaoNumero,
                                  'clientId': widget.clientId,
                                  'clientName': widget.clientName,
                                };
                                context.push(
                                  '/confirmacao-agendamento',
                                  extra: extraData,
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (_selectedProfessional != null && _selectedTime != null) ? AppColors.primary : Colors.grey.shade300,
                          foregroundColor: (_selectedProfessional != null && _selectedTime != null) ? AppColors.white : Colors.grey.shade600,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Text(
                          'Seguir para Confirmação',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirTituloSecao(String title, Color color) {
    return Text(
      title,
      style: GoogleFonts.playfairDisplay(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }

  Widget _buildProfessionalSelectionHorizontal() {
    if (_isLoadingProfs) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_professionals.isEmpty) {
      return Text(
        'Nenhum profissional disponível.',
        style: GoogleFonts.manrope(color: AppColors.textLight),
      );
    }

    return SizedBox(
      height: 200,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: _professionals.length,
        separatorBuilder: (context, index) => const SizedBox(width: 20),
        itemBuilder: (context, index) {
          final prof = _professionals[index];
          final isSelected = _selectedProfessional?.id == prof.id;
          return GestureDetector(
            onTap: () async {
              setState(() {
                _selectedProfessional = prof;
                _isLoadingTimes = true;
                _timeSlots = [];
                _selectedTime = null;
              });
              await _loadProfessionalAvailability();
              await _loadMonthlyBlocks();
              await _updateTimeSlots();
            },
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppColors.accent : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 44,
                        backgroundColor: Colors.grey.shade100,
                        backgroundImage: prof.avatarUrl != null
                            ? NetworkImage(prof.avatarUrl!)
                            : const NetworkImage(
                                'https://images.unsplash.com/photo-1559599101-f09722fb4948?auto=format&fit=crop&w=200&q=80',
                              ),
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  prof.nome,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  prof.cargo ?? 'Especialista',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }


  Widget _construirGradeCalendario() {
    final daysOfWeek = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB'];

    final firstDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final lastDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final startOffset = firstDayOfMonth.weekday % 7; 

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: daysOfWeek
              .map(
                (day) => Expanded(
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.withOpacity(0.6),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: daysInMonth + startOffset,
          itemBuilder: (context, index) {
            if (index < startOffset) return const SizedBox();
            final day = index - startOffset + 1;
            final isInternalSelected = _selectedDate.day == day;

            final now = DateTime.now();
            final dateToCheck = DateTime(_selectedDate.year, _selectedDate.month, day);
            final isPast = dateToCheck.isBefore(DateTime(now.year, now.month, now.day));

            int dayOfWeek = dateToCheck.weekday == 7 ? 0 : dateToCheck.weekday;
            bool isClosed = false;
            
            if (_selectedProfessional != null) {
              if (_profHasConfig) {
                isClosed = !_profAvailableDays.contains(dayOfWeek);
              } else if (_clinicHasConfig) {
                isClosed = !_availableDayOfWeek.contains(dayOfWeek);
              }
            } else {
              if (_clinicHasConfig) {
                isClosed = !_availableDayOfWeek.contains(dayOfWeek);
              }
            }
            
            final isFullyBlocked = _blockedDaysInMonth.contains(day);
            final isUnavailable = isClosed || isFullyBlocked;

            Color textColor = Colors.black;
            if (isInternalSelected) {
              textColor = Colors.white;
            } else if (isPast) {
              textColor = AppColors.accent.withOpacity(0.4);
            } else if (dayOfWeek == 0 || isUnavailable) {
              textColor = Colors.red;
            }

            return GestureDetector(
              onTap: (isPast || isUnavailable)
                  ? null
                  : () {
                      setState(() {
                        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month, day);
                        _selectedTime = null;
                      });
                      _updateTimeSlots();
                    },
              child: Container(
                decoration: BoxDecoration(
                  color: isInternalSelected ? AppColors.accent : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    day.toString(),
                    style: GoogleFonts.manrope(
                      fontWeight: isInternalSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 16,
                      color: textColor,
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

  String _getNomeMes(int month) {
    const meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return meses[month - 1];
  }


  Widget _buildTimeSlotCard(Map<String, dynamic> slot) {
    final startTime = slot['start'] as String;
    final endTime = slot['end'] as String;
    final duration = slot['duration'] as int;
    final isSelected = _selectedTime == startTime;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedTime = startTime);
        // Scroll para o botão de confirmação
        Future.delayed(const Duration(milliseconds: 100), () {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.accent.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$startTime - $endTime',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: isSelected ? Colors.white.withOpacity(0.9) : AppColors.accent,
                ),
                const SizedBox(width: 4),
                Text(
                  '${duration}min de agendamento',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white.withOpacity(0.9) : AppColors.textLight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

