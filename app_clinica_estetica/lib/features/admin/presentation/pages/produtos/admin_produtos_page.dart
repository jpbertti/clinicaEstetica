import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/data/models/product_model.dart';
import '../../../../../core/data/models/caixa_model.dart';
import '../../../../../core/data/repositories/supabase_product_repository.dart';
import '../../../../../core/data/repositories/supabase_caixa_repository.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../../core/theme/app_colors.dart';

class AdminProdutosPage extends StatefulWidget {
  const AdminProdutosPage({super.key});

  @override
  State<AdminProdutosPage> createState() => _AdminProdutosPageState();
}

class _AdminProdutosPageState extends State<AdminProdutosPage> with SingleTickerProviderStateMixin {
  final _repository = SupabaseProductRepository();
  final _caixaRepo = SupabaseCaixaRepository();
  
  late TabController _tabController;
  List<ProductModel> _products = [];
  List<Map<String, dynamic>> _movements = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _movementFilter = 'todos'; // todos, entrada, saida
  String _statusFilter = 'Todos'; // Todos, Ativo, Inativo, Vencimento
  String _sortBy = 'Nenhum'; // Nenhum, Alfabética, Data Criação
  String _movSortBy = 'Nenhum'; // Nenhum, Alfabética, Data

  final Color primaryGreen = AppColors.primary;
  final Color accent = AppColors.accent;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final products = await _repository.getProducts(onlyActive: false);
      final movements = await _repository.getProductMovements(type: _movementFilter);
      setState(() {
        _products = products;
        _movements = movements;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ProductModel> get _filteredProducts {
    final now = DateTime.now();
    return _products.where((p) {
      final matchesSearch = p.nome.toLowerCase().contains(_searchQuery.toLowerCase());
      
      bool matchesStatus = _statusFilter == 'Todos';
      if (_statusFilter == 'Ativo') matchesStatus = p.ativo;
      if (_statusFilter == 'Inativo') matchesStatus = !p.ativo;
      if (_statusFilter == 'Vencimento') {
        matchesStatus = p.dataVencimento != null && 
                        p.dataVencimento!.isBefore(now.add(const Duration(days: 30))) && 
                        p.dataVencimento!.isAfter(now.subtract(const Duration(days: 1)));
      }
      
      return matchesSearch && matchesStatus;
    }).toList()
      ..sort((a, b) {
        if (_sortBy == 'Alfabética') {
          return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
        } else if (_sortBy == 'Data Criação') {
          // Data Criação desc (mais novos primeiro)
          final dateA = a.criadoEm ?? DateTime(2000);
          final dateB = b.criadoEm ?? DateTime(2000);
          return dateB.compareTo(dateA);
        }
        return 0; // Nenhum: mantém a ordem original
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryGreen = AppColors.primary;
    final secondaryGold = AppColors.accent;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(primaryGreen, secondaryGold),
          _buildTabBar(primaryGreen),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ABA 1: PRODUTOS (ESTOQUE)
                Column(
                  children: [
                    _buildStatsRow(),
                    _buildFiltersAndActions(secondaryGold),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Buscar produto...',
                          hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                          prefixIcon: Icon(Icons.search, color: AppColors.accent, size: 20),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadAll,
                        color: primaryGreen,
                        child: _isLoading && _products.isEmpty
                            ? Center(child: CircularProgressIndicator(color: primaryGreen))
                            : _filteredProducts.isEmpty
                                ? LayoutBuilder(
                                    builder: (context, constraints) => SingleChildScrollView(
                                      physics: const AlwaysScrollableScrollPhysics(),
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                        child: _buildEmptyState(primaryGreen, 'Nenhum produto encontrado'),
                                      ),
                                    ),
                                  )
                                : _buildProductList(primaryGreen, secondaryGold),
                      ),
                    ),
                  ],
                ),
                // ABA 2: HISTÓRICO
                Column(
                  children: [
                    _buildHistoryFiltersAndActions(secondaryGold),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadAll,
                        color: primaryGreen,
                        child: _isLoading && _movements.isEmpty
                            ? Center(child: CircularProgressIndicator(color: primaryGreen))
                            : _movements.isEmpty
                                ? LayoutBuilder(
                                    builder: (context, constraints) => SingleChildScrollView(
                                      physics: const AlwaysScrollableScrollPhysics(),
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                        child: _buildEmptyState(primaryGreen, 'Nenhuma movimentação encontrada'),
                                      ),
                                    ),
                                  )
                                : _buildMovementList(primaryGreen, secondaryGold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/admin/produtos/novo').then((_) => _loadAll()),
        backgroundColor: secondaryGold,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTabBar(Color primary) {
    final accentColor = AppColors.accent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ItemAba(
              label: 'Estoque',
              isSelected: _tabController.index == 0,
              onTap: () => setState(() => _tabController.animateTo(0)),
              primaryColor: primary,
              accentColor: accentColor,
            ),
            const SizedBox(width: 40), // Reduced from 60
            _ItemAba(
              label: 'Histórico',
              isSelected: _tabController.index == 1,
              onTap: () => setState(() => _tabController.animateTo(1)),
              primaryColor: primary,
              accentColor: accentColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color primary, Color gold) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Produtos', style: TextStyle(fontFamily: 'Playfair Display', color: primary, fontWeight: FontWeight.bold, fontSize: 24)),
              IconButton(
                onPressed: _tabController.index == 0 ? _exportStockToPDF : _exportHistoryToPDF, 
                icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 20)
              ),
            ],
          ),
          Text('Gestão de Estoque e Histórico', 
          style: TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.6)),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final totalValue = _products.fold<double>(0, (prev, p) => prev + (p.precoVenda * p.estoqueAtual));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(child: _StatCard(title: 'Itens no Estoque', value: _products.fold<int>(0, (prev, p) => prev + (p.ativo ? p.estoqueAtual : 0)).toString(), color: AppColors.primary, icon: Icons.inventory_2_outlined)),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(title: 'Valor Estoque', value: NumberFormat.simpleCurrency(locale: 'pt_BR').format(totalValue), color: AppColors.primary, icon: Icons.account_balance_wallet_outlined)),
        ],
      ),
    );
  }

  Widget _buildFiltersAndActions(Color gold) {
    final primaryGreen = AppColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          _buildFilterMenu(
            label: 'Status',
            currentValue: _statusFilter,
            options: ['Todos', 'Ativo', 'Inativo', 'Vencimento'],
            onSelected: (val) => setState(() => _statusFilter = val),
            primaryColor: primaryGreen,
            labelColor: gold,
          ),
          const SizedBox(width: 12),
          _buildFilterMenu(
            label: 'Ordenar',
            currentValue: _sortBy,
            options: ['Nenhum', 'Alfabética', 'Data Criação'],
            onSelected: (val) => setState(() => _sortBy = val),
            primaryColor: primaryGreen,
            labelColor: gold,
          ),
          const Spacer(),

        ],
      ),
    );
  }

  Widget _buildHistoryFiltersAndActions(Color gold) {
    final primaryGreen = AppColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          _buildFilterMenu(
            label: 'Filtro',
            currentValue: _movementFilter == 'todos' 
                ? 'Todos' 
                : _movementFilter == 'entrada' 
                    ? 'Entradas' 
                    : 'Saídas',
            options: ['Todos', 'Entradas', 'Saídas'],
            onSelected: (val) {
              setState(() {
                if (val == 'Todos') {
                  _movementFilter = 'todos';
                } else if (val == 'Entradas') _movementFilter = 'entrada';
                else _movementFilter = 'saida';
              });
              _loadAll();
            },
            primaryColor: primaryGreen,
            labelColor: gold,
          ),
          const SizedBox(width: 12),
          _buildFilterMenu(
            label: 'Ordenar',
            currentValue: _movSortBy,
            options: ['Nenhum', 'Alfabética', 'Data'],
            onSelected: (val) => setState(() => _movSortBy = val),
            primaryColor: primaryGreen,
            labelColor: gold,
          ),
          const Spacer(),

        ],
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
              Text(
                option,
                style: TextStyle(fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? primaryColor : Colors.black87,
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
          border: Border.all(color: primaryColor.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
          ],
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
            Icon(Icons.keyboard_arrow_down, size: 18, color: primaryColor),
          ],
        ),
      ),
    );
  }

  Future<void> _exportStockToPDF() async {
    final pdf = pw.Document();
    final items = _filteredProducts;
    final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Relatório de Estoque - Clínica Estética', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Text('Gerado em: $now', style: const pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 20),
          ],
        ),
        build: (pw.Context context) => [
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: ['Produto', 'Categoria', 'Preço Venda', 'Estoque', 'Vencimento', 'Status'],
            data: items.map((p) => [
              p.nome,
              p.categoria ?? '-',
              NumberFormat.simpleCurrency(locale: 'pt_BR').format(p.precoVenda),
              p.estoqueAtual.toString(),
              p.dataVencimento != null ? DateFormat('dd/MM/yy').format(p.dataVencimento!) : '-',
              p.ativo ? 'Ativo' : 'Inativo',
            ]).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> _exportHistoryToPDF() async {
    final pdf = pw.Document();
    final items = _movements;
    final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Relatório de Histórico de Movimentação - Clínica Estética', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Text('Gerado em: $now', style: const pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 20),
          ],
        ),
        build: (pw.Context context) => [
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: ['Data', 'Produto', 'Tipo', 'Qtd', 'Motivo'],
            data: items.map((m) {
              final prod = m['produtos'] as Map<String, dynamic>?;
              final data = DateTime.parse(m['criado_em']).toLocal();
              return [
                DateFormat('dd/MM/yy HH:mm').format(data),
                prod?['nome'] ?? '-',
                (m['tipo_movimentacao'] as String).toUpperCase(),
                m['quantidade'].toString(),
                m['motivo'] ?? '-',
              ];
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Widget _buildProductList(Color primary, Color gold) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 100),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        return _ProductCard(
          product: product,
          onTap: () => context.push('/admin/produtos/editar', extra: product).then((_) => _loadAll()),
          onSell: () => _handleSell(product),
        );
      },
    );
  }

  List<Map<String, dynamic>> get _sortedMovements {
    final list = List<Map<String, dynamic>>.from(_movements);
    list.sort((a, b) {
      if (_movSortBy == 'Alfabética') {
        final nameA = (a['produtos']?['nome'] ?? '').toString().toLowerCase();
        final nameB = (b['produtos']?['nome'] ?? '').toString().toLowerCase();
        return nameA.compareTo(nameB);
      } else if (_movSortBy == 'Data') {
        final dateA = DateTime.parse(a['criado_em']);
        final dateB = DateTime.parse(b['criado_em']);
        return dateB.compareTo(dateA);
      }
      return 0; // Nenhum: mantém a ordem original
    });
    return list;
  }

  Widget _buildMovementList(Color primary, Color gold) {
    final sortedMovs = _sortedMovements;
    final groups = <String, List<Map<String, dynamic>>>{};
    for (var mov in sortedMovs) {
      final date = DateTime.parse(mov['criado_em']).toLocal();
      final key = DateFormat('dd/MM/yyyy').format(date);
      if (!groups.containsKey(key)) groups[key] = [];
      groups[key]!.add(mov);
    }

    final sortedKeys = groups.keys.toList();

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 100),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final dateKey = sortedKeys[index];
        final items = groups[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 12),
              child: Row(
                children: [
                  Text(
                    dateKey == DateFormat('dd/MM/yyyy').format(DateTime.now()) ? 'Hoje' : dateKey,
                    style: TextStyle(color: gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Divider(color: gold.withOpacity(0.3), thickness: 1)),
                ],
              ),
            ),
            ...items.map((mov) {
              final tipo = mov['tipo_movimentacao'] as String;
              final data = DateTime.parse(mov['criado_em']).toLocal();
              final product = mov['produtos'] as Map<String, dynamic>?;
              final imgUrl = product?['imagem_url'] as String?;
              final darkGreen = AppColors.primary;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        image: imgUrl != null ? DecorationImage(image: NetworkImage(imgUrl), fit: BoxFit.cover) : null,
                      ),
                      child: imgUrl == null ? Icon(Icons.inventory_2_outlined, color: primary.withOpacity(0.2), size: 24) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product?['nome'] ?? 'Produto',
                            style: TextStyle(
                              fontFamily: 'Playfair Display',
                              fontWeight: FontWeight.w700, 
                              color: primary, 
                              fontSize: 14
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                DateFormat('HH:mm').format(data),
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                mov['motivo'] ?? '',
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (tipo == 'entrada' ? darkGreen : gold).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${tipo == 'entrada' ? '+' : '-'}${mov['quantidade']}',
                        style: TextStyle(fontWeight: FontWeight.w900,
                          color: tipo == 'entrada' ? darkGreen : gold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(Color primary, String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: primary.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(msg, style: TextStyle(color: primary.withOpacity(0.5), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _handleSell(ProductModel product) async {
    final caixa = await _caixaRepo.getActiveCaixa();
    if (caixa == null) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Caixa Fechado', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontFamily: 'Playfair Display')),
          content: Text('Você precisa abrir o caixa antes de realizar uma venda.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/admin/caixa');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Ir para o Caixa', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }
    
    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _SellProductModal(product: product, caixa: caixa, onComplete: _loadAll),
      );
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({required this.title, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;
  final VoidCallback onSell;

  const _ProductCard({required this.product, required this.onTap, required this.onSell});

  @override
  Widget build(BuildContext context) {
    final primaryGreen = AppColors.primary;
    final secondaryGold = AppColors.accent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), 
            blurRadius: 12, 
            offset: const Offset(0, 4)
          )
        ]
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Imagem ou Ícone
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.background, 
                  borderRadius: BorderRadius.circular(12)
                ),
                child: product.imagemUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12), 
                        child: Image.network(
                          product.imagemUrl!, 
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image_outlined, color: Colors.red, size: 20),
                        ),
                      )
                    : Icon(Icons.inventory_2_outlined, color: primaryGreen, size: 24),
              ),
              const SizedBox(width: 12),
              
              // Informações do Produto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.nome, 
                      style: TextStyle(fontWeight: FontWeight.w800, 
                        fontSize: 17, 
                        color: primaryGreen,
                        fontFamily: 'Playfair Display',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      NumberFormat.simpleCurrency(locale: 'pt_BR').format(product.precoVenda), 
                      style: TextStyle(fontWeight: FontWeight.bold, 
                        color: secondaryGold, 
                        fontSize: 14,
                        fontFamily: 'Inter',
                      )
                    ),
                    const SizedBox(height: 2),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estoque: ${product.estoqueAtual}', 
                          style: TextStyle(fontSize: 11, 
                            color: product.isLowStock ? Colors.red.shade700 : Colors.grey.shade600, 
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          )
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: product.ativo ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            product.ativo ? "ATIVO" : "INATIVO",
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Inter',
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (product.dataVencimento != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Vencimento: ${DateFormat('dd/MM/yy').format(product.dataVencimento!)}',
                        style: TextStyle(fontSize: 11, 
                          color: _isNearExpiration(product.dataVencimento!) ? Colors.red : Colors.grey.shade600,
                          fontWeight: _isNearExpiration(product.dataVencimento!) ? FontWeight.w700 : FontWeight.w500,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Botão de Venda à Direita
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onSell,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: primaryGreen, 
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: primaryGreen.withOpacity(0.2), 
                          blurRadius: 8, 
                          offset: const Offset(0, 2)
                        )
                      ]
                    ),
                    child: Text(
                      'Vender', 
                      style: TextStyle(color: Colors.white, 
                        fontWeight: FontWeight.w900, 
                        fontSize: 12,
                        letterSpacing: 0.5
                      )
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isNearExpiration(DateTime date) {
    final now = DateTime.now();
    return date.isBefore(now.add(const Duration(days: 30))) && date.isAfter(now.subtract(const Duration(days: 1)));
  }
}

class _SellProductModal extends StatefulWidget {
  final ProductModel product;
  final CaixaModel caixa;
  final VoidCallback onComplete;

  const _SellProductModal({required this.product, required this.caixa, required this.onComplete});

  @override
  State<_SellProductModal> createState() => _SellProductModalState();
}

class _SellProductModalState extends State<_SellProductModal> {
  int _qty = 1;
  bool _isSaving = false;
  String _selectedMeio = 'dinheiro';
  String? _selectedClienteId;
  String? _selectedProfissionalId;
  List<Map<String, dynamic>> _clientes = [];
  List<Map<String, dynamic>> _profissionais = [];
  final _repo = SupabaseProductRepository();

  @override
  void initState() {
    super.initState();
    _loadClientes();
    _loadProfissionais();
  }

  Future<void> _loadClientes() async {
    try {
      final res = await Supabase.instance.client
          .from('perfis')
          .select('id, nome_completo')
          .eq('tipo', 'cliente')
          .order('nome_completo');
      if (mounted) {
        setState(() {
          _clientes = List<Map<String, dynamic>>.from(res);
        });
      }
    } catch (e) {
      debugPrint('Erro carregar clientes: $e');
    }
  }

  Future<void> _loadProfissionais() async {
    try {
      final res = await Supabase.instance.client
          .from('perfis')
          .select('id, nome_completo')
          .neq('tipo', 'cliente')
          .order('nome_completo');
      if (mounted) {
        setState(() {
          _profissionais = List<Map<String, dynamic>>.from(res);
        });
      }
    } catch (e) {
      debugPrint('Erro carregar profissionais: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryGreen = AppColors.primary;
    final secondaryGold = AppColors.accent;

    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text('Lançar Venda', style: TextStyle(fontFamily: 'Playfair Display', fontSize: 24, fontWeight: FontWeight.bold, color: primaryGreen)),
            const SizedBox(height: 16),
            Text(widget.product.nome, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: primaryGreen)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _qtyBtn(Icons.remove, () => setState(() => _qty = _qty > 1 ? _qty - 1 : 1)),
                const SizedBox(width: 32),
                Text('$_qty', style: TextStyle(fontFamily: 'Playfair Display', fontSize: 32, fontWeight: FontWeight.bold, color: primaryGreen)),
                const SizedBox(width: 32),
                _qtyBtn(Icons.add, () => setState(() => _qty++)),
              ],
            ),
            const SizedBox(height: 24),
            
            // --- Novos campos ---
            DropdownButtonFormField<String?>(
              initialValue: _selectedClienteId,
              decoration: const InputDecoration(
                labelText: 'Cliente (Opcional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Selecione um cliente (venda avulsa)')),
                ..._clientes.map((c) => DropdownMenuItem(
                      value: c['id'].toString(),
                      child: Text(c['nome_completo']),
                    )),
              ],
              onChanged: (v) => setState(() => _selectedClienteId = v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedMeio,
              decoration: const InputDecoration(
                labelText: 'Forma de Pagamento',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payment_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'dinheiro', child: Text('Dinheiro')),
                DropdownMenuItem(value: 'pix', child: Text('PIX')),
                DropdownMenuItem(value: 'cartao_credito', child: Text('Cartão de Crédito')),
                DropdownMenuItem(value: 'cartao_debito', child: Text('Cartão de Débito')),
                DropdownMenuItem(value: 'convenio', child: Text('Convênio')),
              ],
              onChanged: (v) => setState(() => _selectedMeio = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _selectedProfissionalId,
              decoration: const InputDecoration(
                labelText: 'Profissional (Vendedor)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Selecione o profissional')),
                ..._profissionais.map((p) => DropdownMenuItem(
                      value: p['id'].toString(),
                      child: Text(p['nome_completo']),
                    )),
              ],
              onChanged: (v) => setState(() => _selectedProfissionalId = v),
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFFF6F4EF), borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total a Receber', style: TextStyle(fontWeight: FontWeight.bold, color: primaryGreen)),
                  Text(NumberFormat.simpleCurrency(locale: 'pt_BR').format(widget.product.precoVenda * _qty), style: TextStyle(fontFamily: 'Playfair Display', fontSize: 20, fontWeight: FontWeight.w800, color: secondaryGold)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _confirmSale,
                style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('Confirmar Venda', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar', 
                style: TextStyle(color: secondaryGold, 
                  fontWeight: FontWeight.bold
                )
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300)), child: Icon(icon, color: const Color(0xFF2D5A46))),
    );
  }

  Future<void> _confirmSale() async {
    if (widget.product.estoqueAtual < _qty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Estoque insuficiente!')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _repo.registerSale(ProductSaleModel(
        produtoId: widget.product.id,
        quantidade: _qty,
        valorUnitario: widget.product.precoVenda,
        valorTotal: widget.product.precoVenda * _qty,
        caixaId: widget.caixa.id,
        clienteId: _selectedClienteId,
        profissionalId: _selectedProfissionalId,
        formaPagamento: _selectedMeio,
      ));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venda registrada no caixa com sucesso!'), backgroundColor: Color(0xFF2D5A46)));
        widget.onComplete();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao registrar venda: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _ItemAba extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color primaryColor;
  final Color accentColor;

  const _ItemAba({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 18,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? primaryColor : primaryColor.withOpacity(0.4),
              fontFamily: 'Playfair Display',
            ),
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 3,
            width: 140,
            decoration: BoxDecoration(
              color: isSelected ? accentColor : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

