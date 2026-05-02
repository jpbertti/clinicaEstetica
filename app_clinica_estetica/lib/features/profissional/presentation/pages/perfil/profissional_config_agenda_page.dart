import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_professional_repository.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_notification_repository.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';
import 'package:app_clinica_estetica/features/profissional/presentation/widgets/profissional_app_bar.dart';

class ProfissionalConfigAgendaPage extends StatefulWidget {
  final int initialIndex;
  const ProfissionalConfigAgendaPage({super.key, this.initialIndex = 0});

  @override
  State<ProfissionalConfigAgendaPage> createState() => _ProfissionalConfigAgendaPageState();
}

class _ProfissionalConfigAgendaPageState extends State<ProfissionalConfigAgendaPage> {
  final primaryColor = const Color(0xFF2F5E46);
  final accentColor = const Color(0xFFC7A36B);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialIndex,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: const ProfissionalAppBar(
          title: 'Configurações da Agenda',
          showBackButton: true,
        ),
        body: Column(
          children: [
            TabBar(
              labelColor: primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: accentColor,
              isScrollable: true,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
              tabs: const [
                Tab(text: 'Horário Trabalho'),
                Tab(text: 'Horário Almoço'),
                Tab(text: 'Fechar Agenda'),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _AbaHorarioTrabalho(),
                  _AbaHorarioAlmoco(),
                  _AbaFecharAgenda(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _AbaHorarioTrabalho extends StatefulWidget {
  const _AbaHorarioTrabalho();

  @override
  State<_AbaHorarioTrabalho> createState() => _AbaHorarioTrabalhoState();
}

class _AbaHorarioTrabalhoState extends State<_AbaHorarioTrabalho> {
  final _repo = SupabaseProfessionalRepository();
  final _notificationRepo = SupabaseNotificationRepository();
  bool _isLoading = true;
  bool _isSaving = false;
  
  // 0: Dom, 1: Seg, ..., 6: Sab
  final List<Map<String, dynamic>> _horarios = List.generate(7, (index) => {
    'dia_semana': index,
    'hora_inicio': '08:00',
    'hora_fim': '18:00',
    'fechado': index == 0, // Domingo fechado por padrão
  });

  final List<String> _diasSemanas = [
    'Domingo', 'Segunda-feira', 'Terça-feira', 'Quarta-feira',
    'Quinta-feira', 'Sexta-feira', 'Sábado'
  ];

  final Color primaryColor = const Color(0xFF2F5E46);
  final Color accentColor = const Color(0xFFC7A36B);

  Set<int> _clinicDays = {};

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    await Future.wait([
      _carregarHorarios(),
      _carregarDisponibilidadeClinica(),
    ]);
  }

  Future<void> _carregarDisponibilidadeClinica() async {
    try {
      final days = await _repo.getClinicAvailabilityDays();
      if (mounted) {
        setState(() => _clinicDays = days.toSet());
      }
    } catch (e) {
      debugPrint('Erro ao carregar disponibilidade da clínica: $e');
    }
  }

  Future<void> _carregarHorarios() async {
    final userId = _repo.currentUserId;
    if (userId == null) return;
    
    try {
      final results = await _repo.getProfessionalWorkingHours(userId);
      if (results.isNotEmpty && mounted) {
        setState(() {
          for (var res in results) {
            int dia = res['dia_semana'];
            if (dia >= 0 && dia < 7) {
              _horarios[dia]['hora_inicio'] = res['hora_inicio'].toString().substring(0, 5);
              _horarios[dia]['hora_fim'] = res['hora_fim'].toString().substring(0, 5);
              _horarios[dia]['fechado'] = res['fechado'] ?? false;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar horários: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selecionarHora(int dia, bool isInicio) async {
    final atual = _horarios[dia][isInicio ? 'hora_inicio' : 'hora_fim'].toString();
    final parts = atual.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        final timeStr = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        _horarios[dia][isInicio ? 'hora_inicio' : 'hora_fim'] = timeStr;
      });
    }
  }

  Future<void> _salvar() async {
    final userId = _repo.currentUserId;
    if (userId == null) return;

    setState(() => _isSaving = true);
    try {
      final clinicDays = await _repo.getClinicAvailabilityDays();
      
      for (var h in _horarios) {
        if (!(h['fechado'] as bool) && !clinicDays.contains(h['dia_semana'])) {
          if (mounted) {
            final diaNome = _diasSemanas[h['dia_semana']];
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('A clínica não funciona no(a) $diaNome. Entre em contato com o administrador.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      for (var h in _horarios) {
        await _repo.updateProfessionalWorkingHour(
          professionalId: userId,
          diaSemana: h['dia_semana'],
          horaInicio: '${h['hora_inicio']}:00',
          horaFim: '${h['hora_fim']}:00',
          fechado: h['fechado'],
        );
      }
      if (mounted) {
        String msg = 'Seus horários foram atualizados:';
        for (int i = 1; i < 7; i++) { // Seg a Sab
          final h = _horarios[i];
          if (!(h['fechado'] as bool)) {
            msg += '\n${_diasSemanas[i].substring(0, 3)}: ${h['hora_inicio']}-${h['hora_fim']}';
          }
        }
        if (!(_horarios[0]['fechado'] as bool)) {
          msg += '\nDom: ${_horarios[0]['hora_inicio']}-${_horarios[0]['hora_fim']}';
        }

        await _notificationRepo.sendNotification(
          userId: userId,
          titulo: 'Agenda Atualizada',
          mensagem: msg,
          tipo: 'agenda',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Horários de trabalho salvos!'), backgroundColor: Color(0xFF2F5E46)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 7,
            itemBuilder: (context, index) {
              final h = _horarios[index];
              final fechado = h['fechado'] as bool;
              final clinicaFechada = !_clinicDays.contains(index);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (fechado || clinicaFechada) ? Colors.grey[50] : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                      color: (fechado || clinicaFechada)
                          ? Colors.grey[200]!
                          : primaryColor.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _diasSemanas[index],
                            style: TextStyle(fontWeight: FontWeight.w800,
                              color: (fechado || clinicaFechada) ? Colors.grey : primaryColor,
                            ),
                          ),
                          if (clinicaFechada)
                            Text(
                              'Clínica Fechada',
                              style: TextStyle(fontSize: 10,
                                color: Colors.red[300],
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!fechado && !clinicaFechada) ...[
                      _timeButton(h['hora_inicio'], () => _selecionarHora(index, true)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text('-'),
                      ),
                      _timeButton(h['hora_fim'], () => _selecionarHora(index, false)),
                    ] else
                      Expanded(
                        flex: 4,
                        child: Text(
                          clinicaFechada ? 'Indisponível' : 'Fechado',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Switch(
                      value: !fechado && !clinicaFechada,
                      activeThumbColor: primaryColor,
                      onChanged: clinicaFechada
                          ? null
                          : (v) => setState(() => h['fechado'] = !v),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton(
            onPressed: _isSaving ? null : _salvar,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Salvar Configurações', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
          ),
        ),
      ],
    );
  }

  Widget _timeButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w800, color: primaryColor, fontSize: 13),
        ),
      ),
    );
  }
}


class _AbaHorarioAlmoco extends StatefulWidget {
  const _AbaHorarioAlmoco();

  @override
  State<_AbaHorarioAlmoco> createState() => _AbaHorarioAlmocoState();
}

class _AbaHorarioAlmocoState extends State<_AbaHorarioAlmoco> {
  final _repo = SupabaseProfessionalRepository();
  final _notificationRepo = SupabaseNotificationRepository();
  bool _isLoading = true;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _horarios = List.generate(7, (index) => {
    'dia_semana': index,
    'hora_inicio': '12:00',
    'hora_fim': '13:00',
    'ativo': index != 0, // Inativo no domingo por padrão
  });

  final List<String> _diasSemanas = [
    'Domingo', 'Segunda-feira', 'Terça-feira', 'Quarta-feira',
    'Quinta-feira', 'Sexta-feira', 'Sábado'
  ];

  final Color primaryColor = const Color(0xFF2F5E46);
  Set<int> _clinicDays = {};

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    await Future.wait([
      _carregarAlmoco(),
      _carregarDisponibilidadeClinica(),
    ]);
  }

  Future<void> _carregarDisponibilidadeClinica() async {
    try {
      final days = await _repo.getClinicAvailabilityDays();
      if (mounted) {
        setState(() => _clinicDays = days.toSet());
      }
    } catch (e) {
      debugPrint('Erro ao carregar disponibilidade da clínica: $e');
    }
  }

  Future<void> _carregarAlmoco() async {
    final userId = _repo.currentUserId;
    if (userId == null) return;

    try {
      final results = await _repo.getProfessionalLunchHours(userId);
      if (results.isNotEmpty && mounted) {
        setState(() {
          for (var res in results) {
            int dia = res['dia_semana'];
            if (dia >= 0 && dia < 7) {
              _horarios[dia]['hora_inicio'] = res['hora_inicio'].toString().substring(0, 5);
              _horarios[dia]['hora_fim'] = res['hora_fim'].toString().substring(0, 5);
              _horarios[dia]['ativo'] = res['ativo'] ?? false;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar almoço: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selecionarHora(int dia, bool isInicio) async {
    final atual = _horarios[dia][isInicio ? 'hora_inicio' : 'hora_fim'].toString();
    final parts = atual.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        final timeStr = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        _horarios[dia][isInicio ? 'hora_inicio' : 'hora_fim'] = timeStr;
      });
    }
  }

  Future<void> _salvar() async {
    final userId = _repo.currentUserId;
    if (userId == null) return;

    setState(() => _isSaving = true);
    try {
      final clinicDays = await _repo.getClinicAvailabilityDays();
      
      for (var h in _horarios) {
        if ((h['ativo'] as bool) && !clinicDays.contains(h['dia_semana'])) {
          if (mounted) {
            final diaNome = _diasSemanas[h['dia_semana']];
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('A clínica não funciona no(a) $diaNome. Não é possível configurar intervalo.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      for (var h in _horarios) {
        await _repo.updateProfessionalLunchHour(
          professionalId: userId,
          diaSemana: h['dia_semana'],
          horaInicio: '${h['hora_inicio']}:00',
          horaFim: '${h['hora_fim']}:00',
          ativo: h['ativo'],
        );
      }
      if (mounted) {
        String msg = 'Novo esquema de intervalos:';
        bool temAlgum = false;
        for (int i = 0; i < 7; i++) {
          final h = _horarios[i];
          if (h['ativo'] as bool) {
            msg += '\n${_diasSemanas[i].substring(0, 3)}: ${h['hora_inicio']}-${h['hora_fim']}';
            temAlgum = true;
          }
        }
        if (!temAlgum) msg = 'Todos os intervalos foram removidos.';

        await _notificationRepo.sendNotification(
          userId: userId,
          titulo: 'Intervalos Atualizados',
          mensagem: msg,
          tipo: 'agenda',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Horários de almoço salvos!'), backgroundColor: Color(0xFF2F5E46)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Configure seu horário de intervalo para cada dia. Estes horários ficarão bloqueados para agendamentos.',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 7,
            itemBuilder: (context, index) {
              final h = _horarios[index];
              final ativo = h['ativo'] as bool;
              final clinicaFechada = !_clinicDays.contains(index);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (!ativo || clinicaFechada) ? Colors.grey[50] : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: (!ativo || clinicaFechada) ? Colors.grey[200]! : primaryColor.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _diasSemanas[index],
                            style: TextStyle(fontWeight: FontWeight.w800,
                              color: (!ativo || clinicaFechada) ? Colors.grey : primaryColor,
                            ),
                          ),
                          if (clinicaFechada)
                            Text(
                              'Clínica Fechada',
                              style: TextStyle(fontSize: 10,
                                color: Colors.red[300],
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (ativo && !clinicaFechada) ...[
                      _timeButton(h['hora_inicio'], () => _selecionarHora(index, true)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text('-'),
                      ),
                      _timeButton(h['hora_fim'], () => _selecionarHora(index, false)),
                    ] else
                      Expanded(
                        flex: 4,
                        child: Text(
                          clinicaFechada ? 'Indisponível' : 'Sem intervalo',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Switch(
                      value: ativo && !clinicaFechada,
                      activeThumbColor: primaryColor,
                      onChanged: clinicaFechada 
                          ? null 
                          : (v) => setState(() => h['ativo'] = v),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton(
            onPressed: _isSaving ? null : _salvar,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Salvar Intervalos', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
          ),
        ),
      ],
    );
  }

  Widget _timeButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w800, color: primaryColor, fontSize: 13),
        ),
      ),
    );
  }
}


class _AbaFecharAgenda extends StatefulWidget {
  const _AbaFecharAgenda();

  @override
  State<_AbaFecharAgenda> createState() => _AbaFecharAgendaState();
}

class _AbaFecharAgendaState extends State<_AbaFecharAgenda> {
  final _repo = SupabaseProfessionalRepository();
  bool _isLoading = true;
  List<Map<String, dynamic>> _bloqueios = [];

  final primaryColor = const Color(0xFF2F5E46);
  final accentColor = const Color(0xFFC7A36B);

  @override
  void initState() {
    super.initState();
    _carregarBloqueios();
  }

  Future<void> _carregarBloqueios() async {
    setState(() => _isLoading = true);
    try {
      final data = await _repo.getAgendaBlocks();
      if (mounted) {
        setState(() {
          _bloqueios = data;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar bloqueios: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removerBloqueio(String id) async {
    try {
      await _repo.removeAgendaBlock(id);
      _carregarBloqueios();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bloqueio removido.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  void _mostrarModalNovoBloqueio() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NovoBloqueioModal(
        onSaved: () {
          Navigator.pop(context);
          _carregarBloqueios();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: _mostrarModalNovoBloqueio,
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text(
              'Novo Bloqueio',
              style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _bloqueios.isEmpty
                ? Center(
                    child: Text(
                      'Nenhum bloqueio programado.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _bloqueios.length,
                    itemBuilder: (context, index) {
                      final item = _bloqueios[index];
                      final dataDate = DateTime.parse(item['data']);
                      final isDiaTodo = item['hora_inicio'] == null && item['hora_fim'] == null;
                      
                      String horarioText = 'Dia Todo';
                      if (!isDiaTodo) {
                        try {
                           final inicio = item['hora_inicio'].toString().substring(0, 5);
                           final fim = item['hora_fim'].toString().substring(0, 5);
                           horarioText = 'das $inicio às $fim';
                        } catch (e) {
                           /* fallback */
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.red.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.event_busy, color: Colors.red),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('dd/MM/yyyy').format(dataDate),
                                    style: TextStyle(fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: Colors.red[800],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    horarioText,
                                    style: TextStyle(color: Colors.red[600],
                                    ),
                                  ),
                                  if (item['motivo'] != null && item['motivo'].toString().isNotEmpty)
                                    Text(
                                      item['motivo'],
                                      style: TextStyle(color: Colors.grey[700],
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _removerBloqueio(item['id']),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _NovoBloqueioModal extends StatefulWidget {
  final VoidCallback onSaved;
  const _NovoBloqueioModal({required this.onSaved});

  @override
  State<_NovoBloqueioModal> createState() => _NovoBloqueioModalState();
}

class _NovoBloqueioModalState extends State<_NovoBloqueioModal> {
  final _repo = SupabaseProfessionalRepository();
  final _notificationRepo = SupabaseNotificationRepository();
  bool _isSaving = false;

  DateTime? _dataEscolhida;
  bool _diaTodo = true;
  TimeOfDay? _inicio;
  TimeOfDay? _fim;
  final _motivoController = TextEditingController();

  final primaryColor = const Color(0xFF2F5E46);

  Future<void> _selecionarData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dataEscolhida = picked);
    }
  }

  Future<void> _selecionarHora(bool isInicio) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isInicio ? (_inicio ?? const TimeOfDay(hour: 8, minute: 0)) : (_fim ?? const TimeOfDay(hour: 18, minute: 0)),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isInicio) {
          _inicio = picked;
        } else {
          _fim = picked;
        }
      });
    }
  }

  Future<void> _salvar() async {
    if (_dataEscolhida == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escolha uma data.')));
       return;
    }
    if (!_diaTodo && (_inicio == null || _fim == null)) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escolha o horário de início e fim.')));
       return;
    }

    setState(() => _isSaving = true);
    try {
      await _repo.addAgendaBlock(
        professionalId: _repo.currentUserId!,
        data: DateFormat('yyyy-MM-dd').format(_dataEscolhida!),
        diaTodo: _diaTodo,
        horaInicio: _inicio != null ? '${_inicio!.hour.toString().padLeft(2, '0')}:${_inicio!.minute.toString().padLeft(2, '0')}' : null,
        horaFim: _fim != null ? '${_fim!.hour.toString().padLeft(2, '0')}:${_fim!.minute.toString().padLeft(2, '0')}' : null,
        motivo: _motivoController.text,
      );

      // Notificações
      final userId = _repo.currentUserId;
      if (userId != null) {
        final dateStr = DateFormat('dd/MM/yyyy').format(_dataEscolhida!);
        final rangeStr = _diaTodo ? 'Dia Inteiro' : 'das ${_inicio!.format(context)} às ${_fim!.format(context)}';
        
        // Notifica clientes afetados
        await _notificationRepo.notifyAffectedClients(
          professionalId: userId,
          date: _dataEscolhida!,
          startStr: _diaTodo ? null : '${_inicio!.hour.toString().padLeft(2, '0')}:${_inicio!.minute.toString().padLeft(2, '0')}:00',
          endStr: _diaTodo ? null : '${_fim!.hour.toString().padLeft(2, '0')}:${_fim!.minute.toString().padLeft(2, '0')}:00',
          message: 'O profissional teve uma alteração na agenda para o dia $dateStr ($rangeStr). Se você tinha um agendamento, entre em contato para confirmar ou reagendar.',
        );

        // Notifica o profissional
        String profMsg = 'Você bloqueou sua agenda para o dia $dateStr ($rangeStr).';
        if (_motivoController.text.isNotEmpty) {
          profMsg += '\nMotivo: ${_motivoController.text}';
        }

        await _notificationRepo.sendNotification(
          userId: userId,
          titulo: 'Agenda Bloqueada',
          mensagem: profMsg,
          tipo: 'agenda',
        );
      }

      widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
        setState(() => _isSaving = false);
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
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Fechar Agenda',
              style: TextStyle(fontFamily: 'Playfair Display', 
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _dataEscolhida != null 
                  ? DateFormat('dd/MM/yyyy').format(_dataEscolhida!)
                  : 'Selecionar Data',
                style: TextStyle(fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _dataEscolhida != null ? primaryColor : Colors.grey,
                ),
              ),
              trailing: Icon(Icons.calendar_today, color: primaryColor),
              onTap: _selecionarData,
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: primaryColor,
              title: Text('Dia todo', style: TextStyle(fontWeight: FontWeight.w800)),
              value: _diaTodo,
              onChanged: (v) => setState(() => _diaTodo = v),
            ),
            if (!_diaTodo) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _selecionarHora(true),
                      icon: const Icon(Icons.access_time, size: 16),
                      label: Text(_inicio != null ? '${_inicio!.hour.toString().padLeft(2,'0')}:${_inicio!.minute.toString().padLeft(2,'0')}' : 'Início'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _selecionarHora(false),
                      icon: const Icon(Icons.access_time, size: 16),
                      label: Text(_fim != null ? '${_fim!.hour.toString().padLeft(2,'0')}:${_fim!.minute.toString().padLeft(2,'0')}' : 'Fim'),
                    ),
                  ),
                ],
              )
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _motivoController,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _salvar,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Salvar Bloqueio'),
            )
          ],
        ),
      ),
    );
  }
}

