import 'package:app_clinica_estetica/core/data/repositories/supabase_admin_log_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_clinica_estetica/core/data/models/service_model.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_service_repository.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_professional_repository.dart';
import 'package:app_clinica_estetica/core/theme/app_button_styles.dart';
import 'package:app_clinica_estetica/core/utils/string_utils.dart';

class AdminVincularServicoPage extends StatefulWidget {
  final Map<String, dynamic> professional;

  const AdminVincularServicoPage({super.key, required this.professional});

  @override
  State<AdminVincularServicoPage> createState() => _AdminVincularServicoPageState();
}

class _AdminVincularServicoPageState extends State<AdminVincularServicoPage> {
  final _serviceRepo = SupabaseServiceRepository();
  final _profRepo = SupabaseProfessionalRepository();

  List<ServiceModel> _allServices = [];
  Set<String> _linkedServiceIds = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final services = await _serviceRepo.getActiveServices();
      final linkedIds = await _profRepo.getLinkedServiceIds(widget.professional['id']);

      setState(() {
        _allServices = services;
        _linkedServiceIds = linkedIds.toSet();
      });
    } catch (e) {
      debugPrint('Erro ao carregar dados para vinculação: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar serviços. Tente novamente.')),
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
      await _profRepo.saveLinkedServices(
        widget.professional['id'],
        _linkedServiceIds.toList(),
      );

      // Log da ação
      await SupabaseAdminLogRepository().logAction(
        acao: 'Vincular Serviços',
        detalhes: 'Profissional: ${widget.professional['nome']}, Serviços: ${_linkedServiceIds.length} vinculados',
        tabelaAfetada: 'profissional_servicos',
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
                                'Selecione os serviços que este profissional pode realizar na clínica.',
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
                child: _allServices.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhum serviço ativo encontrado.',
                          style: TextStyle(color: Colors.black54,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: _allServices.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final service = _allServices[index];
                          final isLinked = _linkedServiceIds.contains(service.id);

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isLinked 
                                    ? primaryColor.withAlpha(76) // 0.3 * 255 = 76.5
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(7), // 0.03 * 255 = 7.65
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
                                    _linkedServiceIds.add(service.id);
                                  } else {
                                    _linkedServiceIds.remove(service.id);
                                  }
                                });
                              },
                              activeColor: primaryColor,
                              checkColor: Colors.white,
                              title: Text(
                                service.nome,
                                style: TextStyle(fontWeight: FontWeight.bold,
                                  color: isLinked ? primaryColor : Colors.black87,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Text(
                                '${service.duracaoMinutos} min • R\$ ${service.preco.toStringAsFixed(2)}',
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
                                  image: service.imagemUrl != null 
                                      ? DecorationImage(
                                          image: NetworkImage(service.imagemUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: service.imagemUrl == null
                                    ? const Icon(Icons.spa, color: accentColor)
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
              color: Colors.black.withAlpha(12), // 0.05 * 255
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveLinks,
            style: AppButtonStyles.primary(),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(StringUtils.toTitleCase('salvar vínculos')),
          ),
        ),
      ),
    );
  }
}

