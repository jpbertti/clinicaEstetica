import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';

class AdminProfissionaisPage extends StatefulWidget {
  const AdminProfissionaisPage({super.key});

  @override
  State<AdminProfissionaisPage> createState() => _AdminProfissionaisPageState();
}

class _AdminProfissionaisPageState extends State<AdminProfissionaisPage> {
  String selectedCategory = 'Todos';
  String selectedStatus = 'Todos';
  List<Map<String, dynamic>> _profissionais = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfissionais();
  }

  Future<void> _loadProfissionais() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('perfis')
          .select()
          .or('tipo.eq.profissional,tipo.eq.admin')
          .order('nome_completo');

      setState(() {
        _profissionais = (response as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar profissionais: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppColors.primary;
    final accentColor = AppColors.accent;
    final bgColor = AppColors.background;


    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title and Add Button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Equipe da Clínica',
                  style: TextStyle(fontFamily: 'Playfair Display', 
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                Text(
                  'Gerencie os Profissionais',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar profissional...',
                hintStyle: TextStyle(
                  color: Colors.black38,
                  fontSize: 14,
                ),
                prefixIcon: Icon(Icons.search, color: primaryColor, size: 20),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                _buildFilterMenu(
                  label: 'Usuários',
                  currentValue: selectedCategory,
                  options: ['Todos', 'Admin', 'Profissional'],
                  onSelected: (val) => setState(() => selectedCategory = val),
                  primaryColor: primaryColor,
                  labelColor: accentColor,
                ),
                const SizedBox(width: 12),
                _buildFilterMenu(
                  label: 'Status',
                  currentValue: selectedStatus == 'Ativo'
                      ? 'Ativo'
                      : selectedStatus == 'Inativo'
                          ? 'Inativo'
                          : 'Todos',
                  options: ['Todos', 'Ativo', 'Inativo'],
                  onSelected: (val) => setState(() => selectedStatus = val),
                  primaryColor: primaryColor,
                  labelColor: accentColor,
                ),
                if (selectedCategory != 'Todos' || selectedStatus != 'Todos') ...[
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        selectedCategory = 'Todos';
                        selectedStatus = 'Todos';
                      });
                    },
                    child: Text(
                      'Limpar',
                      style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _profissionais.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhum profissional encontrado',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadProfissionais,
                        color: accentColor,
                        child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _profissionais.length,
                        itemBuilder: (context, index) {
                          final prof = _profissionais[index];
                          final nome = prof['nome_completo'] ?? '';
                          final email = prof['email'] ?? '';
                          final cargo = prof['cargo'] ?? 'Profissional';
                          final tipo = prof['tipo'] ?? 'profissional';
                          final avatarUrl = prof['avatar_url'];
                          // Mocking status as there is no status column in perfis yet, or we assume active
                          final bool isActive = prof['ativo'] ?? true; 

                          // Filtering logic
                          if (selectedCategory != 'Todos' && tipo.toLowerCase() != selectedCategory.toLowerCase()) {
                            return const SizedBox.shrink();
                          }
                          // Since we don't have a status column, status filter will show all if 'Todos' or 'Ativo'
                          if (selectedStatus != 'Todos' && selectedStatus == 'Inativo') {
                            return const SizedBox.shrink();
                          }

                          // Search filter
                          if (_searchController.text.isNotEmpty &&
                              !nome.toLowerCase().contains(_searchController.text.toLowerCase())) {
                            return const SizedBox.shrink();
                          }

                          return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: primaryColor.withOpacity(0.1),
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null
                            ? Icon(Icons.person, color: primaryColor, size: 30)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nome,
                              style: TextStyle(
                                fontFamily: 'Playfair Display',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),

                            Text(
                              cargo,
                              style: TextStyle(fontSize: 13,
                                color: accentColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              email,
                              style: TextStyle(fontSize: 12,
                                color: Colors.black38,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? primaryColor.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isActive ? 'Ativo' : 'Inativo',
                                style: TextStyle(fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isActive ? primaryColor : Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.black26),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 220, maxWidth: 350),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (value) async {
                          if (value == 'editar') {
                            final result = await context.push('/admin/profissionais/editar', extra: prof);
                            if (result == true) {
                              _loadProfissionais();
                            }
                          } else if (value == 'vincular-servicos') {
                            if (!isActive) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Apenas profissionais ativos podem ser vinculados a serviços!'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            final result = await context.push('/admin/profissionais/vincular', extra: prof);
                            if (result == true) {
                              _loadProfissionais();
                            }
                          } else if (value == 'vincular-pacotes') {
                            if (!isActive) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Apenas profissionais ativos podem ser vinculados a pacotes!'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            final result = await context.push(
                              '/admin/profissionais/vincular-pacotes/${prof['id']}',
                              extra: prof,
                            );
                            if (result == true) {
                              _loadProfissionais();
                            }
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'editar',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Editar',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'vincular-servicos',
                            child: Row(
                              children: [
                                Icon(Icons.link, size: 18),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Vincular Serviços',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'vincular-pacotes',
                            child: Row(
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 18),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Vincular Projetos',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: () async {
        final result = await context.push('/admin/profissionais/novo');
        if (result == true) {
          _loadProfissionais();
        }
      },
      backgroundColor: accentColor,
      child: const Icon(Icons.add, color: Colors.white),
    ),
  );
  }

  Widget _buildFilterMenu({
    required String label,
    required String currentValue,
    required List<String> options,
    required Function(String) onSelected,
    required Color primaryColor,
    Color? labelColor,
  }) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => options.map((option) {
        final bool isSelected = currentValue == option;
        return PopupMenuItem<String>(
          value: option,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  option,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? primaryColor : Colors.black87,
                  ),
                ),
              ),
              if (isSelected) ...[
                const Spacer(),
                Icon(Icons.check, size: 16, color: primaryColor),
              ],
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryColor.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ',
              style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w600,
                color: labelColor ?? Colors.black54,
              ),
            ),
            Text(
              currentValue,
              style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 16, color: primaryColor),
          ],
        ),
      ),
    );
  }
}

