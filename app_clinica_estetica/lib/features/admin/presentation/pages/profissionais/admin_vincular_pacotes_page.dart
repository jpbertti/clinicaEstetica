import 'package:app_clinica_estetica/core/data/repositories/supabase_admin_log_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_clinica_estetica/core/data/models/pacote_template_model.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_package_repository.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_professional_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminVincularPacotesPage extends StatefulWidget {
  final Map<String, dynamic> professional;

  const AdminVincularPacotesPage({super.key, required this.professional});

  @override
  State<AdminVincularPacotesPage> createState() => _AdminVincularPacotesPageState();
}

class _AdminVincularPacotesPageState extends State<AdminVincularPacotesPage> {
  late final SupabasePackageRepository _packageRepo;
  final _profRepo = SupabaseProfessionalRepository();

  List<PacoteTemplateModel> _allPackages = [];
  Set<String> _linkedPackageIds = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _packageRepo = SupabasePackageRepository(Supabase.instance.client);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final packages = await _packageRepo.getTemplates();
      final linkedIds = await _profRepo.getLinkedPackageIds(widget.professional['id']);

      setState(() {
        _allPackages = packages.where((p) => p.ativo).toList();
        _linkedPackageIds = linkedIds.toSet();
      });
    } catch (e) {
      debugPrint('Erro ao carregar dados para vinculação: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar projetos. Tente novamente.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveLinks() async {
    setState(() => _isSaving = true);
    try {
      await _profRepo.saveLinkedPackages(
        widget.professional['id'],
        _linkedPackageIds.toList(),
      );

      // Log da ação
      await SupabaseAdminLogRepository().logAction(
        acao: 'Vincular Projetos',
        detalhes: 'Profissional: ${widget.professional['nome_completo']}, Projetos: ${_linkedPackageIds.length} vinculados',
        tabelaAfetada: ' profissional_pacotes',
        itemId: widget.professional['id'],
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vínculos salvos com sucesso!'),
            backgroundColor: Color(0xFF2D5A46),
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      debugPrint('Erro ao salvar vínculos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2F5E46);
    const accentColor = Color(0xFFC7A36B);
    const bgColor = Color(0xFFF6F4EF);

    final profName = widget.professional['nome_completo'] ?? 'Profissional';

    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: primaryColor))
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: primaryColor.withOpacity(0.1),
                          backgroundImage: widget.professional['avatar_url'] != null 
                              ? NetworkImage(widget.professional['avatar_url']) 
                              : null,
                          child: widget.professional['avatar_url'] == null
                              ? const Icon(Icons.person, color: primaryColor, size: 32)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profName,
                                style: TextStyle(fontFamily: 'Playfair Display', 
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Selecione os projetos que este profissional poderá realizar agendamentos.',
                                style: TextStyle(fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _allPackages.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhum projeto ativo encontrado.',
                          style: TextStyle(color: Colors.black54,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: _allPackages.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final package = _allPackages[index];
                          final isLinked = _linkedPackageIds.contains(package.id);

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isLinked 
                                    ? primaryColor.withAlpha(76)
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(7),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: CheckboxListTile(
                              value: isLinked,
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    _linkedPackageIds.add(package.id);
                                  } else {
                                    _linkedPackageIds.remove(package.id);
                                  }
                                });
                              },
                              activeColor: primaryColor,
                              checkColor: Colors.white,
                              title: Text(
                                package.titulo,
                                style: TextStyle(fontWeight: FontWeight.bold,
                                  color: isLinked ? primaryColor : Colors.black87,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Text(
                                '${package.quantidadeSessoes} sessões • R\$ ${package.valorTotal.toStringAsFixed(2)}',
                                style: TextStyle(fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                              secondary: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(12),
                                  image: package.imagemUrl != null 
                                      ? DecorationImage(
                                          image: NetworkImage(package.imagemUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: package.imagemUrl == null
                                    ? const Icon(Icons.inventory_2_outlined, color: accentColor)
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
      bottomNavigationBar: _isLoading ? null : Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveLinks,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'SALVAR VÍNCULOS',
                    style: TextStyle(fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

