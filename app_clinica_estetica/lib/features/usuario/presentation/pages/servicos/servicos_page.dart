import 'package:app_clinica_estetica/core/data/repositories/supabase_package_repository.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:app_clinica_estetica/core/app_config.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:app_clinica_estetica/core/data/models/service_model.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_service_repository.dart';
import 'package:app_clinica_estetica/core/widgets/app_bottom_nav_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:app_clinica_estetica/core/widgets/skeleton_widgets.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:app_clinica_estetica/core/widgets/map_view_widget.dart';
import 'package:app_clinica_estetica/core/data/models/pacote_template_model.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_promotion_repository.dart';

class ServicosPage extends StatefulWidget {
  final String? initialCategory;
  final String? initialServiceId;
  const ServicosPage({super.key, this.initialCategory, this.initialServiceId});

  @override
  State<ServicosPage> createState() => _ServicosPageState();
}

class _ServicosPageState extends State<ServicosPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _procedimentosKey = GlobalKey();
  final GlobalKey _pacotesKey = GlobalKey();
  final GlobalKey _contatoKey = GlobalKey();
  final GlobalKey _localizacaoKey = GlobalKey();
  int _activeTabIndex = 0;
  bool _isManualScrolling = false;
  final GlobalKey _targetServiceKey = GlobalKey();

  final _servicoRepository = SupabaseServiceRepository();
  final _packageRepository = SupabasePackageRepository(Supabase.instance.client);
  final _promotionRepository = SupabasePromotionRepository();
  List<ServiceModel> _todosOsServicos = [];
  List<ServiceModel> _servicosFiltrados = [];
  List<PacoteTemplateModel> _pacotes = [];
  Set<String> _servicosPromocaoIds = {};
  Set<String> _pacotesPromocaoIds = {};
  List<String> _categorias = [];
  String? _categoriaSelecionada;
  bool _carregando = true;
  bool _showProcedimentos = true;
  bool _showPacotes = true;

  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<ServiceModel> _searchResults = [];
  bool _isSearchingLocal = false;
  bool _showSearchField = false;
  String? _highlightedServiceId;

  // Filtros Avançados
  double _maxPrice = 2000.0;
  String _sortBy = 'Popularidade'; // 'Preço: Menor', 'Preço: Maior', 'A-Z'

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final servicos = await _servicoRepository.getActiveServices();
      final categoriasData = await _servicoRepository.getCategories();
      final pacotes = await _packageRepository.getTemplates();
      final promocoes = await _promotionRepository.getPromotions();
      
      if (mounted) {
        setState(() {
          _todosOsServicos = servicos;
          _pacotes = pacotes.where((p) => p.ativo).toList();
          
          // Mapeia IDs de serviços e pacotes vinculados a promoções ativas (banners)
          _servicosPromocaoIds = promocoes
              .where((p) => p.ativo && p.servicoId != null)
              .map((p) => p.servicoId!)
              .toSet();
          _pacotesPromocaoIds = promocoes
              .where((p) => p.ativo && p.pacoteId != null)
              .map((p) => p.pacoteId!)
              .toSet();
          
          // Filtro: Apenas categorias que possuem serviços ativos correspondentes
          final nomesCategoriasAtivas = _todosOsServicos
              .map((s) => s.categoriaNome?.toLowerCase() ?? '')
              .where((nome) => nome.isNotEmpty)
              .toSet();
              
          _categorias = categoriasData
              .map((c) => c['nome'] as String)
              .where((nome) => nomesCategoriasAtivas.contains(nome.toLowerCase()))
              .toList();

          _showProcedimentos = _todosOsServicos.isNotEmpty;
          _showPacotes = _pacotes.isNotEmpty;

          // Aplica categoria inicial se fornecida ou inferida do serviço
          if (widget.initialServiceId != null) {
            final targetService = _todosOsServicos.firstWhere(
              (s) => s.id == widget.initialServiceId,
              orElse: () => _todosOsServicos.first,
            );
            _categoriaSelecionada = targetService.categoriaNome;
            _servicosFiltrados = _todosOsServicos
                .where((s) => s.categoriaNome == _categoriaSelecionada)
                .toList();
            
            // Scroll para o serviço após o build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToService();
            });
          } else if (widget.initialCategory != null) {
            _categoriaSelecionada = widget.initialCategory;
            _servicosFiltrados = _todosOsServicos
                .where((s) => s.categoriaNome == widget.initialCategory)
                .toList();
          } else {
            _servicosFiltrados = servicos;
          }

          _carregando = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar serviços: $e');
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  void _filtrarServicos() {
    setState(() {
      _servicosFiltrados = _todosOsServicos.where((s) {
        final matchesCategory = _categoriaSelecionada == null || s.categoriaNome == _categoriaSelecionada;
        final matchesPrice = s.preco <= _maxPrice;
        return matchesCategory && matchesPrice;
      }).toList();

      // Ordenação
      if (_sortBy == 'Preço: Menor') {
        _servicosFiltrados.sort((a, b) => a.preco.compareTo(b.preco));
      } else if (_sortBy == 'Preço: Maior') {
        _servicosFiltrados.sort((a, b) => b.preco.compareTo(a.preco));
      } else if (_sortBy == 'A-Z') {
        _servicosFiltrados.sort((a, b) => a.nome.compareTo(b.nome));
      }
    });
  }

  void _filtrarPorCategoria(String? categoria) {
    setState(() {
      _categoriaSelecionada = categoria;
      _filtrarServicos();
    });
  }


  bool _isAdvancedFilterActive() {
    return _maxPrice < 2000.0 || _sortBy != 'Popularidade';
  }

  void _showFilterSheet() {
    
    

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filtros Avançados',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: AppColors.primary,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                Text(
                  'Preço Máximo: R\$ ${_maxPrice.toInt()}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Slider(
                  value: _maxPrice,
                  min: 0,
                  max: 2000,
                  divisions: 20,
                  activeColor: AppColors.accent,
                  inactiveColor: AppColors.primary.withOpacity(0.1),
                  onChanged: (val) {
                    setModalState(() => _maxPrice = val);
                    setState(() {});
                  },
                ),
                
                const SizedBox(height: 24),
                Text(
                  'Ordenar por',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                ...['Popularidade', 'Preço: Menor', 'Preço: Maior', 'A-Z'].map((option) {
                  return RadioListTile<String>(
                    title: Text(
                      option,
                      style: TextStyle(fontSize: 14),
                    ),
                    value: option,
                    groupValue: _sortBy,
                    activeColor: AppColors.accent,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setModalState(() => _sortBy = val!);
                      setState(() {});
                    },
                  );
                }),
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      _filtrarServicos();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text(
                      'APLICAR FILTROS',
                      style: TextStyle(fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setModalState(() {
                      _maxPrice = 2000.0;
                      _sortBy = 'Popularidade';
                    });
                    setState(() {
                      _maxPrice = 2000.0;
                      _sortBy = 'Popularidade';
                    });
                    _filtrarServicos();
                  },
                  child: Center(
                    child: Text(
                      'Limpar Filtros Avançados',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  int _getVisibleTabIndex(int globalIndex) {
    if (globalIndex == 0) return 0;
    if (globalIndex == 1) return _showProcedimentos ? 1 : 0;
    if (globalIndex == 2) {
      int idx = 0;
      if (_showProcedimentos) idx++;
      if (_showPacotes) idx++;
      return idx;
    }
    return 0;
  }

  void _onScroll() {
    if (_isManualScrolling) return;

    final scrollPosition = _scrollController.offset;

    // Pequeno offset para ativar o menu um pouco antes de chegar no topo
    const offset = 100.0;

    double? contatoOffset = _getOffset(_contatoKey);
    double? localizacaoOffset = _getOffset(_localizacaoKey);

    int newIndex = _activeTabIndex;

    // Seções em ordem reversa para detecção de scroll
    final sections = [
      {'index': _getVisibleTabIndex(2), 'key': _localizacaoKey},
      {'index': _getVisibleTabIndex(2), 'key': _contatoKey},
      if (_showPacotes) {'index': _getVisibleTabIndex(1), 'key': _pacotesKey},
      if (_showProcedimentos) {'index': _getVisibleTabIndex(0), 'key': _procedimentosKey},
    ];

    for (final section in sections) {
      final pos = _getOffset(section['key'] as GlobalKey);
      if (pos != null && scrollPosition >= pos - offset) {
        newIndex = section['index'] as int;
        break;
      }
    }

    if (newIndex != _activeTabIndex) {
      setState(() => _activeTabIndex = newIndex);
    }
  }

  double? _getOffset(GlobalKey key) {
    final RenderBox? renderBox =
        key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      // O offset global precisa ser ajustado pela posição atual do scroll para ser relativo ao conteúdo
      return position.dy +
          _scrollController.offset -
          100; // 100
    }
    return null;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearchingLocal = false;
        });
      }
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.length < 2) return;

      if (mounted) setState(() => _isSearchingLocal = true);
      try {
        final results = await _servicoRepository.searchServices(query);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearchingLocal = false;
          });
        }
      } catch (e) {
        debugPrint('Erro na busca: $e');
        if (mounted) setState(() => _isSearchingLocal = false);
      }
    });
  }

  void _toggleSearch() {
    setState(() {
      _showSearchField = !_showSearchField;
      if (!_showSearchField) {
        _searchController.clear();
        _searchResults = [];
        _isSearchingLocal = false;
      }
    });
  }

  void _scrollToSection(GlobalKey key, int index) {
    if (_activeTabIndex == index) return;

    setState(() {
      _activeTabIndex = index;
      _isManualScrolling = true;
    });

    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      ).then((_) {
        // Aguarda o término da animação para reativar o listener de scroll
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() => _isManualScrolling = false);
          }
        });
      });
    }
  }

  void _scrollToService() {
    if (_targetServiceKey.currentContext != null) {
      Scrollable.ensureVisible(
        _targetServiceKey.currentContext!,
        duration: const Duration(seconds: 1),
        curve: Curves.easeInOut,
        alignment: 0.1, // Alinha um pouco abaixo do topo
      );
    }
  }

  Future<void> _abrirMapa() async {
    final address = AppConfig.endereco;
    if (address.isEmpty || address == 'Aguardando configuração...') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Endereço não configurado.')),
        );
      }
      return;
    }

    final urlString = AppConfig.getSearchUrl();
    final uri = Uri.parse(urlString);
    
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Erro ao abrir mapa: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao abrir o mapa.')),
        );
      }
    }
  }

  Future<void> _iniciarWhatsApp() async {
    final rawPhone = AppConfig.whatsapp;
    if (rawPhone.isEmpty || rawPhone == 'Aguardando configuração...') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp não configurado.')),
        );
      }
      return;
    }

    final cleanPhone = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isEmpty) return;
    
    final phoneNumber = cleanPhone.startsWith('55') ? cleanPhone : '55$cleanPhone';
    
    final message =
        'Olá! Gostaria de agendar um procedimento na ${AppConfig.nomeComercial}.';
    final url = Uri.parse(
      'https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}',
    );

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Erro ao abrir WhatsApp: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: 8,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (!_showSearchField) ...[
                        GestureDetector(
                          onTap: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/inicio');
                            }
                          },
                          child: const Icon(
                            Icons.arrow_back,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Serviços',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                  fontFamily: 'Playfair Display',
                                  color: AppColors.primary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _toggleSearch,
                          child:
                              const Icon(Icons.search, color: AppColors.primary, size: 24),
                        ),
                      ] else ...[
                        Expanded(
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.search,
                                    color: AppColors.accent, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    autofocus: true,
                                    onChanged: _onSearchChanged,
                                    style: TextStyle(fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'Buscar...',
                                      hintStyle: TextStyle(color: AppColors.primary.withOpacity(0.3),
                                        fontSize: 14,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _toggleSearch,
                                  child: const Icon(Icons.close,
                                      color: AppColors.accent, size: 18),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_showSearchField && _searchController.text.isNotEmpty)
                    _construirResultadosBusca(AppColors.primary, AppColors.accent),
                  const SizedBox(height: 16),
                  Divider(
                    color: AppColors.accent.withOpacity(0.2),
                    thickness: 1,
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero/Logo Section
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              image: DecorationImage(
                                image: NetworkImage(
                                  AppConfig.logoUrl ?? 'https://lh3.googleusercontent.com/aida-public/AB6AXuDghgOrF35ZoCk6Qmyu6t61hMibKufGBsw18qoRqieAWh1wt-LLLI9Pbuplao7S5jeH7XKXSp7H7W3wa-V0iyHX__EdSsfmpkwDWKa8e8P1C5d7mw1B8ffE2JOTtARmPl33BPKyh8hmi2LX3NcyjQPJY8J89E4U82qlyHS07VTJ0OKiFu-hHOxZRFlSBtEnYy44-h6cHM5a1HRS3YFVS9y_h5Gi_wQpQdwkoagRsFmIiy96g4Na6G1y0u6DJVDq8FrAjh3kbC6_wJhq',
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Nome da clínica removido do cabeçalho fixo conforme solicitação
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),

                    // Tabs Menu (Anchors)
                    StickyHeader(
                      backgroundColor: AppColors.background,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            if (_showProcedimentos)
                              _construirItemAba(
                                'PROCEDIMENTOS',
                                _getVisibleTabIndex(0) == _activeTabIndex,
                                AppColors.primary,
                                () => _scrollToSection(_procedimentosKey, _getVisibleTabIndex(0)),
                              ),
                            if (_showPacotes)
                              _construirItemAba(
                                'PACOTES',
                                _getVisibleTabIndex(1) == _activeTabIndex,
                                AppColors.primary,
                                () => _scrollToSection(_pacotesKey, _getVisibleTabIndex(1)),
                              ),
                            _construirItemAba(
                              'CONTATO',
                              _getVisibleTabIndex(2) == _activeTabIndex,
                              AppColors.primary,
                              () => _scrollToSection(_contatoKey, _getVisibleTabIndex(2)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1),

                    // Procedimentos Seção
                    if (_showProcedimentos)
                      Padding(
                        key: _procedimentosKey,
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Procedimentos Exclusivos',
                              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                    fontFamily: 'Playfair Display',
                                    color: AppColors.primary,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              'MENU DE SERVIÇOS',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.accent,
                                    letterSpacing: 1.6,
                                  ),
                            ),
                            const SizedBox(height: 24),
                            // Filtros de Categoria
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.03),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String?>(
                                        isExpanded: true,
                                        value: _categoriaSelecionada,
                                        icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary, size: 20),
                                        hint: Text(
                                          'TODAS CATEGORIAS',
                                          style: TextStyle(fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary.withOpacity(0.6),
                                          ),
                                        ),
                                        style: TextStyle(fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                        onChanged: (val) => _filtrarPorCategoria(val),
                                        items: [
                                          DropdownMenuItem<String?>(
                                            value: null,
                                            child: Text(
                                              'TODOS',
                                              style: TextStyle(fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          ..._categorias.map((cat) => DropdownMenuItem<String?>(
                                            value: cat,
                                            child: Text(
                                              cat.toUpperCase(),
                                              style: TextStyle(fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          )),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Botão de Filtros Avançados
                                InkWell(
                                  onTap: _showFilterSheet,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                      height: 50,
                                      width: 50,
                                      decoration: BoxDecoration(
                                        color: _isAdvancedFilterActive() 
                                            ? AppColors.accent 
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _isAdvancedFilterActive() 
                                              ? AppColors.accent 
                                              : AppColors.primary.withOpacity(0.2),
                                        ),
                                        boxShadow: _isAdvancedFilterActive() ? [
                                          BoxShadow(
                                            color: AppColors.accent.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          )
                                        ] : [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                    child: Icon(
                                      Icons.tune_rounded,
                                      color: _isAdvancedFilterActive() ? Colors.white : AppColors.primary,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                          // Lista de Serviços
                          if (_carregando)
                            AnimationLimiter(
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: 4,
                                separatorBuilder: (context, index) => const SizedBox(height: 16),
                                itemBuilder: (context, index) => const CardSkeleton(),
                              ),
                            )
                          else if (_servicosFiltrados.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 40,
                                ),
                                child: Text(
                                  'Nenhum procedimento encontrado.',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.black38,
                                  ),
                                ),
                              ),
                            )
                          else
                            AnimationLimiter(
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _servicosFiltrados.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 16),
                                itemBuilder: (context, index) {
                                  final service = _servicosFiltrados[index];
                                  return AnimationConfiguration.staggeredList(
                                    position: index,
                                    duration: const Duration(milliseconds: 375),
                                    child: SlideAnimation(
                                      verticalOffset: 50.0,
                                      child: FadeInAnimation(
                                        child: _CardServico(
                                          key: service.id == (widget.initialServiceId ?? _highlightedServiceId)
                                              ? _targetServiceKey
                                              : null,
                                          service: service,
                                          isVinculadoPromocao: _servicosPromocaoIds.contains(service.id),
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

                    // Pacotes Seção
                    if (_showPacotes)
                      Padding(
                        key: _pacotesKey,
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pacotes de Tratamento',
                              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontFamily: 'Playfair Display',
                                color: AppColors.primary,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'ECONOMIA E RESULTADOS',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (_carregando)
                              const Center(child: CircularProgressIndicator(color: AppColors.accent))
                            else if (_pacotes.isEmpty)
                              Text(
                                'Nenhum pacote promocional no momento.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.black38,
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _pacotes.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 16),
                                itemBuilder: (context, index) {
                                  final pacote = _pacotes[index];
                                  return _CardPacote(
                                    pacote: pacote,
                                    isVinculadoPromocao: _pacotesPromocaoIds.contains(pacote.id),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),

                    // Contato Section
                    Padding(
                      key: _contatoKey,
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fale Conosco',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontFamily: 'Playfair Display',
                              color: AppColors.primary,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _construirItemContato(
                            icon: const Icon(Icons.chat, color: AppColors.accent),
                            title: 'WhatsApp',
                            value: AppConfig.whatsapp,
                            accentColor: AppColors.accent,
                            onTap: _iniciarWhatsApp,
                          ),
                          ValueListenableBuilder<bool>(
                            valueListenable: AppConfig.telefoneFixoAtivoNotifier,
                            builder: (context, ativo, child) {
                              if (!ativo) return const SizedBox.shrink();
                              return Column(
                                children: [
                                  const SizedBox(height: 12),
                                  _construirItemContato(
                                    icon: const Icon(
                                      Icons.phone_outlined,
                                      color: AppColors.accent,
                                    ),
                                    title: 'Fixo',
                                    value: AppConfig.telefoneFixo,
                                    accentColor: AppColors.accent,
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Localização Section
                    ValueListenableBuilder<String?>(
                      valueListenable: AppConfig.mapaIframeNotifier,
                      builder: (context, mapaIframe, child) {
                        return Padding(
                          key: _localizacaoKey,
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Localização',
                                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  fontFamily: 'Playfair Display',
                                  color: AppColors.primary,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              GestureDetector(
                                onTap: _abrirMapa,
                                child: Container(
                                  height: 250,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppColors.primary.withOpacity(0.1),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Stack(
                                      children: [
                                        // Real Multiplatform Map
                                        if (AppConfig.getMapaUrl() != null)
                                          MapViewWidget(url: AppConfig.getMapaUrl()!)
                                        else
                                          Container(
                                            color: Colors.grey[200],
                                            child: Center(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.map_outlined, color: Colors.grey[400], size: 48),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Mapa não configurado',
                                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        
                                        // Invisible overlay
                                        // to intercept taps and open full maps
                                        Positioned.fill(
                                          child: GestureDetector(
                                            onTap: _abrirMapa,
                                            behavior: HitTestBehavior.translucent,
                                            child: Container(
                                              color: Colors.transparent,
                                            ),
                                          ),
                                        ),

                                        // Badge de "Endereço Atualizado"
                                        if (mapaIframe != null && mapaIframe.isNotEmpty)
                                          Positioned(
                                            top: 12,
                                            right: 12,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withOpacity(0.9),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                'MAPA ATIVO',
                                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ValueListenableBuilder<String>(
                                valueListenable: AppConfig.enderecoNotifier,
                                builder: (context, endereco, child) {
                                  return Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        color: Color(0xFFC7A36B),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          endereco,
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavigationBar(activeIndex: 1),
    );
  }


  Widget _construirItemAba(
    String label,
    bool isActive,
    Color primaryColor,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: isActive
              ? Border(bottom: BorderSide(color: AppColors.primary, width: 2))
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.w900,
            fontSize: 13,
            color: isActive ? AppColors.primary : Colors.black26,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _construirResultadosBusca(Color primaryColor, Color accentColor) {
    if (_isSearchingLocal) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Center(
            child:
                CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
      );
    }

    if (_searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(
          'Nenhum resultado encontrado.',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.primary.withOpacity(0.5),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: _searchResults.length,
        separatorBuilder: (context, index) => Divider(
          color: Colors.grey.withOpacity(0.1),
          height: 16,
        ),
        itemBuilder: (context, index) {
          final servico = _searchResults[index];
          return GestureDetector(
            onTap: () {
              final selectedId = servico.id;
              _toggleSearch(); // Fecha busca
              
              setState(() {
                _highlightedServiceId = selectedId;
                _categoriaSelecionada = servico.categoriaNome;
              });

              // Agenda o scroll para o próximo frame, após o build do setState acima
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToService();
              });
            },
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    servico.imagemUrl ??
                        'https://images.unsplash.com/photo-1570172619644-dfd03ed5d881?w=100',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              servico.nome,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                fontFamily: 'Playfair Display',
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (servico.isPromocao)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'OFERTA',
                                style: TextStyle(fontSize: 6,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                        Text(
                          servico.formattedPrice,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.accent),
              ],
            ),
          );
        },
      ),
    );
  }


  Widget _construirItemContato({
    required Widget icon,
    required String title,
    required String value,
    required Color accentColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            SizedBox(width: 24, height: 24, child: icon),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black38,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (onTap != null)
              TextButton(
                onPressed: onTap,
                child: Text(
                  'CHAMAR',
                  style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
              )
            else
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Número copiado com sucesso!'),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: AppColors.accent,
                    ),
                  );
                },
                child: Text(
                  'COPIAR',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Helper Widget for Sticky Header simulation
class StickyHeader extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;

  const StickyHeader({
    super.key,
    required this.child,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(color: AppColors.background, child: child);
  }
}

class _CardServico extends StatelessWidget {
  final ServiceModel service;
  final bool isVinculadoPromocao;

  const _CardServico({
    super.key, 
    required this.service,
    this.isVinculadoPromocao = false,
  });

  @override
  Widget build(BuildContext context) {
    
    

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: service.imagemUrl != null && service.imagemUrl!.isNotEmpty
                    ? Image.network(
                        service.imagemUrl!,
                        height: 110,
                        width: 110,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 110,
                          width: 110,
                          color: AppColors.accent.withOpacity(0.1),
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: AppColors.accent,
                          ),
                        ),
                      )
                    : Container(
                        height: 110,
                        width: 110,
                        color: AppColors.accent.withOpacity(0.1),
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: AppColors.accent,
                        ),
                      ),
              ),
              Positioned(
                bottom: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    (service.categoriaNome ?? 'GERAL').toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              if (service.isPromocao || isVinculadoPromocao)
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'OFERTA',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  service.nome,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFamily: 'Playfair Display',
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  service.descricao,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (service.isPromocao) ...[
                      Text(
                        service.formattedPrice,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: Colors.black38,
                        ),
                      ),
                      Text(
                        service.formattedPromotionalPrice,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      if (service.dataFimPromocao != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.event_available, size: 14, color: AppColors.accent),
                            const SizedBox(width: 4),
                            Text(
                              'Oferta válida até ${DateFormat('dd/MM/yy').format(service.dataFimPromocao!)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ] else
                      Text(
                        service.formattedPrice,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: AppColors.accent),
                    const SizedBox(width: 4),
                    Text(
                      '${service.duracaoMinutos} min',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.push(
                      '/servico-detalhes',
                      extra: service,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'RESERVAR AGORA',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
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

class _CardPacote extends StatelessWidget {
  final PacoteTemplateModel pacote;
  final bool isVinculadoPromocao;

  const _CardPacote({
    required this.pacote,
    this.isVinculadoPromocao = false,
  });

  @override
  Widget build(BuildContext context) {
    
    

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppColors.accent.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ícone ou Imagem do Pacote
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: pacote.imagemUrl != null && pacote.imagemUrl!.isNotEmpty
                      ? Image.network(
                          pacote.imagemUrl!,
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 100,
                            width: 100,
                            color: AppColors.accent.withOpacity(0.05),
                            child: const Icon(Icons.inventory_2_outlined, color: AppColors.accent),
                          ),
                        )
                      : Container(
                          height: 100,
                          width: 100,
                          color: AppColors.accent.withOpacity(0.05),
                          child: const Icon(Icons.inventory_2_outlined, color: AppColors.accent),
                        ),
                ),
                if (pacote.isPromocao || isVinculadoPromocao)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'OFERTA',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 6,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
                        pacote.titulo,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontFamily: 'Playfair Display',
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pacote.descricao ?? 'Aproveite este pacote exclusivo.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Valor do Pacote',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Colors.black38,
                                ),
                              ),
                              if (pacote.isPromocao) ...[
                                Text(
                                  pacote.formattedPrice,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.black38,
                                  ),
                                ),
                                Text(
                                  pacote.formattedPromotionalPrice,
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                if (pacote.dataFimPromocao != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.event_available, size: 14, color: AppColors.accent),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Oferta válida até ${DateFormat('dd/MM/yy').format(pacote.dataFimPromocao!)}',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.accent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ] else
                                Text(
                                  pacote.formattedPrice,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.repeat, size: 14, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${pacote.quantidadeSessoes} Sessões',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                context.push('/pacote-detalhes', extra: pacote);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'RESERVAR AGORA',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
      ),
    );
  }
}



