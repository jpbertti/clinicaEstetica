import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../../../auth/data/auth_service.dart';
import 'package:app_clinica_estetica/core/theme/app_button_styles.dart';

class AdminAddClientePage extends StatefulWidget {
  const AdminAddClientePage({super.key});

  @override
  State<AdminAddClientePage> createState() => _AdminAddClientePageState();
}

class _AdminAddClientePageState extends State<AdminAddClientePage> {
  final _phoneFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _obsController = TextEditingController();
  
  // Default password as requested
  final String _defaultPassword = '123456';

  Uint8List? _imageBytes;
  XFile? _imageFile;
  final _picker = ImagePicker();
  bool _isSaving = false;

  // Validation Notifiers
  final _nomeValid = ValueNotifier<bool>(true);
  final _emailValid = ValueNotifier<bool>(true);
  final _telefoneValid = ValueNotifier<bool>(true);

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _telefoneController.dispose();
    _obsController.dispose();
    _nomeValid.dispose();
    _emailValid.dispose();
    _telefoneValid.dispose();
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
    _telefoneValid.value = _telefoneController.text.isNotEmpty;

    if (!_nomeValid.value || !_emailValid.value || !_telefoneValid.value) {
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

      // Using the existing admin registration helper which calls the RPC
      await AuthService().registerProfessionalAsAdmin(
        nome: _nomeController.text,
        email: _emailController.text,
        password: _defaultPassword,
        cargo: 'Cliente', // Default cargo for clients
        telefone: _telefoneController.text,
        tipo: 'cliente',
        avatarUrl: imageUrl,
        observacoes: _obsController.text,
        ativo: true,
        comissaoAgendamentosPercentual: 0,
        comissaoProdutosPercentual: 0,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cliente cadastrado com sucesso!'),
            backgroundColor: Color(0xFF2D5A46),
          ),
        );
        context.pop(true); // Return true to trigger refresh
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
    const primaryColor = Color(0xFF2D5A46);
    const accentColor = Color(0xFFC7A36B);
    const backgroundColor = Color(0xFFF6F4EF);

    return Scaffold(
      backgroundColor: backgroundColor,
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
                      child: const Icon(Icons.arrow_back, color: primaryColor, size: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Novo cliente',
                          style: TextStyle(fontFamily: 'Playfair Display', 
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        Text(
                          'Cadastre um novo cliente no sistema',
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
                              color: primaryColor.withOpacity(0.1),
                              border: Border.all(color: accentColor, width: 2),
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
                                    color: primaryColor,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: accentColor,
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
                        style: TextStyle(fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
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
                          icon: Icons.person,
                          hint: 'Nome do cliente',
                          primaryColor: primaryColor,
                          accentColor: accentColor,
                          isValid: _nomeValid,
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          label: 'E-mail',
                          controller: _emailController,
                          icon: Icons.mail,
                          hint: 'email@exemplo.com',
                          keyboardType: TextInputType.emailAddress,
                          primaryColor: primaryColor,
                          accentColor: accentColor,
                          isValid: _emailValid,
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          label: 'Telefone',
                          controller: _telefoneController,
                          icon: Icons.phone,
                          hint: '(DDD) 99999-9999',
                          keyboardType: TextInputType.phone,
                          primaryColor: primaryColor,
                          accentColor: accentColor,
                          isValid: _telefoneValid,
                          inputFormatters: [_phoneFormatter],
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          label: 'Senha padrão',
                          controller: TextEditingController(text: _defaultPassword),
                          icon: Icons.lock_outline,
                          enabled: false,
                          primaryColor: primaryColor,
                          accentColor: accentColor,
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          label: 'Observações (opcional)',
                          controller: _obsController,
                          icon: Icons.notes,
                          hint: 'Notas sobre o cliente...',
                          maxLines: 3,
                          primaryColor: primaryColor,
                          accentColor: accentColor,
                          required: false,
                        ),
                        const SizedBox(height: 32),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => context.pop(),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text(
                                  'Cancelar',
                                  style: AppButtonStyles.primaryTextStyle(color: accentColor),
                                ),
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
                                      _isSaving ? 'Salvando...' : 'Cadastrar cliente',
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
    ValueNotifier<bool>? isValid,
    String? hint,
    bool enabled = true,
    int maxLines = 1,
    TextInputType? keyboardType,
    required Color primaryColor,
    required Color accentColor,
    bool required = true,
    List<TextInputFormatter>? inputFormatters,
  }) {
    if (isValid == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              label,
              style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
          ),
          TextFormField(
            controller: controller,
            enabled: enabled,
            maxLines: maxLines,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            style: TextStyle(fontSize: 14, 
              color: enabled ? primaryColor : primaryColor.withOpacity(0.5)
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.black26, fontSize: 14),
              prefixIcon: Icon(icon, color: primaryColor, size: 20),
              filled: true,
              fillColor: enabled ? Colors.black.withOpacity(0.03) : Colors.black.withOpacity(0.01),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accentColor, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ],
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: isValid,
      builder: (context, valid, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                label,
                style: TextStyle(fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ),
            TextFormField(
              controller: controller,
              maxLines: maxLines,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              style: TextStyle(fontSize: 14, color: primaryColor),
              onChanged: (v) {
                if (!valid && v.isNotEmpty) isValid.value = true;
              },
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.black26, fontSize: 14),
                prefixIcon: Icon(icon, color: primaryColor, size: 20),
                filled: true,
                fillColor: Colors.black.withOpacity(0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: !valid
                      ? const BorderSide(color: Colors.red, width: 1.5)
                      : BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: !valid
                      ? const BorderSide(color: Colors.red, width: 1.5)
                      : BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: !valid ? Colors.red : accentColor,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            if (!valid)
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
}

