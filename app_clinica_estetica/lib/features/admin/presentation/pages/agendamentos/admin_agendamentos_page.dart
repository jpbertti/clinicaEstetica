import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:app_clinica_estetica/features/admin/presentation/widgets/admin_reagendamento_modal.dart';
import 'package:app_clinica_estetica/core/data/models/notification_model.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_notification_repository.dart';
import 'package:app_clinica_estetica/core/data/models/professional_model.dart';

import 'package:app_clinica_estetica/core/data/repositories/supabase_caixa_repository.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_professional_repository.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';
import 'package:app_clinica_estetica/core/theme/app_button_styles.dart';
import 'package:app_clinica_estetica/core/utils/string_utils.dart';

class AdminAgendamentosPage extends StatefulWidget {
  const AdminAgendamentosPage({super.key});

  @override
  State<AdminAgendamentosPage> createState() => _AdminAgendamentosPageState();
}

class _AdminAgendamentosPageState extends State<AdminAgendamentosPage> {
  final _supabase = Supabase.instance.client;
  final _notificationRepo = SupabaseNotificationRepository();
  final _caixaRepo = SupabaseCaixaRepository();
  final _professionalRepo = SupabaseProfessionalRepository();
  final ScrollController _dayScrollController = ScrollController();
  DateTime _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  String? _selectedProfessionalId;
  String _selectedStatus = 'todos';
  
  List<Map<String, dynamic>> _professionals = [];
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoadingAppts = true;
  bool _isCalendarExpanded = false;
  bool _isGridView = false;
  bool _isMonthlyView = false;
  String? _activeCaixaId;
  Set<int> _clinicAvailableDays = {1, 2, 3, 4, 5, 6, 0}; // Default all open
  List<DateTime> _blockedDays = [];

  final Color primaryGreen = const Color(0xFF2F5E46);
  final Color accent = const Color(0xFFC7A36B);
  final Color bgColor = const Color(0xFFF6F4EF);

  @override
  void initState() {
    super.initState();
    // Garantir que começamos no dia de hoje sem horas/minutos para filtros precisos
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    
    _loadInitialData();
    
    // Garantir que a rolagem aconteça após o primeiro frame estar pronto
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 300), () => _scrollToSelectedDay());
      }
    });
  }

  void _scrollToSelectedDay() {
    if (_dayScrollController.hasClients) {
      final double screenWidth = MediaQuery.of(context).size.width;
      const double itemWidth = 72.0; // 60 width + 12 margin
      final double targetOffset = ((_selectedDate.day - 1) * itemWidth) - (screenWidth / 2) + (itemWidth / 2);
      
      _dayScrollController.animateTo(
        targetOffset.clamp(0.0, _dayScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _loadInitialData() async {
    await _loadAvailability();
    await _loadProfessionals();
    await _loadAppointments();
  }

  Future<void> _loadAvailability() async {
    try {
      final clinicDays = await _professionalRepo.getClinicAvailabilityDays();
      final blocks = await _professionalRepo.getMonthlyBlocks(_selectedProfessionalId, _selectedDate.year, _selectedDate.month);
      
      if (mounted) {
        setState(() {
          _clinicAvailableDays = clinicDays.toSet();
          _blockedDays = blocks.map((b) => DateTime.parse(b['data'])).toList();
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar disponibilidade: $e');
    }
  }

  Future<void> _loadProfessionals() async {
    try {
      final profRepo = SupabaseProfessionalRepository();
      // O repository já exclui perfis administrativos
      final response = await profRepo.getProfessionals();
      
      if (mounted) {
        setState(() {
          // Adicionamos a opção "Todos" explicitamente no início da lista
          _professionals = [
            {'id': 'todos', 'nome_completo': 'Todos'},
            ...response,
          ];
          
          // Se o profissional selecionado não estiver mais na lista, voltamos para "Todos"
          if (_selectedProfessionalId != null && _selectedProfessionalId != 'todos' && !response.any((p) => p['id'] == _selectedProfessionalId)) {
            _selectedProfessionalId = 'todos';
          }
          if (_selectedProfessionalId == null) {
            _selectedProfessionalId = 'todos';
          }
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar profissionais: $e');
    }
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoadingAppts = true);
    try {
      // Carregar caixa ativo
      final activeCaixa = await _caixaRepo.getActiveCaixa();
      _activeCaixaId = activeCaixa?.id;

      final DateTime start;
      final DateTime end;
      
      if (_isMonthlyView) {
        start = DateTime(_selectedDate.year, _selectedDate.month, 1);
        end = DateTime(_selectedDate.year, _selectedDate.month + 1, 0, 23, 59, 59);
      } else {
        start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        end = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
      }

      final startStr = start.toIso8601String();
      final endStr = end.toIso8601String();

      var query = _supabase
          .from('agendamentos')
          .select('*, servicos(nome, duracao_minutos), perfis!cliente_id(id, nome_completo, avatar_url), profissional:perfis!profissional_id(nome_completo), pacote:pacotes_contratados(id, sessoes_totais, template:pacotes_templates!template_id(titulo))')
          .gte('data_hora', startStr)
          .lte('data_hora', endStr);

      if (_selectedProfessionalId != null && _selectedProfessionalId != 'todos') {
        query = query.eq('profissional_id', _selectedProfessionalId!);
      }

      if (_selectedStatus != 'todos') {
        query = query.eq('status', _selectedStatus);
      }

      final response = await query.order('data_hora', ascending: true);
      
      setState(() {
        _appointments = List<Map<String, dynamic>>.from(response);
        _isLoadingAppts = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar agendamentos: $e');
      setState(() => _isLoadingAppts = false);
    }
  }

  void _showOpenCaixaDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: accent, size: 22),
            const SizedBox(width: 10),
            Text('Caixa fechado', style: TextStyle(fontWeight: FontWeight.bold, color: primaryGreen)),
          ],
        ),
        content: Text(
          'O caixa está fechado no momento.\n\nPor favor, solicite ao administrador que realize a abertura do caixa para que seja possível registrar pagamentos.',
          style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: AppButtonStyles.primary(),
            child: Text(StringUtils.toTitleCase('fechar')),
          ),
        ],
      ),
    );
  }

  bool _isUpdatingStatus = false;

  Future<void> _updateStatus(Map<String, dynamic> appointment, String newStatus) async {
    if (_isUpdatingStatus) return;

    // Não permitir finalizar se for data futura
    if (newStatus == 'concluido') {
      final DateTime apptDate = DateTime.parse(appointment['data_hora']).toLocal();
      final DateTime now = DateTime.now();
      
      // Se a data do agendamento for após agora (comparando apenas a data ou data/hora completa?)
      // O usuário disse "data seguinte", mas geralmente não se finaliza se for futuro.
      if (apptDate.isAfter(now)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Não é possível finalizar um agendamento futuro.'),
            backgroundColor: Colors.orange[800],
          ),
        );
        return;
      }
    }
    
    Map<String, dynamic> paymentData = {};
    if (newStatus == 'concluido' || newStatus == 'pagar') {
      // Se for apenas conclusão e já estiver pago, não precisa abrir o diálogo de pagamento
      final jaEstaPago = appointment['pago'] == true;
      
      if (newStatus == 'concluido' && jaEstaPago) {
        // Já está pago, não faz nada com paymentData (permanece vazio)
        paymentData = {};
      } else {
        // Recarregar status do caixa para garantir que não está pegando estado antigo
        final activeCaixa = await _caixaRepo.getActiveCaixa();
        _activeCaixaId = activeCaixa?.id;

        // Precisa de um caixa aberto para pagar
        if (_activeCaixaId == null) {
          _showOpenCaixaDialog();
          return;
        }

        // Precisa pagar (ou concluir sem ter pago ainda)
        final result = await _showPaymentDialog(appointment);
        if (result == null) return; // Cancelou
        paymentData = result;
      }
    }

    setState(() => _isUpdatingStatus = true);
    try {
      final appointmentId = appointment['id'];
      final profissionalId = appointment['profissional_id'];
      
      final Map<String, dynamic> updates = {};
      
      if (newStatus == 'pagar' || (newStatus == 'concluido' && paymentData.isNotEmpty)) {
        // Calcular comissão
        final profResponse = await _supabase
            .from('perfis')
            .select('comissao_agendamentos_percentual')
            .eq('id', profissionalId)
            .single();
        
        final double percentualComissao = (profResponse['comissao_agendamentos_percentual'] ?? 0).toDouble();
        
        // O valor total pode vir de paymentData['valor_total'] ou do agendamento original
        final double valorTotal = (paymentData['valor_total'] ?? appointment['valor_total'] ?? 0).toDouble();
        final double valorComissao = (valorTotal * percentualComissao) / 100;
        
        updates['valor_comissao'] = valorComissao;
      }

      if (newStatus == 'pagar') {
        // Lançar ou Editar pagamento
        updates.addAll(paymentData);
        updates['pago'] = true;
        // Só atualiza a data se ainda não estiver pago
        if (appointment['pago'] != true) {
          updates['data_pagamento'] = DateTime.now().toUtc().toIso8601String();
        }
      } else {
        updates['status'] = newStatus;
        updates.addAll(paymentData);
        if (newStatus == 'concluido' && appointment['pago'] != true) {
          updates['pago'] = true;
          updates['data_pagamento'] = DateTime.now().toUtc().toIso8601String();
        }
      }

      // Vincular ao caixa ativo se houver pagamento e não for nulo
      if ((newStatus == 'concluido' || newStatus == 'pagar') && _activeCaixaId != null) {
         updates['caixa_id'] = _activeCaixaId;
      }
      
      await _supabase
          .from('agendamentos')
          .update(updates)
          .eq('id', appointmentId);

      // Enviar notificação ao usuário
      final clienteId = appointment['cliente_id'];
      final serviceName = appointment['servicos'] != null ? appointment['servicos']['nome'] : 'procedimento';
      final double valorTotal = (updates['valor_total'] ?? appointment['valor_total'] ?? 0).toDouble();
      final valorFormatado = 'R\$ ${valorTotal.toStringAsFixed(2)}';
      
      String title = 'Status de Agendamento';
      String message = 'O status do seu agendamento de $serviceName foi atualizado. Valor: $valorFormatado.';
      String notificationType = 'status_change';
      
      final appointmentDate = DateTime.parse(appointment['data_hora']);
      final dateStr = DateFormat('dd/MM', 'pt_BR').format(appointmentDate);
      final timeStr = DateFormat('HH:mm').format(appointmentDate);

      if (newStatus == 'pagar') {
        title = 'Pagamento Lançado';
        message = 'O pagamento para o seu atendimento de $serviceName em $dateStr às $timeStr foi registrado. Valor: $valorFormatado.';
        notificationType = 'pagamento';
      } else {
        switch(newStatus) {
          case 'concluido': 
            title = 'Atendimento Finalizado';
            message = 'Seu atendimento de $serviceName em $dateStr às $timeStr foi finalizado. Valor: $valorFormatado. Esperamos que tenha gostado!';
            notificationType = 'concluido';
            break;
          case 'confirmado': 
            title = 'Agendamento Confirmado';
            message = 'Seu agendamento de $serviceName foi confirmado para $dateStr às $timeStr.';
            notificationType = 'confirmado';
            break;
          case 'cancelado': 
            title = 'Agendamento Cancelado';
            message = 'Seu agendamento de $serviceName para $dateStr às $timeStr foi cancelado.';
            notificationType = 'cancelamento';
            break;
          case 'no_show':
            title = 'No-show Registrado';
            message = 'Registramos que você não compareceu ao agendamento de $serviceName em $dateStr às $timeStr. Entre em contato se houve algum engano.';
            notificationType = 'no_show';
            break;
        }
      }
      
      final notification = NotificationModel(
        userId: clienteId,
        titulo: title,
        mensagem: message,
        tipo: notificationType,
        isLida: false,
        dataCriacao: DateTime.now(),
      );
      
      await _notificationRepo.saveNotification(notification);
      
      await _loadAppointments();
      if (mounted) {
        final feedback = newStatus == 'pagar' ? 'Pagamento registrado com sucesso' : 'Status atualizado para ${newStatus}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(feedback),
            backgroundColor: primaryGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao atualizar status: $e');
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  void _rescheduleAppointment(Map<String, dynamic> appointment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AdminReagendamentoModal(
        appointment: appointment,
        onReagendado: _loadAppointments,
      ),
    );
  }

  void _changeMonth(int offset) {
    setState(() {
      final lastDayThisMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
      
      int newDay;
      if (offset > 0 && _selectedDate.day == lastDayThisMonth) {
        // Last day of month + Next -> goes to 1st of next month
        newDay = 1;
      } else if (offset < 0 && _selectedDate.day == 1) {
        // 1st day of month + Back -> goes to last day of previous month
        newDay = DateTime(_selectedDate.year, _selectedDate.month, 0).day;
      } else {
        // Standard preservation with clamping
        final targetMonth = DateTime(_selectedDate.year, _selectedDate.month + offset, 1);
        final daysInTargetMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
        newDay = _selectedDate.day > daysInTargetMonth ? daysInTargetMonth : _selectedDate.day;
      }
      
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + offset, newDay);
    });
    _loadAvailability();
    _loadAppointments();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedDay());
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: bgColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Container(
                color: bgColor,
                padding: const EdgeInsets.only(top: 20, bottom: 10),
                child: Column(
                  children: [
                    // --- Header: Month Navigation ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.chevron_left, color: primaryGreen),
                          onPressed: () => _changeMonth(-1),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              () {
                                String formatted = DateFormat('MMMM yyyy', 'pt_BR').format(_selectedDate);
                                if (formatted.isEmpty) return "";
                                return formatted[0].toUpperCase() + formatted.substring(1);
                              }(),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: primaryGreen,
                                fontFamily: 'Playfair Display',
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.chevron_right, color: primaryGreen),
                          onPressed: () => _changeMonth(1),
                        ),
                      ],
                    ),
                    
                    // --- Monthly View Button ---
                    // --- Monthly View Button (Placed after Professionais if needed, or before) ---
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 0),
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _isMonthlyView = !_isMonthlyView;
                            if (_isMonthlyView) {
                              _isGridView = false;
                            }
                            _loadAppointments();
                          });
                        },
                        icon: Icon(
                          _isMonthlyView ? Icons.calendar_view_day : Icons.calendar_month,
                          color: accent,
                          size: 18,
                        ),
                        label: Text(
                          _isMonthlyView ? 'Visualização diária' : 'Visualização mensal',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryGreen,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                        // --- Professional Selection (Always Visible) ---
                        if (!_isMonthlyView) ...[
                            // --- Calendar Navigation / Toggle ---
                            const SizedBox(height: 10),
                            _buildDaySelector(),
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: () => setState(() => _isCalendarExpanded = !_isCalendarExpanded),
                              icon: Icon(_isCalendarExpanded ? Icons.keyboard_arrow_up : Icons.calendar_month, color: primaryGreen),
                              label: Text(_isCalendarExpanded ? 'Fechar calendário' : 'Abrir calendário', style: TextStyle(color: primaryGreen)),
                            ),
                            if (_isCalendarExpanded) ...[
                              const SizedBox(height: 10),
                              _buildFullCalendar(),
                            ],
                            const SizedBox(height: 10),
                        ],

                        
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 160, 
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            itemCount: _professionals.length,
                            itemBuilder: (context, index) {
                              final professional = _professionals[index];
                              final String profId = professional['id'];
                              final String profName = professional['nome_completo'] ?? '';
                              final String? profCargo = professional['cargo'];
                              final String? avatarUrl = professional['avatar_url'];
                              
                              final isSelected = _selectedProfessionalId == profId;

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedProfessionalId = profId;
                                    if (profId == 'todos') {
                                      _isGridView = false;
                                    }
                                  });
                                  _loadAvailability();
                                  _loadAppointments();
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 16),
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
                                                color: isSelected ? accent : Colors.transparent,
                                                width: 2.5,
                                              ),
                                            ),
                                            child: CircleAvatar(
                                              radius: 34,
                                              backgroundColor: isSelected ? accent.withOpacity(0.1) : Colors.grey[100],
                                              child: profId == 'todos'
                                                  ? Icon(Icons.people_outline, color: isSelected ? accent : Colors.grey, size: 28)
                                                  : ClipOval(
                                                      child: avatarUrl != null && avatarUrl.isNotEmpty
                                                          ? Image.network(
                                                              avatarUrl,
                                                              width: 68,
                                                              height: 68,
                                                              fit: BoxFit.cover,
                                                              errorBuilder: (c, e, s) => Icon(Icons.person, color: isSelected ? accent : Colors.grey),
                                                            )
                                                          : Icon(Icons.person, color: isSelected ? accent : Colors.grey),
                                                    ),
                                            ),
                                          ),
                                          if (isSelected)
                                            Positioned(
                                              bottom: 0,
                                              right: 0,
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: accent,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: Colors.white, width: 2),
                                                ),
                                                child: const Icon(
                                                  Icons.check,
                                                  color: Colors.white,
                                                  size: 12,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        profId == 'todos' ? 'Todos' : profName.split(' ')[0],
                                        style: GoogleFonts.playfairDisplay(
                                          fontSize: 14,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                          color: primaryGreen,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        profId == 'todos' ? 'Clínica' : (profCargo ?? 'Profissional'),
                                        style: GoogleFonts.manrope(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: accent,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // --- Filters Row (Status + Views) ---
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildFilterMenu(
                                label: 'Status',
                                currentValue: _selectedStatus.isNotEmpty 
                                    ? _selectedStatus[0].toUpperCase() + _selectedStatus.substring(1)
                                    : 'Todos',
                                options: ['Todos', 'Confirmado', 'Pendente', 'Concluído'],
                                onSelected: (val) {
                                  setState(() => _selectedStatus = val.toLowerCase());
                                  _loadAppointments();
                                },
                              ),
                              if (!_isMonthlyView && _selectedProfessionalId != 'todos')
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: primaryGreen.withOpacity(0.1)),
                                  ),
                                  child: Row(
                                    children: [
                                      _buildToggleButton(
                                        icon: Icons.view_agenda_outlined,
                                        isSelected: !_isGridView,
                                        onTap: () => setState(() => _isGridView = false),
                                      ),
                                      _buildToggleButton(
                                        icon: Icons.grid_view_outlined,
                                        isSelected: _isGridView,
                                        onTap: () => setState(() => _isGridView = true),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (_isMonthlyView) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.calendar_month, color: accent, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Visualização mensal',
                                    style: TextStyle(fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: primaryGreen,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ]


                  ],
                ),
              ),
            ),

            SliverAppBar(
              pinned: true,
              backgroundColor: bgColor,
              automaticallyImplyLeading: false,
              elevation: 0,
              toolbarHeight: 0,
              collapsedHeight: 0,
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(_isMonthlyView ? 10 : 60),
                child: Container(
                  width: double.infinity,
                  color: bgColor,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_isMonthlyView) ...[
                        const SizedBox(height: 4),
                        Text(
                          () {
                            String dateStr = DateFormat("EEEE, dd 'de' MMMM 'de' yyyy", 'pt_BR').format(_selectedDate);
                            return dateStr.split(' ').map((word) {
                              if (word.toLowerCase() == 'de') return 'de';
                              if (word.contains('-')) {
                                return word.split('-').map((part) => 
                                  part.isNotEmpty ? part[0].toUpperCase() + part.substring(1) : ''
                                ).join('-');
                              }
                              return word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '';
                            }).join(' ');
                          }(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen,
                            fontFamily: 'Playfair Display',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: _isLoadingAppts
            ? Center(child: CircularProgressIndicator(color: primaryGreen))
            : _appointments.isEmpty
                ? RefreshIndicator(
                    onRefresh: _loadAppointments,
                    color: primaryGreen,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.5,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_busy, size: 64, color: primaryGreen.withOpacity(0.2)),
                            const SizedBox(height: 16),
                            Text(
                              'Nenhum agendamento para este dia.',
                              style: TextStyle(color: primaryGreen.withOpacity(0.5)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadAppointments,
                    color: primaryGreen,
                    child: _isMonthlyView
                        ? _buildMonthlyGroupedList()
                        : (_isGridView 
                            ? _buildGridView()
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: _appointments.length,
                                itemBuilder: (context, index) {
                                  final appt = _appointments[index];
                                  return _buildAppointmentCard(
                                    appt: appt,
                                    isPast: DateTime.parse(appt['data_hora']).isBefore(DateTime.now()),
                                  );
                                },
                              )),
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/admin/agendamentos/novo').then((_) => _loadAppointments()),
        backgroundColor: accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildDaySelector() {
    final lastDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;

    return SizedBox(
      height: 95,
      child: ListView.builder(
        controller: _dayScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: daysInMonth,
        itemBuilder: (context, index) {
          final day = DateTime(_selectedDate.year, _selectedDate.month, index + 1);
          
          final isSelected = day.year == _selectedDate.year &&
                            day.month == _selectedDate.month &&
                            day.day == _selectedDate.day;

          final dayOfWeek = day.weekday == 7 ? 0 : day.weekday;
          final isClosed = !_clinicAvailableDays.contains(dayOfWeek);
          final isBlocked = _blockedDays.any((d) => 
            d.year == day.year && d.month == day.month && d.day == day.day);

          return GestureDetector(
            onTap: (isClosed || isBlocked) ? null : () {
              setState(() => _selectedDate = day);
              _loadAppointments();
              _scrollToSelectedDay();
            },
            child: _buildDateItem(
              () {
                String dayStr = DateFormat('EEE', 'pt_BR').format(day);
                return dayStr.isNotEmpty ? dayStr[0].toUpperCase() + dayStr.substring(1).toLowerCase() : "";
              }(),
              day.day.toString().padLeft(2, '0'),
              isSelected,
              isBlocked: isBlocked,
              isClosed: isClosed,
            ),
          );
        },
      ),
    );
  }

  Widget _buildFullCalendar() {
    final firstDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final lastDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final startOffset = firstDayOfMonth.weekday % 7;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black26,
                          ),
                        ),
                      ),
                    ))
                .toList(),
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
            itemCount: daysInMonth + startOffset,
            itemBuilder: (context, index) {
              if (index < startOffset) return const SizedBox();
              final dayNum = index - startOffset + 1;
              final day = DateTime(_selectedDate.year, _selectedDate.month, dayNum);
              final isSelected = _selectedDate.day == dayNum;
              
              final dayOfWeek = day.weekday == 7 ? 0 : day.weekday;
              final isClosed = !_clinicAvailableDays.contains(dayOfWeek);
              final isBlocked = _blockedDays.any((d) => 
                d.year == day.year && d.month == day.month && d.day == day.day);
              final isUnavailable = isClosed || isBlocked;
              final isPast = day.isBefore(today);

              return GestureDetector(
                onTap: (isUnavailable || isPast) ? null : () {
                  setState(() {
                    _selectedDate = day;
                    _isCalendarExpanded = false;
                  });
                  _loadAppointments();
                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedDay());
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? accent 
                        : (isUnavailable ? Colors.red.withOpacity(0.05) : Colors.transparent),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected 
                          ? accent 
                          : (isUnavailable ? Colors.red.withOpacity(0.2) : Colors.transparent),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayNum.toString(),
                          style: TextStyle(fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected 
                                ? Colors.white 
                                : (isUnavailable 
                                    ? Colors.red 
                                    : (isPast ? accent.withOpacity(0.4) : Colors.black)),
                          ),
                        ),
                        if (isUnavailable && !isSelected)
                          Icon(Icons.lock_clock, size: 8, color: Colors.red.withOpacity(0.5)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateItem(String day, String number, bool isSelected, {bool isBlocked = false, bool isClosed = false}) {
    final bool isUnavailable = isBlocked || isClosed;
    
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          width: 60,
          height: 68,
          decoration: BoxDecoration(
            color: isSelected 
                ? primaryGreen 
                : (isUnavailable ? Colors.red.withOpacity(0.05) : Colors.white),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: isSelected 
                  ? accent 
                  : (isUnavailable ? Colors.red.withOpacity(0.3) : primaryGreen.withOpacity(0.1)),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accent.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                day,
                style: TextStyle(fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected 
                      ? Colors.white.withOpacity(0.8) 
                      : (isUnavailable ? Colors.red.withOpacity(0.5) : Colors.black38),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                number,
                style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isSelected 
                      ? Colors.white 
                      : (isUnavailable ? Colors.red : Colors.black87),
                ),
              ),
            ],
          ),
        ),
        if (isSelected) 
          Container(
            margin: const EdgeInsets.only(right: 12, top: 4),
            width: 12,
            height: 4,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          )
        else if (isUnavailable)
          Container(
            margin: const EdgeInsets.only(right: 12, top: 4),
            child: Icon(Icons.lock_clock, size: 10, color: Colors.red.withOpacity(0.5)),
          ),
      ],
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? Colors.white : primaryGreen.withOpacity(0.4),
        ),
      ),
    );
  }

  Widget _buildGridView() {
    final double hourHeight = _getOptimalHourHeight();
    const int startHour = 8;
    const int endHour = 21;
    final int totalHours = endHour - startHour;
    final double totalHeight = (totalHours + 1) * hourHeight;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(), // Garante que interaja com NestedScrollView
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: SizedBox(
        height: totalHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Coluna de Horários com altura explícita
            SizedBox(
              width: 70,
              height: totalHeight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate((totalHours + 1) * 2, (index) {
                  final hour = startHour + (index ~/ 2);
                  final isHalfHour = index % 2 != 0;
                  
                  // Don't show the last :30 if it exceeds our range significantly
                  if (hour == endHour && isHalfHour) return const SizedBox.shrink();

                  return Container(
                    height: hourHeight / 2,
                    width: 70,
                    alignment: Alignment.topCenter,
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      isHalfHour 
                        ? '${hour.toString().padLeft(2, '0')}:30' 
                        : '${hour.toString().padLeft(2, '0')}:00',
                      style: TextStyle(
                        fontSize: isHalfHour ? 11 : 14,
                        fontWeight: isHalfHour ? FontWeight.w500 : FontWeight.bold,
                        color: isHalfHour ? primaryGreen.withOpacity(0.5) : primaryGreen,
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Grade de Agendamentos com altura explícita
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SizedBox(
                    height: totalHeight,
                    child: Stack(
                      children: [
                        // Linhas de Fundo
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate((totalHours + 1) * 2, (index) {
                            final isHalfHour = index % 2 != 0;
                            return Container(
                              height: hourHeight / 2,
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: isHalfHour 
                                        ? primaryGreen.withOpacity(0.02) 
                                        : primaryGreen.withOpacity(0.06),
                                    width: isHalfHour ? 0.5 : 1,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),

                        // Cards de Agendamentos com lógica de sobreposição
                        ..._buildContinuousAppointmentCards(hourHeight, startHour, constraints.maxWidth),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContinuousAppointmentCards(double hourHeight, int startHour, double maxWidth) {
    // Filtrar apenas pendentes, confirmados e concluídos para a grade
    final filteredAppts = _appointments.where((appt) {
      final status = appt['status'] ?? 'pendente';
      return status == 'pendente' || status == 'confirmado' || status == 'concluido';
    }).toList();

    if (filteredAppts.isEmpty) return [];

    // 1. Sort by start time and then by duration (longer first)
    final List<Map<String, dynamic>> sortedAppts = List.from(filteredAppts);
    sortedAppts.sort((a, b) {
      final startA = DateTime.parse(a['data_hora']).toLocal();
      final startB = DateTime.parse(b['data_hora']).toLocal();
      int compare = startA.compareTo(startB);
      if (compare == 0) {
        final durA = a['servicos']?['duracao_minutos'] ?? 60;
        final durB = b['servicos']?['duracao_minutos'] ?? 60;
        return durB.compareTo(durA);
      }
      return compare;
    });

    // 2. Cluster overlapping appointments
    final List<List<Map<String, dynamic>>> clusters = [];
    if (sortedAppts.isNotEmpty) {
      List<Map<String, dynamic>> currentCluster = [sortedAppts[0]];
      DateTime clusterEnd = _getEnd(sortedAppts[0]);
      
      for (int i = 1; i < sortedAppts.length; i++) {
        final appt = sortedAppts[i];
        final start = DateTime.parse(appt['data_hora']).toLocal();
        
        if (start.isBefore(clusterEnd)) {
          // Overlaps with current cluster
          currentCluster.add(appt);
          final end = _getEnd(appt);
          // Buffer visual de 35 min para detectar sobreposição que o math.max(90) causaria
          final visualEnd = start.add(const Duration(minutes: 35));
          if (end.isAfter(clusterEnd)) clusterEnd = end;
          if (visualEnd.isAfter(clusterEnd)) clusterEnd = visualEnd;
        } else {
          // New cluster
          clusters.add(currentCluster);
          currentCluster = [appt];
          clusterEnd = _getEnd(appt);
        }
      }
      clusters.add(currentCluster);
    }

    final List<Widget> widgets = [];

      // 3. Process each cluster
    for (final cluster in clusters) {
      final List<List<Map<String, dynamic>>> columns = [];
      final Map<Map<String, dynamic>, int> apptToColumn = {};

      for (final appt in cluster) {
        final start = DateTime.parse(appt['data_hora']).toLocal();
        final end = _getEnd(appt);

        int colIdx = -1;
        for (int i = 0; i < columns.length; i++) {
          bool overlaps = false;
          for (final other in columns[i]) {
            final otherStart = DateTime.parse(other['data_hora']).toLocal();
            final otherEnd = _getEnd(other);
            
            // Usamos um buffer de tempo maior para detectar sobreposições "visuais"
            // Se o card tem altura mínima de 90px, ele ocupa cerca de (90/hourHeight)*60 minutos
            final minVisualMinutes = (90.0 / hourHeight) * 60;
            final visualEndOther = otherStart.add(Duration(minutes: minVisualMinutes.toInt()));
            final effectiveEndOther = otherEnd.isAfter(visualEndOther) ? otherEnd : visualEndOther;
            
            final visualEndStart = start.add(Duration(minutes: minVisualMinutes.toInt()));
            final effectiveEndStart = end.isAfter(visualEndStart) ? end : visualEndStart;

            if (start.isBefore(effectiveEndOther) && effectiveEndStart.isAfter(otherStart)) {
              overlaps = true;
              break;
            }
          }
          if (!overlaps) {
            colIdx = i;
            break;
          }
        }

        if (colIdx == -1) {
          colIdx = columns.length;
          columns.add([appt]);
        } else {
          columns[colIdx].add(appt);
        }
        apptToColumn[appt] = colIdx;
      }

      final int totalColsInCluster = columns.length;
      // Define a largura baseada no número de colunas, dividindo o espaço igualmente
      final double clusterColWidth = (maxWidth - 10) / totalColsInCluster;

      for (final appt in cluster) {
        final start = DateTime.parse(appt['data_hora']).toLocal();
        final duration = appt['servicos']?['duracao_minutos'] ?? 60;
        
        final hourOffset = start.hour - startHour + (start.minute / 60.0);
        final top = hourOffset * hourHeight;
        final height = (duration / 60.0) * hourHeight;

        final colIdx = apptToColumn[appt] ?? 0;
        final left = colIdx * clusterColWidth;

        widgets.add(
          Positioned(
            top: top,
            left: left,
            width: clusterColWidth - 4, // Pequeno espaçamento entre cards laterais
            height: math.max(height, 120.0), // Aumentado de 100 para 120 para evitar overflow
            child: _buildAppointmentCard(
              appt: appt,
              isPast: start.isBefore(DateTime.now()),
              compact: true,
              isContinuation: false,
              useFullHeight: true,
            ),
          ),
        );
      }
    }

    return widgets;
  }

  double _getOptimalHourHeight() {
    if (_appointments.isEmpty) return 160.0;
    
    // Contar agendamentos por hora para determinar densidade
    final Map<int, int> counts = {};
    for (final appt in _appointments) {
      try {
        final start = DateTime.parse(appt['data_hora']).toLocal();
        counts[start.hour] = (counts[start.hour] ?? 0) + 1;
      } catch (_) {}
    }
    
    int maxDensity = 0;
    for (final count in counts.values) {
      if (count > maxDensity) maxDensity = count;
    }

    // Se tiver muitos agendamentos no mesmo horário (ex: sessões curtas de 20 min),
    // precisamos de mais espaço vertical para que os cards (mínimo 90px) não se sobreponham.
    if (maxDensity >= 3) return 300.0;
    if (maxDensity >= 2) return 240.0;
    
    return 160.0;
  }

  DateTime _getEnd(Map<String, dynamic> appt) {
    final start = DateTime.parse(appt['data_hora']).toLocal();
    final duration = appt['servicos']?['duracao_minutos'] ?? 60;
    return start.add(Duration(minutes: duration));
  }

  Widget _buildFilterMenu({
    required String label,
    required String currentValue,
    required List<String> options,
    required Function(String) onSelected,
  }) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => options.map((option) {
        final bool isSelected = currentValue == option || (currentValue == 'Todos' && option == 'Todos');
        return PopupMenuItem<String>(
          value: option,
          child: Row(
            children: [
              Text(
                option,
                style: TextStyle(fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? primaryGreen : Colors.black87,
                ),
              ),
              if (isSelected) ...[
                const Spacer(),
                Icon(Icons.check, size: 16, color: primaryGreen),
              ],
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryGreen.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ',
              style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
            Text(
              currentValue,
              style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.bold,
                color: primaryGreen,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 16, color: primaryGreen),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentCard({
    required Map<String, dynamic> appt,
    required bool isPast,
    bool compact = false,
    bool isContinuation = false,
    bool useFullHeight = false,
  }) {
    final clientId = appt['perfis']?['id']?.toString() ?? '';
    final date = DateTime.parse(appt['data_hora']).toLocal();
    final time = DateFormat('HH:mm').format(date);
    final clientName = appt['perfis']?['nome_completo'] ?? 'Cliente';
    final service = appt['servicos']?['nome'] ?? 'Serviço';
    final staff = appt['profissional']?['nome_completo'] ?? 'Profissional';
    final status = appt['status'] ?? 'pendente';

    Color statusColor = Colors.grey;
    if (status == 'concluido' || status == 'confirmado') statusColor = primaryGreen;
    if (status == 'cancelado') statusColor = Colors.red;
    if (status == 'pendente') statusColor = accent;
    if (status == 'no_show') statusColor = Colors.deepOrange;

    return Container(
      margin: EdgeInsets.only(bottom: useFullHeight ? 0 : 12),
      padding: EdgeInsets.only(
        left: compact ? 12 : 16,
        right: compact ? 12 : 20,
        top: compact ? 6 : 16,
        bottom: compact ? 6 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: compact ? Border.all(color: primaryGreen.withOpacity(0.1)) : null,
      ),
      child: compact
          // ═══ MODO GRID: Status → Procedimento → Infos | ⋮ ═══
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. STATUS
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                status == 'no_show'
                                    ? Icons.person_off
                                    : (status == 'cancelado'
                                        ? Icons.cancel
                                        : (status == 'concluido' || status == 'confirmado'
                                            ? Icons.check_circle
                                            : Icons.schedule)),
                                size: 10,
                                color: statusColor,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  status == 'no_show'
                                      ? 'NO-SHOW'
                                      : (appt['pago'] == true && status != 'no_show'
                                          ? 'PAGO - ${status.toUpperCase()}'
                                          : status.toUpperCase()),
                                  style: TextStyle(fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                    letterSpacing: 0.6,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // 2. PROCEDIMENTO
                      Text(
                        service.toUpperCase(),
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: primaryGreen,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (appt['pacote_contratado_id'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${appt['pacote']?['template']?['titulo'] ?? 'Pacote'}',
                          style: TextStyle(fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: accent,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Sessão ${appt['sessao_numero']} de ${appt['pacote']?['sessoes_totais'] ?? '?' }',
                          style: TextStyle(fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      // 3. HORARIO
                      Builder(builder: (context) {
                        final endTime = _getEnd(appt);
                        return Text(
                          '$time ― ${DateFormat('HH:mm').format(endTime)}',
                          style: TextStyle(fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen.withOpacity(0.8),
                          ),
                        );
                      }),
                      const SizedBox(height: 5),
                      // 4. PROFISSIONAL
                      Text(
                        staff,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: accent.withOpacity(0.8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      // 5. CLIENTE
                      Text(
                        clientName,
                        style: TextStyle(fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 2),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.black26, size: 18),
                  onSelected: (value) {
                    if (value == 'alterar') {
                      _rescheduleAppointment(appt);
                    } else if (value == 'switch_prof') {
                      _switchProfessional(appt);
                    } else if (value == 'ver_cliente') {
                      context.push('/admin/clientes/$clientId', extra: clientName);
                    } else if (value == 'nao_pago') {
                      _marcarComoNaoPago(appt);
                    } else {
                      _updateStatus(appt, value);
                    }
                  },
                  itemBuilder: (context) {
                    // isEditable if it belongs to current active cashier (even if concluded)
                    final isEditable = appt['caixa_id']?.toString() == _activeCaixaId;
                    return [
                      if (!isPast) ...[
                        if (status != 'concluido')
                          const PopupMenuItem(value: 'concluido', child: Text('Concluir')),
                        const PopupMenuItem(value: 'confirmado', child: Text('Confirmar')),
                        const PopupMenuItem(value: 'alterar', child: Text('Alterar')),
                        const PopupMenuItem(value: 'switch_prof', child: Text('Trocar Profissional')),
                        const PopupMenuItem(value: 'cancelado', child: Text('Cancelar')),
                        if (appt['pago'] != true) ...[
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'pagar',
                            child: Row(children: [
                              Icon(Icons.attach_money, size: 18, color: primaryGreen),
                              const SizedBox(width: 8),
                              const Text('Lançar Pagamento'),
                            ]),
                          ),
                        ],
                        if (isEditable && appt['pago'] == true) ...[
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'pagar',
                            child: Row(children: [
                              Icon(Icons.edit_outlined, size: 18, color: accent),
                              const SizedBox(width: 8),
                              const Text('Editar Pagamento'),
                            ]),
                          ),
                          PopupMenuItem(
                            value: 'nao_pago',
                            child: Row(children: [
                              Icon(Icons.money_off, size: 18, color: Colors.red),
                              const SizedBox(width: 8),
                              const Text('Não Pago (Excluir)'),
                            ]),
                          ),
                        ],
                        const PopupMenuDivider(),
                      ],
                      if (isPast && (status != 'concluido' || isEditable || appt['pago'] != true) && status != 'cancelado' && status != 'no_show') ...[
                        if (appt['pago'] != true) ...[
                          PopupMenuItem(
                            value: 'pagar',
                            child: Row(
                              children: [
                                Icon(Icons.payments_outlined, color: primaryGreen, size: 20),
                                const SizedBox(width: 12),
                                const Text('Lançar Pagamento'),
                              ],
                            ),
                          ),
                        ],
                        if (isEditable && appt['pago'] == true) ...[
                          PopupMenuItem(
                            value: 'pagar',
                            child: Row(
                              children: [
                                Icon(Icons.edit_note, color: accent, size: 20),
                                const SizedBox(width: 12),
                                const Text('Editar Pagamento'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'nao_pago',
                            child: Row(
                              children: [
                                const Icon(Icons.money_off, color: Colors.red, size: 20),
                                const SizedBox(width: 12),
                                const Text('Não Pago'),
                              ],
                            ),
                          ),
                        ],
                        if (status != 'concluido') ...[
                          PopupMenuItem(
                            value: 'concluido',
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                                const SizedBox(width: 12),
                                const Text('Concluir'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'no_show',
                            child: Row(
                              children: [
                                const Icon(Icons.person_off_outlined, color: Colors.orange, size: 20),
                                const SizedBox(width: 12),
                                const Text('No-show'),
                              ],
                            ),
                          ),
                        ],
                        const PopupMenuDivider(),
                      ],
                      PopupMenuItem(
                        value: 'ver_cliente',
                        child: Row(children: [
                          Icon(Icons.person_outline, size: 18, color: primaryGreen),
                          const SizedBox(width: 8),
                          const Text('Ver dados do cliente'),
                        ]),
                      ),
                    ];
                  },
                ),
              ],
            )
          // ═══ MODO LISTA: layout original ═══
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: TextStyle(fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                      ),
                    ),
                    Builder(builder: (context) {
                      final duration = appt['servicos']?['duracao_minutos'] ?? 60;
                      final endTime = date.add(Duration(minutes: duration));
                      return Text(
                        DateFormat('HH:mm').format(endTime),
                        style: TextStyle(fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: primaryGreen,
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. STATUS
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              status == 'no_show'
                                  ? Icons.person_off
                                  : (status == 'cancelado'
                                      ? Icons.cancel
                                      : (status == 'concluido' || status == 'confirmado'
                                          ? Icons.check_circle
                                          : Icons.info)),
                              size: 12,
                              color: statusColor,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                status == 'no_show'
                                    ? 'NO-SHOW'
                                    : (appt['pago'] == true && status != 'no_show'
                                        ? 'PAGO - ${status.toUpperCase()}'
                                        : status.toUpperCase()),
                                style: TextStyle(fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                  letterSpacing: 0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        service.toUpperCase(),
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryGreen,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (appt['pacote_contratado_id'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${appt['pacote']?['template']?['titulo'] ?? 'Pacote'} - Sessão ${appt['sessao_numero']} de ${appt['pacote']?['sessoes_totais'] ?? '?' }',
                          style: TextStyle(fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: accent,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      // 3. CLIENTE
                      Text(
                        clientName,
                        style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // 4. PROFISSIONAL
                      if (appt['profissional'] != null && appt['profissional']['nome_completo'] != null) ...[
                        Text(
                          appt['profissional']['nome_completo'].toString(),
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: accent.withOpacity(0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.black26, size: 24),
            onSelected: (value) {
              if (value == 'alterar') {
                _rescheduleAppointment(appt);
              } else if (value == 'switch_prof') {
                _switchProfessional(appt);
              } else if (value == 'ver_cliente') {
                context.push('/admin/clientes/$clientId', extra: clientName);
              } else if (value == 'nao_pago') {
                _marcarComoNaoPago(appt);
              } else {
                _updateStatus(appt, value);
              }
            },
            itemBuilder: (context) {
              final isEditable = appt['pago'] == true && appt['caixa_id']?.toString() == _activeCaixaId;

              return [
                if (!isPast) ...[
                  if (status != 'concluido')
                    const PopupMenuItem(value: 'concluido', child: Text('Concluir')),
                  
                  const PopupMenuItem(value: 'confirmado', child: Text('Confirmar')),
                  const PopupMenuItem(value: 'alterar', child: Text('Alterar')),
                  const PopupMenuItem(value: 'switch_prof', child: Text('Trocar Profissional')),
                  const PopupMenuItem(value: 'cancelado', child: Text('Cancelar')),
                  
                  if (appt['pago'] != true && status != 'concluido') ...[
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'pagar',
                      child: Row(
                        children: [
                          Icon(Icons.attach_money, size: 18, color: primaryGreen),
                          const SizedBox(width: 8),
                          const Text('Lançar Pagamento'),
                        ],
                      ),
                    ),
                  ],
                  if (isEditable) ...[
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'pagar',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: accent),
                          const SizedBox(width: 8),
                          const Text('Editar Pagamento'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'nao_pago',
                      child: Row(
                        children: [
                          Icon(Icons.money_off, size: 18, color: Colors.red),
                          const SizedBox(width: 8),
                          const Text('Não Pago (Excluir)'),
                        ],
                      ),
                    ),
                  ],
                  const PopupMenuDivider(),
                ],
                if (isPast && status != 'concluido' && status != 'cancelado' && status != 'no_show') ...[
                  if (appt['pago'] != true) ...[
                    PopupMenuItem(
                      value: 'pagar',
                      child: Row(
                        children: [
                          Icon(Icons.attach_money, size: 18, color: primaryGreen),
                          const SizedBox(width: 8),
                          const Text('Lançar Pagamento'),
                        ],
                      ),
                    ),
                  ],
                  if (isEditable) ...[
                    PopupMenuItem(
                      value: 'pagar',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: accent),
                          const SizedBox(width: 8),
                          const Text('Editar Pagamento'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'nao_pago',
                      child: Row(
                        children: [
                          Icon(Icons.money_off, size: 18, color: Colors.red),
                          const SizedBox(width: 8),
                          const Text('Não Pago (Excluir)'),
                        ],
                      ),
                    ),
                  ],
                  PopupMenuItem(
                    value: 'concluido',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, size: 18, color: primaryGreen),
                        const SizedBox(width: 8),
                        const Text('Concluir'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'no_show',
                    child: Row(
                      children: [
                        Icon(Icons.person_off_outlined, size: 18, color: Colors.deepOrange),
                        const SizedBox(width: 8),
                        const Text('No-show (Não compareceu)'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                ],
                PopupMenuItem(
                  value: 'ver_cliente',
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, size: 18, color: primaryGreen),
                      const SizedBox(width: 8),
                      const Text('Ver dados do cliente'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _showPaymentDialog(Map<String, dynamic> appointment) async {
    double valor = (appointment['valor_total'] as num?)?.toDouble() ?? 
                   (appointment['servicos']?['preco'] as num?)?.toDouble() ?? 0;
    String formaPagamento = appointment['forma_pagamento'] ?? 'dinheiro';
    int parcelas = appointment['parcelas'] ?? 1;
    String? convenioNome = appointment['convenio_nome'];
    final valorController = TextEditingController(text: valor.toStringAsFixed(2).replaceAll('.', ','));
    final convenioController = TextEditingController(text: convenioNome);
    final observacoesController = TextEditingController(text: appointment['observacoes'] ?? '');

    return await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Finalizar Atendimento', style: TextStyle(fontWeight: FontWeight.bold, color: primaryGreen)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Confirme os dados do pagamento:', style: TextStyle(fontSize: 14, color: Colors.black54)),
                const SizedBox(height: 20),
                TextField(
                  controller: valorController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Valor Total',
                    prefixText: 'R\$ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Forma de Pagamento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: formaPagamento,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'dinheiro', child: Text('Dinheiro')),
                    DropdownMenuItem(value: 'pix', child: Text('PIX')),
                    DropdownMenuItem(value: 'cartao_credito', child: Text('Cartão de Crédito')),
                    DropdownMenuItem(value: 'cartao_debito', child: Text('Cartão de Débito')),
                    DropdownMenuItem(value: 'convenio', child: Text('Convênio')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      formaPagamento = val!;
                      if (formaPagamento != 'cartao_credito') {
                        parcelas = 1;
                      }
                    });
                  },
                ),
                if (formaPagamento == 'cartao_credito') ...[
                  const SizedBox(height: 20),
                  Text('Parcelamento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: parcelas,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items: List.generate(18, (index) => index + 1)
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(p == 1 ? 'À Vista (1x)' : 'Parcelado ($p x)'),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => parcelas = val!),
                  ),
                ],
                if (formaPagamento == 'convenio') ...[
                  const SizedBox(height: 20),
                  TextField(
                    controller: convenioController,
                    decoration: InputDecoration(
                      labelText: 'Nome do Convênio',
                      hintText: 'Ex: Unimed, Amil...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                TextField(
                  controller: observacoesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Observações',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar', 
                style: TextStyle(color: accent, 
                  fontWeight: FontWeight.bold,
                )
              ),
            ),
              ElevatedButton(
                onPressed: () {
                  final double finalValor = double.tryParse(valorController.text.replaceAll(',', '.')) ?? valor;
                  Navigator.pop(context, {
                    'valor_total': finalValor,
                    'forma_pagamento': formaPagamento,
                    'parcelas': parcelas,
                    'convenio_nome': formaPagamento == 'convenio' ? convenioController.text : null,
                    'observacoes': observacoesController.text,
                  });
                },
                style: AppButtonStyles.primary(),
                child: Text(StringUtils.toTitleCase('confirmar e finalizar')),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _marcarComoNaoPago(Map<String, dynamic> appointment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar Alteração', style: TextStyle(fontWeight: FontWeight.bold, color: primaryGreen)),
        content: const Text('Deseja realmente marcar este agendamento como NÃO PAGO? Isso removerá o registro financeiro.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar', 
              style: TextStyle(color: accent, 
                fontWeight: FontWeight.bold,
              )
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isUpdatingStatus = true);
    try {
      // 1. Atualizar agendamento no Supabase
      await _supabase.from('agendamentos').update({
        'pago': false,
        'caixa_id': null,
        'forma_pagamento': null,
        'valor_total': appointment['servicos']?['preco'], // Volta pro preço original se quiser, ou mantém o que tava
        'data_pagamento': null,
        'parcelas': 1,
        'convenio_nome': null,
        'valor_comissao': 0,
      }).eq('id', appointment['id']);

      // 2. Notificar Admin
      final clientName = appointment['perfis']?['nome_completo'] ?? 'Cliente';
      final serviceName = appointment['servicos']?['nome'] ?? 'procedimento';
      final dateStr = DateFormat('dd/MM').format(DateTime.parse(appointment['data_hora']).toLocal());
      
      await _notificationRepo.notifyAllAdmins(
        titulo: 'Pagamento Estornado (Não Pago)',
        mensagem: 'O agendamento de $clientName ($serviceName) em $dateStr foi marcado como NÃO PAGO pelo administrador.',
        tipo: 'status_change',
      );

      // 3. Notificar Usuário
      final userNotification = NotificationModel(
        userId: appointment['cliente_id'],
        titulo: 'Status de Pagamento Alterado',
        mensagem: 'Seu pagamento para o serviço $serviceName em $dateStr foi alterado para pendente/não pago. Entre em contato para mais detalhes.',
        tipo: 'status_change',
        isLida: false,
        dataCriacao: DateTime.now(),
      );
      await _notificationRepo.saveNotification(userNotification);

      await _loadAppointments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agendamento marcado como NÃO PAGO'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint('Erro ao marcar como não pago: $e');
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _switchProfessional(Map<String, dynamic> appt) async {
    try {
      final serviceId = appt['servicos']?['id']?.toString() ?? appt['servico_id']?.toString();
      final currentProfId = appt['profissional_id'].toString();
      final apptDateTime = DateTime.parse(appt['data_hora']).toLocal();
      final duration = appt['servicos']?['duracao_minutos'] ?? 60;

      if (serviceId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro: ID do serviço não encontrado.')),
          );
          return;
      }

      // 1. Carregar profissionais que fazem o serviço
      final allProfsForService = await _professionalRepo.getProfessionalsByService(serviceId);
      final otherProfs = allProfsForService.where((p) => p.id != currentProfId).toList();

      if (otherProfs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não há outros profissionais cadastrados para este serviço.')),
          );
        }
        return;
      }

      if (!mounted) return;

      // 2. Mostrar Diálogo de Seleção
      final selectedProf = await showDialog<ProfessionalModel>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Trocar Profissional', style: TextStyle(fontWeight: FontWeight.bold, color: primaryGreen)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: otherProfs.length,
              itemBuilder: (context, index) {
                final prof = otherProfs[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: primaryGreen.withOpacity(0.1),
                    child: Icon(Icons.person, color: primaryGreen),
                  ),
                  title: Text(prof.nome, style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.pop(context, prof),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ],
        ),
      );

      if (selectedProf == null) return;

      // 3. Verificar Disponibilidade
      final isAvailable = await _professionalRepo.checkProfessionalAvailability(
        profId: selectedProf.id,
        startDateTime: apptDateTime,
        durationMinutes: duration,
      );

      if (!isAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('O profissional ${selectedProf.nome} não tem agenda livre neste horário.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      // 4. Confirmar Troca
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar Troca'),
          content: Text('Deseja realmente trocar para o profissional ${selectedProf.nome}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Não')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: AppButtonStyles.primary(),
              child: Text(StringUtils.toTitleCase('sim, trocar')),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // 5. Atualizar no Banco
      await _supabase.from('agendamentos').update({
        'profissional_id': selectedProf.id,
      }).eq('id', appt['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profissional alterado com sucesso!'), backgroundColor: Color(0xFF2D5A46)),
        );
        _loadAppointments();
      }
    } catch (e) {
      debugPrint('Erro ao trocar profissional: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao realizar a troca. Tente novamente.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }
  Widget _buildMonthlyGroupedList() {
    if (_appointments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_month_outlined, size: 64, color: accent.withOpacity(0.15)),
              const SizedBox(height: 16),
              Text(
                'Nenhum agendamento encontrado no período',
                style: TextStyle(fontSize: 16,
                  color: Colors.black45,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Agrupar por data
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var appt in _appointments) {
      final date = DateTime.parse(appt['data_hora']).toLocal();
      final key = DateFormat('yyyy-MM-dd').format(date);
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(appt);
    }

    final sortedKeys = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final dateKey = sortedKeys[index];
        final dayAppts = grouped[dateKey]!;
        final firstApptDate = DateTime.parse(dayAppts.first['data_hora']).toLocal();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: accent.withOpacity(0.2), width: 1)),
                ),
                child: Row(
                  children: [
                    Text(
                      DateFormat("EEEE, dd 'de' MMMM 'de' yyyy", 'pt_BR')
                          .format(firstApptDate)
                          .toLowerCase(),
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ...dayAppts.map((appt) => _buildAppointmentCard(
              appt: appt,
              isPast: DateTime.parse(appt['data_hora']).isBefore(DateTime.now()),
            )),
          ],
        );
      },
    );
  }
}



