import 'package:app_clinica_estetica/core/theme/app_colors.dart';
import 'package:app_clinica_estetica/core/data/models/appointment_model.dart';
import 'package:app_clinica_estetica/core/data/models/evaluation_model.dart';
import 'package:app_clinica_estetica/core/data/repositories/appointment_repository.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_appointment_repository.dart';
import 'package:app_clinica_estetica/features/auth/data/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_clinica_estetica/core/widgets/app_bottom_nav_bar.dart';
import 'package:intl/intl.dart';

class HistoricoAvaliacoesPage extends StatefulWidget {
  const HistoricoAvaliacoesPage({super.key});

  @override
  State<HistoricoAvaliacoesPage> createState() => _HistoricoAvaliacoesPageState();
}

class _HistoricoAvaliacoesPageState extends State<HistoricoAvaliacoesPage> {
  final IAppointmentRepository _appointmentRepo = SupabaseAppointmentRepository();
  List<EvaluationModel> _avaliacoes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarAvaliacoes();
  }

  Future<void> _carregarAvaliacoes() async {
    setState(() => _isLoading = true);
    try {
      final userId = AuthService.currentUserId;
      if (userId != null) {
        final data = await _appointmentRepo.getUserEvaluations(userId);
        setState(() {
          _avaliacoes = data;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar avaliações: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _podeEditar(DateTime? dataAvaliacao) {
    if (dataAvaliacao == null) return false;
    final diff = DateTime.now().difference(dataAvaliacao).inDays;
    return diff <= 7;
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Row(
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
                          'Minhas Avaliações',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Playfair Display', 
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
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

            // Review List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _avaliacoes.isEmpty
                      ? const Center(
                          child: Text(
                            'Você ainda não fez avaliações.',
                            style: TextStyle(color: AppColors.primary),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _carregarAvaliacoes,
                          color: AppColors.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            itemCount: _avaliacoes.length,
                            itemBuilder: (context, index) {
                              final avaliacao = _avaliacoes[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: _construirCardAvaliacao(
                                  avaliacao: avaliacao,
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavigationBar(activeIndex: 3),
    );
  }

  Widget _construirCardAvaliacao({
    required EvaluationModel avaliacao,
  }) {
    const primary = AppColors.primary;
    const accent = AppColors.accent;
    const textPrimary = AppColors.textPrimary;
    final formattedDate = avaliacao.criadoEm != null
        ? DateFormat("d 'de' MMM 'de' y", 'pt_BR').format(avaliacao.criadoEm!)
        : 'Data desconhecida';

    final podeEditar = _podeEditar(avaliacao.criadoEm);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      avaliacao.serviceName ?? 'Procedimento',
                      style: TextStyle(fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AVALIAÇÃO EM $formattedDate'.toUpperCase(),
                      style: TextStyle(fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: primary.withOpacity(0.6),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    Icons.star,
                    color: index < avaliacao.nota
                        ? accent
                        : accent.withOpacity(0.2),
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (avaliacao.fotos.isNotEmpty) ...[
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: NetworkImage(avaliacao.fotos.first),
                      fit: BoxFit.cover,
                    ),
                    border: Border.all(color: accent.withOpacity(0.2)),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Text(
                  avaliacao.comentario ?? 'Sem comentário.',
                  style: TextStyle(fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: textPrimary.withOpacity(0.8),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: accent.withOpacity(0.1)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person, color: primary, size: 14),
                    ),
                    const SizedBox(width: 8),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 12,
                          color: primary,
                        ),
                        children: [
                          const TextSpan(text: 'Profissional: '),
                          TextSpan(
                            text: avaliacao.professionalName ?? 'Profissional',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (podeEditar)
                  GestureDetector(
                    onTap: () async {
                      // Para editar, precisamos converter a avaliação de volta em um atendimento
                      // ou passar os dados necessários.
                      final appointment = AppointmentModel(
                        id: avaliacao.agendamentoId,
                        clienteId: avaliacao.clienteId,
                        profissionalId: avaliacao.profissionalId,
                        servicoId: '', // Não é crítico para a edição
                        dataHora: avaliacao.appointmentDate ?? DateTime.now(),
                        status: 'concluido',
                        criadoEm: DateTime.now(),
                        serviceName: avaliacao.serviceName,
                        professionalName: avaliacao.professionalName,
                      );
                      
                      await context.push('/avaliar-atendimento', extra: {
                        'appointment': appointment,
                        'initialEvaluation': avaliacao,
                      });
                      _carregarAvaliacoes();
                    },
                    child: Text(
                      'EDITAR',
                      style: TextStyle(fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: accent,
                        letterSpacing: 0.5,
                      ),
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

