import 'package:flutter/material.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_professional_repository.dart';

class AdminProfessionalLunchPage extends StatefulWidget {
  final Map<String, dynamic> professional;
  const AdminProfessionalLunchPage({super.key, required this.professional});

  @override
  State<AdminProfessionalLunchPage> createState() => _AdminProfessionalLunchPageState();
}

class _AdminProfessionalLunchPageState extends State<AdminProfessionalLunchPage> {
  final _profRepo = SupabaseProfessionalRepository();
  bool _isLoading = true;
  List<Map<String, dynamic>> _lunchHours = [];

  // Dias da semana em PT-BR
  final List<String> _days = [
    'Domingo',
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _profRepo.getProfessionalLunchHours(widget.professional['id']);
      
      // Inicializar lista com todos os dias se estiver vazia
      final List<Map<String, dynamic>> initialized = [];
      for (int i = 0; i < 7; i++) {
        final existing = data.where((d) => d['dia_semana'] == i).toList();
        if (existing.isNotEmpty) {
          initialized.add(existing.first);
        } else {
          initialized.add({
            'dia_semana': i,
            'hora_inicio': '12:00:00',
            'hora_fim': '13:00:00',
            'ativo': false,
          });
        }
      }
      
      setState(() {
        _lunchHours = initialized;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar horários de almoço: $e');
      setState(() => _isLoading = false);
    }
  }

  void _updateLocalTime(int index, bool isStart, String time) {
    setState(() {
      if (isStart) {
        _lunchHours[index]['hora_inicio'] = '$time:00';
      } else {
        _lunchHours[index]['hora_fim'] = '$time:00';
      }
    });
    _saveUpdate(index);
  }

  Future<void> _toggleDay(int index, bool value) async {
    setState(() {
      _lunchHours[index]['ativo'] = value;
    });
    _saveUpdate(index);
  }

  Future<void> _saveUpdate(int index) async {
    final dayData = _lunchHours[index];
    try {
      await _profRepo.updateProfessionalLunchHour(
        professionalId: widget.professional['id'],
        diaSemana: dayData['dia_semana'],
        horaInicio: dayData['hora_inicio'],
        horaFim: dayData['hora_fim'],
        ativo: dayData['ativo'],
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2F5E46);
    const accentColor = Color(0xFFC7A36B);
    const backgroundColor = Color(0xFFF6F4EF);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: primaryColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'HORÁRIO DE ALMOÇO',
          style: TextStyle(fontFamily: 'Playfair Display', 
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: primaryColor))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Defina o intervalo de descanso para ${widget.professional['nome_completo']} em cada dia da semana.',
                  style: TextStyle(fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 7,
                    separatorBuilder: (context, index) => Divider(height: 1, color: primaryColor.withOpacity(0.05)),
                    itemBuilder: (context, index) {
                      final dayData = _lunchHours[index];
                      final bool isActive = dayData['ativo'] ?? false;
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                _days[index],
                                style: TextStyle(fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isActive ? primaryColor : Colors.grey,
                                ),
                              ),
                            ),
                            if (isActive) ...[
                              _buildTimeSelector(
                                dayData['hora_inicio'].substring(0, 5),
                                (time) => _updateLocalTime(index, true, time),
                                primaryColor,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text('até', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ),
                              _buildTimeSelector(
                                dayData['hora_fim'].substring(0, 5),
                                (time) => _updateLocalTime(index, false, time),
                                primaryColor,
                              ),
                            ] else ...[
                              Expanded(
                                flex: 3,
                                child: Center(
                                  child: Text(
                                    'Sem Intervalo',
                                    style: TextStyle(fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.grey.withOpacity(0.5),
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 8),
                            Switch.adaptive(
                              value: isActive,
                              onChanged: (v) => _toggleDay(index, v),
                              activeTrackColor: accentColor.withOpacity(0.3),
                              activeColor: accentColor,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 40),
                Center(
                  child: Text(
                    'Os horários fora deste intervalo serão considerados disponíveis para agendamento, respeitando o horário de funcionamento da clínica.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.black38,
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildTimeSelector(String time, Function(String) onSelected, Color primaryColor) {
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
            color: primaryColor,
          ),
        ),
      ),
    );
  }
}

