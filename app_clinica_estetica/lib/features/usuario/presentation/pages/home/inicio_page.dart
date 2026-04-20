import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:app_clinica_estetica/core/data/models/service_model.dart';
import 'package:app_clinica_estetica/core/data/models/appointment_model.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_service_repository.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_appointment_repository.dart';
import 'package:app_clinica_estetica/features/auth/data/auth_service.dart';
import 'package:app_clinica_estetica/core/widgets/app_bottom_nav_bar.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_notification_repository.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_promotion_repository.dart';
import 'package:app_clinica_estetica/core/data/models/promotion_model.dart';
import 'package:app_clinica_estetica/core/data/models/pacote_template_model.dart';
import 'package:app_clinica_estetica/core/widgets/skeleton_widgets.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

class InicioPage extends StatefulWidget {
  const InicioPage({super.key});

  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> {
  int _currentOffer = 0;
  Timer? _offerTimer;
  late PageController _pageController;
  List<ServiceModel> _servicos = [];
  List<AppointmentModel> _proximosAgendamentos = [];
  List<PromotionModel> _promocoes = [];
  List<Map<String, dynamic>> _categoriasData = [];
  bool _carregandoDados = true;
  int _unreadNotifications = 0;
  bool get _temNotificacoes => _unreadNotifications > 0;
  
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<ServiceModel> _searchResults = [];
  bool _isSearching = false;
  
  final _servicoRepository = SupabaseServiceRepository();
  final _agendamentoRepository = SupabaseAppointmentRepository();
  final _notificationRepository = SupabaseNotificationRepository();
  final _promotionRepository = SupabasePromotionRepository();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _carregarDados();
    _startOfferTimer();
  }

  @override
  void dispose() {
    _offerTimer?.cancel();
    _pageController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    try {
      await Future.wait([
        _carregarServicos(), 
        _carregarAgendamentos(),
        _carregarNotificacoes(),
        _carregarPromocoes(),
      ]);
    } finally {
      if (mounted) {
        setState(() => _carregandoDados = false);
      }
    }
  }

  Future<void> _carregarNotificacoes() async {
    if (AuthService.currentUserId == null) return;
    try {
      final count = await _notificationRepository.getUnreadCount(AuthService.currentUserId!);
      if (mounted) {
        setState(() {
          _unreadNotifications = count;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar notificações: $e');
    }
  }

  Future<void> _carregarAgendamentos() async {
    if (AuthService.currentUserId == null) return;
    try {
      final agendamentos = await _agendamentoRepository.getUpcomingAppointments(
        AuthService.currentUserId!,
      );
      if (mounted) {
        setState(() {
          _proximosAgendamentos = agendamentos;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar agendamentos: $e');
    }
  }

  Future<void> _carregarServicos() async {
    try {
      final results = await Future.wait([
        _servicoRepository.getActiveServices(),
        _servicoRepository.getCategories(),
      ]);
      
      if (mounted) {
        setState(() {
          _servicos = results[0] as List<ServiceModel>;
          final allCategorias = results[1] as List<Map<String, dynamic>>;
          
          // Filtro: Apenas categorias que possuem serviços ativos na lista
          final nomesCategoriasAtivas = _servicos
              .map((s) => s.categoriaNome?.toLowerCase() ?? '')
              .where((nome) => nome.isNotEmpty)
              .toSet();
              
          _categoriasData = allCategorias.where((cat) {
            final nomeCat = cat['nome']?.toString().toLowerCase() ?? '';
            return nomesCategoriasAtivas.contains(nomeCat);
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar serviços/categorias: $e');
    }
  }

  PromotionModel? _getServicePromotion(String serviceId) {
    try {
      return _promocoes.firstWhere((p) => p.servicoId == serviceId);
    } catch (_) {
      return null;
    }
  }

  PromotionModel? _getPackagePromotion(String packageId) {
    try {
      return _promocoes.firstWhere((p) => p.pacoteId == packageId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _carregarPromocoes() async {
    try {
      final promocoes = await _promotionRepository.getPromotions();
      if (mounted) {
        setState(() {
          _promocoes = promocoes;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar promoções: $e');
    }
  }

  void _startOfferTimer() {
    _offerTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && _promocoes.isNotEmpty) {
        final nextOffer = (_currentOffer + 1) % _promocoes.length;
        _pageController.animateToPage(
          nextOffer,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.length < 2) return;
      
      if (mounted) setState(() => _isSearching = true);
      try {
        final results = await _servicoRepository.searchServices(query);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        debugPrint('Erro na busca: $e');
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    // "sexta-feira, 20 de março de 2026"
    final rawDate = DateFormat("EEEE, d 'de' MMMM 'de' yyyy", 'pt_BR').format(now);
    
    // Capitalize first letter of each word (ignoring 'de')
    return rawDate.split(' ').map((word) {
      if (word.toLowerCase() == 'de') return word;
      if (word.isEmpty) return word;
      if (word.contains('-')) {
        return word.split('-').map((p) => p.length > 1 ? '${p[0].toUpperCase()}${p.substring(1)}' : p.toUpperCase()).join('-');
      }
      return word.length > 1 ? '${word[0].toUpperCase()}${word.substring(1)}' : word.toUpperCase();
    }).join(' ');
  }

  String _getFirstName() {
    final fullName = AuthService.currentUserNome ?? 'Visitante';
    return fullName.split(' ')[0];
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _carregarDados,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _construirSaudacao(),
                _construirData(),
                _construirBarraPesquisa(),
                if (_searchController.text.isNotEmpty)
                  _construirResultadosBusca(),
                _construirBannerOfertas(),
                _construirSecaoCategorias(),
                _construirProximosAgendamentos(),
                _construirPacotesPromocionais(),
                _construirRecomendados(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavigationBar(activeIndex: 0),
    );
  }

  Widget _construirSaudacao() {

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: AppColors.accent, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  image: AuthService.currentUserAvatarUrl != null
                      ? DecorationImage(
                          image: NetworkImage(AuthService.currentUserAvatarUrl!),
                          fit: BoxFit.cover,
                        )
                      : DecorationImage(
                          image: NetworkImage(
                            AuthService.defaultAvatarUrl.replaceAll(
                              'User',
                              Uri.encodeComponent(_getFirstName()),
                            ),
                          ),
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Olá, ${_getFirstName()}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontFamily: 'Playfair Display',
                          color: AppColors.primary,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    'Bem-vinda(o) de volta!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.primary,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w300,
                        ),
                  ),
                ],
              ),
            ],
          ),
          GestureDetector(
            onTap: () async {
              await context.push('/notificacoes');
              _carregarNotificacoes(); // Refresh count when coming back
            },
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    _temNotificacoes
                        ? Icons.notifications
                        : Icons.notifications_none_outlined,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                if (_temNotificacoes)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      height: 10,
                      width: 10,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
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

  Widget _construirData() {

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Text(
        _getCurrentDate(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.accent,
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _construirBarraPesquisa() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppColors.accent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Buscar tratamentos...',
                  hintStyle: TextStyle(
                    color: AppColors.primary.withOpacity(0.3),
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: AppColors.accent),
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _construirResultadosBusca() {

    if (_isSearching) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
        ),
      );
    }

    if (_searchResults.isEmpty && _searchController.text.length >= 2) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        child: Text(
          'Nenhum resultado encontrado.',
          style: TextStyle(fontSize: 14,
            color: AppColors.primary.withOpacity(0.5),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _searchResults.length,
        separatorBuilder: (context, index) => Divider(
          color: Colors.grey.withOpacity(0.1),
          height: 24,
        ),
        itemBuilder: (context, index) {
          final servico = _searchResults[index];
          return GestureDetector(
            onTap: () {
              // Navegar para agendamento do serviço
              context.push('/servicos', extra: {'initialServiceId': servico.id});
            },
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: NetworkImage(
                        servico.imagemUrl ??
                            'https://images.unsplash.com/photo-1570172619644-dfd03ed5d881?w=200',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              servico.nome,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                fontFamily: 'Playfair Display',
                              ),
                            ),
                          ),
                          if (servico.isPromocao || _getServicePromotion(servico.id) != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Oferta',
                                style: TextStyle(fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (servico.isPromocao) ...[
                        Row(
                          children: [
                            Text(
                              servico.formattedPrice,
                              style: TextStyle(fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              servico.formattedPromotionalPrice,
                              style: TextStyle(fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                          Text(
                            servico.formattedPrice,
                            style: TextStyle(fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                            ),
                          ),

                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: AppColors.accent,
                ),

              ],
            ),
          );
        },
      ),
    );
  }

  Widget _construirBannerOfertas() {

    if (_carregandoDados) {
      return Container(
        height: 190,
        margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        child: const Skeleton(borderRadius: 30),
      );
    }

    if (_promocoes.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 190,
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: PageView.builder(
        controller: _pageController,
        itemCount: _promocoes.length,
        onPageChanged: (index) {
          setState(() {
            _currentOffer = index;
          });
        },
        itemBuilder: (context, index) {
          final oferta = _promocoes[index];
          return GestureDetector(
            onTap: () {
              if (oferta.servicoId != null) {
                context.push('/servicos', extra: {'initialServiceId': oferta.servicoId});
              } else if (oferta.pacoteId != null && oferta.pacote != null) {
                context.push('/pacote-detalhes', extra: oferta.pacote);
              }
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                image: DecorationImage(
                  image: NetworkImage(oferta.imagemUrl),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.35),
                    BlendMode.darken,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Oferta limitada',
                        style: TextStyle(color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      oferta.titulo,
                      style: TextStyle(fontFamily: 'Playfair Display', 
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      oferta.subtitulo,
                      style: TextStyle(color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _construirSecaoCategorias() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Categorias',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontFamily: 'Playfair Display',
                  color: AppColors.primary,
                ),
              ),
              TextButton(
                onPressed: () => context.push('/servicos'),
                child: Text(
                  'Ver todas',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 100,
          child: _carregandoDados
              ? ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 5,
                  itemBuilder: (context, index) => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: CategorySkeleton(),
                  ),
                )
                : _categoriasData.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhuma categoria encontrada',
                          style: TextStyle(fontSize: 12,
                            color: AppColors.primary.withOpacity(0.4),
                          ),
                        ),
                      )
                    : AnimationLimiter(
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _categoriasData.length,
                          itemBuilder: (context, index) {
                            final categoria = _categoriasData[index];
                            final nome = categoria['nome'] ?? '';
                            final imagemUrl = categoria['icone_url'];
                            final iconeKey = categoria['icone'];

                            return AnimationConfiguration.staggeredList(
                              position: index,
                              duration: const Duration(milliseconds: 375),
                              child: SlideAnimation(
                                verticalOffset: 50.0,
                                child: FadeInAnimation(
                                  child: _CategoryItem(
                                    icon: _getIconForCategory(iconeKey ?? nome),
                                    imageUrl: imagemUrl,
                                    label: nome,
                                    isActive: false,
                                    onTap: () {
                                      context.push('/servicos', extra: {'initialCategory': nome});
                                    },
                                  ),
                                ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _construirPacotesPromocionais() {
    
    if (_carregandoDados) return const SizedBox.shrink();

    final pacotesEmOferta = _promocoes
        .where((p) => p.pacoteId != null && p.pacote != null)
        .map((p) => p.pacote!)
        .toList();

    if (pacotesEmOferta.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Explore Nossos Serviços',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontFamily: 'Playfair Display',
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Icon(
                Icons.auto_awesome_outlined,
                color: AppColors.accent,
                size: 20,
              ),

            ],
          ),
        ),
        SizedBox(
          height: 310, // Ajustado para o tamanho do card
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: pacotesEmOferta.length,
            itemBuilder: (context, index) {
              final pacote = pacotesEmOferta[index];
              return Container(
                width: 200,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: _RecommendedCard(
                  pacote: pacote,
                  isVinculadoPromocao: true, // It's in the discount section
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _construirRecomendados() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recomendados para você',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const Icon(
                Icons.auto_awesome_outlined,
                color: AppColors.accent,
                size: 20,
              ),
            ],
          ),
        ),
        if (_carregandoDados)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              itemBuilder: (context, index) => const Skeleton(borderRadius: 20),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AnimationLimiter(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _servicos.length > 4 ? 4 : _servicos.length,
                itemBuilder: (context, index) {
                  final servico = _servicos[index];
                  final promo = _getServicePromotion(servico.id);

                  return AnimationConfiguration.staggeredGrid(
                    position: index,
                    duration: const Duration(milliseconds: 375),
                    columnCount: 2,
                    child: ScaleAnimation(
                      child: FadeInAnimation(
                        child: _RecommendedCard(
                          servico: servico,
                          isVinculadoPromocao: promo != null,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _construirProximosAgendamentos() {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Próximos Agendamentos',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.primary,
                ),
              ),
              if (_proximosAgendamentos.isNotEmpty)
                TextButton(
                  onPressed: () => context.push('/agenda'),
                  child: Text(
                    'Ver agenda',
                    style: TextStyle(color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_carregandoDados)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: CardSkeleton(),
          )
        else if (_proximosAgendamentos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.primary.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 48,
                    color: AppColors.accent.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum agendamento ativo',
                    style: TextStyle(fontSize: 18,
                      fontFamily: 'Playfair Display',
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),

                  const SizedBox(height: 8),
                  Text(
                    'Que tal reservar um momento para você hoje?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14,
                      color: AppColors.primary.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => context.push('/servicos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, // Verde escuro
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Novo Agendamento',
                      style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AnimationConfiguration.synchronized(
              child: FadeInAnimation(
                duration: const Duration(milliseconds: 600),
                child: _construirCardAgendamentoHome(
                  title: _proximosAgendamentos.first.serviceName ?? 'Serviço',
                  date: DateFormat(
                    "d 'de' MMMM",
                    'pt_BR',
                  ).format(_proximosAgendamentos.first.dataHora),
                  time: DateFormat(
                    'HH:mm',
                  ).format(_proximosAgendamentos.first.dataHora),
                  professional:
                      _proximosAgendamentos.first.professionalName ??
                      'Especialista',
                  status: _proximosAgendamentos.first.status,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _construirCardAgendamentoHome({
    required String title,
    required String date,
    required String time,
    required String professional,
    required String status,
  }) {
    final appointment = _proximosAgendamentos.first;
    final duracao = appointment.serviceDuration ?? 60;
    final timeEnd = DateFormat('HH:mm').format(
      appointment.dataHora.add(Duration(minutes: duracao)),
    );

    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    Color statusBg;

    if (status.toLowerCase() == 'confirmado') {
      statusColor = AppColors.primary;
      statusBg = AppColors.primary.withOpacity(0.1);
      statusLabel = 'Confirmado';
      statusIcon = Icons.check_circle_rounded;
    } else if (status.toLowerCase() == 'pendente') {
      statusColor = AppColors.accent;
      statusBg = AppColors.accent.withOpacity(0.1);
      statusLabel = 'Aguardando';
      statusIcon = Icons.schedule_rounded;
    } else {
      statusColor = AppColors.primary;
      statusBg = AppColors.primary.withOpacity(0.1);
      statusLabel = status.isNotEmpty ? '${status[0].toUpperCase()}${status.substring(1).toLowerCase()}' : status;
      statusIcon = Icons.info_rounded;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () => context.push(
            '/detalhes-agendamento',
            extra: appointment,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(statusIcon, color: statusColor, size: 10),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: GoogleFonts.manrope(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Date Badge
                    Text(
                      date,
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Premium Icon
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.calendar_today_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appointment.sessaoNumero != null
                                ? '$title (Sessão ${appointment.sessaoNumero})'
                                : title,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 12, color: AppColors.accent),
                              const SizedBox(width: 4),
                              Text(
                                '$time - $timeEnd',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.person_rounded, size: 12, color: Colors.black26),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  professional,
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black45,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Action Area
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Confirmar detalhes ou reagendar',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary.withOpacity(0.6),
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final IconData icon;
  final String? imageUrl;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _CategoryItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.imageUrl,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    // Removida variável local accentColor em favor de AppColors.accent


    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: Column(
          children: [
            Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: isActive
                    ? null
                    : Border.all(color: AppColors.accent.withOpacity(0.1)),
              ),
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          icon,
                          color: isActive
                              ? AppColors.accent
                              : AppColors.accent.withOpacity(0.6),
                          size: 26,
                        ),
                      ),
                    )
                  : Icon(
                      icon,
                      color: isActive
                          ? AppColors.accent
                          : AppColors.accent.withOpacity(0.6),
                      size: 26,
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.primary,

                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// Mapa auxiliar para ícones enquanto não há imagens enviadas pelo admin
IconData _getIconForCategory(String nome) {
  final cleanNome = nome.toLowerCase().trim();
  if (cleanNome.contains('facial')) return Icons.face_retouching_natural;
  if (cleanNome.contains('corporal')) return Icons.accessibility_new_rounded;
  if (cleanNome.contains('massagem') || cleanNome.contains('relax')) return Icons.spa;
  if (cleanNome.contains('laser')) return Icons.flash_on;
  if (cleanNome.contains('limpeza')) return Icons.clean_hands;
  if (cleanNome.contains('unha')) return Icons.brush;
  if (cleanNome.contains('cabelo')) return Icons.content_cut;
  
  switch (cleanNome) {
    case 'facial':
      return Icons.face_outlined;
    case 'corporal':
      return Icons.accessibility_new_outlined;
    case 'relax':
      return Icons.spa_outlined;
    case 'laser':
      return Icons.content_cut_outlined;
    default:
      return Icons.category_outlined;
  }
}

class _RecommendedCard extends StatelessWidget {
  final ServiceModel? servico;
  final PacoteTemplateModel? pacote;
  final String? promoTag;
  final bool isVinculadoPromocao;

  const _RecommendedCard({
    this.servico,
    this.pacote,
    this.promoTag,
    this.isVinculadoPromocao = false,
  });

  @override
  Widget build(BuildContext context) {
    final image = (servico?.imagemUrl ?? pacote?.imagemUrl) ?? 
        'https://images.unsplash.com/photo-1512290923902-8a9f81dc2069?w=400';
    final title = servico?.nome ?? pacote?.titulo ?? '';
    final isPromocao = (servico?.isPromocao ?? pacote?.isPromocao) ?? false;
    final mostrarBadge = isPromocao || isVinculadoPromocao;
    final badgeLabel = mostrarBadge ? 'Oferta' : promoTag;
    
    final price = servico?.formattedPrice ?? pacote?.formattedPrice ?? '';
    final promoPrice = servico?.formattedPromotionalPrice ?? pacote?.formattedPromotionalPrice ?? '';

    return GestureDetector(
      onTap: () {
        if (servico != null) {
          context.push(
            '/agendamento',
            extra: {'service': servico},
          );
        } else if (pacote != null) {
          context.push('/pacote-detalhes', extra: pacote);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Hero(
                tag: 'service-image-$title',
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    image: DecorationImage(
                      image: NetworkImage(image),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: badgeLabel != null
                      ? Stack(
                          children: [
                            Positioned(
                              top: 12,
                              left: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: const BoxDecoration(
                                  color: AppColors.accent, // Dourado
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(8),
                                    bottomRight: Radius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  badgeLabel ?? '',
                                  style: TextStyle(color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 14,
                      fontFamily: 'Playfair Display',
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (isPromocao) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              price,
                              style: TextStyle(fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            Text(
                              promoPrice,
                              style: TextStyle(fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Text(
                          price,
                          style: TextStyle(fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: () {
                        if (servico != null) {
                          context.push(
                            '/agendamento',
                            extra: {'service': servico},
                          );
                        } else if (pacote != null) {
                          context.push('/pacote-detalhes', extra: pacote);
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            servico != null ? 'Agendar' : 'Detalhes',
                            style: TextStyle(fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward, size: 12),
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
}

