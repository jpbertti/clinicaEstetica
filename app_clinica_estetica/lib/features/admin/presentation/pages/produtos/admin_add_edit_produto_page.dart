import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/data/models/product_model.dart';
import '../../../../../core/data/repositories/supabase_product_repository.dart';
import '../../../../../core/widgets/currency_formatter.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';

class AdminAddEditProdutoPage extends StatefulWidget {
  final ProductModel? product;
  const AdminAddEditProdutoPage({super.key, this.product});

  @override
  State<AdminAddEditProdutoPage> createState() => _AdminAddEditProdutoPageState();
}

class _AdminAddEditProdutoPageState extends State<AdminAddEditProdutoPage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = SupabaseProductRepository();
  bool _isLoading = false;

  // Notificadores para validação visual
  final _nomeError = ValueNotifier<bool>(false);
  final _precoError = ValueNotifier<bool>(false);
  final _categoriaError = ValueNotifier<bool>(false);
  final _linkPagamentoError = ValueNotifier<bool>(false);

  late TextEditingController _nomeController;
  late TextEditingController _descController;
  late TextEditingController _precoController;
  late TextEditingController _precoCustoController;
  late TextEditingController _estoqueAtualController;
  late TextEditingController _estoqueMinimoController;
  late TextEditingController _comissaoController;
  late TextEditingController _linkPagamentoController;
  
  DateTime? _dataVencimento;
  bool _ativo = true;
  String? _selectedCategoria;
  final List<String> _categorias = ['Cabelo', 'Corpo', 'Rosto', 'Maquiagem', '+ Adicionar Nova...'];

  Uint8List? _imageBytes;
  String? _currentImageUrl;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.product?.nome ?? '');
    _descController = TextEditingController(text: widget.product?.descricao ?? '');
    _precoController = TextEditingController(text: widget.product != null ? _formatInitialCurrency(widget.product!.precoVenda) : 'R\$ 0,00');
    _precoCustoController = TextEditingController(text: widget.product?.precoCusto != null ? _formatInitialCurrency(widget.product!.precoCusto!) : 'R\$ 0,00');
    _estoqueAtualController = TextEditingController(text: widget.product?.estoqueAtual.toString() ?? '0');
    _estoqueMinimoController = TextEditingController(text: widget.product?.estoqueMinimo.toString() ?? '1');
    _comissaoController = TextEditingController(text: widget.product?.comissaoPercentual.toString() ?? '0');
    _linkPagamentoController = TextEditingController(text: '');
    _dataVencimento = widget.product?.dataVencimento;
    _ativo = widget.product?.ativo ?? true;
    _currentImageUrl = widget.product?.imagemUrl;
  }

  String _formatInitialCurrency(double value) {
    int cents = (value * 100).round();
    String s = cents.toString().padLeft(3, '0');
    String integer = s.substring(0, s.length - 2);
    String decimal = s.substring(s.length - 2);
    return 'R\$ $integer,$decimal';
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descController.dispose();
    _precoController.dispose();
    _precoCustoController.dispose();
    _estoqueAtualController.dispose();
    _estoqueMinimoController.dispose();
    _comissaoController.dispose();
    _linkPagamentoController.dispose();
    _nomeError.dispose();
    _precoError.dispose();
    _categoriaError.dispose();
    _linkPagamentoError.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _imageBytes = bytes;
      });
    }
  }

  double _parseCurrency(String text) {
    String cleaned = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return 0.0;
    return double.parse(cleaned) / 100;
  }

  Future<void> _saveProduct() async {
    bool hasError = false;

    if (_nomeController.text.trim().isEmpty) {
      _nomeError.value = true;
      hasError = true;
    }
    if (_precoController.text.trim().isEmpty) {
      _precoError.value = true;
      hasError = true;
    }
    if (_selectedCategoria == null || _selectedCategoria == '+ Adicionar Nova...') {
      _categoriaError.value = true;
      hasError = true;
    }

    if (hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, preencha todos os campos obrigatórios.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? imageUrl = _currentImageUrl;

      if (_imageBytes != null) {
        final fileName = 'prod_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final uploadedUrl = await _repo.uploadProductImage(fileName, _imageBytes!);
        if (uploadedUrl != null) imageUrl = uploadedUrl;
      }

      final product = ProductModel(
        id: widget.product?.id ?? '',
        nome: _nomeController.text,
        descricao: _descController.text,
        precoVenda: _parseCurrency(_precoController.text),
        precoCusto: _precoCustoController.text.isNotEmpty ? _parseCurrency(_precoCustoController.text) : null,
        comissaoPercentual: double.tryParse(_comissaoController.text) ?? 0.0,
        estoqueAtual: int.tryParse(_estoqueAtualController.text) ?? 0,
        estoqueMinimo: int.tryParse(_estoqueMinimoController.text) ?? 5,
        imagemUrl: imageUrl,
        ativo: _ativo,
        dataVencimento: _dataVencimento,
        categoria: _selectedCategoria,
      );

      if (widget.product == null) {
        await _repo.createProduct(product);
      } else {
        await _repo.updateProduct(widget.product!.id, product);
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produto salvo com sucesso!'), backgroundColor: AppColors.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar produto: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Nova Categoria',
          style: TextStyle(color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontFamily: 'Playfair Display',
          ),
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nome da categoria'),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(side: BorderSide.none),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.accent),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  if (!_categorias.contains(name)) {
                    _categorias.insert(_categorias.length - 1, name);
                  }
                  _selectedCategoria = name;
                  _categoriaError.value = false;
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppColors.primary;
    final accentColor = AppColors.accent;
    final backgroundColor = AppColors.background;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho Padrão (Alinhado à esquerda)
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.arrow_back, color: primaryColor, size: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product == null ? 'Novo Produto' : 'Editar Produto',
                          style: TextStyle(fontFamily: 'Playfair Display', 
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        Text(
                          widget.product == null 
                              ? 'Cadastre novos produtos para a clínica' 
                              : 'Atualize as informações do produto',
                          style: TextStyle(
                            fontSize: 12, 
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Foto do Produto (Circular com borda dourada)
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                color: accentColor, 
                                width: 2,
                              ),
                              image: _imageBytes != null
                                  ? DecorationImage(
                                      image: MemoryImage(_imageBytes!),
                                      fit: BoxFit.cover,
                                    )
                                  : (_currentImageUrl != null && _currentImageUrl!.isNotEmpty)
                                      ? DecorationImage(
                                          image: NetworkImage(_currentImageUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                            ),
                            child: (_imageBytes == null && (_currentImageUrl == null || _currentImageUrl!.isEmpty))
                                ? Center(
                                    child: Icon(Icons.shopping_bag_outlined, size: 32, color: primaryColor),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        (_imageBytes == null && (_currentImageUrl == null || _currentImageUrl!.isEmpty))
                            ? '+ Adicionar Foto'
                            : 'Alterar Foto',
                        style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accentColor.withOpacity(0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildInputField(
                      label: 'Nome do Produto',
                      controller: _nomeController,
                      icon: Icons.shopping_bag_outlined,
                      hint: 'Nome do produto',
                      isRequired: true,
                      errorNotifier: _nomeError,
                      primaryColor: primaryColor,
                      accentColor: accentColor,
                    ),
                    const SizedBox(height: 20),
                    _buildInputField(
                      label: 'Descrição',
                      controller: _descController,
                      icon: Icons.description_outlined,
                      hint: 'Faça uma descrição do seu produto',
                      maxLines: 3,
                      primaryColor: primaryColor,
                      accentColor: accentColor,
                    ),
                    const SizedBox(height: 20),
                    _buildInputField(
                      label: 'Preço de Venda',
                      controller: _precoController,
                      icon: Icons.sell_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [CurrencyInputFormatter()],
                      isRequired: true,
                      errorNotifier: _precoError,
                      primaryColor: primaryColor,
                      accentColor: accentColor,
                    ),
                    const SizedBox(height: 20),
                    _buildDropdownField(
                      label: 'Categoria',
                      value: _selectedCategoria,
                      items: _categorias,
                      onChanged: (v) {
                        if (v == '+ Adicionar Nova...') {
                          _showAddCategoryDialog();
                        } else {
                          setState(() {
                            _selectedCategoria = v;
                            _categoriaError.value = false;
                          });
                        }
                      },
                      icon: Icons.category_outlined,
                      errorNotifier: _categoriaError,
                      primaryColor: primaryColor,
                      accentColor: accentColor,
                    ),
                    const SizedBox(height: 20),
                    _buildInputField(
                      label: 'Preço de Custo (Opcional)',
                      controller: _precoCustoController,
                      icon: Icons.payments_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [CurrencyInputFormatter()],
                      primaryColor: primaryColor,
                      accentColor: accentColor,
                    ),
                    const SizedBox(height: 20),
                    _buildInputField(
                      label: 'Estoque Atual',
                      controller: _estoqueAtualController,
                      icon: Icons.inventory_2_outlined,
                      keyboardType: TextInputType.number,
                      primaryColor: primaryColor,
                      accentColor: accentColor,
                    ),
                    const SizedBox(height: 20),
                    _buildInputField(
                      label: 'Estoque Mínimo (Alerta)',
                      controller: _estoqueMinimoController,
                      icon: Icons.notifications_active_outlined,
                      keyboardType: TextInputType.number,
                      primaryColor: primaryColor,
                      accentColor: accentColor,
                    ),
                    const SizedBox(height: 20),
                    _buildInputField(
                      label: 'Comissão (%)',
                      controller: _comissaoController,
                      icon: Icons.percent_outlined,
                      keyboardType: TextInputType.number,
                      primaryColor: primaryColor,
                      accentColor: accentColor,
                    ),
                    const SizedBox(height: 24),
                    _buildDateField(
                      label: 'Data de Vencimento',
                      value: _dataVencimento,
                      icon: Icons.event_available_outlined,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _dataVencimento ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (date != null) setState(() => _dataVencimento = date);
                      },
                      primaryColor: primaryColor,
                      accentColor: accentColor,
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Switch(
                          value: _ativo,
                          onChanged: (v) => setState(() => _ativo = v),
                          activeThumbColor: primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Produto Ativo',
                          style: TextStyle(fontWeight: FontWeight.bold,
                            color: _ativo ? primaryColor : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => context.pop(),
                            child: Text(
                              'Cancelar',
                              style: TextStyle(color: accentColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveProduct,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text('Salvar Produto', style: TextStyle(fontWeight: FontWeight.bold)),
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
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required IconData icon,
    required VoidCallback onTap,
    required Color primaryColor,
    required Color accentColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: accentColor),
          ),
        ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icon, color: primaryColor, size: 20),
                const SizedBox(width: 12),
                Text(
                  value != null ? DateFormat('dd/MM/yyyy').format(value) : 'Selecionar Data',
                  style: TextStyle(fontSize: 14,
                    color: value != null ? primaryColor : Colors.black26,
                  ),
                ),
                const Spacer(),
                if (value != null)
                  GestureDetector(
                    onTap: () {
                      setState(() => _dataVencimento = null);
                    },
                    child: const Icon(Icons.close, size: 18, color: Colors.red),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<dynamic>? inputFormatters,
    bool isRequired = false,
    ValueNotifier<bool>? errorNotifier,
    required Color primaryColor,
    required Color accentColor,
  }) {
    final notifier = errorNotifier ?? ValueNotifier<bool>(false);
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (context, hasError, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: hasError ? Colors.red : accentColor,
                ),
              ),
            ),
            TextFormField(
              controller: controller,
              maxLines: maxLines,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters?.cast<TextInputFormatter>(),
              onChanged: (val) {
                if (val.isNotEmpty && notifier.value) {
                  notifier.value = false;
                }
              },
              style: TextStyle(fontSize: 14, color: primaryColor),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle:
                    TextStyle(color: Colors.black26, fontSize: 14),
                prefixIcon: Icon(icon, color: primaryColor, size: 20),
                filled: true,
                fillColor: Colors.black.withOpacity(0.03),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: hasError
                        ? const BorderSide(color: Colors.red, width: 1.5)
                        : BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: hasError
                        ? const BorderSide(color: Colors.red, width: 1.5)
                        : BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: hasError ? Colors.red : accentColor, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            if (hasError)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  'Este campo é obrigatório',
                  style: TextStyle(color: Colors.red, fontSize: 11),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    required IconData icon,
    ValueNotifier<bool>? errorNotifier,
    required Color primaryColor,
    required Color accentColor,
  }) {
    final notifier = errorNotifier ?? ValueNotifier<bool>(false);
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (context, hasError, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: hasError ? Colors.red : accentColor,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: hasError
                    ? Border.all(color: Colors.red, width: 1.5)
                    : Border.all(color: Colors.transparent, width: 1.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: value,
                  isExpanded: true,
                  icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                  hint: Text('Selecionar...',
                      style: TextStyle(fontSize: 14, color: Colors.black26)),
                  items: items.map((String item) {
                    return DropdownMenuItem<String>(
                      value: item,
                      child: Text(item,
                          style: TextStyle(fontSize: 14, color: primaryColor)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    onChanged(val);
                    if (val != null) notifier.value = false;
                  },
                ),
              ),
            ),
            if (hasError)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  'Obrigatório',
                  style: TextStyle(color: Colors.red, fontSize: 11),
                ),
              ),
          ],
        );
      },
    );
  }
}

