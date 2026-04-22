import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:app_clinica_estetica/core/theme/app_button_styles.dart';
import 'package:app_clinica_estetica/core/utils/string_utils.dart';
import '../../../../auth/data/auth_service.dart';

class AdminAddProfissionalPage extends StatefulWidget {
  const AdminAddProfissionalPage({super.key});

  @override
  State<AdminAddProfissionalPage> createState() => _AdminAddProfissionalPageState();
}

class _AdminAddProfissionalPageState extends State<AdminAddProfissionalPage> {
  final _phoneFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );
  
  final _formKey = GlobalKey<FormState>();
  bool _isActive = true;
  bool _obscurePassword = true;
  String _selectedPermission = 'profissional';

  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _cargoController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _comissaoAgendamentosController = TextEditingController(text: '0');
  final _comissaoProdutosController = TextEditingController(text: '0');
  final _obsController = TextEditingController();

  Uint8List? _imageBytes;
  XFile? _imageFile;
  final _picker = ImagePicker();
  bool _isSaving = false;

  // Validation Notifiers
  final _nomeValid = ValueNotifier<bool>(true);
  final _emailValid = ValueNotifier<bool>(true);
  final _senhaValid = ValueNotifier<bool>(true);
  final _cargoValid = ValueNotifier<bool>(true);
  final _telefoneValid = ValueNotifier<bool>(true);
  final _comissaoAgendamentosValid = ValueNotifier<bool>(true);
  final _comissaoProdutosValid = ValueNotifier<bool>(true);

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _cargoController.dispose();
    _telefoneController.dispose();
    _comissaoAgendamentosController.dispose();
    _comissaoProdutosController.dispose();
    _obsController.dispose();
    _nomeValid.dispose();
    _emailValid.dispose();
    _senhaValid.dispose();
    _cargoValid.dispose();
    _telefoneValid.dispose();
    _comissaoAgendamentosValid.dispose();
    _comissaoProdutosValid.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _imageFile = image;
        _imageBytes = bytes;
      });
    }
  }

  Future<String?> _uploadImage(String email) async {
    if (_imageBytes == null) return null;
    try {
      final extension = _imageFile?.name.split('.').last ?? 'jpg';
      final fileName = 'avatar_${email}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      await Supabase.instance.client.storage
          .from('perfis')
          .uploadBinary(fileName, _imageBytes!);
      
      final url = Supabase.instance.client.storage.from('perfis').getPublicUrl(fileName);
      return url;
    } catch (e) {
      debugPrint('Erro no upload: $e');
      return null;
    }
  }

  Future<void> _save() async {
    // Reset validations
    _nomeValid.value = _nomeController.text.isNotEmpty;
    _emailValid.value = _emailController.text.isNotEmpty;
    _senhaValid.value = _senhaController.text.isNotEmpty;
    _cargoValid.value = _cargoController.text.isNotEmpty;
    _telefoneValid.value = _telefoneController.text.isNotEmpty;
    _comissaoAgendamentosValid.value = _comissaoAgendamentosController.text.isNotEmpty;
    _comissaoProdutosValid.value = _comissaoProdutosController.text.isNotEmpty;

    if (!_nomeValid.value ||
        !_emailValid.value ||
        !_senhaValid.value ||
        !_cargoValid.value ||
        !_telefoneValid.value ||
        !_comissaoAgendamentosValid.value ||
        !_comissaoProdutosValid.value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, preencha todos os campos obrigatórios'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final imageUrl = await _uploadImage(_emailController.text);

      await AuthService().registerProfessionalAsAdmin(
        nome: _nomeController.text,
        email: _emailController.text,
        password: _senhaController.text,
        cargo: _cargoController.text,
        telefone: _telefoneController.text,
        tipo: _selectedPermission,
        avatarUrl: imageUrl,
        observacoes: _obsController.text,
        ativo: _isActive,
        comissaoAgendamentosPercentual:
            double.tryParse(_comissaoAgendamentosController.text) ?? 0,
        comissaoProdutosPercentual:
            double.tryParse(_comissaoProdutosController.text) ?? 0,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profissional cadastrado com sucesso! Agenda padrão: Seg-Sex 08-20h, Sáb 08-13h.'),
            backgroundColor: AppColors.primary,
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: const Icon(Icons.arrow_back, color: AppColors.primary, size: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Adicionar profissional',
                          style: TextStyle(
                            fontFamily: 'Playfair Display', 
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          'Cadastre novos profissionais para a clínica',
                          style: TextStyle(
                            fontFamily: 'Inter',
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
              
              // Profile Photo Section
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
                              color: AppColors.primary.withOpacity(0.1),
                              border: Border.all(color: AppColors.accent, width: 2),
                              image: _imageBytes != null
                                  ? DecorationImage(
                                      image: MemoryImage(_imageBytes!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _imageBytes == null
                                ? const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: AppColors.primary,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add_a_photo,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _imageBytes == null ? '+ Adicionar foto' : 'Alterar foto',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Form Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black.withOpacity(0.05)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildInputField(
                          label: 'Nome completo',
                          controller: _nomeController,
                          icon: Icons.badge,
                          hint: 'Nome do profissional',
                          isValid: _nomeValid,
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          label: 'E-mail corporativo',
                          controller: _emailController,
                          icon: Icons.mail,
                          hint: 'email@clinica.com',
                          keyboardType: TextInputType.emailAddress,
                          isValid: _emailValid,
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          label: 'Senha de acesso',
                          controller: _senhaController,
                          icon: Icons.lock,
                          hint: 'Mínimo 6 caracteres',
                          obscureText: _obscurePassword,
                          isPassword: true,
                          onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                          isValid: _senhaValid,
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          label: 'Cargo',
                          controller: _cargoController,
                          icon: Icons.work,
                          hint: 'Ex: Esteticista, Biomédica...',
                          isValid: _cargoValid,
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          label: 'Telefone',
                          controller: _telefoneController,
                          icon: Icons.phone,
                          hint: '(DDD) 99999-9999',
                          keyboardType: TextInputType.phone,
                          isValid: _telefoneValid,
                          inputFormatters: [_phoneFormatter],
                        ),
                        const SizedBox(height: 20),
                        _buildDropdownField(
                          label: 'Nível de permissão',
                          value: _selectedPermission,
                          icon: Icons.admin_panel_settings,
                          items: const [
                            {'value': 'admin', 'label': 'Administrador'},
                            {'value': 'profissional', 'label': 'Profissional'},
                          ],
                          onChanged: (val) => setState(() => _selectedPermission = val!),
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          label: 'Comissão agenda (%)',
                          controller: _comissaoAgendamentosController,
                          icon: Icons.calendar_today,
                          keyboardType: TextInputType.number,
                          isValid: _comissaoAgendamentosValid,
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          label: 'Comissão produtos (%)',
                          controller: _comissaoProdutosController,
                          icon: Icons.shopping_bag,
                          keyboardType: TextInputType.number,
                          isValid: _comissaoProdutosValid,
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          label: 'Observações internas (opcional)',
                          controller: _obsController,
                          icon: Icons.notes,
                          hint: 'Notas, restrições ou detalhes...',
                          maxLines: 3,
                          required: false,
                        ),
                        const SizedBox(height: 20),
                        // Status Toggle
                        _buildToggleField(
                          label: 'Status do profissional',
                          value: _isActive,
                          onChanged: (val) => setState(() => _isActive = val),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => context.pop(),
                                style: AppButtonStyles.cancelButtonStyle(),
                                child: Text(StringUtils.toTitleCase('cancelar'), style: AppButtonStyles.cancelTextStyle()),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _save,
                                style: AppButtonStyles.primary(),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_isSaving)
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    else
                                      const Icon(Icons.person_add, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isSaving ? StringUtils.toTitleCase('cadastrando...') : StringUtils.toTitleCase('cadastrar profissional'),
                                    ),
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
              ),
              const SizedBox(height: 32),
              // Help Cards
              Row(
                children: [
                  _buildInfoCard(
                    icon: Icons.security,
                    title: 'Acesso',
                    desc: 'O profissional receberá as credenciais por e-mail.',
                  ),
                  const SizedBox(width: 12),
                  _buildInfoCard(
                    icon: Icons.event_available,
                    title: 'Agenda',
                    desc: 'A agenda padrão será criada automaticamente.',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    bool obscureText = false,
    bool isPassword = false,
    VoidCallback? onTogglePassword,
    int maxLines = 1,
    TextInputType? keyboardType,
    ValueNotifier<bool>? isValid,
    bool required = true,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final ValueNotifier<bool> validNotifier = isValid ?? ValueNotifier<bool>(true);

    return ValueListenableBuilder<bool>(
      valueListenable: validNotifier,
      builder: (context, valid, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ),
            TextFormField(
              controller: controller,
              obscureText: obscureText,
              maxLines: maxLines,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14, 
                color: AppColors.primary,
              ),
              onChanged: (v) {
                if (!valid && v.isNotEmpty) validNotifier.value = true;
              },
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.black26, 
                  fontSize: 14,
                ),
                prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
                suffixIcon: isPassword
                    ? IconButton(
                        icon: Icon(
                          obscureText ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        onPressed: onTogglePassword,
                      )
                    : null,
                filled: true,
                fillColor: Colors.black.withOpacity(0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: !valid && required
                      ? const BorderSide(color: Colors.red, width: 1.5)
                      : BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: !valid && required
                      ? const BorderSide(color: Colors.red, width: 1.5)
                      : BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: !valid && required ? Colors.red : AppColors.accent,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            if (!valid && required)
              const Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  'Este campo é obrigatório',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.red, 
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required IconData icon,
    required List<Map<String, String>> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isExpanded: true,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14, 
                      color: AppColors.primary,
                    ),
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                    onChanged: onChanged,
                    items: items.map((item) {
                      return DropdownMenuItem<String>(
                        value: item['value'],
                        child: Text(item['label']!),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToggleField({
    required String label,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status disponibilidade',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value ? 'Profissional ativo' : 'Profissional inativo',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Transform.scale(
                    scale: 0.8,
                    alignment: Alignment.centerRight,
                    child: Switch(
                      value: value,
                      onChanged: onChanged,
                      activeThumbColor: Colors.white,
                      activeTrackColor: AppColors.success,
                      inactiveThumbColor: Colors.grey[400],
                      inactiveTrackColor: Colors.grey[200],
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  Text(
                    value ? 'Ativo' : 'Inativo',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: value ? AppColors.success : Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 9,
                color: Colors.black45,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
