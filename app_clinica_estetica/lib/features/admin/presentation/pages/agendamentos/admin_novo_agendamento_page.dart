import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';
import 'package:app_clinica_estetica/core/data/models/service_model.dart';
import 'package:app_clinica_estetica/core/data/models/pacote_template_model.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_service_repository.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_package_repository.dart';
import 'package:intl/intl.dart';
import 'package:app_clinica_estetica/core/services/report_app_bar_service.dart';

class AdminNovoAgendamentoPage extends StatefulWidget {
  const AdminNovoAgendamentoPage({super.key});

  @override
  State<AdminNovoAgendamentoPage> createState() => _AdminNovoAgendamentoPageState();
}

class _AdminNovoAgendamentoPageState extends State<AdminNovoAgendamentoPage> {
  final _supabase = Supabase.instance.client;
  final _serviceRepo = SupabaseServiceRepository();
  late final _packageRepo = SupabasePackageRepository(_supabase);
  final _reportAppBarService = ReportAppBarService();

  int _currentStep = 0; // 0: Procedimento, 1: Cliente
  
  // State Step 0
  List<ServiceModel> _services = [];
  List<PacoteTemplateModel> _packages = [];
  bool _isLoadingProcedures = true;
  String _procedureSearch = '';
  
  ServiceModel? _selectedService;
  PacoteTemplateModel? _selectedPackage;

  // State Step 1
  List<Map<String, dynamic>> _clients = [];
  bool _isLoadingClients = false;
  String _clientSearch = '';
  Map<String, dynamic>? _selectedClient;

  @override
  void initState() {
    super.initState();
    _loadProcedures();
    _updateTitle();
  }

  void _updateTitle() {
    _reportAppBarService.setTitleOnly(
      _currentStep == 0 ? 'Selecionar o Procedimento' : 'Selecionar o Cliente',
      hideLeading: _currentStep == 1,
    );
  }

  @override
  void dispose() {
    _reportAppBarService.reset();
    super.dispose();
  }

  Future<void> _loadProcedures() async {
    setState(() => _isLoadingProcedures = true);
    try {
      final services = await _serviceRepo.getActiveServices();
      final packages = await _packageRepo.getTemplates();
      setState(() {
        _services = services;
        _packages = packages.where((p) => p.ativo).toList();
        _isLoadingProcedures = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar procedimentos: $e');
      setState(() => _isLoadingProcedures = false);
    }
  }

  Future<void> _loadClients() async {
    setState(() => _isLoadingClients = true);
    try {
      final response = await _supabase
          .from('perfis')
          .select('id, nome_completo, email, telefone, avatar_url')
          .eq('tipo', 'cliente')
          .ilike('nome_completo', '%$_clientSearch%')
          .order('nome_completo')
          .limit(20);
      
      setState(() {
        _clients = List<Map<String, dynamic>>.from(response);
        _isLoadingClients = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar clientes: $e');
      setState(() => _isLoadingClients = false);
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_selectedService == null && _selectedPackage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione um serviço ou pacote')),
        );
        return;
      }
      setState(() => _currentStep = 1);
      _updateTitle();
      _loadClients();
    } else {
      if (_selectedClient == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione um cliente')),
        );
        return;
      }
      
      // Final step: Navigate to AgendamentoPage
      context.push(
        '/agendamento',
        extra: {
          'service': _selectedService,
          'pacote': _selectedPackage,
          'clientId': _selectedClient!['id'],
          'clientName': _selectedClient!['nome_completo'],
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentStep > 0) {
          setState(() => _currentStep = 0);
          _updateTitle();
        }
      },
      child: Container(
        color: AppColors.background,
        child: Column(
          children: [
            // Progress Indicator
            LinearProgressIndicator(
              value: (_currentStep + 1) / 2,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            Expanded(
              child: _currentStep == 0 ? _buildProcedureStep() : _buildClientStep(),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  if (_currentStep > 0) ...[
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 55,
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _currentStep = 0;
                              _updateTitle();
                            });
                          },
                          child: const Text(
                            'Voltar',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _nextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: Text(
                          _currentStep == 0 ? 'Próximo: Selecionar Cliente' : 'Próximo: Escolher Data e Profissional',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcedureStep() {
    final filteredServices = _services.where((s) => s.nome.toLowerCase().contains(_procedureSearch.toLowerCase())).toList();
    final filteredPackages = _packages.where((p) => p.titulo.toLowerCase().contains(_procedureSearch.toLowerCase())).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            onChanged: (val) => setState(() => _procedureSearch = val),
            decoration: InputDecoration(
              hintText: 'Buscar serviço ou pacote...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingProcedures
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (filteredServices.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('SERVIÇOS', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent)),
                      ),
                      ...filteredServices.map((s) => _buildSelectionCard(
                        title: s.nome,
                        subtitle: NumberFormat.simpleCurrency(locale: 'pt_BR').format(s.preco),
                        isSelected: _selectedService?.id == s.id,
                        imageUrl: s.imagemUrl,
                        onTap: () => setState(() {
                          _selectedService = s;
                          _selectedPackage = null;
                        }),
                      )),
                    ],
                    if (filteredPackages.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('PACOTES', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent)),
                      ),
                      ...filteredPackages.map((p) => _buildSelectionCard(
                        title: p.titulo,
                        subtitle: '${p.quantidadeSessoes} sessões',
                        isSelected: _selectedPackage?.id == p.id,
                        imageUrl: p.imagemUrl,
                        onTap: () => setState(() {
                          _selectedPackage = p;
                          _selectedService = null;
                        }),
                      )),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildClientStep() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            onChanged: (val) {
              _clientSearch = val;
              _loadClients();
            },
            decoration: InputDecoration(
              hintText: 'Buscar cliente por nome...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingClients && _clients.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _clients.length,
                  itemBuilder: (context, index) {
                    final client = _clients[index];
                    final isSelected = _selectedClient?['id'] == client['id'];
                    final phone = client['telefone'] ?? 'Sem telefone';
                    return _buildSelectionCard(
                      title: client['nome_completo'] ?? 'Sem nome',
                      subtitle: '${client['email'] ?? 'N/A'} • ${phone}',
                      isSelected: isSelected,
                      onTap: () => setState(() => _selectedClient = client),
                      avatarUrl: client['avatar_url'],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSelectionCard({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    String? avatarUrl,
    String? imageUrl,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: avatarUrl != null
            ? CircleAvatar(backgroundImage: NetworkImage(avatarUrl))
            : imageUrl != null
                ? Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                : CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Icon(
                      _currentStep == 0 ? Icons.spa_rounded : Icons.person,
                      color: AppColors.primary,
                    ),
                  ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: AppColors.primary)
            : const Icon(Icons.circle_outlined, color: Colors.grey),
      ),
    );
  }
}
