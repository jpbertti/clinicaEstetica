import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_notification_repository.dart';
import 'package:app_clinica_estetica/core/data/repositories/dashboard_repository.dart';

class AdminHorariosPage extends StatefulWidget {
  const AdminHorariosPage({super.key});

  @override
  State<AdminHorariosPage> createState() => _AdminHorariosPageState();
}

class _AdminHorariosPageState extends State<AdminHorariosPage> {
  final _supabase = Supabase.instance.client;
  final _notificationRepo = SupabaseNotificationRepository();
  final _dashboardRepo = SupabaseDashboardRepository();
  bool _loading = true;
  List<Map<String, dynamic>> _horariosClinica = [];
  List<Map<String, dynamic>> _bloqueiosAgenda = [];

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _loading = true);
    await Future.wait([
      _carregarHorarios(),
      _carregarBloqueios(),
    ]);
    setState(() => _loading = false);
  }

  Future<void> _carregarHorarios() async {
    try {
      final response = await _supabase
          .from('horarios_clinica')
          .select()
          .order('dia_semana', ascending: true);
      
      if (response.isEmpty) {
        final List<Map<String, dynamic>> defaults = [];
        for (int i = 0; i < 7; i++) {
          defaults.add({
            'dia_semana': i,
            'hora_inicio': '08:00:00',
            'hora_fim': '18:00:00',
            'fechado': i == 0 ? true : false,
          });
        }
        await _supabase.from('horarios_clinica').insert(defaults);
        return _carregarHorarios();
      } else {
        _horariosClinica = List<Map<String, dynamic>>.from(response);
      }
    } catch (e) {
      debugPrint('Erro ao carregar horários: $e');
    }
  }
  Future<void> _carregarBloqueios() async {
    try {
      final response = await _supabase
          .from('bloqueios_agenda')
          .select('*, profissional:perfis!profissional_id(nome_completo), autor:perfis!usuario_id(nome_completo)')
          .order('data', ascending: false);

      
      setState(() {
        _bloqueiosAgenda = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Erro ao carregar bloqueios com join: $e');
      // Fallback simples se o join falhar
      try {
        final fallback = await _supabase
            .from('bloqueios_agenda')
            .select()
            .order('data', ascending: false);
        setState(() {
          _bloqueiosAgenda = List<Map<String, dynamic>>.from(fallback);
        });
      } catch (e2) {
        debugPrint('Erro no fallback de bloqueios: $e2');
      }
    }
  }

  Future<void> _atualizarHorario(int index, String campo, dynamic valor) async {
    final horario = _horariosClinica[index];
    try {
      await _supabase
          .from('horarios_clinica')
          .update({campo: valor})
          .eq('id', horario['id']);
      
      final dayName = _getDayName(horario['dia_semana']);
      final oldValue = horario[campo];
      final statusStr = valor == true ? 'Fechado' : (campo == 'fechado' ? 'Aberto' : '$valor');
      
      String label = campo;
      if (campo == 'fechado') label = 'Status';
      if (campo == 'hora_inicio') label = 'Início';
      if (campo == 'hora_fim') label = 'Fim';

      String oldValStr = oldValue == true ? 'Fechado' : (campo == 'fechado' ? 'Aberto' : '$oldValue');
      if (campo == 'hora_inicio' || campo == 'hora_fim') {
        oldValStr = (oldValue as String).substring(0, 5);
      }
      String newValStr = valor == true ? 'Fechado' : (campo == 'fechado' ? 'Aberto' : '$valor');
      if (campo == 'hora_inicio' || campo == 'hora_fim') {
          newValStr = (valor as String).substring(0, 5);
      }

      await _dashboardRepo.logActivity(
        tipo: 'configuracao',
        titulo: 'Horário Alterado',
        descricao: 'O horário de $dayName ($label) foi alterado para $statusStr.',
        userId: _supabase.auth.currentUser?.id,
        metadata: {
          'changes': [
            {
              'campo': '$dayName - $label',
              'antigo': oldValStr,
              'novo': newValStr,
            }
          ]
        },
      );

      _carregarHorarios();
      setState(() {});
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao atualizar horário'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _bloquearDia() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('pt', 'BR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2F5E46), // Header and selection
              onPrimary: Colors.white,
              onSurface: Color(0xFF2B2B2B),
            ),
            datePickerTheme: DatePickerThemeData(
              headerBackgroundColor: const Color(0xFF2F5E46),
              headerForegroundColor: Colors.white,
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2F5E46), // Green OK
                textStyle: TextStyle(fontWeight: FontWeight.bold),
              ),
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: const Color(0xFFC7A36B), // Gold Cancel
                textStyle: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    // Diálogo para escolher se é dia todo ou parcial
    TimeOfDay? start;
    TimeOfDay? end;
    bool isFullDay = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        bool partial = false;
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Tipo de Bloqueio', style: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFF2F5E46))),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<bool>(
                  title: Text('Dia Inteiro', style: TextStyle(fontSize: 14)),
                  value: false,
                  groupValue: partial,
                  onChanged: (v) => setDialogState(() => partial = v!),
                  activeColor: const Color(0xFF2F5E46),
                ),
                RadioListTile<bool>(
                  title: Text('Horário Parcial', style: TextStyle(fontSize: 14)),
                  value: true,
                  groupValue: partial,
                  onChanged: (v) => setDialogState(() => partial = v!),
                  activeColor: const Color(0xFF2F5E46),
                ),
                if (partial) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 8, minute: 0));
                            if (t != null) setDialogState(() => start = t);
                          },
                          child: Text(start?.format(context) ?? 'Início', style: TextStyle(color: const Color(0xFFC7A36B))),
                        ),
                      ),
                      const Text(' - '),
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 18, minute: 0));
                            if (t != null) setDialogState(() => end = t);
                          },
                          child: Text(end?.format(context) ?? 'Fim', style: TextStyle(color: const Color(0xFFC7A36B))),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancelar', style: TextStyle(color: Colors.grey))),
              TextButton(
                onPressed: () {
                  if (partial && (start == null || end == null)) return;
                  isFullDay = !partial;
                  Navigator.pop(context, true);
                },
                child: Text('Confirmar', style: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFF2F5E46))),
              ),
            ],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          );
        });
      },
    );

    if (result != true) return;

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(picked);
      
      // Construir range para verificação
      DateTime checkStart;
      DateTime checkEnd;
      
      if (isFullDay) {
        checkStart = DateTime(picked.year, picked.month, picked.day);
        checkEnd = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      } else {
        checkStart = DateTime(picked.year, picked.month, picked.day, start!.hour, start!.minute);
        checkEnd = DateTime(picked.year, picked.month, picked.day, end!.hour, end!.minute);
      }

      final startStr = checkStart.toUtc().toIso8601String();
      final endStr = checkEnd.toUtc().toIso8601String();

      // Verifica agendamentos conflitantes
      final response = await _supabase
          .from('agendamentos')
          .select('id, status, perfis!cliente_id(nome_completo)')
          .gte('data_hora', startStr)
          .lte('data_hora', endStr)
          .inFilter('status', ['confirmado', 'pendente']);

      if (response.isNotEmpty) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFFF6F4EF),
              title: Text('Bloqueio Indisponível', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Este dia possui agendamentos ativos. Cancele-os ou reagende-os primeiro:', style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 16),
                  ...response.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, size: 16, color: Color(0xFFC7A36B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${(a['perfis'] as Map)['nome_completo']} (${a['status']})',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Entendido', style: TextStyle(color: const Color(0xFF2F5E46), fontWeight: FontWeight.bold)),
                ),
              ],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          );
        }
        return;
      }

      await _supabase.from('bloqueios_agenda').insert({
        'data': dateStr,
        'hora_inicio': isFullDay ? null : '${start!.hour.toString().padLeft(2, '0')}:${start!.minute.toString().padLeft(2, '0')}:00',
        'hora_fim': isFullDay ? null : '${end!.hour.toString().padLeft(2, '0')}:${end!.minute.toString().padLeft(2, '0')}:00',
        'dia_todo': isFullDay,
        'motivo': isFullDay ? 'Bloqueio administrativo (Clínica)' : 'Bloqueio parcial (Clínica)',
        'usuario_id': _supabase.auth.currentUser?.id,
      });

      // Notificações
      final formattedDate = DateFormat('dd/MM/yyyy').format(picked);
      final rangeStr = isFullDay ? 'Dia Inteiro' : 'das ${start!.format(context)} às ${end!.format(context)}';
      
      await _notificationRepo.notifyAffectedClients(
        professionalId: null, // Global block
        date: picked,
        startStr: isFullDay ? null : '${start!.hour.toString().padLeft(2, '0')}:${start!.minute.toString().padLeft(2, '0')}:00',
        endStr: isFullDay ? null : '${end!.hour.toString().padLeft(2, '0')}:${end!.minute.toString().padLeft(2, '0')}:00',
        message: 'A clínica terá uma alteração no funcionamento para o dia $formattedDate ($rangeStr). Se você tinha um agendamento, entre em contato para confirmar ou reagendar.',
      );

      await _dashboardRepo.logActivity(
        tipo: 'configuracao',
        titulo: 'Novo Bloqueio de Agenda',
        descricao: 'Um bloqueio global foi adicionado para o dia $formattedDate ($rangeStr).',
        userId: _supabase.auth.currentUser?.id,
        metadata: {
          'changes': [
            {
              'campo': 'Novo Bloqueio Global',
              'antigo': 'Disponível',
              'novo': 'Bloqueado ($formattedDate - $rangeStr)',
            }
          ]
        },
      );

      _carregarBloqueios();
      setState(() {});
    } catch (e) {
      debugPrint('Erro ao bloquear: $e');
    }
  }

  Future<void> _removerBloqueio(String id) async {
    try {
      final bloqueio = _bloqueiosAgenda.where((b) => b['id'].toString() == id).firstOrNull;
      final dateStr = bloqueio != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(bloqueio['data'])) : 'Desconhecido';

      await _supabase.from('bloqueios_agenda').delete().eq('id', id);
      
      await _dashboardRepo.logActivity(
        tipo: 'configuracao',
        titulo: 'Bloqueio Removido',
        descricao: 'O bloqueio do dia $dateStr foi removido.',
        userId: _supabase.auth.currentUser?.id,
        metadata: {
          'changes': [
            {
              'campo': 'Remoção de Bloqueio',
              'antigo': 'Bloqueado ($dateStr)',
              'novo': 'Disponível',
            }
          ]
        },
      );

      _carregarBloqueios();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bloqueio removido com sucesso.')),
        );
      }
      setState(() {});
    } catch (e) {
      debugPrint('Erro ao remover bloqueio: $e');
    }
  }

  Future<void> _confirmarRemocao(String id) async {
    const primaryColor = Color(0xFF2F5E46);
    const goldColor = Color(0xFFC7A36B);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar exclusão', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
        content: Text('Deseja mesmo excluir este bloqueio?', style: TextStyle()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: goldColor, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Excluir', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    if (result == true) {
      await _removerBloqueio(id);
    }
  }

  String _getDayName(int day) {
    const days = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
    return days[day];
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2F5E46);
    const goldColor = Color(0xFFC7A36B);
    const backgroundColor = Color(0xFFF6F4EF);
    final softGreen = primaryColor.withOpacity(0.05);

    final clinicBlocks = _bloqueiosAgenda.where((b) => b['profissional_id'] == null).toList();
    final profBlocks = _bloqueiosAgenda.where((b) => b['profissional_id'] != null).toList();

    return Scaffold(
      backgroundColor: backgroundColor,
      body: _loading 
        ? const Center(child: CircularProgressIndicator(color: primaryColor))
        : SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                _buildSectionHeader('Horários Semanais', primaryColor),
                const SizedBox(height: 8),
                _buildWorkingHoursCard(primaryColor, goldColor, softGreen),
                const SizedBox(height: 32),
                _buildSectionHeader('Bloqueios da Clínica', primaryColor),
                _buildClinicBlockingCard(clinicBlocks, primaryColor, goldColor, softGreen),
                const SizedBox(height: 32),
                _buildSectionHeader('Bloqueios pelo Profissional', primaryColor),
                if (profBlocks.isEmpty)
                  _buildEmptyState('Nenhum bloqueio de profissional ativo.')
                else
                  ...profBlocks.map((b) => _buildProfessionalBlockCard(b, primaryColor, goldColor)),
              ],
            ),
          ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2F5E46).withOpacity(0.05)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: TextStyle(fontSize: 18,
          fontWeight: FontWeight.bold,
          color: color.withOpacity(0.8),
          fontFamily: 'Playfair Display',
        ),
      ),
    );
  }

  Widget _buildWorkingHoursCard(Color primaryColor, Color goldColor, Color softGreen) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _horariosClinica.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: primaryColor.withOpacity(0.05)),
        itemBuilder: (context, index) {
          final horario = _horariosClinica[index];
          final bool fechado = horario['fechado'] ?? false;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    _getDayName(horario['dia_semana']),
                    style: TextStyle(fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: fechado ? Colors.grey : primaryColor,
                    ),
                  ),
                ),
                if (!fechado) ...[
                  _buildTimeSelector(
                    horario['hora_inicio'].toString().substring(0, 5),
                    (time) => _atualizarHorario(index, 'hora_inicio', '$time:00'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('até', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                  _buildTimeSelector(
                    horario['hora_fim'].toString().substring(0, 5),
                    (time) => _atualizarHorario(index, 'hora_fim', '$time:00'),
                  ),
                ] else ...[
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: Text(
                        'Fechado',
                        style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.red.withOpacity(0.7),
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Switch(
                  value: !fechado,
                  activeThumbColor: goldColor,
                  onChanged: (val) => _atualizarHorario(index, 'fechado', !val),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeSelector(String time, Function(String) onSelected) {
    return InkWell(
      onTap: () async {
        final TimeOfDay? picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(
            hour: int.parse(time.split(':')[0]),
            minute: int.parse(time.split(':')[1]),
          ),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF2F5E46),
                  onPrimary: Colors.white,
                  onSurface: Color(0xFF2B2B2B),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          onSelected('${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F4EF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          time,
          style: TextStyle(fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF2F5E46),
          ),
        ),
      ),
    );
  }

  Widget _buildClinicBlockingCard(List<Map<String, dynamic>> blocks, Color primaryColor, Color goldColor, Color softGreen) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Bloqueie datas específicas para feriados, reformas ou eventos da clínica.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14,
              color: primaryColor.withOpacity(0.7),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _bloquearDia,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Adicionar Bloqueio'),
              style: ElevatedButton.styleFrom(
                backgroundColor: goldColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
          if (blocks.isNotEmpty) ...[
            const SizedBox(height: 24),
            Divider(color: primaryColor.withOpacity(0.05)),
            const SizedBox(height: 16),
            ...blocks.map((bloqueio) {
              final date = DateTime.parse(bloqueio['data']);
              final isPast = date.isBefore(DateTime.now().subtract(const Duration(days: 1)));

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.calendar_today, size: 16, color: primaryColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('dd/MM/yyyy').format(date),
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryColor),
                          ),
                          Row(
                            children: [
                              if (bloqueio['hora_inicio'] != null)
                                Text(
                                  '${bloqueio['hora_inicio'].substring(0, 5)} até ${bloqueio['hora_fim'].substring(0, 5)}',
                                  style: TextStyle(fontSize: 12, color: goldColor, fontWeight: FontWeight.w600),
                                )
                              else
                                Text(
                                  'Dia inteiro',
                                  style: TextStyle(fontSize: 12, color: Colors.black38),
                                ),
                            ],
                          ),
                          if (bloqueio['autor'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Por: ${(bloqueio['autor'] as Map)['nome_completo']}',
                                style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!isPast)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        onPressed: () => _confirmarRemocao(bloqueio['id'].toString()),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(Icons.history, color: Colors.grey.withOpacity(0.5), size: 18),
                      ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildProfessionalBlockCard(Map<String, dynamic> bloqueio, Color primaryColor, Color goldColor) {
    final date = DateTime.parse(bloqueio['data']);
    final isPast = date.isBefore(DateTime.now().subtract(const Duration(days: 1)));
    final profName = (bloqueio['profissional'] as Map?)?['nome_completo'] ?? 'Profissional';

    final motivo = bloqueio['motivo'] ?? 'Não informado';
    final isDiaTodo = bloqueio['dia_todo'] ?? (bloqueio['hora_inicio'] == null);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: goldColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.person_off_outlined, color: goldColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('dd/MM/yyyy').format(date),
                  style: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                // Período na linha abaixo da data
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: isDiaTodo ? Colors.red : Colors.orange[800]),
                    const SizedBox(width: 4),
                    Text(
                      isDiaTodo ? 'Dia Todo' : '${bloqueio['hora_inicio'].substring(0, 5)} - ${bloqueio['hora_fim'].substring(0, 5)}',
                      style: TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDiaTodo ? Colors.red : Colors.orange[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Motivo: $motivo',
                  style: TextStyle(fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                // Usuário/Profissional na linha de baixo
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_outline, size: 12, color: primaryColor.withOpacity(0.6)),
                          const SizedBox(width: 4),
                          Text(
                            profName,
                            style: TextStyle(fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: primaryColor.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (bloqueio['autor'] != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '•',
                        style: TextStyle(color: Colors.grey.withOpacity(0.5)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Por: ${(bloqueio['autor'] as Map)['nome_completo']}',
                        style: TextStyle(fontSize: 11,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!isPast)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              onSelected: (val) {
                if (val == 'remover') {
                  _confirmarRemocao(bloqueio['id'].toString());
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'remover',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Remover Bloqueio', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            )
          else
            Icon(Icons.lock_clock, color: Colors.grey.withOpacity(0.3), size: 20),
        ],
      ),
    );
  }
}

