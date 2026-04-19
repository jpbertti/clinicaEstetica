import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_clinica_estetica/core/widgets/app_bottom_nav_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_clinica_estetica/core/app_config.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';

class AjudaSuportePage extends StatefulWidget {
  const AjudaSuportePage({super.key});

  @override
  State<AjudaSuportePage> createState() => _AjudaSuportePageState();
}

class _AjudaSuportePageState extends State<AjudaSuportePage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  String _endereco = AppConfig.endereco;
  String _whatsapp = AppConfig.whatsapp;
  String _emailContato = AppConfig.emailContato ?? 'suporte@clinicapremium.com';
  String _horariosFormatados = 'Carregando horários...';

  @override
  void initState() {
    super.initState();
    _fetchClinicaData();
  }

  Future<void> _fetchClinicaData() async {
    try {
      final results = await Future.wait([
        _supabase.from('configuracoes_clinica').select().maybeSingle(),
        _supabase.from('horarios_clinica').select().order('dia_semana'),
      ]);

      if (results[0] != null) {
        final config = results[0] as Map<String, dynamic>;
        setState(() {
          _endereco = config['endereco'] ?? _endereco;
          _whatsapp = config['whatsapp'] ?? _whatsapp;
          _emailContato = config['email_contato'] ?? _emailContato;
        });
      }

      if (results[1] != null) {
        final hours = results[1] as List<dynamic>;
        final List<String> lines = [];
        final dias = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
        
        for (var h in hours) {
          final diaIdx = h['dia_semana'] as int;
          if (h['fechado'] == true) {
            lines.add('${dias[diaIdx]}: Fechado');
          } else {
            final abert = (h['hora_inicio'] as String).substring(0, 5);
            final fech = (h['hora_fim'] as String).substring(0, 5);
            lines.add('${dias[diaIdx]}: $abert às $fech');
          }
        }
        
        setState(() {
          _horariosFormatados = lines.isEmpty ? 'Horários não informados' : lines.join('\n');
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar dados da clínica: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                      style: IconButton.styleFrom(
                        splashFactory: NoSplash.splashFactory,
                        hoverColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        overlayColor: Colors.transparent,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Ajuda & Suporte',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Playfair Display', 
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // Equalizer for center align
                  ],
                ),
              ),

              // Divider below title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    Divider(
                      color: AppColors.accent.withOpacity(0.2),
                      thickness: 1,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Category Grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                  children: [
                    _construirCardCategoria(
                      context,
                      'Dúvidas Frequentes',
                      Icons.help_outline,
                      AppColors.primary,
                      AppColors.card,
                      () => _mostrarFAQ(context, 'Dúvidas Frequentes', [
                        {'p': 'Como funciona o app?', 'r': 'O app permite agendar procedimentos, gerenciar seus horários e receber avisos sobre sua beleza.'},
                        {'p': 'Onde fica a clínica?', 'r': 'Estamos localizados em: $_endereco.'},
                        {'p': 'Horário de funcionamento', 'r': _horariosFormatados},
                      ]),
                    ),
                    _construirCardCategoria(
                      context,
                      'Pagamentos',
                      Icons.payments_outlined,
                      AppColors.primary,
                      AppColors.card,
                      () => _mostrarFAQ(context, 'Pagamentos', [
                        {'p': 'Quais as formas de pagamento?', 'r': 'Aceitamos cartões de crédito, débito, PIX e dinheiro diretamente na clínica.'},
                        {'p': 'Posso parcelar?', 'r': 'Sim, parcelamos em até 6x sem juros em procedimentos acima de R\$ 500,00.'},
                        {'p': 'É seguro pagar pelo app?', 'r': 'No momento, os pagamentos são realizados presencialmente na clínica.'},
                      ]),
                    ),
                    _construirCardCategoria(
                      context,
                      'Procedimentos',
                      Icons.medical_services_outlined,
                      AppColors.primary,
                      AppColors.card,
                      () => _mostrarFAQ(context, 'Procedimentos', [
                        {'p': 'Como escolher o serviço?', 'r': 'Você pode ver todos os detalhes na aba "Serviços" e escolher o que melhor se adapta a você.'},
                        {'p': 'Preciso de avaliação?', 'r': 'Alguns procedimentos exigem avaliação prévia. Nossos profissionais informarão no primeiro contato.'},
                        {'p': 'Tem contraindicações?', 'r': 'Cada serviço tem suas especificações. Consulte a descrição detalhada.'},
                      ]),
                    ),
                    _construirCardCategoria(
                      context,
                      'Agendamentos',
                      Icons.calendar_today_outlined,
                      AppColors.primary,
                      AppColors.card,
                      () => _mostrarFAQ(context, 'Agendamentos', [
                        {'p': 'Como desmarcar?', 'r': 'Acesse "Minha Agenda", selecione o horário e clique em cancelar (mínimo 24h de antecedência).'},
                        {'p': 'Posso reagendar?', 'r': 'Sim, dentro do prazo de 24h você pode trocar o horário diretamente no app.'},
                        {'p': 'E se eu me atrasar?', 'r': 'Tolerância de 15 minutos. Após isso, o atendimento pode ser reagendado.'},
                      ]),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Contact Channels
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Canais de Atendimento',
                      style: TextStyle(fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _construirItemContato(
                      'Falar com Atendimento',
                      'Inicie uma conversa no WhatsApp',
                      Icons.chat_bubble_outline,
                      _abrirWhatsApp,
                    ),
                    const SizedBox(height: 12),
                    _construirItemContato(
                      'Enviar E-mail',
                      'Retornamos em até 24 horas',
                      Icons.email_outlined,
                      _abrirEmail,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              const SizedBox(height: 48),

              // Footer
              Center(
                child: Text(
                  'Versão 2.4.0 - Aesthetic Clinic Premium',
                  style: TextStyle(fontSize: 12,
                    color: AppColors.textSecondary.withOpacity(0.6),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavigationBar(activeIndex: 3),
    );
  }

  Future<void> _abrirWhatsApp() async {
    final phone = _whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
    const message = "Olá! Gostaria de tirar uma dúvida sobre os serviços da clínica.";
    final url = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(message)}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _abrirEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: _emailContato,
      query: encodeQueryParameters(<String, String>{
        'subject': 'Suporte App - Clínica Estética',
      }),
    );
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    }
  }

  String? encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  void _mostrarFAQ(BuildContext context, String title, List<Map<String, String>> questions) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                title,
                style: const TextStyle(fontFamily: 'Playfair Display', 
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  itemCount: questions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final item = questions[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withOpacity(0.05)),
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['p']!,
                              style: const TextStyle(fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item['r']!,
                              style: const TextStyle(fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirCardCategoria(
    BuildContext context,
    String title,
    IconData icon,
    Color primary,
    Color card,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primary.withOpacity(0.05)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: primary, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirItemContato(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    const container = AppColors.softGreen;
    const primary = AppColors.primary;
    const secondary = AppColors.textSecondary;
    const accent = AppColors.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primary.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: container,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: primary, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: secondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

