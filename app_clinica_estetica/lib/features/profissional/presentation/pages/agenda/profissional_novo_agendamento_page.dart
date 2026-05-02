import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';
import 'package:app_clinica_estetica/core/theme/app_button_styles.dart';
import 'package:app_clinica_estetica/core/data/models/service_model.dart';
import 'package:app_clinica_estetica/core/data/models/pacote_template_model.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_service_repository.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_package_repository.dart';
import 'package:intl/intl.dart';
import 'package:app_clinica_estetica/features/auth/data/auth_service.dart';
import 'package:app_clinica_estetica/core/data/models/profile_model.dart';
import 'package:app_clinica_estetica/features/profissional/presentation/widgets/profissional_app_bar.dart';

class ProfissionalNovoAgendamentoPage extends StatefulWidget {
  const ProfissionalNovoAgendamentoPage({super.key});

  @override
  State<ProfissionalNovoAgendamentoPage> createState() => _ProfissionalNovoAgendamentoPageState();
}

class _ProfissionalNovoAgendamentoPageState extends State<ProfissionalNovoAgendamentoPage> {
  final _supabase = Supabase.instance.client;
  final _serviceRepo = SupabaseServiceRepository();
  late final _packageRepo = SupabasePackageRepository(Supabase.instance.client);

  int _currentStep = 0; // 0: Procedimento, 1: Cliente
  
  // State Step 0
  List<ServiceModel> _services = [];
  List<PacoteTemplateModel> _packages = [];
  bool _isLoadingProcedures = true;
  String _procedureSearch = '';
  
  ServiceModel? _selectedService;
  PacoteTemplateModel? _selectedPackage;

  // New state to store professional profile
  ProfileModel? _profProfile;

  // State Step 1
  List<Map<String, dynamic>> _clients = [];
  bool _isLoadingClients = false;
  String _clientSearch = '';
  Map<String, dynamic>? _selectedClient;

  @override
  void initState() {
    super.initState();
    _loadProcedures();
    _loadProfessionalProfile();
  }

  Future<void> _loadProfessionalProfile() async {
    final userId = AuthService.currentUserId;
    if (userId == null) return;
    
    try {
      final response = await _supabase.from('perfis').select().eq('id', userId).single();
      setState(() {
        _profProfile = ProfileModel.fromJson(response);
      });
    } catch (e) {
      debugPrint('Erro ao carregar perfil do profissional: $e');
    }
  }


  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadProcedures() async {
    setState(() => _isLoadingProcedures = true);
    try {
      final professionalId = AuthService.currentUserId;
      if (professionalId == null) return;

      final services = await _serviceRepo.getServicesByProfessional(professionalId);
      final packages = await _packageRepo.getTemplatesByProfessional(professionalId);
      
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
          const SnackBar(content: Text('Selecione um dos seus serviços ou pacotes')),
        );
        return;
      }
      setState(() => _currentStep = 1);
      _loadClients();
    } else {
      if (_selectedClient == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione um cliente')),
        );
        return;
      }
      
      // Final step: Navigate to AgendamentoPage with pre-selected professional
      context.push(
        '/agendamento',
        extra: {
          'service': _selectedService,
          'pacote': _selectedPackage,
          'clientId': _selectedClient!['id'],
          'clientName': _selectedClient!['nome_completo'],
          'profissional': _profProfile,
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
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: const ProfissionalAppBar(
          title: 'Novo Agendamento',
          showBackButton: true,
        ),
        body: Column(
          children: [
            // Progress Indicator
            LinearProgressIndicator(
              value: (_currentStep + 1) / 2,
              backgroundColor: AppColors.primary.withOpacity(0.1),
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
                        height: 45,
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _currentStep = 0;
                            });
                          },
                          child: const Text(
                            'Voltar',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _nextStep,
                      style: AppButtonStyles.primary(),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _currentStep == 0 ? Icons.person : Icons.calendar_month_outlined,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _currentStep == 0 ? 'Próximo: selecionar cliente' : 'Finalizar seleção',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            onChanged: (val) => setState(() => _procedureSearch = val),
            decoration: InputDecoration(
              hintText: 'Pesquisar procedimento...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingProcedures
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadProcedures,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      if (_services.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text('SERVIÇOS', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textLight, letterSpacing: 1.2)),
                        ),
                        ..._services
                            .where((s) => s.nome.toLowerCase().contains(_procedureSearch.toLowerCase()))
                            .map((s) => _buildProcedureCard(s, null)),
                      ],
                      if (_packages.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text('PACOTES', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textLight, letterSpacing: 1.2)),
                        ),
                        ..._packages
                            .where((p) => p.titulo.toLowerCase().contains(_procedureSearch.toLowerCase()))
                            .map((p) => _buildProcedureCard(null, p)),
                      ],
                      if (_services.isEmpty && _packages.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text('Nenhum procedimento disponível para você.'),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildProcedureCard(ServiceModel? service, PacoteTemplateModel? package) {
    final isSelected = (service != null && _selectedService?.id == service.id) ||
                       (package != null && _selectedPackage?.id == package.id);
    
    final title = service?.nome ?? package?.titulo ?? '';
    final sub = service != null ? 'Serviço • ${NumberFormat.simpleCurrency(locale: 'pt_BR').format(service.preco)}' : 'Pacote';

    return GestureDetector(
      onTap: () {
        setState(() {
          if (service != null) {
            _selectedService = service;
            _selectedPackage = null;
          } else {
            _selectedPackage = package;
            _selectedService = null;
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.primary.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(service != null ? Icons.spa : Icons.inventory_2, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.2)),
                  Text(sub, style: const TextStyle(color: AppColors.textLight, fontSize: 13)),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: AppColors.primary),
          ],
        ),
      ),
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
              hintText: 'Pesquisar nome do cliente...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingClients
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _clients.length,
                  itemBuilder: (context, index) {
                    final client = _clients[index];
                    final isSelected = _selectedClient?['id'] == client['id'];
                    return GestureDetector(
                      onTap: () => setState(() => _selectedClient = client),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.primary.withOpacity(0.1),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundImage: client['avatar_url'] != null ? NetworkImage(client['avatar_url']) : null,
                              child: client['avatar_url'] == null ? const Icon(Icons.person) : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(client['nome_completo'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                  Text(client['email'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                                ],
                              ),
                            ),
                            if (isSelected) const Icon(Icons.check_circle, color: AppColors.primary),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
