import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import 'package:app_clinica_estetica/features/auth/data/auth_service.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_professional_repository.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_notification_repository.dart';
import 'package:app_clinica_estetica/core/data/models/notification_model.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_caixa_repository.dart';
import 'package:app_clinica_estetica/core/data/models/professional_model.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_clinica_estetica/features/admin/presentation/widgets/admin_reagendamento_modal.dart';
import 'package:app_clinica_estetica/features/profissional/presentation/pages/shell/profissional_shell_page.dart';
import 'package:app_clinica_estetica/features/profissional/presentation/widgets/profissional_app_bar.dart';
import 'package:app_clinica_estetica/features/profissional/presentation/widgets/profissional_bottom_nav_bar.dart';

class ProfissionalAgendaPage extends StatefulWidget {
  const ProfissionalAgendaPage({super.key});

  @override
  State<ProfissionalAgendaPage> createState() => _ProfissionalAgendaPageState();
}

class _ProfissionalAgendaPageState extends State<ProfissionalAgendaPage> {
  final _supabase = Supabase.instance.client;
  final _notificationRepo = SupabaseNotificationRepository();
  final _caixaRepo = SupabaseCaixaRepository();
  final ScrollController _dayScrollController = ScrollController();
  DateTime _selectedDate = DateTime.now();
  String _selectedStatus = 'todos';

  List<Map<String, dynamic>> _appointments = [];
  bool _isLoadingAppts = true;
  bool _isCalendarExpanded = false;
  bool _isGridView =
      true; // Iniciamos em modo grid por padrão conforme solicitado
  bool _isMonthlyView = false;
  String? _activeCaixaId;

  // Novos estados para Almoço e Bloqueios
  final _profRepo = SupabaseProfessionalRepository();
  Map<String, TimeOfDay>? _lunchTime;
  List<Map<String, dynamic>> _agendaBlocks = [];
  Set<int> _clinicAvailableDays = {};
  List<DateTime> _blockedDays = [];

  final Color primaryGreen = AppColors.primary;
  final Color accent = AppColors.accent;
  final Color bgColor = AppColors.background;
  final Color goldColor = const Color(0xFFC7A36B);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    // Escuta por pedidos de atualização vindos do Shell
    ProfissionalShellPage.refreshNotifier.addListener(_loadAppointments);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedDay());
  }

  @override
  void dispose() {
    ProfissionalShellPage.refreshNotifier.removeListener(_loadAppointments);
    _dayScrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedDay() {
    if (_dayScrollController.hasClients) {
      final double screenWidth = MediaQuery.of(context).size.width;
      const double itemWidth = 72.0; // 60 width + 12 margin
      final double targetOffset =
          ((_selectedDate.day - 1) * itemWidth) -
          (screenWidth / 2) +
          (itemWidth / 2);

      _dayScrollController.animateTo(
        targetOffset.clamp(0.0, _dayScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _loadInitialData() async {
    await Future.wait([_loadAppointments(), _loadAvailabilityData()]);
  }

  Future<void> _loadAvailabilityData() async {
    try {
      final professionalId = AuthService.currentUserId;
      if (professionalId == null) return;

      final clinicDays = await _profRepo.getClinicAvailabilityDays();
      final monthlyBlocks = await _profRepo.getMonthlyBlocks(
        professionalId,
        _selectedDate.year,
        _selectedDate.month,
      );

      if (mounted) {
        setState(() {
          _clinicAvailableDays = clinicDays.toSet();
          _blockedDays = monthlyBlocks
              .map((b) => DateTime.parse(b['data']))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados de disponibilidade: $e');
    }
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoadingAppts = true);
    try {
      final professionalId = AuthService.currentUserId;
      if (professionalId == null) return;

      // Carregar caixa ativo
      final activeCaixa = await _caixaRepo.getActiveCaixa();
      _activeCaixaId = activeCaixa?.id;

      // Carregar Almoço e Bloqueios
      final blocksData = await _profRepo.getProfessionalBlocksAndLunch(
        professionalId,
        _selectedDate,
      );
      _lunchTime = blocksData['lunch'] as Map<String, TimeOfDay>?;
      _agendaBlocks = List<Map<String, dynamic>>.from(blocksData['blocks']);

      final startRange = _isMonthlyView
          ? DateTime(
              _selectedDate.year,
              _selectedDate.month,
              1,
            ).toIso8601String()
          : DateTime(
              _selectedDate.year,
              _selectedDate.month,
              _selectedDate.day,
            ).toIso8601String();
      final endRange = _isMonthlyView
          ? DateTime(
              _selectedDate.year,
              _selectedDate.month + 1,
              0,
              23,
              59,
              59,
            ).toIso8601String()
          : DateTime(
              _selectedDate.year,
              _selectedDate.month,
              _selectedDate.day,
              23,
              59,
              59,
            ).toIso8601String();

      var query = _supabase
          .from('agendamentos')
          .select(
            '*, servicos(nome, duracao_minutos), cliente:perfis!cliente_id(id, nome_completo, avatar_url), profissional:perfis!profissional_id(nome_completo)',
          )
          .eq('profissional_id', professionalId)
          .gte('data_hora', startRange)
          .lte('data_hora', endRange);

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

  bool _isUpdatingStatus = false;

  Future<void> _updateStatus(
    Map<String, dynamic> appointment,
    String newStatus,
  ) async {
    if (_isUpdatingStatus) return;

    final professionalId = AuthService.currentUserId;
    if (professionalId == null) return;

    // Não permitir finalizar se for data futura
    if (newStatus == 'concluido') {
      final DateTime apptDate = DateTime.parse(
        appointment['data_hora'],
      ).toLocal();
      final DateTime now = DateTime.now();
      if (apptDate.isAfter(now)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Não é possível finalizar um agendamento futuro.',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }
    }

    Map<String, dynamic> paymentData = {};
    if (newStatus == 'concluido' || newStatus == 'pagar') {
      final jaEstaPago = appointment['pago'] == true;
      if (newStatus == 'concluido' && jaEstaPago) {
        paymentData = {};
      } else {
        final activeCaixa = await _caixaRepo.getActiveCaixa();
        _activeCaixaId = activeCaixa?.id;
        if (_activeCaixaId == null) {
          _showOpenCaixaDialog();
          return;
        }
        final result = await _showPaymentDialog(appointment);
        if (result == null) return;
        paymentData = result;
      }
    }

    setState(() => _isUpdatingStatus = true);
    try {
      final appointmentId = appointment['id'];
      final profissionalId = appointment['profissional_id'];
      final Map<String, dynamic> updates = {};

      if (newStatus == 'pagar' ||
          (newStatus == 'concluido' && paymentData.isNotEmpty)) {
        final profResponse = await _supabase
            .from('perfis')
            .select('comissao_agendamentos_percentual')
            .eq('id', profissionalId)
            .single();
        final double percentualComissao =
            (profResponse['comissao_agendamentos_percentual'] ?? 0).toDouble();
        final double valorTotal =
            (paymentData['valor_total'] ?? appointment['valor_total'] ?? 0)
                .toDouble();
        final double valorComissao = (valorTotal * percentualComissao) / 100;
        updates['valor_comissao'] = valorComissao;
      }

      if (newStatus == 'pagar') {
        updates.addAll(paymentData);
        updates['pago'] = true;
        if (appointment['pago'] != true)
          updates['data_pagamento'] = DateTime.now().toUtc().toIso8601String();
      } else {
        updates['status'] = newStatus;
        updates.addAll(paymentData);
        if (newStatus == 'concluido' && appointment['pago'] != true) {
          updates['pago'] = true;
          updates['data_pagamento'] = DateTime.now().toUtc().toIso8601String();
        }
      }

      if ((newStatus == 'concluido' || newStatus == 'pagar') &&
          _activeCaixaId != null) {
        updates['caixa_id'] = _activeCaixaId;
      }

      await _supabase
          .from('agendamentos')
          .update(updates)
          .eq('id', appointmentId);

      // Notificações
      final clienteId = appointment['cliente_id'];
      final clientName = appointment['cliente']?['nome_completo'] ?? appointment['perfis']?['nome_completo'] ?? 'Cliente';
      final serviceName = appointment['servicos'] != null
          ? appointment['servicos']['nome']
          : 'procedimento';
      final double valorTotal =
          (updates['valor_total'] ?? appointment['valor_total'] ?? 0)
              .toDouble();
      final valorFormatado = 'R\$ ${valorTotal.toStringAsFixed(2)}';

      String title = 'Status de Agendamento';
      String message =
          'O status do seu agendamento de $serviceName foi atualizado.';
      String notificationType = 'status_change';

      final appointmentDate = DateTime.parse(appointment['data_hora']);
      final dateStr = DateFormat('dd/MM', 'pt_BR').format(appointmentDate);
      final timeStr = DateFormat('HH:mm').format(appointmentDate);

      switch (newStatus) {
        case 'concluido':
          title = 'Atendimento Finalizado';
          message =
              'Seu atendimento de $serviceName em $dateStr às $timeStr foi finalizado. Esperamos que tenha gostado!';
          notificationType = 'concluido';
          break;
        case 'confirmado':
          title = 'Agendamento Confirmado';
          message =
              'Seu agendamento de $serviceName foi confirmado para $dateStr às $timeStr.';
          notificationType = 'confirmado';
          break;
        case 'cancelado':
          title = 'Agendamento Cancelado';
          message =
              'Seu agendamento de $serviceName para $dateStr às $timeStr foi cancelado.';
          notificationType = 'cancelamento';
          break;
        case 'no_show':
          title = 'No-show Registrado';
          message =
              'Registramos que você não compareceu ao agendamento de $serviceName em $dateStr às $timeStr. Entre em contato se houve algum engano.';
          notificationType = 'no_show';
          break;
        case 'pagar':
          title = 'Pagamento Lançado';
          message =
              'O pagamento para o seu atendimento de $serviceName em $dateStr às $timeStr foi registrado. Valor: $valorFormatado.';
          notificationType = 'pagamento';
          break;
      }

      await _notificationRepo.saveNotification(
        NotificationModel(
          userId: clienteId,
          titulo: title,
          mensagem: message,
          tipo: notificationType,
          isLida: false,
          dataCriacao: DateTime.now(),
        ),
      );

      // Notificar Profissional (ele mesmo) sobre a alteração (como log)
      await _notificationRepo.saveNotification(
        NotificationModel(
          userId: AuthService.currentUserId!,
          titulo: 'Alteração Realizada',
          mensagem:
              'Você alterou o status do agendamento de $serviceName ($clientName) para ${newStatus.toUpperCase()}.',
          tipo: 'logger',
          isLida: false,
          dataCriacao: DateTime.now(),
        ),
      );

      await _loadAppointments();
    } catch (e) {
      debugPrint('Erro ao atualizar status: $e');
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
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
            Text(
              'Caixa Fechado',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: primaryGreen,
              ),
            ),
          ],
        ),
        content: Text(
          'O caixa está fechado no momento.\n\nPor favor, solicite ao administrador que realize a abertura do caixa para que seja possível registrar pagamentos.',
          style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Fechar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _marcarComoNaoPago(Map<String, dynamic> appointment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Confirmar Alteração',
          style: TextStyle(fontWeight: FontWeight.bold, color: primaryGreen),
        ),
        content: const Text(
          'Deseja realmente marcar este agendamento como NÃO PAGO? Isso removerá o registro financeiro.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: accent, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isUpdatingStatus = true);
    try {
      await _supabase
          .from('agendamentos')
          .update({
            'pago': false,
            'caixa_id': null,
            'forma_pagamento': null,
            'data_pagamento': null,
            'parcelas': 1,
            'convenio_nome': null,
            'valor_comissao': 0,
          })
          .eq('id', appointment['id']);
      await _loadAppointments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agendamento marcado como NÃO PAGO'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao marcar como não pago: $e');
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<Map<String, dynamic>?> _showPaymentDialog(
    Map<String, dynamic> appointment,
  ) async {
    double valor =
        (appointment['valor_total'] as num?)?.toDouble() ??
        (appointment['servicos']?['preco'] as num?)?.toDouble() ??
        0;
    String formaPagamento = appointment['forma_pagamento'] ?? 'pix';
    int parcelas = appointment['parcelas'] ?? 1;
    String? convenioNome = appointment['convenio_nome'];
    final valorController = TextEditingController(
      text: valor.toStringAsFixed(2).replaceAll('.', ','),
    );
    final convenioController = TextEditingController(text: convenioNome);
    final observacoesController = TextEditingController(
      text: appointment['observacoes'] ?? '',
    );

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Finalizar Atendimento',
            style: TextStyle(fontWeight: FontWeight.bold, color: primaryGreen),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confirme os dados do pagamento:',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: valorController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Valor Total',
                    prefixText: 'R\$ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Forma de Pagamento',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: formaPagamento,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'dinheiro',
                      child: Text('Dinheiro'),
                    ),
                    DropdownMenuItem(value: 'pix', child: Text('PIX')),
                    DropdownMenuItem(
                      value: 'cartao_credito',
                      child: Text('Cartão de Crédito'),
                    ),
                    DropdownMenuItem(
                      value: 'cartao_debito',
                      child: Text('Cartão de Débito'),
                    ),
                    DropdownMenuItem(
                      value: 'convenio',
                      child: Text('Convênio'),
                    ),
                  ],
                  onChanged: (val) {
                    setDialogState(() {
                      formaPagamento = val!;
                      if (formaPagamento != 'cartao_credito') parcelas = 1;
                    });
                  },
                ),
                if (formaPagamento == 'cartao_credito') ...[
                  const SizedBox(height: 20),
                  Text(
                    'Parcelamento',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: parcelas,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                    ),
                    items: List.generate(18, (i) => i + 1)
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(
                              p == 1 ? 'À Vista (1x)' : 'Parcelado ($p x)',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setDialogState(() => parcelas = val!),
                  ),
                ],
                if (formaPagamento == 'convenio') ...[
                  const SizedBox(height: 20),
                  TextField(
                    controller: convenioController,
                    decoration: InputDecoration(
                      labelText: 'Nome do Convênio',
                      hintText: 'Ex: Unimed, Amil...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                TextField(
                  controller: observacoesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Observações',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                splashFactory: NoSplash.splashFactory,
              ),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final double finalValor =
                    double.tryParse(
                      valorController.text.replaceAll(',', '.'),
                    ) ??
                    valor;
                Navigator.pop(context, {
                  'valor_total': finalValor,
                  'forma_pagamento': formaPagamento,
                  'parcelas': parcelas,
                  'convenio_nome': formaPagamento == 'convenio'
                      ? convenioController.text
                      : null,
                  'observacoes': observacoesController.text,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Confirmar e Finalizar'),
            ),
          ],
        ),
      ),
    );
  }

  void _changeMonth(int offset) {
    setState(() {
      DateTime newDate;
      if (offset > 0) {
        // Se estiver no final do mês, vai para o primeiro dia do próximo
        final lastDayOfMonth = DateTime(
          _selectedDate.year,
          _selectedDate.month + 1,
          0,
        ).day;
        if (_selectedDate.day == lastDayOfMonth) {
          newDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
        } else {
          // Caso contrário, tenta manter o dia no próximo mês
          final nextMonth = DateTime(
            _selectedDate.year,
            _selectedDate.month + 1,
            1,
          );
          final lastDayNextMonth = DateTime(
            nextMonth.year,
            nextMonth.month + 1,
            0,
          ).day;
          final newDay = _selectedDate.day > lastDayNextMonth
              ? lastDayNextMonth
              : _selectedDate.day;
          newDate = DateTime(nextMonth.year, nextMonth.month, newDay);
        }
      } else {
        // Se estiver no primeiro dia do mês, vai para o último do anterior
        if (_selectedDate.day == 1) {
          newDate = DateTime(_selectedDate.year, _selectedDate.month, 0);
        } else {
          // Caso contrário, tenta manter o dia no mês anterior
          final prevMonth = DateTime(
            _selectedDate.year,
            _selectedDate.month - 1,
            1,
          );
          final lastDayPrevMonth = DateTime(
            prevMonth.year,
            prevMonth.month + 1,
            0,
          ).day;
          final newDay = _selectedDate.day > lastDayPrevMonth
              ? lastDayPrevMonth
              : _selectedDate.day;
          newDate = DateTime(prevMonth.year, prevMonth.month, newDay);
        }
      }
      _selectedDate = newDate;
    });
    _loadAppointments();
    _loadAvailabilityData();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedDay());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: const ProfissionalAppBar(title: 'Agenda'),
      bottomNavigationBar: const ProfissionalBottomNavigationBar(
        activeIndex: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/profissional/novo-agendamento'),
        backgroundColor: accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Container(
                color: bgColor,
                padding: const EdgeInsets.only(top: 20, bottom: 10),
                child: Column(
                  children: [
                    // --- Navegação de Mês ---
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
                                String formatted = DateFormat(
                                  'MMMM yyyy',
                                  'pt_BR',
                                ).format(_selectedDate);
                                if (formatted.isEmpty) return '';
                                return formatted[0].toUpperCase() +
                                    formatted.substring(1);
                              }(),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: primaryGreen,
                                fontFamily: 'Playfair Display',
                                letterSpacing: -0.5,
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

                    // --- Botão Visualização Mensal ---
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 0),
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _isMonthlyView = !_isMonthlyView;
                            if (_isMonthlyView) _isGridView = false;
                            _loadAppointments();
                          });
                        },
                        icon: Icon(
                          _isMonthlyView
                              ? Icons.calendar_view_day
                              : Icons.calendar_month,
                          color: accent,
                          size: 18,
                        ),
                        label: Text(
                          _isMonthlyView
                              ? 'Visualização Diária'
                              : 'Visualização Mensal',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryGreen,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                    // --- Seletor de dia (apenas no modo diário) ---
                    if (!_isMonthlyView) ...[
                      const SizedBox(height: 10),
                      _buildDaySelector(),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () => setState(
                          () => _isCalendarExpanded = !_isCalendarExpanded,
                        ),
                        icon: Icon(
                          _isCalendarExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.calendar_month,
                          color: primaryGreen,
                        ),
                        label: Text(
                          _isCalendarExpanded
                              ? 'Fechar Calendário'
                              : 'Abrir Calendário',
                          style: TextStyle(color: primaryGreen),
                        ),
                      ),
                      if (_isCalendarExpanded) ...[
                        const SizedBox(height: 10),
                        _buildFullCalendar(),
                      ],
                      const SizedBox(height: 10),
                    ],

                    // --- Filtros: Status + Toggle de Vista ---
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildFilterMenu(
                            label: 'Status',
                            currentValue: _selectedStatus.isNotEmpty
                                ? _selectedStatus[0].toUpperCase() +
                                      _selectedStatus.substring(1)
                                : 'Todos',
                            options: [
                              'Todos',
                              'Confirmado',
                              'Pendente',
                              'Concluído',
                            ],
                            onSelected: (val) {
                              setState(
                                () => _selectedStatus =
                                    val.toLowerCase() == 'concluído'
                                    ? 'concluido'
                                    : val.toLowerCase(),
                              );
                              _loadAppointments();
                            },
                          ),
                          if (!_isMonthlyView)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: primaryGreen.withOpacity(0.1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _buildToggleButton(
                                    icon: Icons.view_agenda_outlined,
                                    isSelected: !_isGridView,
                                    onTap: () =>
                                        setState(() => _isGridView = false),
                                  ),
                                  _buildToggleButton(
                                    icon: Icons.grid_view_outlined,
                                    isSelected: _isGridView,
                                    onTap: () =>
                                        setState(() => _isGridView = true),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_month, color: accent, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Visualização Mensal',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: primaryGreen,
                                letterSpacing: 1.2,
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

            // --- Header Sticky com data ---
            SliverAppBar(
              pinned: true,
              backgroundColor: bgColor,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: false,
              elevation: 0,
              toolbarHeight: 0,
              collapsedHeight: 0,
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(_isMonthlyView ? 0 : 96),
                child: Container(
                  width: double.infinity,
                  color: bgColor,
                  padding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: _isMonthlyView ? 0 : 10,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_isMonthlyView) ...[
                        const SizedBox(height: 4),
                        Text(
                          () {
                            String dateStr = DateFormat(
                              "EEEE, dd 'de' MMMM 'de' yyyy",
                              'pt_BR',
                            ).format(_selectedDate);
                            return dateStr
                                .split(' ')
                                .map((word) {
                                  if (word.toLowerCase() == 'de') return 'de';
                                  if (word.contains('-')) {
                                    return word
                                        .split('-')
                                        .map(
                                          (part) => part.isNotEmpty
                                              ? part[0].toUpperCase() +
                                                    part.substring(1)
                                              : '',
                                        )
                                        .join('-');
                                  }
                                  return word.isNotEmpty
                                      ? word[0].toUpperCase() +
                                            word.substring(1)
                                      : '';
                                })
                                .join(' ');
                          }(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: goldColor,
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
                        Icon(
                          Icons.event_busy,
                          size: 64,
                          color: primaryGreen.withOpacity(0.2),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhum agendamento para este dia.',
                          style: TextStyle(
                            color: primaryGreen.withOpacity(0.5),
                          ),
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
                          : SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  physics: const NeverScrollableScrollPhysics(),
                                  shrinkWrap: true,
                                  itemCount: _appointments.length,
                                  itemBuilder: (context, index) {
                                    final appt = _appointments[index];
                                    return _buildAppointmentCard(appt: appt);
                                  },
                                ),
                              ),
                            )),
              ),
      ),
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

  Widget _buildDaySelector() {
    final daysInMonth = DateTime(
      _selectedDate.year,
      _selectedDate.month + 1,
      0,
    ).day;
    return SizedBox(
      height: 95,
      child: ListView.builder(
        controller: _dayScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: daysInMonth,
        itemBuilder: (context, index) {
          final day = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            index + 1,
          );
          final isSelected =
              day.day == _selectedDate.day && day.month == _selectedDate.month;

          final dayOfWeek = day.weekday == 7 ? 0 : day.weekday;
          final isClosed = !_clinicAvailableDays.contains(dayOfWeek);
          final isBlocked = _blockedDays.any(
            (d) =>
                d.year == day.year && d.month == day.month && d.day == day.day,
          );

          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = day);
              _loadAppointments();
              _scrollToSelectedDay();
            },
            child: _buildDateItem(
              () {
                String dayStr = DateFormat('EEE', 'pt_BR').format(day);
                return dayStr.isNotEmpty
                    ? dayStr[0].toUpperCase() +
                          dayStr.substring(1).toLowerCase()
                    : '';
              }(),
              day.day.toString().padLeft(2, '0'),
              isSelected,
              isClosed: isClosed,
              isBlocked: isBlocked,
            ),
          );
        },
      ),
    );
  }

  Widget _buildFullCalendar() {
    final firstDayOfMonth = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      1,
    );
    final daysInMonth = DateTime(
      _selectedDate.year,
      _selectedDate.month + 1,
      0,
    ).day;
    final startOffset = firstDayOfMonth.weekday % 7;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textLight,
                        ),
                      ),
                    ),
                  ),
                )
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
              final day = DateTime(
                _selectedDate.year,
                _selectedDate.month,
                dayNum,
              );
              final isSelected = _selectedDate.day == dayNum;

              final dayOfWeek = day.weekday == 7 ? 0 : day.weekday;
              final isClosed = !_clinicAvailableDays.contains(dayOfWeek);
              final isBlocked = _blockedDays.any(
                (d) =>
                    d.year == day.year &&
                    d.month == day.month &&
                    d.day == day.day,
              );
              final isUnavailable = isClosed || isBlocked;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = day;
                    _isCalendarExpanded = false;
                  });
                  _loadAppointments();
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _scrollToSelectedDay(),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isUnavailable ? AppColors.error : primaryGreen)
                        : (isUnavailable
                              ? AppColors.error.withOpacity(0.05)
                              : Colors.transparent),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : (isUnavailable
                                ? AppColors.error.withOpacity(0.2)
                                : primaryGreen.withOpacity(0.05)),
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayNum.toString(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? AppColors.white
                                : (isUnavailable
                                      ? AppColors.error.withOpacity(0.5)
                                      : AppColors.textPrimary),
                          ),
                        ),
                        if (isUnavailable && !isSelected)
                          Icon(
                            Icons.lock_clock,
                            size: 8,
                            color: AppColors.error.withOpacity(0.5),
                          ),
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

  Widget _buildDateItem(
    String day,
    String number,
    bool isSelected, {
    bool isBlocked = false,
    bool isClosed = false,
  }) {
    final bool isUnavailable = isBlocked || isClosed;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          width: 60,
          height: 68,
          decoration: BoxDecoration(
            color: isSelected
                ? (isUnavailable ? AppColors.error : primaryGreen)
                : (isUnavailable
                      ? AppColors.error.withOpacity(0.05)
                      : AppColors.white),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: isSelected
                  ? (isUnavailable ? AppColors.error : accent)
                  : (isUnavailable
                        ? AppColors.error.withOpacity(0.3)
                        : primaryGreen.withOpacity(0.1)),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accent.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                day,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? AppColors.white.withOpacity(0.7)
                      : (isUnavailable
                            ? AppColors.error.withOpacity(0.4)
                            : AppColors.textLight),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                number,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? AppColors.white
                      : (isUnavailable
                            ? AppColors.error.withOpacity(0.5)
                            : AppColors.textPrimary),
                ),
              ),
              if (isUnavailable && !isSelected)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.lock_clock,
                    size: 10,
                    color: AppColors.error.withOpacity(0.5),
                  ),
                ),
            ],
          ),
        ),
        if (isSelected)
          Container(
            margin: const EdgeInsets.only(top: 4, right: 12),
            width: 24,
            height: 4,
            decoration: BoxDecoration(
              color: isUnavailable ? AppColors.error : accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }

  Widget _buildGridView() {
    final double hourHeight = _getOptimalHourHeight();
    const int startHour = 8;
    const int endHour = 21;
    final int totalHours = endHour - startHour;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Coluna de Horários
            Column(
              children: List.generate(totalHours + 1, (index) {
                final hour = startHour + index;
                return Container(
                  height: hourHeight,
                  width: 70,
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${hour.toString().padLeft(2, '0')}:00',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }),
            ),

            // Grade de Agendamentos
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      // Linhas de Fundo
                      Column(
                        children: List.generate(totalHours + 1, (index) {
                          return Container(
                            height: hourHeight,
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: primaryGreen.withOpacity(0.05),
                                  width: 1,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),

                      // Almoço (se houver)
                      if (_lunchTime != null)
                        _buildLunchBlock(
                          hourHeight,
                          startHour,
                          constraints.maxWidth,
                        ),

                      // Bloqueios de Agenda
                      ..._buildAgendaBlockCards(
                        hourHeight,
                        startHour,
                        constraints.maxWidth,
                      ),

                      // Cards de Agendamentos
                      ..._buildContinuousAppointmentCards(
                        hourHeight,
                        startHour,
                        constraints.maxWidth,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLunchBlock(double hourHeight, int startHour, double maxWidth) {
    final inicio = _lunchTime!['inicio'] as TimeOfDay;
    final fim = _lunchTime!['fim'] as TimeOfDay;

    final startOffset = inicio.hour - startHour + (inicio.minute / 60.0);
    final durationHours =
        (fim.hour + fim.minute / 60.0) - (inicio.hour + inicio.minute / 60.0);

    if (startOffset < 0) return const SizedBox();

    return Positioned(
      top: startOffset * hourHeight,
      left: 0,
      width: maxWidth,
      height: durationHours * hourHeight,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.restaurant, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                'HORÁRIO DE ALMOÇO',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAgendaBlockCards(
    double hourHeight,
    int startHour,
    double maxWidth,
  ) {
    return _agendaBlocks.map((block) {
      final isDiaTodo = block['dia_todo'] == true;
      double top = 0;
      double height = (21 - 8) * hourHeight;

      if (!isDiaTodo &&
          block['hora_inicio'] != null &&
          block['hora_fim'] != null) {
        final inicioStr = block['hora_inicio'].toString();
        final fimStr = block['hora_fim'].toString();
        final startH = int.parse(inicioStr.split(':')[0]);
        final startM = int.parse(inicioStr.split(':')[1]);
        final endH = int.parse(fimStr.split(':')[0]);
        final endM = int.parse(fimStr.split(':')[1]);

        final startOffset = startH - startHour + (startM / 60.0);
        final endOffset = endH - startHour + (endM / 60.0);
        top = startOffset * hourHeight;
        height = (endOffset - startOffset) * hourHeight;
      }

      return Positioned(
        top: top,
        left: 0,
        width: maxWidth,
        height: height,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withOpacity(0.2), width: 1),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.block, color: Colors.red, size: 24),
                const SizedBox(height: 8),
                Text(
                  'AGENDA FECHADA',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[800],
                    fontSize: 14,
                  ),
                ),
                if (block['motivo'] != null &&
                    block['motivo'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Text(
                      block['motivo'],
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red[600], fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildContinuousAppointmentCards(
    double hourHeight,
    int startHour,
    double maxWidth,
  ) {
    if (_appointments.isEmpty) return [];

    final List<Map<String, dynamic>> sortedAppts = List.from(_appointments);
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

    final List<List<Map<String, dynamic>>> clusters = [];
    if (sortedAppts.isNotEmpty) {
      List<Map<String, dynamic>> currentCluster = [sortedAppts[0]];
      DateTime clusterEnd = _getEnd(
        sortedAppts[0],
      ).add(const Duration(minutes: 5)); // Pequeno buffer de segurança

      for (int i = 1; i < sortedAppts.length; i++) {
        final appt = sortedAppts[i];
        final start = DateTime.parse(appt['data_hora']).toLocal();

        // Se o agendamento atual começa antes do fim do cluster atual, ele pertence a este cluster
        if (start.isBefore(clusterEnd)) {
          currentCluster.add(appt);
          final end = _getEnd(appt).add(const Duration(minutes: 5));
          if (end.isAfter(clusterEnd)) clusterEnd = end;
        } else {
          clusters.add(currentCluster);
          currentCluster = [appt];
          clusterEnd = _getEnd(appt).add(const Duration(minutes: 5));
        }
      }
      clusters.add(currentCluster);
    }

    final List<Widget> widgets = [];

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

            // Buffer visual para considerar que agendamentos muito próximos
            // não devem ficar na mesma coluna para evitar sobreposição visual
            final visualBuffer = const Duration(minutes: 5);
            final effectiveOtherEnd = otherEnd.add(visualBuffer);
            final effectiveStart = start;

            if (effectiveStart.isBefore(effectiveOtherEnd) &&
                end.isAfter(otherStart)) {
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

      final int totalColsInCluster = math.max(1, columns.length);
      final double clusterColWidth = math.max(
        100.0,
        (maxWidth - 10) / totalColsInCluster,
      );

      for (final appt in cluster) {
        final start = DateTime.parse(appt['data_hora']).toLocal();
        final duration = appt['servicos']?['duracao_minutos'] ?? 60;

        final hourOffset = start.hour - startHour + (start.minute / 60.0);
        final top = hourOffset * hourHeight;
        final height = (duration / 60.0) * hourHeight;

        // Usamos 90.0 como altura mínima para agendamentos muito curtos
        final visualHeight = math.max(height, 90.0);

        final colIdx = apptToColumn[appt] ?? 0;
        final left = colIdx * clusterColWidth;

        widgets.add(
          Positioned(
            top: top,
            left: left,
            width: math.max(40.0, clusterColWidth - 4),
            height: math.max(20.0, visualHeight),
            child: _buildAppointmentCard(
              appt: appt,
              compact: true,
              useFullHeight: true,
            ),
          ),
        );
      }
    }

    return widgets;
  }

  double _getOptimalHourHeight() {
    if (_appointments.isEmpty) return 170.0;

    // Contar agendamentos por hora para determinar densidade
    final Map<int, int> counts = {};
    for (final appt in _appointments) {
      try {
        final start = DateTime.parse(appt['data_hora']).toLocal();
        counts[start.hour] = (counts[start.hour] ?? 0) + 1;
      } catch (_) {}
    }

    int maxDensity = 0;
    for (var count in counts.values) {
      if (count > maxDensity) maxDensity = count;
    }

    // Se tiver 3 ou mais no mesmo horário, expande bem (para evitar sobreposição de 20min)
    if (maxDensity >= 3) return 280.0;
    // Se tiver 2 no mesmo horário, expande um pouco (para evitar sobreposição de 30min)
    if (maxDensity >= 2) return 220.0;
    // Caso contrário, mantém compacto
    return 170.0;
  }

  DateTime _getEnd(Map<String, dynamic> appt) {
    final start = DateTime.parse(appt['data_hora']).toLocal();
    final duration = appt['servicos']?['duracao_minutos'] ?? 60;
    return start.add(Duration(minutes: duration));
  }

  Widget _buildAppointmentCard({
    required Map<String, dynamic> appt,
    bool compact = false,
    bool useFullHeight = false,
  }) {
    final date = DateTime.parse(appt['data_hora']).toLocal();
    final time = DateFormat('HH:mm').format(date);
    final duration = appt['servicos']?['duracao_minutos'] ?? 60;
    final endDate = date.add(Duration(minutes: duration));

    // Supabase retorna o join cliente:perfis!cliente_id com chave 'cliente'
    final clientName =
        appt['cliente']?['nome_completo'] ??
        appt['perfis']?['nome_completo'] ??
        '—';
    final service = appt['servicos']?['nome'] ?? 'Serviço';
    final status = appt['status'] ?? 'pendente';
    final isPast = date.isBefore(DateTime.now());

    Color statusColor = AppColors.accent;
    if (status == 'concluido' || status == 'confirmado')
      statusColor = AppColors.success;
    if (status == 'cancelado') statusColor = AppColors.error;
    if (status == 'no_show') statusColor = AppColors.warning;

    return Container(
      margin: EdgeInsets.only(bottom: useFullHeight ? 0 : 12),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 8 : 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: compact
            ? Border.all(color: primaryGreen.withOpacity(0.1))
            : null,
      ),
      child: compact
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
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
                                        : (status == 'concluido' ||
                                                  status == 'confirmado'
                                              ? Icons.check_circle
                                              : Icons.schedule)),
                              size: 10,
                              color: statusColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              status == 'no_show'
                                  ? 'NO-SHOW'
                                  : (appt['pago'] == true && status != 'no_show'
                                        ? 'PAGO - ${status.toUpperCase()}'
                                        : status.toUpperCase()),
                              style: GoogleFonts.manrope(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                      const SizedBox(height: 4),
                      Text(
                        '$time ― ${DateFormat('HH:mm').format(endDate)}',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: primaryGreen.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        clientName,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _buildCardActionMenu(appt, isPast, status, statusColor, true),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      time,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                      ),
                    ),
                    Text(
                      DateFormat('HH:mm').format(endDate),
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: primaryGreen.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
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
                                        : (status == 'concluido' ||
                                                  status == 'confirmado'
                                              ? Icons.check_circle
                                              : Icons.info)),
                              size: 12,
                              color: statusColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              status == 'no_show'
                                  ? 'NO-SHOW'
                                  : (appt['pago'] == true && status != 'no_show'
                                        ? 'PAGO - ${status.toUpperCase()}'
                                        : status.toUpperCase()),
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                                letterSpacing: 0.5,
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
                      const SizedBox(height: 4),
                      Text(
                        clientName,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_isMonthlyView) ...[
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd/MM').format(date),
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: accent,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _buildCardActionMenu(appt, isPast, status, statusColor, false),
              ],
            ),
    );
  }

  Widget _buildCardActionMenu(
    Map<String, dynamic> appt,
    bool isPast,
    String status,
    Color statusColor,
    bool isCompact,
  ) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: AppColors.textLight,
        size: isCompact ? 18 : 24,
      ),
      onSelected: (value) {
        if (value == 'alterar') {
          _showReagendarModal(appt);
        } else if (value == 'ver_cliente') {
          final clientId =
              appt['cliente_id']?.toString() ??
              appt['cliente']?['id']?.toString() ??
              '';
          final clientNameLocal = appt['cliente']?['nome_completo'] ?? appt['perfis']?['nome_completo'] ?? 'Cliente';
          if (clientId.isNotEmpty) {
            context.push(
              '/profissional/clientes/$clientId',
              extra: clientNameLocal,
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ID do cliente não encontrado')),
            );
          }
        } else if (value == 'trocar_profissional') {
          _switchProfessional(appt);
        } else if (value == 'nao_pago') {
          _marcarComoNaoPago(appt);
        } else if (value == 'alterar_status_concluido') {
          _showAlterarStatusConcluidoMenu(appt);
        } else {
          _updateStatus(appt, value);
        }
      },
      itemBuilder: (context) {
        final isEditable = appt['caixa_id']?.toString() == _activeCaixaId;
        return [
          if (!isPast) ...[
            if (status == 'concluido')
              PopupMenuItem(
                value: 'alterar_status_concluido',
                child: Row(
                  children: [
                    Icon(Icons.edit_road_outlined, size: 18, color: goldColor),
                    const SizedBox(width: 8),
                    const Text('Alterar Status'),
                  ],
                ),
              )
            else
              const PopupMenuItem(value: 'concluido', child: Text('Concluir')),

            const PopupMenuItem(value: 'confirmado', child: Text('Confirmar')),
            const PopupMenuItem(
              value: 'alterar',
              child: Text('Reagendar'),
            ),
            const PopupMenuItem(
              value: 'trocar_profissional',
              child: Text('Trocar Profissional'),
            ),
            const PopupMenuItem(value: 'cancelado', child: Text('Cancelar')),

            if (appt['pago'] != true) ...[
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
            if (isEditable && appt['pago'] == true) ...[
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
                    Icon(Icons.money_off, size: 18, color: AppColors.error),
                    const SizedBox(width: 8),
                    const Text('Não Pago (Excluir)'),
                  ],
                ),
              ),
            ],
            const PopupMenuDivider(),
          ],
          if (isPast) ...[
            if (status == 'concluido')
              PopupMenuItem(
                value: 'alterar_status_concluido',
                child: Row(
                  children: [
                    Icon(Icons.edit_road_outlined, size: 18, color: goldColor),
                    const SizedBox(width: 8),
                    const Text('Alterar Status'),
                  ],
                ),
              ),
            if (status != 'concluido' &&
                status != 'cancelado' &&
                status != 'no_show') ...[
              PopupMenuItem(
                value: 'concluido',
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: primaryGreen,
                    ),
                    const SizedBox(width: 8),
                    const Text('Concluir'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'no_show',
                child: Row(
                  children: [
                    Icon(
                      Icons.person_off_outlined,
                      size: 18,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    const Text('No-show (Não compareceu)'),
                  ],
                ),
              ),
            ],
            if (appt['pago'] != true &&
                status != 'cancelado' &&
                status != 'no_show') ...[
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
            if (isEditable && appt['pago'] == true) ...[
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
                    Icon(Icons.money_off, size: 18, color: AppColors.error),
                    const SizedBox(width: 8),
                    const Text('Não Pago (Excluir)'),
                  ],
                ),
              ),
            ],
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
    );
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
      color: Colors.white,
      elevation: 4,
      offset: const Offset(0, 40),
      itemBuilder: (context) => options.map((opt) {
        final isSelected =
            currentValue.toLowerCase() == opt.toLowerCase() ||
            (currentValue.toLowerCase() == 'concluido' &&
                opt.toLowerCase() == 'concluído');

        Color dotColor = primaryGreen;
        if (opt.toLowerCase() == 'pendente') dotColor = AppColors.warning;
        if (opt.toLowerCase() == 'cancelado') dotColor = AppColors.error;
        if (opt.toLowerCase() == 'confirmado') dotColor = AppColors.success;
        if (opt.toLowerCase() == 'concluído' ||
            opt.toLowerCase() == 'concluido')
          dotColor = Colors.blue;

        return PopupMenuItem<String>(
          value: opt,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                opt,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? primaryGreen : Colors.black87,
                  fontSize: 14,
                ),
              ),
              if (isSelected) ...[
                const Spacer(),
                Icon(Icons.check, color: primaryGreen, size: 16),
              ],
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryGreen.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: primaryGreen.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune_rounded, color: primaryGreen, size: 16),
            const SizedBox(width: 8),
            Text(
              currentValue,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: primaryGreen,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: primaryGreen,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  void _showReagendarModal(Map<String, dynamic> appointment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AdminReagendamentoModal(
        appointment: appointment,
        onReagendado: () {
          _loadAppointments();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Agendamento alterado com sucesso!'),
              backgroundColor: AppColors.primary,
            ),
          );
        },
      ),
    );
  }

  Future<void> _switchProfessional(Map<String, dynamic> appt) async {
    try {
      final String? serviceId = appt['servico_id']?.toString();
      final String? currentProfId = appt['profissional_id']?.toString();
      final DateTime apptDateTime = DateTime.parse(appt['data_hora']);
      final int duration = appt['servicos']?['duracao_minutos'] as int? ?? 60;

      if (serviceId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro: ID do serviço não encontrado.')),
        );
        return;
      }

      // 1. Carregar profissionais que fazem o serviço
      final allProfsForService = await _profRepo.getProfessionalsByService(
        serviceId,
      );
      final otherProfs = allProfsForService
          .where((p) => p.id != currentProfId)
          .toList();

      if (otherProfs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Não há outros profissionais cadastrados para este serviço.',
              ),
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      // 2. Mostrar Diálogo de Seleção
      final selectedProf = await showDialog<ProfessionalModel>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Trocar Profissional',
            style: TextStyle(fontWeight: FontWeight.bold, color: primaryGreen),
          ),
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
                  title: Text(
                    prof.nome,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () => Navigator.pop(context, prof),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );

      if (selectedProf == null) return;

      // 3. Verificar Disponibilidade
      final isAvailable = await _profRepo.checkProfessionalAvailability(
        profId: selectedProf.id,
        startDateTime: apptDateTime,
        durationMinutes: duration,
      );

      if (!isAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'O profissional ${selectedProf.nome} não tem agenda livre neste horário.',
              ),
              backgroundColor: AppColors.error,
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
          content: Text(
            'Deseja realmente trocar para o profissional ${selectedProf.nome}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Não'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
              child: const Text(
                'Sim, trocar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // 5. Atualizar no Banco
      await _supabase
          .from('agendamentos')
          .update({'profissional_id': selectedProf.id})
          .eq('id', appt['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profissional alterado com sucesso!'),
            backgroundColor: AppColors.primary,
          ),
        );
        _loadAppointments();
      }
    } catch (e) {
      debugPrint('Erro ao trocar profissional: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao realizar a troca. Tente novamente.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildMonthlyGroupedList() {
    if (_appointments.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 48,
                color: primaryGreen.withOpacity(0.2),
              ),
              const SizedBox(height: 16),
              Text(
                'Nenhum agendamento para este mês',
                style: GoogleFonts.manrope(color: AppColors.textSecondary),
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
      if (!grouped.containsKey(key)) grouped[key] = [];
      grouped[key]!.add(appt);
    }

    // Ordenar as datas
    final sortedKeys = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: EdgeInsets.zero,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final dateKey = sortedKeys[index];
        final dayAppts = grouped[dateKey]!;
        final dateTime = DateTime.parse(dateKey);

        // Formatar: Quinta-Feira, 09 de Abril de 2026
        final String headerDate = DateFormat(
          "EEEE, dd 'de' MMMM 'de' yyyy",
          'pt_BR',
        ).format(dateTime);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Text(
                headerDate.toLowerCase(),
                style: GoogleFonts.playfairDisplay(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryGreen,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...dayAppts.map(
              (appt) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildAppointmentCard(appt: appt),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAlterarStatusConcluidoMenu(Map<String, dynamic> appt) {
    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Alterar Status de Concluído',
                  style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryGreen,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.pending_actions, color: goldColor),
                title: const Text('Voltar para Pendente'),
                onTap: () {
                  Navigator.pop(context);
                  _updateStatus(appt, 'pendente');
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: Colors.red),
                title: const Text('Cancelar Agendamento'),
                onTap: () {
                  Navigator.pop(context);
                  _updateStatus(appt, 'cancelado');
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.calendar_month_outlined,
                  color: primaryGreen,
                ),
                title: const Text('Alterar Data (Reagendar)'),
                onTap: () {
                  Navigator.pop(context);
                  _showReagendarModal(appt);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
