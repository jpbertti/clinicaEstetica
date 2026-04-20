import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_clinica_estetica/core/data/models/pacote_template_model.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_package_repository.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_admin_log_repository.dart';
import 'package:app_clinica_estetica/core/widgets/currency_formatter.dart';
import 'package:intl/intl.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_notification_repository.dart';
import 'package:app_clinica_estetica/core/theme/app_button_styles.dart';
import 'package:app_clinica_estetica/core/utils/string_utils.dart';

class AdminAddEditPacotePage extends StatefulWidget {
  final PacoteTemplateModel? pacoteToEdit;

  const AdminAddEditPacotePage({super.key, this.pacoteToEdit});

  @override
  State<AdminAddEditPacotePage> createState() => _AdminAddEditPacotePageState();
}

class _AdminAddEditPacotePageState extends State<AdminAddEditPacotePage> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _valorController = TextEditingController();
  final _valorPromocionalController = TextEditingController();
  final _sessoesController = TextEditingController();
  final _comissaoController = TextEditingController();

  DateTime? _dataInicioPromocao;
  DateTime? _dataFimPromocao;

  String? _selectedCategoryId;
  List<PacoteServicoItem> _selectedServiceItems = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _services = [];
  bool _ativo = true;

  Uint8List? _imageBytes;
  String? _imageName;
  String? _currentImageUrl;
  bool _isLoading = false;
  late final SupabasePackageRepository _packageRepo;
  final Map<String, ExpansibleController> _expansionControllers = {};

  final List<String> _iconOptions = [
    'spa',
    'face',
    'brush',
    'content_cut',
    'auto_awesome',
    'water_drop',
    'favorite',
    'health_and_safety',
    'sentiment_very_satisfied',
    'clean_hands',
  ];

  @override
  void initState() {
    super.initState();
    _packageRepo = SupabasePackageRepository(Supabase.instance.client);
    _loadInitialData();
    // - [x] **Administrative UI**
    // - [x] Fix date selection in `AdminEditProcedimentoPage` (prevent past dates)
    // - [x] Update `AdminEditProcedimentoPage` to save `admin_promocao_id` and send notifications
    // - [x] Update `AdminAddProcedimentoPage` to save `admin_promocao_id` and send notifications
    // - [/] Update `AdminAddEditPacotePage` to save `admin_promocao_id`, fix dates, and send notifications
    if (widget.pacoteToEdit != null) {
      _tituloController.text = widget.pacoteToEdit!.titulo;
      _descricaoController.text = widget.pacoteToEdit!.descricao ?? '';
      _valorController.text = widget.pacoteToEdit!.valorTotal
          .toStringAsFixed(2)
          .replaceAll('.', ',');
      if (widget.pacoteToEdit!.valorPromocional != null) {
        _valorPromocionalController.text = widget.pacoteToEdit!.valorPromocional!
            .toStringAsFixed(2)
            .replaceAll('.', ',');
      }
      _sessoesController.text = widget.pacoteToEdit!.quantidadeSessoes
          .toString();
      _currentImageUrl = widget.pacoteToEdit!.imagemUrl;
      _selectedCategoryId = widget.pacoteToEdit!.categoriaId;
      _selectedServiceItems = List<PacoteServicoItem>.from(
        widget.pacoteToEdit!.servicos ?? [],
      );
      _ativo = widget.pacoteToEdit!.ativo;
      _comissaoController.text = (widget.pacoteToEdit!.comissaoPercentual ?? 0)
          .toStringAsFixed(0);
      _dataInicioPromocao = widget.pacoteToEdit!.dataInicioPromocao;
      _dataFimPromocao = widget.pacoteToEdit!.dataFimPromocao;
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      final categoriesResp = await supabase
          .from('categorias')
          .select()
          .order('nome');
      final servicesResp = await supabase
          .from('servicos')
          .select()
          .eq('ativo', true)
          .order('nome');

      setState(() {
        _categories = List<Map<String, dynamic>>.from(categoriesResp);
        _services = List<Map<String, dynamic>>.from(servicesResp);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar dados iniciais: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    _valorController.dispose();
    _valorPromocionalController.dispose();
    _sessoesController.dispose();
    _comissaoController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageName = pickedFile.name;
      });
    }
  }

  IconData _getIconData(String iconName) {
    iconName = iconName.replaceFirst('icon:', '').trim();
    switch (iconName) {
      case 'spa':
        return Icons.spa;
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

  Future<String?> _uploadImage(Uint8List bytes, String fileName) async {
    try {
      final extension = fileName.split('.').last;
      final finalFileName =
          'pacotes/${DateTime.now().millisecondsSinceEpoch}.$extension';

      await Supabase.instance.client.storage
          .from('servicos')
          .uploadBinary(
            finalFileName,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$extension'),
          );
      return Supabase.instance.client.storage
          .from('servicos')
          .getPublicUrl(finalFileName);
    } catch (e) {
      debugPrint('Erro no upload de imagem: $e');
      throw Exception('Erro ao enviar imagem para o storage.');
    }
  }

  Future<void> _savePacote() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedServiceItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione ao menos um procedimento'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl = _currentImageUrl;
      if (_imageBytes != null && _imageName != null) {
        imageUrl = await _uploadImage(_imageBytes!, _imageName!);
      }

      final double valorTotal = double.parse(
        _valorController.text
            .replaceAll(r'R$', '')
            .replaceAll('.', '')
            .replaceAll(',', '.')
            .trim(),
      );

      double? valorPromocional;
      if (_valorPromocionalController.text.isNotEmpty) {
        valorPromocional = double.parse(
          _valorPromocionalController.text
              .replaceAll(r'R$', '')
              .replaceAll('.', '')
              .replaceAll(',', '.')
              .trim(),
        );
      }

      // Calculate total sessions from all services
      final int totalSessoes = _selectedServiceItems.fold(
        0,
        (sum, item) => sum + item.quantidadeSessoes,
      );

      final double? comissaoPercentual = double.tryParse(
        _comissaoController.text.trim(),
      );

      final pacote = PacoteTemplateModel(
        id: widget.pacoteToEdit?.id ?? '',
        titulo: _tituloController.text.trim(),
        descricao: _descricaoController.text.trim().isEmpty
            ? null
            : _descricaoController.text.trim(),
        valorTotal: valorTotal,
        quantidadeSessoes: totalSessoes,
        imagemUrl: imageUrl,
        categoriaId: _selectedCategoryId,
        servicos: _selectedServiceItems,
        ativo: _ativo,
        comissaoPercentual: comissaoPercentual,
        valorPromocional: valorPromocional,
        dataInicioPromocao: _dataInicioPromocao,
        dataFimPromocao: _dataFimPromocao,
        adminPromocaoId: valorPromocional != null ? Supabase.instance.client.auth.currentUser?.id : null,
      );

      if (widget.pacoteToEdit == null) {
        final inserted = await _packageRepo.createTemplate(pacote);
        await SupabaseAdminLogRepository().logAction(
          acao: 'Cadastrar Pacote',
          tabelaAfetada: 'pacotes_templates',
          itemId: inserted.id,
          detalhes: 'Pacote: ${inserted.titulo}',
        );
      } else {
        await _packageRepo.updateTemplate(pacote);
        await SupabaseAdminLogRepository().logAction(
          acao: 'Editar Pacote',
          tabelaAfetada: 'pacotes_templates',
          itemId: pacote.id,
          detalhes: 'Pacote: ${pacote.titulo}',
        );
      }

      // Notificar clientes se houver promoção nova ou alterada
      if (valorPromocional != null) {
        try {
          final adminId = Supabase.instance.client.auth.currentUser?.id;
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

          final msg = 'Oferta Incrível! O pacote "${_tituloController.text}" está com preço promocional: '
              'R\$ ${valorPromocional.toStringAsFixed(2).replaceFirst('.', ',')} ($periodo). '
              'Garanta o seu! - Por: $adminNome';

          await SupabaseNotificationRepository().notifyAllClients(
            titulo: '🔥 Novo Pacote em Promoção!',
            mensagem: msg,
            tipo: 'promocao',
          );
        } catch (notifierError) {
          debugPrint('Erro ao enviar notificação de promoção: $notifierError');
          // Não interrompe o fluxo principal se a notificação falhar
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pacote salvo com sucesso!'),
            backgroundColor: Color(0xFF2D5A46),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar pacote: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final controller = TextEditingController();
    bool saving = false;
    String tempSelectedIcon = _iconOptions.first;
    bool tempIsUsingIcon = true;
    XFile? tempImageFile;
    Uint8List? tempImageBytes;
    final picker = ImagePicker();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Nova Categoria',
            style: TextStyle(fontFamily: 'Playfair Display', 
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2D5A46),
              fontSize: 20,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: const Color(0xFF2D5A46),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: tempIsUsingIcon
                        ? Icon(
                            _getIconData(tempSelectedIcon),
                            size: 32,
                            color: const Color(0xFF2D5A46),
                          )
                        : tempImageBytes != null
                        ? Image.memory(
                            tempImageBytes!,
                            fit: BoxFit.cover,
                            width: 70,
                            height: 70,
                          )
                        : Icon(Icons.photo, size: 32, color: Colors.grey[300]),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: TextStyle(color: const Color(0xFF2D5A46),
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ex: Capilares',
                    hintStyle: TextStyle(color: Colors.black38,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFF2D5A46),
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 100,
                  width: double.maxFinite,
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemCount: _iconOptions.length + 1,
                    itemBuilder: (ctx, index) {
                      if (index == 0) {
                        return GestureDetector(
                          onTap: () async {
                            final picked = await picker.pickImage(
                              source: ImageSource.gallery,
                            );
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
                              color: !tempIsUsingIcon
                                  ? const Color(0xFF2D5A46)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.black.withOpacity(0.05),
                              ),
                            ),
                            child: Icon(
                              Icons.add_a_photo,
                              size: 18,
                              color: !tempIsUsingIcon
                                  ? Colors.white
                                  : const Color(0xFF2D5A46),
                            ),
                          ),
                        );
                      }

                      final iconName = _iconOptions[index - 1];
                      final isSelected =
                          tempIsUsingIcon && tempSelectedIcon == iconName;
                      return GestureDetector(
                        onTap: () => setDialogState(() {
                          tempSelectedIcon = iconName;
                          tempIsUsingIcon = true;
                        }),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF2D5A46)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.black.withOpacity(0.05),
                            ),
                          ),
                          child: Icon(
                            _getIconData(iconName),
                            size: 18,
                            color: isSelected
                                ? Colors.white
                                : const Color(
                                    0xFF2D5A46,
                                  ).withOpacity(0.5),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancelar',
                style: TextStyle(color: const Color(0xFFC7A36B)),
              ),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
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
                          final fileName =
                              'categorias/${DateTime.now().millisecondsSinceEpoch}.$ext';
                          await Supabase.instance.client.storage
                              .from('perfis')
                              .uploadBinary(
                                fileName,
                                bytes,
                                fileOptions: FileOptions(
                                  contentType: 'image/$ext',
                                ),
                              );

                          iconValue = Supabase.instance.client.storage
                              .from('perfis')
                              .getPublicUrl(fileName);
                        }

                        final resp = await Supabase.instance.client
                            .from('categorias')
                            .insert({
                              'nome': name,
                              'ordem': 99,
                              'icone_url': iconValue,
                            })
                            .select()
                            .single();

                        await _loadInitialData();
                        if (ctx.mounted) {
                          setState(() {
                            _selectedCategoryId = resp['id'].toString();
                          });
                          Navigator.pop(ctx);
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('Erro ao salvar: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              style: AppButtonStyles.primary(),
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF2D5A46);
    const goldColor = Color(0xFFC7A36B);
    const backgroundColor = Color(0xFFF6F4EF);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cabeçalho Padrão (Alinhado à esquerda)
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.arrow_back, color: primaryGreen, size: 24),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.pacoteToEdit == null ? 'Novo Pacote' : 'Editar Pacote',
                                style: TextStyle(fontFamily: 'Playfair Display', 
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: primaryGreen,
                                ),
                              ),
                              Text(
                                widget.pacoteToEdit == null
                                    ? 'Crie uma nova oferta de sessões'
                                    : 'Ajuste os detalhes deste pacote',
                                style: TextStyle(fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Foto do Pacote (Circular com borda dourada)
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
                                    color: Colors.grey[200],
                                    border: Border.all(
                                      color: goldColor,
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
                                      ? const Center(
                                          child: Icon(Icons.add_a_photo, size: 32, color: primaryGreen),
                                        )
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: primaryGreen,
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
                                color: goldColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Card do Formulário (Container Branco)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.05),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader('Dados básicos', goldColor),
                            const SizedBox(height: 16),
                            _buildTextField(
                              label: 'Título do pacote',
                              controller: _tituloController,
                              hint: 'Ex: Combo Verão VIP',
                              icon: Icons.title_rounded,
                              validator: (v) =>
                                  v!.isEmpty ? 'Obrigatório' : null,
                            ),
                            const SizedBox(height: 24),
                            _buildTextField(
                              label: 'Descrição completa',
                              controller: _descricaoController,
                              hint:
                                  'Descreva os benefícios e o que está incluso...',
                              icon: Icons.description_outlined,
                              maxLines: 4,
                            ),

                            const SizedBox(height: 32),
                            _buildSectionHeader(
                              'Status do pacote',
                              goldColor,
                            ),
                            const SizedBox(height: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Status',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: goldColor,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Defina se este pacote está disponível para venda.',
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
                                      value: _ativo,
                                      onChanged: (val) => setState(() => _ativo = val),
                                      activeThumbColor: Colors.white,
                                      activeTrackColor: primaryGreen,
                                      inactiveThumbColor: Colors.white,
                                      inactiveTrackColor: Colors.grey[300],
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _ativo ? 'Ativo' : 'Inativo',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: _ativo ? primaryGreen : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 32),
                            _buildSectionHeader(
                              'Valores e sessões',
                              goldColor,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              label: 'Valor total do pacote',
                              controller: _valorController,
                              hint: r'R$ 0,00',
                              icon: Icons.payments_outlined,
                              keyboardType: TextInputType.number,
                              formatters: [
                                CurrencyInputFormatter(),
                              ],
                              validator: (v) =>
                                  v!.isEmpty ? 'Obrigatório' : null,
                            ),
                            const SizedBox(height: 24),
                            _buildTextField(
                              label: 'Valor promocional (opcional)',
                              controller: _valorPromocionalController,
                              hint: r'R$ 0,00',
                              icon: Icons.local_offer_outlined,
                              keyboardType: TextInputType.number,
                              formatters: [
                                CurrencyInputFormatter(),
                              ],
                              onChanged: (v) {
                                setState(() {});
                              },
                              suffixIcon: _valorPromocionalController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close,
                                          size: 18, color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          _valorPromocionalController.clear();
                                          _dataInicioPromocao = null;
                                          _dataFimPromocao = null;
                                        });
                                      },
                                    )
                                  : null,
                            ),
                            if (_valorPromocionalController.text.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _buildPromotionDatePicker(goldColor, primaryGreen),
                            ],
                            const SizedBox(height: 24),
                            _buildTextField(
                              label: 'Comissão do profissional (%)',
                              controller: _comissaoController,
                              hint: 'Ex: 30',
                              icon: Icons.percent_rounded,
                              keyboardType: TextInputType.number,
                              formatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),

                            const SizedBox(height: 32),
                            _buildSectionHeader('Categoria', goldColor),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 56,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF6F4EF),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _selectedCategoryId,
                                        style: TextStyle(color: Colors.black,
                                          fontSize: 15,
                                        ),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                        ),
                                        items: _categories.map((cat) {
                                          return DropdownMenuItem(
                                            value: cat['id'].toString(),
                                            child: Text(cat['nome'].toString()),
                                          );
                                        }).toList(),
                                        onChanged: (val) => setState(
                                          () => _selectedCategoryId = val,
                                        ),
                                        validator: (value) =>
                                            value == null ? 'Selecione' : null,
                                        hint: Text(
                                          'Selecione...',
                                          style: TextStyle(color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _showAddCategoryDialog,
                                  child: Container(
                                    height: 56,
                                    width: 56,
                                    decoration: BoxDecoration(
                                      color: primaryGreen,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.add_rounded,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 32),
                            _buildSectionHeader(
                              'Procedimentos inclusos',
                              goldColor,
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: primaryGreen.withOpacity(0.1),
                                ),
                              ),
                              child: Column(
                                children: _services.map((service) {
                                  final int index = _selectedServiceItems
                                      .indexWhere(
                                        (item) =>
                                            item.servicoId == service['id'],
                                      );
                                  final bool isSelected = index != -1;

                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      dividerColor: Colors.transparent,
                                    ),
                                    child: ExpansionTile(
                                      iconColor: primaryGreen,
                                      collapsedIconColor: primaryGreen,
                                      controller: _expansionControllers.putIfAbsent(
                                        service['id'],
                                        () => ExpansibleController(),
                                      ),
                                      initiallyExpanded: isSelected,
                                      leading: Checkbox(
                                        value: isSelected,
                                        activeColor: primaryGreen,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        onChanged: (val) {
                                          final controller = _expansionControllers.putIfAbsent(
                                            service['id'],
                                            () => ExpansibleController(),
                                          );
                                          setState(() {
                                            if (val == true) {
                                              _selectedServiceItems.add(
                                                PacoteServicoItem(
                                                  servicoId: service['id'],
                                                  quantidadeSessoes:
                                                      5, // Default sessions
                                                ),
                                              );
                                              // Auto-expand after build
                                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                                if (!controller.isExpanded) {
                                                  controller.expand();
                                                }
                                              });
                                            } else {
                                              _selectedServiceItems.removeAt(
                                                index,
                                              );
                                              // Collapse
                                              controller.collapse();
                                            }
                                          });
                                        },
                                      ),
                                      title: Text(
                                        service['nome'],
                                        style: TextStyle(fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? primaryGreen
                                              : Colors.black87,
                                        ),
                                      ),
                                      subtitle: () {
                                        final double? precoPromocional = service['preco_promocional'] != null 
                                            ? (service['preco_promocional'] as num).toDouble() 
                                            : null;
                                        final bool hasPromotion = precoPromocional != null && precoPromocional < (service['preco'] as num);
                                        
                                        if (hasPromotion) {
                                          return Row(
                                            children: [
                                              Text(
                                                'R\$ ${service['preco'].toStringAsFixed(2)}',
                                                style: TextStyle(fontSize: 12,
                                                  color: Colors.grey,
                                                  decoration: TextDecoration.lineThrough,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'R\$ ${precoPromocional.toStringAsFixed(2)}',
                                                style: TextStyle(fontSize: 12,
                                                  color: goldColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          );
                                        }
                                        
                                        return Text(
                                          'R\$ ${service['preco'].toStringAsFixed(2)}',
                                          style: TextStyle(fontSize: 12,
                                            color: goldColor,
                                          ),
                                        );
                                      }(),
                                      children: isSelected
                                          ? [
                                              Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                      72,
                                                      0,
                                                      16,
                                                      16,
                                                    ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Quantidade de sessões para este procedimento:',
                                                      style:
                                                          TextStyle(fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color:
                                                                Colors.black87,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    _buildSessionList(
                                                      value:
                                                          _selectedServiceItems[index]
                                                              .quantidadeSessoes,
                                                      onChanged: (newVal) {
                                                        setState(() {
                                                          _selectedServiceItems[index] =
                                                              PacoteServicoItem(
                                                                servicoId:
                                                                    service['id'],
                                                                quantidadeSessoes:
                                                                    newVal,
                                                              );
                                                        });
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ]
                                          : [],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Botões de Ação
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: _isLoading ? null : () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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
                            onPressed: _isLoading ? null : _savePacote,
                            style: AppButtonStyles.primary(),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.save, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        StringUtils.toTitleCase(widget.pacoteToEdit == null
                                            ? 'cadastrar'
                                            : 'salvar'),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSessionList({
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    const primaryGreen = Color(0xFF2D5A46);

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 19, // 2 to 20
        itemBuilder: (context, index) {
          final sessionNum = index + 2;
          final isSelected = value == sessionNum;

          return GestureDetector(
            onTap: () => onChanged(sessionNum),
            child: Container(
              width: 40,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected ? primaryGreen : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? primaryGreen : Colors.black12,
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: primaryGreen.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  sessionNum.toString(),
                  style: TextStyle(fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPromotionDatePicker(Color accentColor, Color primaryColor) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final hasRange = _dataInicioPromocao != null && _dataFimPromocao != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month, size: 16, color: accentColor),
              const SizedBox(width: 8),
              Text(
                'Programar período (opcional)',
                style: TextStyle(fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              if (hasRange)
                GestureDetector(
                  onTap: () => setState(() {
                    _dataInicioPromocao = null;
                    _dataFimPromocao = null;
                  }),
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
                initialDateRange: hasRange
                    ? DateTimeRange(
                        start: _dataInicioPromocao!,
                        end: _dataFimPromocao!,
                      )
                    : null,
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: primaryColor,
                        onPrimary: Colors.white,
                        onSurface: primaryColor,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (range != null) {
                setState(() {
                  _dataInicioPromocao = range.start;
                  _dataFimPromocao = range.end;
                });
              }
            },
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasRange
                        ? '${dateFormat.format(_dataInicioPromocao!)} - ${dateFormat.format(_dataFimPromocao!)}'
                        : 'Selecionar intervalo de datas...',
                    style: TextStyle(fontSize: 13,
                      color: hasRange ? primaryColor : Colors.black38,
                      fontWeight:
                          hasRange ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: accentColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color goldColor) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: goldColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(fontSize: 12,
            fontWeight: FontWeight.w900,
            color: goldColor,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    IconData? icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFC7A36B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: formatters,
          validator: validator,
          onChanged: onChanged,
          style: TextStyle(fontSize: 14,
            color: const Color(0xFF2D5A46),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 14,
              color: Colors.black26,
            ),
            prefixIcon: icon != null
                ? Icon(icon, size: 20, color: const Color(0xFF2D5A46))
                : null,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.black.withOpacity(0.05),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.black.withOpacity(0.05),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF2D5A46),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}

