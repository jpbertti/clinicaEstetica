import 'package:app_clinica_estetica/features/auth/data/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_clinica_estetica/core/services/notification_service.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_notification_repository.dart';
import 'package:app_clinica_estetica/core/data/models/pacote_template_model.dart';

class ConfirmacaoAgendamentoPage extends StatefulWidget {
  final Map<String, dynamic>? bookingData;

  const ConfirmacaoAgendamentoPage({super.key, this.bookingData});

  @override
  State<ConfirmacaoAgendamentoPage> createState() =>
      _ConfirmacaoAgendamentoPageState();
}

class _ConfirmacaoAgendamentoPageState
    extends State<ConfirmacaoAgendamentoPage> {
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_BR', null);
  }

  Future<void> _handleConfirmBooking() async {
    setState(() => _isConfirming = true);

    try {
      final serviceName = widget.bookingData?['serviceName'] ?? 'Procedimento';
      final supabase = Supabase.instance.client;
      final clientIdValue = widget.bookingData?['clientId'];
      final clientNameValue = widget.bookingData?['clientName'];
      
      final userId = (clientIdValue != null && clientIdValue.toString().isNotEmpty) 
          ? clientIdValue.toString() 
          : AuthService.currentUserId;

      debugPrint('AGENDAMENTO_DEBUG: Confirmando agendamento.');
      debugPrint('AGENDAMENTO_DEBUG: clientId enviado: $clientIdValue');
      debugPrint('AGENDAMENTO_DEBUG: clientName enviado: $clientNameValue');
      debugPrint('AGENDAMENTO_DEBUG: isAdmin: ${AuthService.isAdmin}');
      debugPrint('AGENDAMENTO_DEBUG: currentUserId (AuthService): ${AuthService.currentUserId}');
      debugPrint('AGENDAMENTO_DEBUG: userId que será usado no INSERT: $userId');

      if (userId == null) {
        throw Exception('Usuário não identificado para o agendamento.');
      }

      final serviceId = widget.bookingData?['serviceId'];
      final professionalId = widget.bookingData?['professionalId'];
      final date = widget.bookingData?['date'] as DateTime?;
      final timeStr = widget.bookingData?['time'] as String?;
      final priceValue = widget.bookingData?['priceValue'] ?? 0.0;
      final pacote = widget.bookingData?['pacote'] as PacoteTemplateModel?;
      final sessaoNumero = widget.bookingData?['sessaoNumero'] as int?;

      if (serviceId == null ||
          professionalId == null ||
          date == null ||
          timeStr == null) {
        throw Exception('Dados do agendamento incompletos.');
      }

      // Combinar data e hora com segurança
      final timeParts = timeStr.split(':');
      final scheduledDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );

      // Validação final: Garantir que o horário não passou
      if (scheduledDateTime.isBefore(DateTime.now())) {
        throw Exception(
          'Este horário acabou de passar. Por favor, escolha outro.',
        );
      }

      // 1. Verificar se o USUÁRIO já tem agendamento que sobrepõe este novo horário
      final serviceDuration = widget.bookingData?['duracaoMinutos'] ?? 60;
      final slotEnd = scheduledDateTime.add(Duration(minutes: serviceDuration));

      final startOfDay = DateTime(
        date.year,
        date.month,
        date.day,
      ).toUtc().toIso8601String();
      final endOfDay = DateTime(
        date.year,
        date.month,
        date.day,
        23,
        59,
        59,
      ).toUtc().toIso8601String();

      final userBookings = await supabase
          .from('agendamentos')
          .select(
            'id, data_hora, status, servicos:servico_id(nome, duracao_minutos), perfis:profissional_id(nome_completo)',
          )
          .eq('cliente_id', userId)
          .neq('status', 'cancelado')
          .gte('data_hora', startOfDay)
          .lte('data_hora', endOfDay);

      for (var booking in userBookings) {
        final bStart = DateTime.parse(booking['data_hora']).toLocal();
        final servData = booking['servicos'];
        int bDuration = 60;
        String sName = 'Procedimento';

        if (servData is Map) {
          bDuration = servData['duracao_minutos'] as int? ?? 60;
          sName = servData['nome']?.toString() ?? 'Procedimento';
        } else if (servData is List && servData.isNotEmpty) {
          bDuration = servData[0]['duracao_minutos'] as int? ?? 60;
          sName = servData[0]['nome']?.toString() ?? 'Procedimento';
        }

        final bEnd = bStart.add(Duration(minutes: bDuration));

        if (scheduledDateTime.isBefore(bEnd) && slotEnd.isAfter(bStart)) {
          final pData = booking['perfis'];
          String pName = 'Profissional';
          if (pData is Map) {
            pName = pData['nome_completo']?.toString() ?? 'Profissional';
          } else if (pData is List && pData.isNotEmpty) {
            pName = pData[0]['nome_completo']?.toString() ?? 'Profissional';
          }

          throw Exception(
            'Você já possui um agendamento das ${DateFormat('HH:mm').format(bStart)} às ${DateFormat('HH:mm').format(bEnd)} que conflita com este ($sName com $pName).',
          );
        }
      }

      // 2. Verificar se o PROFISSIONAL já tem agendamento que sobrepõe
      final profBookings = await supabase
          .from('agendamentos')
          .select(
            'id, data_hora, status, servicos:servico_id(nome, duracao_minutos), perfis:cliente_id(nome_completo)',
          )
          .eq('profissional_id', professionalId)
          .neq('status', 'cancelado')
          .gte('data_hora', startOfDay)
          .lte('data_hora', endOfDay);

      for (var booking in profBookings) {
        final bStart = DateTime.parse(booking['data_hora']).toLocal();
        final servData = booking['servicos'];
        int bDuration = 60;

        if (servData is Map) {
          bDuration = servData['duracao_minutos'] as int? ?? 60;
        } else if (servData is List && servData.isNotEmpty) {
          bDuration = servData[0]['duracao_minutos'] as int? ?? 60;
        }

        final bEnd = bStart.add(Duration(minutes: bDuration));

        if (scheduledDateTime.isBefore(bEnd) && slotEnd.isAfter(bStart)) {
          throw Exception(
            'Infelizmente este horário (ou parte dele) acabou de ser preenchido por outro cliente. Por favor, selecione outro horário.',
          );
        }
      }

      // 3. Lógica de Pacote (se aplicável)
      String? pacoteContratadoId;
      if (pacote != null) {
        // Verificar se usuário já tem esse pacote ativo
        final existingContract = await supabase
            .from('pacotes_contratados')
            .select('id')
            .eq('cliente_id', userId)
            .eq('template_id', pacote.id)
            .eq('status', 'ativo')
            .limit(1)
            .maybeSingle();

        if (existingContract != null) {
          pacoteContratadoId = existingContract['id'];
        } else {
          // Criar novo contrato de pacote
          final newContract = await supabase.from('pacotes_contratados').insert({
            'cliente_id': userId,
            'template_id': pacote.id,
            'profissional_id': professionalId,
            'valor_pago': pacote.valorTotal,
            'sessoes_totais': pacote.quantidadeSessoes,
            'sessoes_realizadas': 0,
            'status': 'ativo',
          }).select().single();
          pacoteContratadoId = newContract['id'];
        }
      }

      // 4. Inserir no Supabase
      final bookingResponse = await supabase
          .from('agendamentos')
          .insert({
            'cliente_id': userId,
            'servico_id': serviceId,
            'profissional_id': professionalId,
            'data_hora': scheduledDateTime.toUtc().toIso8601String(),
            'valor_total': priceValue,
            'status': 'pendente',
            'pacote_contratado_id': pacoteContratadoId,
            'sessao_numero': sessaoNumero,
          })
          .select()
          .single();

      // 5. Atualizar sessões realizadas se for pacote
      if (pacoteContratadoId != null) {
        await supabase.rpc('increment_pacote_sessoes', params: {
          'contract_id': pacoteContratadoId,
        });
      }

      // 3. Agendar Notificações Locais
      try {
        final notificationService = NotificationService();
        final bookingId = bookingResponse['id'].hashCode;

        // Notificação Imediata
        await notificationService.showImmediateNotification(
          id: bookingId,
          title: 'Agendamento Confirmado! ✨',
          body: 'Sua reserva para $serviceName foi realizada com sucesso.',
        );

        // Lembrete para o dia
        await notificationService.scheduleNotification(
          id: bookingId + 1,
          title: 'Lembrete de Beleza 🌸',
          body: 'Seu horário de $serviceName é em breve. Te esperamos!',
          scheduledDate: scheduledDateTime,
        );
      } catch (e) {
        debugPrint('Erro ao agendar notificação: $e');
      }

      // Notificar Administradores e Profissional
      try {
        final notifRepo = SupabaseNotificationRepository();
        final timeParts = timeStr.split(':');
        final start = DateTime(
          date.year,
          date.month,
          date.day,
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
        );
        final end = start.add(Duration(minutes: serviceDuration));
        final interval =
            "${DateFormat('HH:mm').format(start)} - ${DateFormat('HH:mm').format(end)}";

        // Notificar Admins
        await notifRepo.notifyAllAdmins(
          titulo: 'Novo Agendamento',
          mensagem:
              'Um novo agendamento foi feito para $serviceName às $interval no dia ${DateFormat('dd/MM/yyyy').format(start)}.',
          tipo: 'agendamento',
        );

        await notifRepo.sendNotification(
          userId: professionalId,
          titulo: 'Novo Agendamento',
          mensagem:
              'Você tem um novo agendamento: $serviceName às $interval no dia ${DateFormat('dd/MM/yyyy').format(start)}.',
          tipo: 'agendamento',
        );
      } catch (e) {
        debugPrint('Erro ao notificar: $e');
      }

      if (mounted) {
        context.go('/sucesso-agendamento');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConfirming = false);
        String errorMessage = 'Ocorreu um erro inesperado.';
        if (e.toString().contains('Exception:')) {
          errorMessage = e.toString().split('Exception: ')[1];
        } else {
          errorMessage = e.toString();
        }

        if (!mounted) return;
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mock data if bookingData is null (based on design)
    final serviceName =
        widget.bookingData?['serviceName'] ?? 'Limpeza de Pele Profunda';
    final servicePrice = widget.bookingData?['price'] ?? 'R\$ 280,00';
    final serviceImage =
        widget.bookingData?['serviceImage'] ??
        'https://images.unsplash.com/photo-1512290923902-8a9f81dc2069?auto=format&fit=crop&q=80&w=400';
    final professionalName = widget.bookingData?['professional'] ?? 'Ana Silva';
    final professionalImage =
        widget.bookingData?['professionalImage'] ??
        'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&q=80&w=200';
    final selectedDate =
        widget.bookingData?['date'] as DateTime? ?? DateTime(2023, 10, 12);
    final selectedTime = widget.bookingData?['time'] ?? '09:00';
    final pacoteNome = widget.bookingData?['pacoteNome'] as String?;
    final procedimentoNome = widget.bookingData?['procedimentoNome'] as String?;
    final sessaoNumero = widget.bookingData?['sessaoNumero'] as int?;

    final formattedDate = DateFormat(
      "d 'de' MMMM 'de' y",
      'pt_BR',
    ).format(selectedDate);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(
                        Icons.chevron_left,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                  ),
                  Text(
                    'CONFIRMAÇÃO DO AGENDAMENTO',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontFamily: 'Playfair Display',
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Service Image and Card
                    Container(
                      width: double.infinity,
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
                      child: Column(
                        children: [
                          Hero(
                            tag: 'service-image-$serviceImage',
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(30),
                              ),
                              child: serviceImage.startsWith('http')
                                  ? Image.network(
                                      serviceImage,
                                      height: 250,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                                height: 250,
                                                color: Colors.grey[200],
                                                child: const Icon(
                                                  Icons.image_not_supported,
                                                ),
                                              ),
                                    )
                                  : Image.asset(
                                      serviceImage,
                                      height: 250,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                                height: 250,
                                                color: Colors.grey[200],
                                                child: const Icon(
                                                  Icons.image_not_supported,
                                                ),
                                              ),
                                    ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 24,
                              horizontal: 16,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.bookingData?['clientName'] != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.person_outline, size: 14, color: AppColors.accent),
                                        const SizedBox(width: 4),
                                        Text(
                                          'CLIENTE: ${widget.bookingData!['clientName']}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.accent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                  Text(
                                    (pacoteNome ?? serviceName).toUpperCase(),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: pacoteNome != null ? 20 : 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                      height: 1.2,
                                      fontFamily: 'Playfair Display',
                                    ),
                                  ),
                                if (pacoteNome != null && procedimentoNome != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    procedimentoNome,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                                if (sessaoNumero != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Sessão $sessaoNumero',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.accent,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Detail Cards
                          _construirCardDetalhe(
                            icon: Icons.calendar_today_outlined,
                            label: 'DATA',
                            value: formattedDate,
                          ),
                          const SizedBox(height: 12),

                          // Cálculo do horário de término para exibição
                          _construirCardDetalhe(
                            icon: Icons.access_time,
                            label: 'HORÁRIO',
                            value: () {
                              try {
                                final timeParts = selectedTime.split(':');
                                final start = DateTime(
                                  selectedDate.year,
                                  selectedDate.month,
                                  selectedDate.day,
                                  int.parse(timeParts[0]),
                                  int.parse(timeParts[1]),
                                );
                                final duration =
                                    widget.bookingData?['duracaoMinutos'] ?? 60;
                                final end = start.add(
                                  Duration(minutes: duration),
                                );
                                return "$selectedTime - ${DateFormat('HH:mm').format(end)}";
                              } catch (e) {
                                return selectedTime;
                              }
                            }(),
                          ),
                          const SizedBox(height: 12),
                          _construirCardDetalheComAvatar(
                            image:
                                professionalImage ??
                                'https://images.unsplash.com/photo-1559599101-f09722fb4948?auto=format&fit=crop&w=200&q=80',
                            label: 'PROFISSIONAL',
                            value: professionalName,
                            subtitle: widget.bookingData?['professionalCargo'],
                          ),

                          const SizedBox(height: 32),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: Divider(color: Color(0xFFF0F0F0)),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'TOTAL DO SERVIÇO',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  servicePrice,
                                  style: TextStyle(
                                    fontFamily: 'Playfair Display',
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    Text(
                      '* Ao confirmar, você concorda com nossa política de cancelamento de 24 horas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12,
                        color: Colors.black45,
                        height: 1.5,
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(color: AppColors.background),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          onPressed: _isConfirming
              ? null
              : _handleConfirmBooking,
          child: _isConfirming
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'Confirmar Agendamento',
                  style: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _construirCardDetalhe({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: AppColors.accent,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirCardDetalheComAvatar({
    required String image,
    required String label,
    required String value,
    String? subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: image.startsWith('http')
                ? NetworkImage(image)
                : AssetImage(image) as ImageProvider,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: AppColors.accent,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle.toUpperCase(),
                    style: TextStyle(fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                      letterSpacing: 0.5,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

