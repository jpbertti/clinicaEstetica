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
      _currentStep == 0 ? 'Selecionar o procedimento' : 'Selecionar o cliente',
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
                        height: 45,
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
                            _currentStep == 0 ? 'Próximo: Selecionar Cliente' : 'Agendar',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
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
    final filteredServices = _services.where((s) => s.nome.toLowerCase().contains(_procedureSearch.toLowerCase())).toList();
    final filteredPackages = _packages.where((p) => p.titulo.toLowerCase().contains(_procedureSearch.toLowerCase())).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              onChanged: (val) => setState(() => _procedureSearch = val),
              style: const TextStyle(color: Color(0xFF305F47), fontFamily: 'Inter'),
              decoration: const InputDecoration(
                hintText: 'Buscar serviço ou pacote...',
                hintStyle: TextStyle(color: Color(0xFF305F47), fontFamily: 'Playfair Display', fontSize: 13),
                prefixIcon: Icon(Icons.search, color: Color(0xFF305F47)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 15),
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
                        child: Text('Serviços', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent)),
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
                        child: Text('Pacotes', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent)),
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
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              onChanged: (val) {
                _clientSearch = val;
                _loadClients();
              },
              style: const TextStyle(color: Color(0xFF305F47), fontFamily: 'Inter'),
              decoration: const InputDecoration(
                hintText: 'Buscar cliente por nome...',
                hintStyle: TextStyle(color: Color(0xFF305F47), fontFamily: 'Playfair Display', fontSize: 13),
                prefixIcon: Icon(Icons.search, color: Color(0xFF305F47)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 15),
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
                    return _buildSelectionCard(
                      title: client['nome_completo'] ?? 'Sem nome',
                      subtitle: '${client['email'] ?? 'N/A'}\n${client['telefone'] ?? 'Sem telefone'}',
                      isSelected: isSelected,
                      onTap: () => setState(() => _selectedClient = client),
                      avatarUrl: client['avatar_url'],
                      isClient: true,
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
    bool isClient = false,
  }) {
    final Color selectedBorderColor = const Color(0xFFC7A46B); // Always Gold for selected items per user request
    final Color selectedBgColor = selectedBorderColor.withOpacity(0.05);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? selectedBgColor : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isSelected ? selectedBorderColor : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: onTap,
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: avatarUrl != null
                ? Image.network(avatarUrl, fit: BoxFit.cover)
                : imageUrl != null
                    ? Image.network(imageUrl, fit: BoxFit.cover)
                    : Container(
                        color: (isClient ? const Color(0xFF305F47) : AppColors.primary).withOpacity(0.1),
                        child: Icon(
                          isClient ? Icons.person : Icons.spa_rounded,
                          color: isClient ? const Color(0xFF305F47) : AppColors.primary,
                        ),
                      ),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Playfair Display',
            color: isClient ? const Color(0xFF305F47) : AppColors.primary,
            fontSize: 17,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              height: 1.4,
              fontFamily: 'Inter',
            ),
            maxLines: 2,
            overflow: TextOverflow.visible,
          ),
        ),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: Color(0xFF305F47), size: 28)
            : Icon(Icons.radio_button_off, color: Colors.grey[300], size: 28),
      ),
    );
  }
}
