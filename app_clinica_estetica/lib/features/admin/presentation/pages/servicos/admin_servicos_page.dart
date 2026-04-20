import 'package:app_clinica_estetica/core/data/repositories/supabase_admin_log_repository.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_service_repository.dart';
import 'package:app_clinica_estetica/core/data/models/pacote_template_model.dart';
import 'package:app_clinica_estetica/core/data/models/service_model.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_package_repository.dart';
import 'package:intl/intl.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';
import 'package:app_clinica_estetica/core/theme/app_button_styles.dart';

class AdminServicosPage extends StatefulWidget {
  const AdminServicosPage({super.key});

  @override
  State<AdminServicosPage> createState() => _AdminServicosPageState();
}

class _AdminServicosPageState extends State<AdminServicosPage> {
  final TextEditingController _procedureSearchController = TextEditingController();
  final TextEditingController _categorySearchController = TextEditingController();
  final TextEditingController _packageSearchController = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _filteredCategories = [];
  List<Map<String, dynamic>> _procedures = [];
  List<Map<String, dynamic>> _filteredProcedures = [];
  List<PacoteTemplateModel> _pacotes = [];
  List<PacoteTemplateModel> _filteredPacotes = [];

  String? _selectedCategoryFilter;
  final GlobalKey _proceduresSectionKey = GlobalKey();
  final GlobalKey _packagesSectionKey = GlobalKey();

  // Icon Selection for Categories (String identifiers)
  final List<String> _iconOptions = [
    'spa',
    'face',
    'brush',
    'content_cut',
    'auto_awesome',
    'water_drop',
    'favorite',
    'health_and_safety',
    'sentiment_very_satisfied',
    'clean_hands',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _procedureSearchController.addListener(_applyFilters);
    _categorySearchController.addListener(_applyFilters);
    _packageSearchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _procedureSearchController.removeListener(_applyFilters);
    _categorySearchController.removeListener(_applyFilters);
    _packageSearchController.removeListener(_applyFilters);
    _procedureSearchController.dispose();
    _categorySearchController.dispose();
    _packageSearchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final procedureQuery = _procedureSearchController.text.toLowerCase();
    final categoryQuery = _categorySearchController.text.toLowerCase();
    final packageQuery = _packageSearchController.text.toLowerCase();
    
    setState(() {
      _filteredCategories = _categories.where((c) {
        final name = (c['nome'] ?? '').toString().toLowerCase();
        return name.contains(categoryQuery);
      }).toList();

      _filteredProcedures = _procedures.where((p) {
        final name = (p['nome'] ?? '').toString().toLowerCase();
        final cat = (p['categorias'] != null ? p['categorias']['nome'] : 'Geral').toString().toLowerCase();
        
        // Match text search
        bool matchesText = name.contains(procedureQuery) || cat.contains(procedureQuery);
        
        // Match category filter if any
        bool matchesCategory = true;
        if (_selectedCategoryFilter != null) {
          matchesCategory = cat == _selectedCategoryFilter!.toLowerCase();
        }
        
        return matchesText && matchesCategory;
      }).toList();

      _filteredPacotes = _pacotes.where((p) {
        final title = p.titulo.toLowerCase();
        final desc = p.descricao?.toLowerCase() ?? '';
        
        bool matchesText = title.contains(packageQuery) || desc.contains(packageQuery);
        
        bool matchesCategory = true;
        if (_selectedCategoryFilter != null) {
          // Find category name for p.categoriaId
          final catName = _categories.firstWhere(
            (c) => c['id'] == p.categoriaId,
            orElse: () => {'nome': ''}
          )['nome'].toString().toLowerCase();
          matchesCategory = catName == _selectedCategoryFilter!.toLowerCase();
        }
        
        return matchesText && matchesCategory;
      }).toList();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final categoriesResponse = await _supabase
          .from('categorias')
          .select()
          .order('ordem', ascending: true);
      
      final proceduresResponse = await _supabase
          .from('servicos')
          .select('*, categorias(nome)')
          .order('nome', ascending: true);

      final packagesResponse = await SupabasePackageRepository(_supabase).getTemplates();

      // Count procedures per category
      final List<Map<String, dynamic>> enrichedCategories = [];
      for (var cat in (categoriesResponse as List)) {
        final count = (proceduresResponse as List)
            .where((p) => p['categoria_id'] == cat['id'])
            .length;
        enrichedCategories.add({
          ...cat,
          'count': count,
        });
      }

      setState(() {
        _categories = enrichedCategories;
        _filteredCategories = enrichedCategories;
        _procedures = List<Map<String, dynamic>>.from(proceduresResponse);
        _filteredProcedures = _procedures;
        _pacotes = packagesResponse;
        _filteredPacotes = packagesResponse;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar dados: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleProcedureStatus(String id, bool currentStatus) async {
    try {
      await _supabase
          .from('servicos')
          .update({'ativo': !currentStatus})
          .eq('id', id);
      
      // Log da ação
      await SupabaseAdminLogRepository().logAction(
        acao: !currentStatus ? 'Ativar Procedimento' : 'Desativar Procedimento',
        tabelaAfetada: 'servicos',
        itemId: id,
      );

      _loadData(); // Refresh list
    } catch (e) {
      debugPrint('Erro ao atualizar status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar status: $e')),
        );
      }
    }
  }

  Future<void> _deleteProcedure(String id) async {
    final serviceRepo = SupabaseServiceRepository();
    
    // Check if procedure can be deleted
    final canDelete = await serviceRepo.canDeleteService(id);
    
    if (!canDelete) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exclusão Bloqueada'),
            content: const Text(
              'Este procedimento não pode ser excluído pois possui agendamentos ativos ou profissionais vinculados. '
              'Tente desativá-lo em vez de excluir.'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: AppButtonStyles.cancelButtonStyle(),
                child: Text('OK', style: AppButtonStyles.cancelTextStyle()),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir procedimento'),
        content: const Text('Tem certeza que deseja excluir permanentemente este procedimento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: AppButtonStyles.cancelButtonStyle(),
            child: Text('Cancelar', style: AppButtonStyles.cancelTextStyle()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppButtonStyles.small(backgroundColor: Colors.red),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabase.from('servicos').delete().eq('id', id);

        await SupabaseAdminLogRepository().logAction(
          acao: 'Excluir procedimento',
          tabelaAfetada: 'servicos',
          itemId: id,
        );

        if (mounted) _loadData();
      } catch (e) {
        debugPrint('Erro ao excluir: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir: $e')),
          );
        }
      }
    }
  }

  Future<String?> _uploadCategoryImage(Uint8List bytes, String? fileName) async {
    try {
      final extension = fileName?.split('.').last ?? 'jpg';
      final name = 'categorias/${DateTime.now().millisecondsSinceEpoch}.$extension';
      await _supabase.storage.from('perfis').uploadBinary(name, bytes);
      return _supabase.storage.from('perfis').getPublicUrl(name);
    } catch (e) {
      debugPrint('Erro no upload da categoria: $e');
      return null;
    }
  }

  void _showAddCategoryDialog({Map<String, dynamic>? category}) {
    final bool isEditing = category != null;
    final TextEditingController categoryController = TextEditingController(
      text: isEditing ? category['nome'] : '',
    );
    String tempSelectedIcon = 'spa';
    bool tempIsUsingIcon = true;
    Uint8List? tempImageBytes;
    XFile? tempImageFile;
    final ImagePicker picker = ImagePicker();
    
    if (isEditing && category['icone_url'] != null) {
      final String iconUrl = category['icone_url'];
      if (iconUrl.startsWith('http')) {
        tempIsUsingIcon = false;
        tempSelectedIcon = 'photo';
      } else {
        tempSelectedIcon = iconUrl;
        tempIsUsingIcon = true;
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isEditing ? 'Editar categoria' : 'Nova categoria',
            style: TextStyle(
              fontFamily: 'Playfair Display',
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: AppColors.primary.withAlpha(25), width: 3),
                  ),
                  child: ClipOval(
                    child: tempIsUsingIcon
                        ? Icon(_getIconData(tempSelectedIcon), size: 36, color: AppColors.primary)
                        : tempImageBytes != null
                            ? Image.memory(tempImageBytes!, fit: BoxFit.cover, width: 80, height: 80)
                            : (isEditing && category['icone_url'] != null && category['icone_url'].startsWith('http'))
                                ? Image.network(category['icone_url'], fit: BoxFit.cover, width: 80, height: 80)
                                : Icon(Icons.photo, size: 36, color: Colors.grey[300]),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: categoryController,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Nome da categoria',
                    hintStyle: const TextStyle(color: Colors.black26),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                
                SizedBox(
                  height: 120,
                  width: double.maxFinite,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: _iconOptions.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return GestureDetector(
                          onTap: () async {
                            final picked = await picker.pickImage(source: ImageSource.gallery);
                            if (picked != null) {
                              final bytes = await picked.readAsBytes();
                              setDialogState(() {
                                tempImageFile = picked;
                                tempImageBytes = bytes;
                                tempIsUsingIcon = false;
                              });
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: !tempIsUsingIcon ? AppColors.primary : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.add_a_photo,
                              size: 20,
                              color: !tempIsUsingIcon ? Colors.white : AppColors.primary,
                            ),
                          ),
                        );
                      }
                      
                      final iconName = _iconOptions[index - 1];
                      final isSelected = tempIsUsingIcon && tempSelectedIcon == iconName;
                      return GestureDetector(
                        onTap: () => setDialogState(() {
                          tempSelectedIcon = iconName;
                          tempIsUsingIcon = true;
                        }),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _getIconData(iconName),
                            size: 20,
                            color: isSelected ? Colors.white : AppColors.primary.withAlpha(128),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: AppButtonStyles.cancelButtonStyle(),
              child: Text('Cancelar', style: AppButtonStyles.cancelTextStyle()),
            ),
            ElevatedButton(
              onPressed: () async {
                if (categoryController.text.isNotEmpty) {
                  try {
                    String iconValue = tempSelectedIcon;
                    if (!tempIsUsingIcon) {
                      if (tempImageBytes != null) {
                        final uploadUrl = await _uploadCategoryImage(tempImageBytes!, tempImageFile?.name);
                        if (uploadUrl != null) {
                          iconValue = uploadUrl;
                        } else if (isEditing) {
                          iconValue = category['icone_url'];
                        }
                      } else if (isEditing) {
                        iconValue = category['icone_url'];
                      }
                    }
                    
                    if (isEditing) {
                      final newName = categoryController.text;

                      await _supabase.from('categorias').update({
                        'nome': newName,
                        'icone_url': iconValue,
                      }).eq('id', category['id']);

                      await SupabaseAdminLogRepository().logAction(
                        acao: 'Editar categoria',
                        detalhes: 'Categoria: $newName',
                        tabelaAfetada: 'categorias',
                        itemId: category['id'],
                      );
                    } else {
                      final name = categoryController.text;
                      await _supabase.from('categorias').insert({
                        'nome': name,
                        'icone_url': iconValue,
                        'ordem': _categories.length + 1,
                      });

                      await SupabaseAdminLogRepository().logAction(
                        acao: 'Cadastrar categoria',
                        detalhes: 'Categoria: $name',
                        tabelaAfetada: 'categorias',
                      );
                    }
                    
                    if (mounted) {
                      Navigator.pop(context);
                      _loadData();
                    }
                  } catch (e) {
                    debugPrint('Erro ao salvar categoria: $e');
                  }
                }
              },
              style: AppButtonStyles.primary(),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    final count = category['count'] ?? 0;
    final id = category['id'];

    if (count > 0) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exclusão bloqueada'),
            content: Text(
              'Esta categoria não pode ser excluída pois possui $count procedimento(s) vinculado(s). '
              'Tente renomeá-la ou mover os procedimentos para outra categoria primeiro.'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: AppButtonStyles.cancelButtonStyle(),
                child: Text('OK', style: AppButtonStyles.cancelTextStyle()),
              ),
            ],
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir categoria'),
        content: const Text('Tem certeza que deseja excluir esta categoria?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: AppButtonStyles.cancelButtonStyle(),
            child: Text('Cancelar', style: AppButtonStyles.cancelTextStyle()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppButtonStyles.primary(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabase.from('categorias').delete().eq('id', id);

        await SupabaseAdminLogRepository().logAction(
          acao: 'Excluir categoria',
          detalhes: 'Categoria: ${category['nome']}',
          tabelaAfetada: 'categorias',
          itemId: id,
        );

        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir categoria: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primary;
    final accent = AppColors.accent;
    final premiumGray = AppColors.textPrimary;
    final bgColor = AppColors.background;

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'O que deseja criar?',
                    style: TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.category_outlined, color: AppColors.primary),
                    title: const Text('Nova categoria'),
                    onTap: () {
                      Navigator.pop(context);
                      _showAddCategoryDialog();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.spa_outlined, color: AppColors.primary),
                    title: const Text('Novo procedimento'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/admin/servicos/novo').then((value) {
                        if (value == true) _loadData();
                      });
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
                    title: const Text('Novo pacote'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/admin/servicos/pacotes/novo').then((value) {
                        if (value == true) _loadData();
                      });
                    },
                  ),
                ],
              ),
            ),
          );
        },
        backgroundColor: accent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Novo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: accent,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gestão de procedimentos',
                      style: TextStyle(fontFamily: 'Playfair Display', 
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'Gerencie os procedimentos',
                      style: TextStyle(fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                        letterSpacing: 1.6,

                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Categorias',
                          style: TextStyle(fontFamily: 'Playfair Display', 
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withAlpha(25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_filteredCategories.length} Total',
                            style: TextStyle(fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildSearchBar(
                      controller: _categorySearchController,
                      hint: 'Pesquise por categorias...',
                      primary: primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _filteredCategories.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhuma categoria encontrada.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      )
                    : Column(
                        children: _filteredCategories.map((cat) => _buildCategoryCard(
                          category: cat,
                          primary: primary,
                        )).toList(),
                      ),
              ),


              const SizedBox(height: 32),

              Padding(
                key: _proceduresSectionKey,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Procedimentos',
                          style: TextStyle(fontFamily: 'Playfair Display', 
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withAlpha(25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_filteredProcedures.length} Total',
                            style: TextStyle(fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_selectedCategoryFilter != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withAlpha(15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.accent.withAlpha(30)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.filter_list, size: 14, color: AppColors.accent),
                            const SizedBox(width: 8),
                            Text(
                              'Filtrando por: ',
                              style: TextStyle(fontSize: 12,
                                color: Colors.grey[600],
        
                              ),
                            ),
                            Text(
                              _selectedCategoryFilter!,
                              style: TextStyle(fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent,
        
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => setState(() {
                                _selectedCategoryFilter = null;
                                _applyFilters();
                              }),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 10, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    _buildSearchBar(
                      controller: _procedureSearchController,
                      hint: 'Pesquise por procedimentos...',
                      primary: primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: AppColors.accent))
              else if (_filteredProcedures.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Text(
                      'Nenhum procedimento encontrado.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: _filteredProcedures.map((proc) => _buildProcedureCard(
                      procedure: proc,
                      primary: primary,
                      accent: accent,
                      premiumGray: premiumGray,
                    )).toList(),
                  ),
                ),

              const SizedBox(height: 32),

              Padding(
                key: _packagesSectionKey,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Pacotes de serviços',
                          style: TextStyle(fontFamily: 'Playfair Display', 
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withAlpha(25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_filteredPacotes.length} Total',
                            style: TextStyle(fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent,
      
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildSearchBar(
                      controller: _packageSearchController,
                      hint: 'Pesquise por pacotes...',
                      primary: primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: AppColors.accent))
              else if (_filteredPacotes.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      'Nenhum pacote encontrado.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: _filteredPacotes.map((pack) {
                      final catName = _categories.firstWhere(
                        (c) => c['id'] == pack.categoriaId,
                        orElse: () => {'nome': 'Geral'}
                      )['nome'].toString();
                      
                      return _buildPackageCard(
                        package: pack,
                        categoryName: catName,
                        primary: primary,
                        accent: accent,
                        premiumGray: premiumGray,
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPackageCard({
    required PacoteTemplateModel package,
    required String categoryName,
    required Color primary,
    required Color accent,
    required Color premiumGray,
  }) {
    final isActive = package.ativo;
    final confirmedGreen = AppColors.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Opacity(
        opacity: isActive ? 1.0 : 0.6,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 52,
                    height: 52,
                    color: AppColors.primary.withAlpha(13),
                    child: (package.imagemUrl != null && package.imagemUrl!.startsWith('http'))
                        ? Image.network(
                            package.imagemUrl!,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(Icons.inventory_2, color: AppColors.primary, size: 28),
                          )
                        : Icon(Icons.inventory_2, color: AppColors.primary, size: 28),
                  ),
                ),
                if (package.isPromocao)
                  Positioned(
                    top: 2,
                    left: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(230),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.accent, width: 0.5),
                      ),
                      child: Text(
                        'Oferta',
                        style: TextStyle(fontSize: 6,
                          fontWeight: FontWeight.w900,
                          color: AppColors.accent,
                          letterSpacing: 0.5,
  
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    package.titulo,
                    style: TextStyle(fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontFamily: 'Playfair Display',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    categoryName,
                    style: TextStyle(fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary.withAlpha(128),
                      letterSpacing: 1.2,

                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      if (package.isPromocao) ...[
                        Text(
                          package.formattedPromotionalPrice,
                          style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accent,
    
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          package.formattedPrice,
                          style: const TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
    
                          ),
                        ),
                      ] else
                        Text(
                          package.formattedPrice,
                          style: TextStyle(fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accent,
    
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (package.servicos != null && package.servicos!.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: package.servicos!.map((item) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withAlpha(15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.accent.withAlpha(30)),
                          ),
                          child: Text(
                            '${item.quantidadeSessoes}x ${item.nomeServico ?? "Serviço"}',
                            style: TextStyle(fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
      
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.repeat, color: AppColors.accent.withAlpha(200), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${package.servicos!.fold(0, (sum, item) => sum + item.quantidadeSessoes)} sessões no total',
                          style: TextStyle(fontSize: 11,
                            color: premiumGray.withAlpha(160),
                            fontWeight: FontWeight.w600,
    
                          ),
                        ),
                      ],
                    ),
                  ] else
                    Row(
                      children: [
                        Icon(Icons.repeat, color: AppColors.accent.withAlpha(200), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${package.quantidadeSessoes} Sessões',
                          style: TextStyle(fontSize: 12,
                            color: premiumGray.withAlpha(180),
                            fontWeight: FontWeight.w600,
    
                          ),
                        ),
                      ],
                    ),
                  if (package.isPromocao && package.dataFimPromocao != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, color: AppColors.accent.withAlpha(200), size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'Válido até ${DateFormat('dd/MM/yy').format(package.dataFimPromocao!)}',
                            style: TextStyle(fontSize: 11,
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
      
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Transform.scale(
                      scale: 0.8,
                      alignment: Alignment.centerRight,
                      child: Switch(
                        value: isActive,
                        onChanged: (val) => _togglePackageStatus(package),
                        activeThumbColor: Colors.white,
                        activeTrackColor: confirmedGreen,
                        inactiveThumbColor: Colors.grey[400],
                        inactiveTrackColor: Colors.grey[200],
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    Text(
                      isActive ? 'Ativo' : 'Inativo',
                      style: TextStyle(fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: isActive ? confirmedGreen : Colors.grey,

                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.black26, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) {
                    if (value == 'edit') {
                      context.push('/admin/servicos/pacotes/editar', extra: package).then((v) {
                        if (v == true) _loadData();
                      });
                    } else if (value == 'delete') {
                      _deletePackage(package);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 12),
                          Text('Editar'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          SizedBox(width: 12),
                          Text('Excluir', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePackageStatus(PacoteTemplateModel package) async {
    try {
      final updated = package.copyWith(ativo: !package.ativo);
      await SupabasePackageRepository(_supabase).updateTemplate(updated);
      _loadData();
    } catch (e) {
      debugPrint('Erro ao atualizar status: $e');
    }
  }

  Future<void> _deletePackage(PacoteTemplateModel package) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir pacote', style: TextStyle(fontFamily: 'Playfair Display', color: AppColors.primary)),
        content: Text('Tem certeza que deseja excluir o pacote "${package.titulo}"?', style: const TextStyle()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: AppButtonStyles.cancelButtonStyle(),
            child: Text('Cancelar', style: AppButtonStyles.cancelTextStyle()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppButtonStyles.small(backgroundColor: Colors.red),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SupabasePackageRepository(_supabase).deleteTemplate(package.id);
        _loadData();
      } catch (e) {
        debugPrint('Erro ao excluir: $e');
      }
    }
  }

  Widget _buildCategoryCard({
    required Map<String, dynamic> category,
    required Color primary,
  }) {
    final title = category['nome'] ?? 'Sem nome';
    final count = category['count'] ?? 0;
    final String? iconValue = category['icone_url'];
    final bool isCustomImage = iconValue != null && iconValue.startsWith('http');
    
    IconData iconData = Icons.category;
    if (!isCustomImage && iconValue != null) {
      iconData = _getIconData(iconValue);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withAlpha(25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: primary.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: isCustomImage
                ? ClipOval(
                    child: Image.network(
                      iconValue,
                      fit: BoxFit.cover,
                      width: 40,
                      height: 40,
                    )
                  )
                : Icon(iconData, color: primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primary,
                    fontFamily: 'Playfair Display',
                  ),
                ),
                Text(
                  '$count procedimento(s)',
                  style: const TextStyle(fontSize: 12,
                    color: Colors.grey,

                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black26),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'filter') {
                setState(() {
                  _selectedCategoryFilter = category['nome'];
                  _applyFilters();
                });
                // Scroll to procedures
                Scrollable.ensureVisible(
                  _proceduresSectionKey.currentContext!,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              } else if (value == 'edit') {
                _showAddCategoryDialog(category: category);
              } else if (value == 'delete') {
                _deleteCategory(category);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'filter',
                child: Row(
                  children: [
                    Icon(Icons.visibility_outlined, size: 18),
                    SizedBox(width: 12),
                    Text('Ver procedimentos'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 12),
                    Text('Editar'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Excluir', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProcedureCard({
    required Map<String, dynamic> procedure,
    required Color primary,
    required Color accent,
    required Color premiumGray,
  }) {
    final id = procedure['id'] ?? '';
    final title = procedure['nome'] ?? 'Sem nome';
    final category = (procedure['categorias'] != null ? procedure['categorias']['nome'] : 'Geral').toString();
    final priceValue = procedure['preco'] ?? 0.0;
    final price = 'R\$ ${priceValue.toStringAsFixed(2).replaceAll('.', ',')}';
    final isActive = procedure['ativo'] ?? true;
    final imgUrl = procedure['imagem_url'] ?? 'icon:spa';
    final confirmedGreen = AppColors.success;

    final duration = procedure['duracao_minutos'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Opacity(
        opacity: isActive ? 1.0 : 0.6,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image or Icon
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 52,
                    height: 52,
                    color: primary.withAlpha(13),
                    child: imgUrl.startsWith('http')
                        ? Image.network(
                            imgUrl,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            color: isActive ? null : Colors.grey,
                            colorBlendMode: isActive ? null : BlendMode.saturation,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.spa,
                              color: isActive ? primary : Colors.grey,
                              size: 28,
                            ),
                          )
                        : Icon(
                            _getIconData(imgUrl.replaceFirst('icon:', '')),
                            color: isActive ? primary : Colors.grey,
                            size: 28,
                          ),
                  ),
                ),
                if (ServiceModel.fromJson(procedure).isPromocao)
                  Positioned(
                    top: 2,
                    left: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(230),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: accent, width: 0.5),
                      ),
                      child: Text(
                        'Oferta',
                        style: TextStyle(fontSize: 6,
                          fontWeight: FontWeight.w900,
                          color: accent,
                          letterSpacing: 0.5,
  
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primary,
                      fontFamily: 'Playfair Display',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category,
                    style: TextStyle(fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: primary.withAlpha(128),
                      letterSpacing: 1.2,

                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      if (ServiceModel.fromJson(procedure).isPromocao) ...[
                        Text(
                          'R\$ ${procedure['preco_promocional'].toStringAsFixed(2).replaceAll('.', ',')}',
                          style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: accent,
    
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          price,
                          style: const TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
    
                          ),
                        ),
                      ] else
                        Text(
                          price,
                          style: TextStyle(fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: accent,
    
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, color: accent.withAlpha(200), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '$duration min',
                        style: TextStyle(fontSize: 12,
                          color: premiumGray.withAlpha(180),
                          fontWeight: FontWeight.w600,
  
                        ),
                      ),
                    ],
                  ),
                  if (ServiceModel.fromJson(procedure).isPromocao && ServiceModel.fromJson(procedure).dataFimPromocao != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, color: accent.withAlpha(200), size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'Válido até ${DateFormat('dd/MM/yy').format(ServiceModel.fromJson(procedure).dataFimPromocao!)}',
                            style: TextStyle(fontSize: 11,
                              color: accent,
                              fontWeight: FontWeight.w700,
      
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Action
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _toggleProcedureStatus(id, isActive),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Transform.scale(
                          scale: 0.8,
                          alignment: Alignment.centerRight,
                          child: Switch(
                            value: isActive,
                            onChanged: (val) => _toggleProcedureStatus(id, isActive),
                            activeThumbColor: Colors.white,
                            activeTrackColor: AppColors.success,
                            inactiveThumbColor: Colors.grey[400],
                            inactiveTrackColor: Colors.grey[200],
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        Text(
                          isActive ? 'Ativo' : 'Inativo',
                          style: TextStyle(fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: isActive ? AppColors.success : Colors.grey,
    
                          ),
                        ),
                      ],
                  ),
                ),
                const SizedBox(height: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.black26, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) {
                    if (value == 'edit') {
                      context.push('/admin/servicos/editar/$id', extra: procedure).then((value) {
                        if (value == true) _loadData();
                      });
                    } else if (value == 'delete') {
                      _deleteProcedure(id);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 12),
                          Text('Editar'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          SizedBox(width: 12),
                          Text('Excluir', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar({
    required TextEditingController controller,
    required String hint,
    required Color primary,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13,
            color: primary.withAlpha(76),

          ),
          prefixIcon: Icon(
            Icons.search,
            color: primary.withAlpha(102),
            size: 18,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    // Handle both 'icon:name' and 'name' formats for backward compatibility
    iconName = iconName.replaceFirst('icon:', '').trim();
    switch (iconName) {
      case 'spa':
        return Icons.spa;
      case 'face_retouching_natural':
      case 'face':
        return Icons.face_retouching_natural;
      case 'brush':
        return Icons.brush;
      case 'content_cut':
        return Icons.content_cut;
      case 'auto_awesome':
        return Icons.auto_awesome;
      case 'water_drop':
        return Icons.water_drop;
      case 'favorite':
        return Icons.favorite;
      case 'health_and_safety':
        return Icons.health_and_safety;
      case 'sentiment_very_satisfied':
        return Icons.sentiment_very_satisfied;
      case 'clean_hands':
        return Icons.clean_hands;
      case 'vaccines_outlined':
      case 'vaccines':
        return Icons.vaccines_outlined;
      case 'accessibility_new_rounded':
      case 'accessibility':
        return Icons.accessibility_new_rounded;
      default:
        return Icons.spa;
    }
  }
}

