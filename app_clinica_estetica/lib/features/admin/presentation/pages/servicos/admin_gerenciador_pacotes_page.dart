import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_clinica_estetica/core/data/models/pacote_template_model.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_package_repository.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_admin_log_repository.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';

class AdminGerenciadorPacotesPage extends StatefulWidget {
  const AdminGerenciadorPacotesPage({super.key});

  @override
  State<AdminGerenciadorPacotesPage> createState() => _AdminGerenciadorPacotesPageState();
}

class _AdminGerenciadorPacotesPageState extends State<AdminGerenciadorPacotesPage> {
  final TextEditingController _searchController = TextEditingController();
  late final SupabasePackageRepository _packageRepo;
  
  bool _isLoading = true;
  List<PacoteTemplateModel> _pacotes = [];
  List<PacoteTemplateModel> _filteredPacotes = [];

  @override
  void initState() {
    super.initState();
    _packageRepo = SupabasePackageRepository(Supabase.instance.client);
    _loadData();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilter);
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredPacotes = _pacotes.where((p) {
        return p.titulo.toLowerCase().contains(query) ||
               (p.descricao?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final pacotes = await _packageRepo.getTemplates();
      setState(() {
        _pacotes = pacotes;
        _filteredPacotes = pacotes;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar pacotes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar pacotes: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleStatus(PacoteTemplateModel pacote) async {
    try {
      final novoStatus = !pacote.ativo;
      final updated = PacoteTemplateModel(
        id: pacote.id,
        titulo: pacote.titulo,
        descricao: pacote.descricao,
        valorTotal: pacote.valorTotal,
        quantidadeSessoes: pacote.quantidadeSessoes,
        imagemUrl: pacote.imagemUrl,
        ativo: novoStatus,
      );
      
      await _packageRepo.updateTemplate(updated);
      
      await SupabaseAdminLogRepository().logAction(
        acao: novoStatus ? 'Ativar Pacote' : 'Desativar Pacote',
        tabelaAfetada: 'pacotes_template',
        itemId: pacote.id,
        detalhes: 'Pacote: ${pacote.titulo}',
      );

      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar status: $e')),
        );
      }
    }
  }

  Future<void> _deletePacote(PacoteTemplateModel pacote) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir Pacote', style: TextStyle(fontFamily: 'Playfair Display', color: AppColors.primary)),
        content: Text('Tem certeza que deseja excluir o pacote "${pacote.titulo}"?', style: const TextStyle()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: AppButtonStyles.small,
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppButtonStyles.small.copyWith(
              foregroundColor: WidgetStateProperty.all(Colors.red),
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _packageRepo.deleteTemplate(pacote.id);
        
        await SupabaseAdminLogRepository().logAction(
          acao: 'Excluir Pacote (Soft)',
          tabelaAfetada: 'pacotes_template',
          itemId: pacote.id,
          detalhes: 'Pacote inativado por exclusão: ${pacote.titulo}',
        );

        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryGreen = AppColors.primary;
    final goldColor = AppColors.accent;
    final bgColor = AppColors.background;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Gerenciar Pacotes', style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontFamily: 'Playfair Display')),
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryGreen),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: goldColor,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pacotes',
                        style: TextStyle(fontFamily: 'Playfair Display', 
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: goldColor,
                        ),
                      ),
                      Text(
                        '${_filteredPacotes.length} Total',
                        style: TextStyle(fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: goldColor,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/admin/servicos/pacotes/novo').then((v) {
                      if (v == true) _loadData();
                    }),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Novo pacote'),
                    style: AppButtonStyles.primary,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Pesquisar pacotes...',
                  prefixIcon: Icon(Icons.search, color: primaryGreen),
                  filled: true,
                  fillColor: Colors.white,
                  hintStyle: const TextStyle(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: goldColor))
                    : _filteredPacotes.isEmpty
                        ? Center(
                            child: Text(
                              'Nenhum pacote encontrado.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredPacotes.length,
                            itemBuilder: (context, index) {
                              final pacote = _filteredPacotes[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      // Image
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: pacote.imagemUrl != null && pacote.imagemUrl!.isNotEmpty
                                            ? Image.network(
                                                pacote.imagemUrl!,
                                                width: 80,
                                                height: 80,
                                                fit: BoxFit.cover,
                                              )
                                            : Container(
                                                width: 80,
                                                height: 80,
                                                color: Colors.grey[200],
                                                child: const Icon(Icons.inventory_2, color: Colors.grey, size: 30),
                                              ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              pacote.titulo,
                                              style: TextStyle(fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: primaryGreen,
                                                fontFamily: 'Playfair Display',
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            if (pacote.isPromocao) ...[
                                              Row(
                                                children: [
                                                  Text(
                                                    pacote.formattedPrice,
                                                    style: TextStyle(fontSize: 14,
                                                      fontWeight: FontWeight.w500,
                                                      color: Colors.grey,
                                                      decoration: TextDecoration.lineThrough,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    pacote.formattedPromotionalPrice,
                                                    style: TextStyle(fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: goldColor,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '(${pacote.quantidadeSessoes} Sessões)',
                                                    style: TextStyle(fontSize: 12,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ] else ...[
                                              Text(
                                                '${pacote.quantidadeSessoes} Sessões • ${pacote.formattedPrice}',
                                                style: TextStyle(fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: goldColor,
                                                ),
                                              ),
                                            ],
                                            if (pacote.descricao != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                pacote.descricao!,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              )
                                            ],
                                          ],
                                        ),
                                      ),
                                      // Actions
                                      Column(
                                        children: [
                                          Switch(
                                            value: pacote.ativo,
                                            onChanged: (val) => _toggleStatus(pacote),
                                            activeThumbColor: Colors.white,
                                            activeTrackColor: AppColors.success,
                                            inactiveThumbColor: Colors.grey[400],
                                            inactiveTrackColor: Colors.grey[300],
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: Icon(Icons.edit, color: primaryGreen, size: 20),
                                                onPressed: () => context.push('/admin/servicos/pacotes/editar', extra: pacote).then((v) {
                                                  if (v == true) _loadData();
                                                }),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                                onPressed: () => _deletePacote(pacote),
                                              ),
                                            ],
                                          )
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

