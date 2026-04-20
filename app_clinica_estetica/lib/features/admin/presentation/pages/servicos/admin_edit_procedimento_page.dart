import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_admin_log_repository.dart';
import 'package:app_clinica_estetica/core/theme/app_button_styles.dart';
import 'package:app_clinica_estetica/core/utils/string_utils.dart';
import 'package:intl/intl.dart';

// ─── Currency Formatter ────────────────────────────────────────────────────
class _EditCurrencyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final value = int.parse(digits);
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final newText = fmt.format(value / 100);
    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class AdminEditProcedimentoPage extends StatefulWidget {
  final Map<String, dynamic> procedure;
  const AdminEditProcedimentoPage({super.key, required this.procedure});

  @override
  State<AdminEditProcedimentoPage> createState() =>
      _AdminEditProcedimentoPageState();
}

class _AdminEditProcedimentoPageState extends State<AdminEditProcedimentoPage> {
  static const _primaryColor = Color(0xFF2D5A46);
  static const _accentColor = Color(0xFFC7A36B);
  static const _bgColor = Color(0xFFF6F4EF);

  final _formKey = GlobalKey<FormState>();
  late bool _isActive;
  bool _isSaving = false;

  String? _selectedCategoryId;
  late String _selectedDuration;

  final _nomeController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _precoController = TextEditingController();
  final _precoPromocionalController = TextEditingController();
  
  // Promotional Dates
  DateTime? _dataInicioPromocao;
  DateTime? _dataFimPromocao;

  final List<String> _duracoes = [
    '15',
    '20',
    '25',
    '30',
    '40',
    '45',
    '50',
    '60',
    '75',
    '90',
    '100',
    '120',
    '150',
    '180',
    '240'
  ];
  List<Map<String, dynamic>> _categoriasData = [];

  XFile? _imageFile;
  Uint8List? _imageBytes;
  final _picker = ImagePicker();
  String? _currentImageUrl;

  @override
  void initState() {
    super.initState();
    _initData();
    _loadCategories();
  }

  void _initData() {
    final p = widget.procedure;
    _nomeController.text = p['nome'] ?? '';
    _descricaoController.text = p['descricao'] ?? '';
    
    final precoValue = p['preco'] ?? 0.0;
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    _precoController.text = fmt.format(precoValue);
    
    final duration = (p['duracao_minutos'] ?? 60).toString();
    if (!_duracoes.contains(duration)) {
      _duracoes.add(duration);
      _duracoes.sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    }
    _selectedDuration = duration;
    _selectedCategoryId = p['categoria_id'];
    _isActive = p['ativo'] ?? true;
    _currentImageUrl = p['imagem_url'];

    if (p['preco_promocional'] != null) {
      final precoPromocionalValue = p['preco_promocional'];
      _precoPromocionalController.text = fmt.format(precoPromocionalValue);
    }

    if (p['data_inicio_promocao'] != null) {
      _dataInicioPromocao = DateTime.parse(p['data_inicio_promocao']);
    }
    if (p['data_fim_promocao'] != null) {
      _dataFimPromocao = DateTime.parse(p['data_fim_promocao']);
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _precoController.dispose();
    _precoPromocionalController.dispose();
    super.dispose();
  }

  // ─── Load categories from Supabase ─────────────────────────────────────
  Future<void> _loadCategories() async {
    try {
      final response = await Supabase.instance.client
          .from('categorias')
          .select('id, nome, icone_url')
          .order('ordem');

      final data = response as List<dynamic>;
      setState(() {
        _categoriasData = data.cast<Map<String, dynamic>>();

        if (_categoriasData.isNotEmpty) {
          // Only auto-select if nothing is currently selected or the selected ID is invalid
          final bool currentIsInvalid = _selectedCategoryId != null && 
              !_categoriasData.any((c) => c['id'] == _selectedCategoryId);
          
          if (_selectedCategoryId == null || currentIsInvalid) {
            _selectedCategoryId = _categoriasData[0]['id'].toString();
          }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar categorias: $e'),
            backgroundColor: Colors.red),
        );
      }
    }
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
      default:
        return Icons.category_rounded;
    }
  }

  Widget _buildCategoryIcon(String? categoryId) {
    if (categoryId == null) {
      return const Icon(Icons.category, color: _primaryColor, size: 24);
    }

    final category = _categoriasData.firstWhere(
      (c) => c['id'] == categoryId,
      orElse: () => {},
    );

    final String? iconValue = category['icone_url'];

    if (iconValue == null || iconValue.isEmpty) {
      return const Icon(Icons.category, color: _primaryColor, size: 24);
    }

    // Standardized behavior: if starts with http, it's an image. Otherwise, it's an icon name.
    if (iconValue.startsWith('http')) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: _primaryColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Image.network(
            iconValue,
            width: 24,
            height: 24,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.category, color: _primaryColor, size: 24),
          ),
        ),
      );
    }

    return Icon(
      _getIconData(iconValue),
      color: _primaryColor,
      size: 24,
    );
  }

  // ─── Pick image ─────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageFile = picked;
        _imageBytes = bytes;
      });
    }
  }

  // ─── Upload image to Supabase Storage ───────────────────────────────────
  Future<String?> _uploadImage() async {
    if (_imageFile == null) return _currentImageUrl;
    try {
      final bytes = await _imageFile!.readAsBytes();
      final ext = _imageFile!.name.split('.').last;
      final fileName =
          'procedimentos/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await Supabase.instance.client.storage
          .from('perfis')
          .uploadBinary(fileName, bytes,
              fileOptions: FileOptions(contentType: 'image/$ext'));

      final publicUrl = Supabase.instance.client.storage
          .from('perfis')
          .getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      return _currentImageUrl;
    }
  }

  // ─── Parse price from mask ───────────────────────────────────────────────
  double _parsePrice(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return int.parse(digits) / 100;
  }

  // ─── Save procedure to Supabase ──────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? imageUrl = await _uploadImage();
      
      final preco = _parsePrice(_precoController.text);
      final precoPromocional = _precoPromocionalController.text.isNotEmpty 
          ? _parsePrice(_precoPromocionalController.text) 
          : null;
      final adminId = Supabase.instance.client.auth.currentUser?.id;

      if (precoPromocional != null && precoPromocional >= preco) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('O preço promocional deve ser menor que o preço original'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isSaving = false);
        return;
      }

      final data = {
        'nome': _nomeController.text.trim(),
        'descricao': _descricaoController.text.trim(),
        'preco': preco,
        'preco_promocional': precoPromocional,
        'duracao_minutos': int.parse(_selectedDuration),
        'categoria_id': _selectedCategoryId,
        'ativo': _isActive,
        'imagem_url': imageUrl,
        'data_inicio_promocao': _dataInicioPromocao?.toIso8601String(),
        'data_fim_promocao': _dataFimPromocao?.toIso8601String(),
      };
      
      await Supabase.instance.client
          .from('servicos')
          .update(data)
          .eq('id', widget.procedure['id']);

      // Log da ação
      await SupabaseAdminLogRepository().logAction(
        acao: 'Editar Procedimento',
        detalhes: 'Procedimento: ${data['nome']}',
        tabelaAfetada: 'servicos',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Procedimento atualizado com sucesso!',
                style: TextStyle()),
            backgroundColor: _primaryColor,
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar: $e',
                style: TextStyle()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.arrow_back,
                          color: _primaryColor, size: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Editar procedimento',
                          style: TextStyle(fontFamily: 'Playfair Display', 
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor,
                          ),
                        ),
                        Text(
                          'Atualize as informações do serviço',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Photo upload
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[200],
                          border: Border.all(
                            color: _accentColor,
                            width: 2,
                          ),
                          image: _imageBytes != null
                              ? DecorationImage(
                                  image: MemoryImage(_imageBytes!),
                                  fit: BoxFit.cover,
                                )
                              : (_currentImageUrl != null &&
                                      _currentImageUrl!.startsWith('http'))
                                  ? DecorationImage(
                                      image: NetworkImage(_currentImageUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                        ),
                        child: (_imageBytes == null &&
                                (_currentImageUrl == null ||
                                    !_currentImageUrl!.startsWith('http')))
                            ? const Icon(Icons.spa,
                                size: 48, color: _primaryColor)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                              color: _primaryColor,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.add_a_photo,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _imageFile == null
                      ? 'Alterar foto'
                      : 'Foto selecionada ✓',
                  style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _accentColor,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Form Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.black.withAlpha(13)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _inputField(
                        label: 'Nome do procedimento',
                        controller: _nomeController,
                        icon: Icons.edit_document,
                        hint: 'Ex: Protocolo VIP',
                      ),
                      const SizedBox(height: 20),

                      _categoryDropdown(),

                      const SizedBox(height: 20),
                      _inputField(
                        label: 'Descrição',
                        controller: _descricaoController,
                        icon: Icons.description,
                        hint:
                            'Descreva os detalhes e benefícios...',
                        maxLines: 4,
                        required: false,
                      ),
                      const SizedBox(height: 20),

                      // Preço
                      _inputField(
                        label: 'Preço (R\$)',
                        controller: _precoController,
                        icon: Icons.attach_money,
                        hint: 'R\$ 0,00',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          _EditCurrencyFormatter(),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Preço Promocional
                      _inputField(
                        label: 'Preço promocional (opcional)',
                        controller: _precoPromocionalController,
                        icon: Icons.discount,
                        hint: 'R\$ 0,00',
                        required: false,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          _EditCurrencyFormatter(),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder(
                        valueListenable: _precoPromocionalController,
                        builder: (context, value, _) {
                          if (value.text.isNotEmpty) {
                            return _buildPromotionDatePicker();
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      const SizedBox(height: 20),
                      _durationDropdown(),

                      const Divider(height: 36),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _accentColor,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Defina a disponibilidade do procedimento.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Switch(
                                value: _isActive,
                                onChanged: (v) => setState(() => _isActive = v),
                                activeThumbColor: Colors.white,
                                activeTrackColor: _primaryColor,
                                inactiveThumbColor: Colors.white,
                                inactiveTrackColor: Colors.grey[300],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isActive ? 'Ativo' : 'Inativo',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _isActive ? _primaryColor : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: _isSaving
                                  ? null
                                  : () => context.pop(),
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(
                                        vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ),
                                child: Text(
                                  StringUtils.toTitleCase('cancelar'),
                                  style: AppButtonStyles.cancelTextStyle(),
                                ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _save,
                              style: AppButtonStyles.primary(),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ))
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.save, size: 18),
                                        SizedBox(width: 8),
                                        Text(StringUtils.toTitleCase('salvar alterações')),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    int maxLines = 1,
    bool required = true,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10,
            fontWeight: FontWeight.w800,
            color: _accentColor,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: TextStyle(fontSize: 14,
            color: _primaryColor,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 14,
              color: Colors.black26,
            ),
            prefixIcon: Icon(icon, color: _primaryColor, size: 20),
            filled: true,
            fillColor: Colors.black.withAlpha(10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primaryColor, width: 1),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          validator: required
              ? (v) => v == null || v.isEmpty ? 'Campo obrigatório' : null
              : null,
        ),
      ],
    );
  }

  Widget _categoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categoria',
          style: TextStyle(fontSize: 10,
            fontWeight: FontWeight.w800,
            color: _accentColor,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _categoriasData.any((c) => c['id'] == _selectedCategoryId)
              ? _selectedCategoryId
              : null,
          decoration: InputDecoration(
            hintText: 'Selecione uma categoria',
            hintStyle: TextStyle(fontSize: 14,
              color: Colors.black26,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildCategoryIcon(_selectedCategoryId),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 24),
            filled: true,
            fillColor: Colors.black.withAlpha(10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primaryColor, width: 1),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          items: _categoriasData.map((dynamic cat) {
            return DropdownMenuItem<String>(
              value: cat['id'] as String,
              child: Text(cat['nome'] as String,
                  style: TextStyle(fontSize: 14)),
            );
          }).toList(),
          onChanged: (v) => setState(() => _selectedCategoryId = v),
          validator: (v) =>
              v == null ? 'Selecione uma categoria' : null,
        ),
      ],
    );
  }

  Widget _durationDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Duração',
          style: TextStyle(fontSize: 10,
            fontWeight: FontWeight.w800,
            color: _accentColor,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              initialValue: _selectedDuration,
              decoration: const InputDecoration(
                border: InputBorder.none,
                prefixIcon: Icon(Icons.timer, color: _primaryColor, size: 20),
              ),
              items: _duracoes.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text('$value min', style: TextStyle(fontSize: 14)),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedDuration = v!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPromotionDatePicker() {
    final fmt = DateFormat('dd/MM/yyyy');
    final String label = (_dataInicioPromocao != null && _dataFimPromocao != null)
        ? '${fmt.format(_dataInicioPromocao!)} - ${fmt.format(_dataFimPromocao!)}'
        : 'Programar período (Opcional)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Período da Promoção',
          style: TextStyle(fontSize: 10,
            fontWeight: FontWeight.w800,
            color: _accentColor,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              initialDateRange: (_dataInicioPromocao != null && _dataFimPromocao != null)
                  ? DateTimeRange(start: _dataInicioPromocao!, end: _dataFimPromocao!)
                  : null,
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: _primaryColor,
                      onPrimary: Colors.white,
                      onSurface: _primaryColor,
                    ),
                  ),
                  child: child!,
                );
              },
            );

            if (picked != null) {
              setState(() {
                _dataInicioPromocao = picked.start;
                _dataFimPromocao = picked.end;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: _primaryColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 14,
                      color: _dataInicioPromocao != null ? _primaryColor : Colors.black26,
                    ),
                  ),
                ),
                if (_dataInicioPromocao != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        _dataInicioPromocao = null;
                        _dataFimPromocao = null;
                      });
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
