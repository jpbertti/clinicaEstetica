import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_admin_log_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_notification_repository.dart';

// ─── Currency Formatter ────────────────────────────────────────────────────
class _AddCurrencyFormatter extends TextInputFormatter {
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

class AdminAddProcedimentoPage extends StatefulWidget {
  const AdminAddProcedimentoPage({super.key});

  @override
  State<AdminAddProcedimentoPage> createState() =>
      _AdminAddProcedimentoPageState();
}

class _AdminAddProcedimentoPageState extends State<AdminAddProcedimentoPage> {
  static const _primaryColor = Color(0xFF2D5A46);
  static const _accentColor = Color(0xFFC7A36B);
  static const _bgColor = Color(0xFFF6F4EF);

  final _formKey = GlobalKey<FormState>();
  bool _isActive = true;
  bool _isSaving = false;
  bool _isLoadingCategories = true;

  String? _selectedCategoryId;
  String _selectedDuration = '60';

  final _nomeController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _valorController = TextEditingController();
  final _precoPromocionalController = TextEditingController();
  
  // Promotional Dates
  DateTime? _dataInicioPromocao;
  DateTime? _dataFimPromocao;

  // Notificadores de erro para bordas vermelhas
  final _nomeValid = ValueNotifier<bool>(true);
  final _descricaoValid = ValueNotifier<bool>(true);
  final _valorValid = ValueNotifier<bool>(true);
  final _precoPromocionalValid = ValueNotifier<bool>(true);
  final _categoriaValid = ValueNotifier<bool>(true);
  final _duracaoValid = ValueNotifier<bool>(true);

  final List<String> _duracoes = [
    '15', '20', '25', '30', '40', '45', '50', '60', '75', '90', '100', '120', '150', '180', '240'
  ];
  List<Map<String, dynamic>> _categoriasData = [];

  final List<String> _iconOptions = [
    'spa', 'face', 'brush', 'content_cut', 'auto_awesome', 'water_drop', 'favorite', 'health_and_safety', 'sentiment_very_satisfied', 'clean_hands',
  ];

  XFile? _imageFile;
  Uint8List? _imageBytes;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _valorController.dispose();
    _precoPromocionalController.dispose();
    _nomeValid.dispose();
    _descricaoValid.dispose();
    _valorValid.dispose();
    _precoPromocionalValid.dispose();
    _categoriaValid.dispose();
    _duracaoValid.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final response = await Supabase.instance.client
          .from('categorias')
          .select('id, nome, icone_url')
          .order('ordem');

      final data = response as List<dynamic>;
      setState(() {
        _categoriasData = data.cast<Map<String, dynamic>>();

        if (_categoriasData.isNotEmpty) {
          _selectedCategoryId ??= _categoriasData.first['id'];
        }
        _isLoadingCategories = false;
      });
    } catch (e) {
      setState(() {
        _categoriasData = [];
        _isLoadingCategories = false;
      });
    }
  }

  IconData _getIconData(String iconName) {
    iconName = iconName.replaceFirst('icon:', '').trim();
    switch (iconName) {
      case 'spa': return Icons.spa;
      case 'face': return Icons.face_retouching_natural;
      case 'brush': return Icons.brush;
      case 'content_cut': return Icons.content_cut;
      case 'auto_awesome': return Icons.auto_awesome;
      case 'water_drop': return Icons.water_drop;
      case 'favorite': return Icons.favorite;
      case 'health_and_safety': return Icons.health_and_safety;
      case 'sentiment_very_satisfied': return Icons.sentiment_very_satisfied;
      case 'clean_hands': return Icons.clean_hands;
      default: return Icons.category_rounded;
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
    if (iconValue.startsWith('http')) {
      return Container(
        width: 24, height: 24,
        decoration: BoxDecoration(
          color: _primaryColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Image.network(
            iconValue, width: 24, height: 24, fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(Icons.category, color: _primaryColor, size: 24),
          ),
        ),
      );
    }
    return Icon(_getIconData(iconValue), color: _primaryColor, size: 24);
  }

  Future<void> _showAddCategoryDialog() async {
    final controller = TextEditingController();
    bool saving = false;
    String tempSelectedIcon = _iconOptions.first;
    bool tempIsUsingIcon = true;
    XFile? tempImageFile;
    Uint8List? tempImageBytes;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Nova Categoria', style: TextStyle(fontFamily: 'Playfair Display', fontWeight: FontWeight.bold, color: _primaryColor, fontSize: 20)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: _primaryColor.withOpacity(0.1), width: 2),
                  ),
                  child: ClipOval(
                    child: tempIsUsingIcon
                        ? Icon(_getIconData(tempSelectedIcon), size: 32, color: _primaryColor)
                        : tempImageBytes != null
                            ? Image.memory(tempImageBytes!, fit: BoxFit.cover, width: 70, height: 70)
                            : Icon(Icons.photo, size: 32, color: Colors.grey[300]),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: TextStyle(color: _primaryColor, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Ex: Capilares',
                    hintStyle: TextStyle(color: Colors.black38, fontSize: 13),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.04),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _accentColor, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 100, width: double.maxFinite,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 8, crossAxisSpacing: 8),
                    itemCount: _iconOptions.length + 1,
                    itemBuilder: (ctx, index) {
                      if (index == 0) {
                        return GestureDetector(
                          onTap: () async {
                            final picked = await _picker.pickImage(source: ImageSource.gallery);
                            if (picked != null) {
                              final bytes = await picked.readAsBytes();
                              setDialogState(() {
                                tempImageFile = picked;
                                tempImageBytes = bytes;
                                tempIsUsingIcon = false;
                              });
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: !tempIsUsingIcon ? _primaryColor : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.black.withOpacity(0.05)),
                            ),
                            child: Icon(Icons.add_a_photo, size: 18, color: !tempIsUsingIcon ? Colors.white : _primaryColor),
                          ),
                        );
                      }
                      final iconName = _iconOptions[index - 1];
                      final isSelected = tempIsUsingIcon && tempSelectedIcon == iconName;
                      return GestureDetector(
                        onTap: () => setDialogState(() { tempSelectedIcon = iconName; tempIsUsingIcon = true; }),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? _primaryColor : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.black.withOpacity(0.05)),
                          ),
                          child: Icon(_getIconData(iconName), size: 18, color: isSelected ? Colors.white : _primaryColor.withOpacity(0.5)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancelar', style: TextStyle(color: _accentColor))),
            ElevatedButton(
              onPressed: saving ? null : () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                setDialogState(() => saving = true);
                try {
                  String iconValue;
                  if (tempIsUsingIcon) {
                    iconValue = tempSelectedIcon;
                  } else {
                    final bytes = await tempImageFile!.readAsBytes();
                    final ext = tempImageFile!.name.split('.').last;
                    final fileName = 'categorias/${DateTime.now().millisecondsSinceEpoch}.$ext';
                    await Supabase.instance.client.storage.from('perfis').uploadBinary(fileName, bytes, fileOptions: FileOptions(contentType: 'image/$ext'));
                    iconValue = Supabase.instance.client.storage.from('perfis').getPublicUrl(fileName);
                  }
                  final inserted = await Supabase.instance.client.from('categorias').insert({'nome': name, 'ordem': 99, 'icone_url': iconValue}).select('id').single();
                  if (ctx.mounted) Navigator.pop(ctx, inserted['id']);
                } catch (e) {
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Salvar', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    ).then((newCategoryId) {
      if (newCategoryId != null && newCategoryId is String) {
        _loadCategories().then((_) {
          setState(() => _selectedCategoryId = newCategoryId);
        });
      }
    });
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageFile = picked;
        _imageBytes = bytes;
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return null;
    try {
      final bytes = await _imageFile!.readAsBytes();
      final ext = _imageFile!.name.split('.').last;
      final fileName = 'procedimentos/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await Supabase.instance.client.storage.from('perfis').uploadBinary(fileName, bytes, fileOptions: FileOptions(contentType: 'image/$ext'));
      return Supabase.instance.client.storage.from('perfis').getPublicUrl(fileName);
    } catch (e) { return null; }
  }

  double _parsePrice(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return int.parse(digits) / 100;
  }

  Future<void> _saveProcedimento() async {
    _nomeValid.value = _nomeController.text.isNotEmpty;
    _descricaoValid.value = _descricaoController.text.isNotEmpty;
    _valorValid.value = _valorController.text.isNotEmpty;
    _categoriaValid.value = _selectedCategoryId != null;
    _duracaoValid.value = _selectedDuration.isNotEmpty;

    if (!_nomeValid.value || !_descricaoValid.value || !_valorValid.value || !_categoriaValid.value || !_duracaoValid.value) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, preencha todos os campos obrigatórios'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSaving = true);
    try {
      String? imageUrl = await _uploadImage();
      final adminId = Supabase.instance.client.auth.currentUser?.id;

      // Parsing prices
      final preco = double.tryParse(_valorController.text.replaceAll('R\$', '').replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;
      final precoPromocional = _precoPromocionalController.text.isNotEmpty
          ? double.tryParse(_precoPromocionalController.text.replaceAll('R\$', '').replaceAll('.', '').replaceAll(',', '.'))
          : null;

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
        'admin_promocao_id': precoPromocional != null ? adminId : null,
      };

      await Supabase.instance.client.from('servicos').insert(data);

      // Notificar clientes se houver promoção
      if (precoPromocional != null) {
        try {
          final profileResponse = await Supabase.instance.client
              .from('perfis')
              .select('nome_completo')
              .eq('id', adminId ?? '')
              .single();
          final adminNome = profileResponse['nome_completo'] ?? 'Administração';
          
          final df = DateFormat('dd/MM/yyyy');
          final periodo = (_dataInicioPromocao != null && _dataFimPromocao != null)
              ? 'de ${df.format(_dataInicioPromocao!)} até ${df.format(_dataFimPromocao!)}'
              : 'por tempo limitado';

          final msg = 'Novidade! O procedimento ${_nomeController.text} já está disponível com preço promocional: '
              'R\$ ${precoPromocional.toStringAsFixed(2).replaceFirst('.', ',')} ($periodo). '
              'Aproveite! - Por: $adminNome';

          await SupabaseNotificationRepository().notifyAllClients(
            titulo: '🔥 Novo Procedimento em Promoção!',
            mensagem: msg,
            tipo: 'promocao',
          );
        } catch (e) {
          debugPrint('Erro ao enviar notificação de promoção: $e');
        }
      }
      await SupabaseAdminLogRepository().logAction(acao: 'Cadastrar Procedimento', detalhes: 'Procedimento: ${data['nome']}', tabelaAfetada: 'servicos');
      await SupabaseNotificationRepository().notifyAllAdmins(
        titulo: 'Novo Procedimento',
        mensagem: 'Um novo procedimento (${data['nome']}) foi cadastrado.',
        tipo: 'novo_procedimento',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Procedimento salvo com sucesso!'), backgroundColor: _primaryColor));
        context.pop(true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildPromotionDatePicker() {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final hasRange = _dataInicioPromocao != null && _dataFimPromocao != null;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _accentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accentColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month, size: 16, color: _accentColor),
              const SizedBox(width: 8),
              Text(
                'Programar Período (Opcional)',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _accentColor, letterSpacing: 1.2),
              ),
              const Spacer(),
              if (hasRange)
                GestureDetector(
                  onTap: () => setState(() { _dataInicioPromocao = null; _dataFimPromocao = null; }),
                  child: const Icon(Icons.close, size: 16, color: Colors.red),
                ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                initialDateRange: hasRange ? DateTimeRange(start: _dataInicioPromocao!, end: _dataFimPromocao!) : null,
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: _primaryColor, onPrimary: Colors.white, onSurface: _primaryColor)),
                    child: child!,
                  );
                },
              );
              if (range != null) {
                setState(() { _dataInicioPromocao = range.start; _dataFimPromocao = range.end; });
              }
            },
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasRange ? '${dateFormat.format(_dataInicioPromocao!)} - ${dateFormat.format(_dataFimPromocao!)}' : 'Selecionar intervalo de datas...',
                    style: TextStyle(fontSize: 13, color: hasRange ? _primaryColor : Colors.black38, fontWeight: hasRange ? FontWeight.bold : FontWeight.normal),
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18, color: _accentColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.arrow_back, color: _primaryColor, size: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Adicionar Procedimento', style: TextStyle(fontFamily: 'Playfair Display', fontSize: 22, fontWeight: FontWeight.bold, color: _primaryColor)),
                        Text('Cadastre novos serviços para a clínica', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[200],
                          border: Border.all(color: _accentColor, width: 2),
                          image: _imageBytes != null ? DecorationImage(image: MemoryImage(_imageBytes!), fit: BoxFit.cover) : null,
                        ),
                        child: _imageBytes == null ? const Icon(Icons.spa, size: 48, color: _primaryColor) : null,
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: _primaryColor, shape: BoxShape.circle),
                          child: const Icon(Icons.add_a_photo, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _imageFile == null ? '+ Adicionar Foto' : 'Foto selecionada ✓',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _imageFile == null ? _accentColor : _primaryColor),
                ),
              ),
              const SizedBox(height: 28),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black.withOpacity(0.05)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _inputField(label: 'Nome do Procedimento', controller: _nomeController, icon: Icons.edit_document, hint: 'Ex: Protocolo VIP', isValid: _nomeValid),
                      const SizedBox(height: 20),
                      _categoryRow(),
                      const SizedBox(height: 20),
                      _inputField(label: 'Descrição', controller: _descricaoController, icon: Icons.description, hint: 'Descreva os detalhes e benefícios...', maxLines: 4, required: false, isValid: _descricaoValid),
                      const SizedBox(height: 20),
                      _inputField(label: 'Preço (R\$)', controller: _valorController, icon: Icons.attach_money, hint: 'R\$ 0,00', keyboardType: TextInputType.number, inputFormatters: [_AddCurrencyFormatter()], isValid: _valorValid),
                      const SizedBox(height: 20),
                      _inputField(
                        label: 'Preço Promo. (Opcional)', 
                        controller: _precoPromocionalController, 
                        icon: Icons.discount, 
                        hint: 'R\$ 0,00', 
                        keyboardType: TextInputType.number, 
                        required: false, 
                        inputFormatters: [_AddCurrencyFormatter()], 
                        isValid: _precoPromocionalValid,
                        suffix: _precoPromocionalController.text.isNotEmpty 
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _precoPromocionalController.clear();
                                  _dataInicioPromocao = null;
                                  _dataFimPromocao = null;
                                });
                              },
                            )
                          : null,
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
                            'Disponível para agendamentos?',
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
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: _isSaving ? null : () => context.pop(),
                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              child: Text('Cancelar', style: TextStyle(fontWeight: FontWeight.bold, color: _accentColor)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveProcedimento,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 4, shadowColor: _primaryColor.withOpacity(0.4),
                              ),
                              child: _isSaving
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.save, size: 18), const SizedBox(width: 8), Text('Salvar Procedimento', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))]),
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

  Widget _inputField({required String label, required TextEditingController controller, required IconData icon, String? hint, int maxLines = 1, TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters, bool required = true, ValueNotifier<bool>? isValid, Widget? suffix}) {
    final notifier = isValid ?? ValueNotifier<bool>(true);
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (context, valid, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(label),
            TextFormField(
              controller: controller, maxLines: maxLines, keyboardType: keyboardType, inputFormatters: inputFormatters,
              onChanged: (v) { if (v.isNotEmpty) notifier.value = true; setState(() {}); },
              style: TextStyle(fontSize: 14, color: _primaryColor),
              decoration: _inputDec(hint: hint, icon: icon, hasError: !valid, suffix: suffix),
              validator: required ? (v) => (v == null || v.isEmpty) ? 'Campo obrigatório' : null : null,
            ),
            if (!valid) Padding(padding: const EdgeInsets.only(top: 4, left: 4), child: Text('Este campo é obrigatório', style: TextStyle(color: Colors.red, fontSize: 11))),
          ],
        );
      },
    );
  }

  Widget _categoryRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Categoria'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _isLoadingCategories
                  ? Container(height: 52, decoration: BoxDecoration(color: Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _primaryColor)))
                  : DropdownButtonFormField<String>(
                      initialValue: _categoriasData.any((c) => c['id'] == _selectedCategoryId) ? _selectedCategoryId : null,
                      decoration: _inputDec(hint: 'Selecione uma categoria', icon: Icons.category),
                      isExpanded: true,
                      style: TextStyle(fontSize: 14, color: _primaryColor),
                      icon: const Icon(Icons.arrow_drop_down, color: _primaryColor),
                      onChanged: (v) => setState(() => _selectedCategoryId = v),
                      items: _categoriasData.map((c) => DropdownMenuItem<String>(value: c['id'] as String, child: Row(children: [_buildCategoryIcon(c['id'] as String), const SizedBox(width: 12), Text(c['nome'] as String)]))).toList(),
                      validator: (v) => v == null ? 'Campo obrigatório' : null,
                    ),
            ),
            const SizedBox(width: 10),
            Tooltip(
              message: 'Nova categoria',
              child: InkWell(
                onTap: _showAddCategoryDialog, borderRadius: BorderRadius.circular(12),
                child: Container(width: 50, height: 52, decoration: BoxDecoration(color: _accentColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: _accentColor.withOpacity(0.3))), child: const Icon(Icons.add, color: _accentColor, size: 22)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _durationDropdown() {
    return ValueListenableBuilder<bool>(
      valueListenable: _duracaoValid,
      builder: (context, valid, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Duração (min)'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(12), border: valid ? null : Border.all(color: Colors.red, width: 1.5)),
              child: Row(
                children: [
                  const Icon(Icons.timer, color: _primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedDuration, isExpanded: true, style: TextStyle(fontSize: 14, color: _primaryColor),
                        icon: const Icon(Icons.arrow_drop_down, color: _primaryColor),
                        onChanged: (v) { setState(() => _selectedDuration = v!); if (v != null) _duracaoValid.value = true; },
                        items: _duracoes.map((d) => DropdownMenuItem<String>(value: d, child: Text('$d min'))).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!valid) Padding(padding: const EdgeInsets.only(top: 4, left: 4), child: Text('Obrigatório', style: TextStyle(color: Colors.red, fontSize: 11))),
          ],
        );
      },
    );
  }

  Widget _label(String text) => Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _accentColor)));

  InputDecoration _inputDec({String? hint, required IconData icon, bool hasError = false, Widget? suffix}) => InputDecoration(
    hintText: hint, hintStyle: TextStyle(color: Colors.black26, fontSize: 13), prefixIcon: Icon(icon, color: _primaryColor, size: 20),
    suffixIcon: suffix,
    filled: true, fillColor: Colors.black.withOpacity(0.03),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: hasError ? const BorderSide(color: Colors.red, width: 1.5) : BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: hasError ? const BorderSide(color: Colors.red, width: 1.5) : BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hasError ? Colors.red : _primaryColor, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}
