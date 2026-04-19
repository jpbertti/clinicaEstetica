import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class AdminClientesPage extends StatefulWidget {
  const AdminClientesPage({super.key});

  @override
  State<AdminClientesPage> createState() => _AdminClientesPageState();
}

class _AdminClientesPageState extends State<AdminClientesPage> {
  final TextEditingController _searchController = TextEditingController();
  final _supabase = Supabase.instance.client;
  String _selectedFilter = 'Todos';
  bool _isLoading = true;
  List<Map<String, dynamic>> _allClients = [];
  List<Map<String, dynamic>> _filteredClients = [];

  final List<String> _filters = ['Todos', 'Ativos', 'Inativos', 'Novos'];

  @override
  void initState() {
    super.initState();
    _loadClients();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    setState(() => _isLoading = true);
    try {
      // Busca clientes e seus agendamentos para determinar o último atendimento
      final response = await _supabase
          .from('perfis')
          .select('*, agendamentos!cliente_id(data_hora, status)')
          .eq('tipo', 'cliente')
          .order('nome_completo');

      final List<dynamic> data = response as List<dynamic>;
      
      _allClients = data.map((clientData) {
        final client = clientData as Map<String, dynamic>;
        final agendamentos = (client['agendamentos'] as List? ?? []);
        
        // Ordenar agendamentos por data decrescente
        final sortedAgendamentos = List.from(agendamentos)
          ..sort((a, b) => (b['data_hora'] as String).compareTo(a['data_hora'] as String));

        final String? lastAppointment = sortedAgendamentos.isNotEmpty 
            ? sortedAgendamentos.first['data_hora'] 
            : null;

        // Regra para "Novo": Criado nos últimos 30 dias AND nenhum agendamento concluído
        final DateTime createdAt = DateTime.parse(client['criado_em']).toLocal();
        final bool isRecent = DateTime.now().difference(createdAt).inDays < 30;
        final bool hasConcluido = agendamentos.any((a) => a['status'] == 'concluido');
        final bool isNew = isRecent && !hasConcluido;

        // Regra para Inativo: apenas o campo boolean do banco de dados
        final bool isActive = client['ativo'] == true;

        return <String, dynamic>{
          ...client,
          'ultimo_agendamento': lastAppointment,
          'is_new': isNew,
          'ativo': isActive,
        };
      }).toList();

      _applyFilters();
    } catch (e) {
      debugPrint('Erro ao carregar clientes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar clientes: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredClients = _allClients.where((client) {
        final query = _searchController.text.toLowerCase();
        final name = (client['nome_completo'] ?? '').toLowerCase();
        final email = (client['email'] ?? '').toLowerCase();
        
        final matchesSearch = name.contains(query) || email.contains(query);
        
        bool matchesFilter = true;
        if (_selectedFilter == 'Ativos') {
          matchesFilter = client['ativo'] == true;
        } else if (_selectedFilter == 'Inativos') {
          matchesFilter = client['ativo'] == false;
        } else if (_selectedFilter == 'Novos') {
          matchesFilter = client['is_new'] == true;
        }

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF2D5A46);
    const goldColor = Color(0xFFC7A36B);
    const softGreen = Color(0xFF6E8F7B);
    const premiumGray = Color(0xFF2B2B2B);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F4EF),
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
                  'Clientes',
                  style: TextStyle(fontFamily: 'Playfair Display', 
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: primaryGreen,
                  ),
                ),
                Text(
                  'Gerencie seus clientes',
                  style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: goldColor,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        // Search and Filters Section
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Column(
            children: [
              // Search Bar
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(fontSize: 14,
                          color: premiumGray,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Buscar por nome ou e-mail',
                          hintStyle: TextStyle(fontSize: 14,
                            color: softGreen.withOpacity(0.6),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: primaryGreen.withOpacity(0.6),
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _loadClients,
                    child: Container(
                      height: 52,
                      width: 52,
                      decoration: BoxDecoration(
                        color: primaryGreen,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: primaryGreen.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Filter Chips
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedFilter = filter);
                          _applyFilters();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? primaryGreen : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: isSelected
                                ? null
                                : Border.all(
                                    color: primaryGreen.withOpacity(0.1),
                                  ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: primaryGreen.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    )
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            filter,
                            style: TextStyle(fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: isSelected ? Colors.white : softGreen,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Client List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadClients,
            color: primaryGreen,
            child: _isLoading && _allClients.isEmpty
                ? const Center(child: CircularProgressIndicator(color: primaryGreen))
                : _filteredClients.isEmpty
                    ? LayoutBuilder(
                        builder: (context, constraints) => SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight),
                            child: Center(
                              child: Text(
                                'Nenhum cliente encontrado',
                                style: TextStyle(color: softGreen),
                              ),
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _filteredClients.length,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        itemBuilder: (context, index) {
                          return _buildClientCard(
                            context: context,
                            client: _filteredClients[index],
                            primaryGreen: primaryGreen,
                            goldColor: goldColor,
                            softGreen: softGreen,
                            premiumGray: premiumGray,
                          );
                        },
                      ),
          ),
        ),
      ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await context.push('/admin/clientes/novo');
          if (result == true) {
            _loadClients();
          }
        },
        backgroundColor: goldColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildClientCard({
    required BuildContext context,
    required Map<String, dynamic> client,
    required Color primaryGreen,
    required Color goldColor,
    required Color softGreen,
    required Color premiumGray,
  }) {
    final bool isActive = client['ativo'] ?? true;
    final bool isNew = client['is_new'] ?? false;
    final String name = client['nome_completo'] ?? 'Cliente';
    final String? avatarUrl = client['avatar_url'];
    final String? lastDateStr = client['ultimo_agendamento'];
    
    String lastAppointmentText = 'Sem agendamentos';
    if (lastDateStr != null) {
      final lastDate = DateTime.parse(lastDateStr);
      lastAppointmentText = 'Último: ${DateFormat('dd MMM yyyy', 'pt_BR').format(lastDate)}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryGreen.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: goldColor.withOpacity(0.3),
                width: 2,
              ),
              image: avatarUrl != null
                  ? DecorationImage(
                      image: NetworkImage(avatarUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: avatarUrl == null
                ? Icon(Icons.person, color: goldColor.withOpacity(0.5), size: 32)
                : null,
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: primaryGreen, // Nome em cor verde escura
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? primaryGreen.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isActive ? 'Ativo' : 'Inativo',
                            style: TextStyle(fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isActive ? primaryGreen : Colors.red[700],
                            ),
                          ),
                        ),
                        if (isNew) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: goldColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: goldColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Text(
                              'NOVO',
                              style: TextStyle(fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: goldColor,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  lastAppointmentText,
                  style: TextStyle(fontSize: 12,
                    color: softGreen,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    context.push(
                      '/admin/clientes/${client['id']}',
                      extra: client['nome_completo'],
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        'Ver Detalhes',
                        style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: goldColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 10,
                        color: goldColor,
                      ),
                    ],
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

