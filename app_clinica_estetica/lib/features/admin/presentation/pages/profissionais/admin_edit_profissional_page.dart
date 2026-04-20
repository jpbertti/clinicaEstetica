import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_professional_repository.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:app_clinica_estetica/core/theme/app_button_styles.dart';


class AdminEditProfissionalPage extends StatefulWidget {
  final Map<String, dynamic> professional;
  const AdminEditProfissionalPage({super.key, required this.professional});

  @override
  State<AdminEditProfissionalPage> createState() => _AdminEditProfissionalPageState();
}

class _AdminEditProfissionalPageState extends State<AdminEditProfissionalPage> {
  final _phoneFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );
  final _formKey = GlobalKey<FormState>();
  final _profRepo = SupabaseProfessionalRepository();
  
  late bool _isActive;
  late String _selectedPermission;

  late final TextEditingController _nomeController;
  late final TextEditingController _emailController;
  late final TextEditingController _cargoController;
  late final TextEditingController _telefoneController;
  late final TextEditingController _comissaoAgendamentosController;
  late final TextEditingController _comissaoProdutosController;
  late final TextEditingController _obsController;

  Uint8List? _imageBytes;
  XFile? _imageFile;
  final _picker = ImagePicker();
  bool _isSaving = false;
  String? _currentAvatarUrl;

  @override
  void initState() {
    super.initState();
    final prof = widget.professional;
    _nomeController = TextEditingController(text: prof['nome_completo']);
    _emailController = TextEditingController(text: prof['email']);
    _cargoController = TextEditingController(text: prof['cargo']);
    _telefoneController = TextEditingController(text: prof['telefone'] ?? '');
    _comissaoAgendamentosController = TextEditingController(
        text: (prof['comissao_agendamentos_percentual'] ?? 0).toString());
    _comissaoProdutosController = TextEditingController(
        text: (prof['comissao_produtos_percentual'] ?? 0).toString());
    _obsController = TextEditingController(text: prof['observacoes_internas'] ?? '');
    _isActive = prof['ativo'] ?? true;
    _selectedPermission = prof['tipo']?.toString() ?? 'profissional';
    // Garantir que o valor inicial seja válido para o Dropdown
    if (_selectedPermission != 'admin' && _selectedPermission != 'profissional') {
      _selectedPermission = 'profissional';
    }
    _currentAvatarUrl = prof['avatar_url'];
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _cargoController.dispose();
    _telefoneController.dispose();
    _comissaoAgendamentosController.dispose();
    _comissaoProdutosController.dispose();
    _obsController.dispose();
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
    if (_imageBytes == null) {
      debugPrint('Nenhuma imagem nova selecionada, retornando a atual: $_currentAvatarUrl');
      return _currentAvatarUrl;
    }
    try {
      final extension = _imageFile?.name.split('.').last ?? 'jpg';
      final fileName = 'avatar_${email}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      debugPrint('Fazendo upload de nova imagem: $fileName');
      
      await Supabase.instance.client.storage
          .from('perfis')
          .uploadBinary(fileName, _imageBytes!);
      
      final url = Supabase.instance.client.storage.from('perfis').getPublicUrl(fileName);
      debugPrint('Upload concluído, nova URL: $url');
      return url;
    } catch (e) {
      debugPrint('Erro no upload: $e');
      return _currentAvatarUrl;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      debugPrint('Iniciando salvamento do profissional...');
      final imageUrl = await _uploadImage(_emailController.text);
      debugPrint('URL da imagem a ser salva: $imageUrl');

      // Proteção: Se o admin estiver editando a si mesmo, não permitir tirar permissão admin
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null && currentUser.id == widget.professional['id']) {
        if (_selectedPermission != 'admin') {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Você não pode remover sua própria permissão de Administrador!'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }

      await _profRepo.updateProfessional(
        id: widget.professional['id'],
        nome: _nomeController.text,
        cargo: _cargoController.text,
        telefone: _telefoneController.text,
        tipo: _selectedPermission,
        avatarUrl: imageUrl,
        observacoesInternas: _obsController.text,
        ativo: _isActive,
        comissaoAgendamentosPercentual:
            double.tryParse(_comissaoAgendamentosController.text) ?? 0,
        comissaoProdutosPercentual:
            double.tryParse(_comissaoProdutosController.text) ?? 0,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profissional atualizado com sucesso!'),
            backgroundColor: Color(0xFF2D5A46),
          ),
        );
        if (mounted) context.pop(true);
      }
    } catch (e) {
      debugPrint('Erro ao salvar profissional: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ERRO: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Icon(Icons.arrow_back, color: primaryColor, size: 24),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Editar profissional',
                            style: TextStyle(
                              fontFamily: 'Playfair Display',
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          Text(
                            'Atualize os dados do profissional',
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
                                color: primaryColor.withOpacity(0.1),
                                border: Border.all(color: accentColor, width: 2),
                                image: (_imageBytes != null || (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty))
                                    ? DecorationImage(
                                        image: _imageBytes != null 
                                            ? MemoryImage(_imageBytes!) as ImageProvider
                                            : NetworkImage(_currentAvatarUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: (_imageBytes == null && (_currentAvatarUrl == null || _currentAvatarUrl!.isEmpty))
                                  ? Icon(
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
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Alterar foto',
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
                    child: Column(
                      children: [
                        _buildInputField(
                          label: 'Nome completo',
                          controller: _nomeController,
                          icon: Icons.badge,
                          primaryColor: primaryColor,
                          accentColor: accentColor,
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          label: 'E-mail corporativo',
                          controller: _emailController,
                          icon: Icons.mail,
                          enabled: false,
                          primaryColor: primaryColor,
                          accentColor: accentColor,
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          label: 'Cargo',
                          controller: _cargoController,
                          icon: Icons.work,
                          primaryColor: primaryColor,
                          accentColor: accentColor,
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
                          primaryColor: primaryColor,
                          accentColor: accentColor,
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          label: 'Comissão agendamentos (%)',
                          controller: _comissaoAgendamentosController,
                          icon: Icons.calendar_today,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          primaryColor: primaryColor,
                          accentColor: accentColor,
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          label: 'Comissão produtos (%)',
                          controller: _comissaoProdutosController,
                          icon: Icons.shopping_bag,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          primaryColor: primaryColor,
                          accentColor: accentColor,
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          label: 'Observações internas (opcional)',
                          controller: _obsController,
                          icon: Icons.notes,
                          maxLines: 3,
                          primaryColor: primaryColor,
                          accentColor: accentColor,
                        ),
                        const SizedBox(height: 20),
                        // Status Toggle
                        _buildToggleField(
                          label: 'Status do profissional',
                          value: _isActive,
                          onChanged: (val) => setState(() => _isActive = val),
                          primaryColor: primaryColor,
                          accentColor: accentColor,
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(
                                child: TextButton(
                                  onPressed: () => context.pop(),
                                  style: AppButtonStyles.cancelButtonStyle(),
                                  child: Text('Cancelar', style: AppButtonStyles.cancelTextStyle()),
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
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Salvar alterações'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Vincular Serviços Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primaryColor.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.link, color: primaryColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Vincular serviços',
                            style: TextStyle(fontSize: 18,
                              fontFamily: 'Playfair Display',
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Gerencie quais serviços este profissional está habilitado a realizar.',
                        style: TextStyle(fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => context.push('/admin/profissionais/vincular-servicos', extra: widget.professional),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Vincular serviços'),
                        style: AppButtonStyles.small(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Multi-select Packages Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accentColor.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.inventory_2,
                              color: accentColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Pacotes vinculados',
                            style: TextStyle(fontSize: 18,
                              fontFamily: 'Playfair Display',
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Vincule quais pacotes de serviços este profissional está autorizado a realizar.',
                        style: TextStyle(fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => context.push('/admin/profissionais/vincular-pacotes', extra: widget.professional),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Vincular pacotes'),
                        style: AppButtonStyles.small(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Info Cards
                Row(
                  children: [
                    _buildInfoCard(
                      icon: Icons.security,
                      title: 'Segurança',
                      desc: 'A senha deve conter no mínimo 8 caracteres.',
                      color: primaryColor,
                    ),
                    const SizedBox(width: 12),
                    _buildInfoCard(
                      icon: Icons.history_edu,
                      title: 'Logs',
                      desc: 'Toda alteração será registrada no histórico.',
                      color: primaryColor,
                    ),
                    const SizedBox(width: 12),
                    _buildInfoCard(
                      icon: Icons.verified_user,
                      title: 'Privacidade',
                      desc: 'Sujeito aos termos de confidencialidade.',
                      color: primaryColor,
                    ),
                  ],
                ),
              ],
            ),
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
    bool enabled = true,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
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
          style: TextStyle(fontSize: 14, color: enabled ? primaryColor : Colors.grey),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontFamily: 'Inter',
              color: Colors.black26, 
              fontSize: 14,
            ),
            prefixIcon: Icon(icon, color: enabled ? primaryColor : Colors.grey, size: 20),
            filled: true,
            fillColor: Colors.black.withOpacity(0.03),
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
          validator: (value) {
            if (label.contains('Opcional')) return null;
            if (value == null || value.isEmpty) return 'Campo obrigatório';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required IconData icon,
    required List<Map<String, String>> items,
    required void Function(String?) onChanged,
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
            style: TextStyle(fontSize: 13,
              fontWeight: FontWeight.bold,
              color: accentColor,
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
              Icon(icon, color: primaryColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isExpanded: true,
                    style: TextStyle(fontSize: 14, color: primaryColor),
                    icon: Icon(Icons.arrow_drop_down, color: primaryColor),
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

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: TextStyle(fontSize: 9,
                color: Colors.black45,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleField({
    required String label,
    required bool value,
    required Function(bool) onChanged,
    required Color primaryColor,
    required Color accentColor,
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
                    style: TextStyle(fontSize: 8,
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

}
