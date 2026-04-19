import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_clinica_estetica/core/data/models/pacote_contratado_model.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_package_repository.dart';
import 'package:app_clinica_estetica/core/data/models/profile_model.dart';
import 'package:app_clinica_estetica/features/auth/data/auth_service.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';

class MeusPacotesPage extends StatefulWidget {
  const MeusPacotesPage({super.key});

  @override
  State<MeusPacotesPage> createState() => _MeusPacotesPageState();
}

class _MeusPacotesPageState extends State<MeusPacotesPage> {
  late final SupabasePackageRepository _packageRepo;
  bool _isLoading = true;
  List<PacoteContratadoModel> _pacotes = [];

  @override
  void initState() {
    super.initState();
    _packageRepo = SupabasePackageRepository(Supabase.instance.client);
    _loadPacotes();
  }

  Future<void> _loadPacotes() async {
    setState(() => _isLoading = true);
    try {
      final userId = AuthService.currentUserId;
      if (userId != null) {
        final results = await _packageRepo.getContratados(clienteId: userId);
        setState(() {
          _pacotes = results;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Erro ao carregar pacotes: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar seus pacotes: $e')),
        );
      }
    }
  }

  Future<void> _cancelarPacote(PacoteContratadoModel pacote) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Cancelar Pacote', 
          style: TextStyle(fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        content: Text('Tem certeza que deseja cancelar este pacote? Esta ação cancelará o contrato e todos os agendamentos futuros vinculados a ele.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Não', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sim, Cancelar', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      setState(() => _isLoading = true);
      try {
        await _packageRepo.cancelContract(pacote.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pacote cancelado com sucesso.')),
          );
          _loadPacotes();
        }
      } catch (e) {
        debugPrint('Erro ao cancelar pacote: $e');
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao cancelar pacote: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Meus Pacotes',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _pacotes.isEmpty
              ? _buildEmptyState(AppColors.primary)
              : RefreshIndicator(
                  onRefresh: _loadPacotes,
                  color: AppColors.accent,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: _pacotes.length,
                    itemBuilder: (context, index) {
                      return _buildPackageCard(_pacotes[index], AppColors.primary, AppColors.accent);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState(Color primary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: primary.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            'Nenhum pacote encontrado',
            style: TextStyle(fontFamily: 'Playfair Display', 
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Você ainda não possui pacotes contratados.',
            style: TextStyle(fontSize: 14,
              color: primary.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(PacoteContratadoModel pacote, Color primary, Color accent) {
    final progresso = pacote.sessoesRealizadas / pacote.sessoesTotais;
    final concluido = pacote.status.toLowerCase() == 'concluido' || pacote.sessoesRealizadas >= pacote.sessoesTotais;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, primary.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          pacote.template?.titulo ?? 'Pacote de Tratamento',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Playfair Display',
                          ),
                        ),
                      ),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: concluido ? Colors.green.withOpacity(0.2) : accent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: concluido ? Colors.green : accent, width: 1),
                              ),
                              child: Text(
                                concluido ? 'CONCLUÍDO' : 'EM USO',
                                style: TextStyle(color: concluido ? Colors.greenAccent : Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Payment Status
                            Text(
                              pacote.caixaId != null ? 'Pago' : 'Não Pago',
                              style: TextStyle(color: pacote.caixaId != null ? Colors.white70 : Colors.redAccent[100],
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Text(
                    pacote.template?.descricao ?? 'Tratamento estético personalizado',
                    style: TextStyle(color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sessões concluídas',
                        style: TextStyle(color: Colors.grey[600],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${pacote.sessoesRealizadas} / ${pacote.sessoesTotais}',
                        style: TextStyle(color: primary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Stack(
                    children: [
                      Container(
                        height: 8,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        height: 8,
                        width: MediaQuery.of(context).size.width * 0.7 * progresso,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(Icons.calendar_month_outlined, size: 16, color: accent),
                      const SizedBox(width: 8),
                      Text(
                        'Contratado em ${_formatDate(pacote.criadoEm)}',
                        style: TextStyle(color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // If no professional is associated, we might need a default one
                        // for the session selection screen to function.
                        if (pacote.profissional != null || pacote.template != null) {
                          context.push('/pacote-sessao-selecao', extra: {
                            'pacote': pacote.template!,
                            'profissional': pacote.profissional ?? ProfileModel(
                              id: pacote.profissionalId ?? '',
                              nomeCompleto: 'Profissional',
                              email: '',
                              tipo: 'PROFISSIONAL',
                              criadoEm: DateTime.now(),
                            ),
                            'contratoId': pacote.id,
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Visualizar Pacote',
                        style: TextStyle(fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  if (pacote.sessoesRealizadas == 0 && pacote.status != 'cancelado') ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => _cancelarPacote(pacote),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: Text(
                          'Cancelar Pacote',
                          style: TextStyle(fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

