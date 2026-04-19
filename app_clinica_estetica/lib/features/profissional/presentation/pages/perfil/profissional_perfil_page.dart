import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:app_clinica_estetica/features/auth/data/auth_service.dart';

class ProfissionalPerfilPage extends StatefulWidget {
  const ProfissionalPerfilPage({super.key});

  @override
  State<ProfissionalPerfilPage> createState() => _ProfissionalPerfilPageState();
}

class _ProfissionalPerfilPageState extends State<ProfissionalPerfilPage> {
  final _authService = AuthService();
  bool _isUpdating = false;
  final _picker = ImagePicker();

  Future<void> _selecionarImagem(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() => _isUpdating = true);

        final bytes = await pickedFile.readAsBytes();
        final ext = path.extension(pickedFile.path).replaceAll('.', '');
        
        await _authService.uploadAvatar(bytes, ext.isEmpty ? 'png' : ext);

        if (mounted) {
          setState(() => _isUpdating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto de perfil atualizada!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar imagem: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mostrarOpcoesFonteImagem() {
    const primaryColor = Color(0xFF2F5E46);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: primaryColor),
              title: const Text('Escolher da Galeria'),
              onTap: () {
                Navigator.pop(context);
                _selecionarImagem(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: primaryColor),
              title: const Text('Tirar Foto'),
              onTap: () {
                Navigator.pop(context);
                _selecionarImagem(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoEdicao(String title, String currentValue, {bool isEmail = false, bool isNome = false, bool isCargo = false}) {
    final controller = TextEditingController(text: currentValue);
    const goldColor = Color(0xFFC7A36B);
    const primaryColor = Color(0xFF2F5E46);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Editar $title',
          style: TextStyle(fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: isEmail
              ? TextInputType.emailAddress
              : (isNome || isCargo ? TextInputType.text : TextInputType.phone),
          decoration: InputDecoration(
            hintText: 'Digite o novo $title',
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: goldColor),
            ),
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: goldColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final value = controller.text.trim();

                    if (AuthService.currentUserId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sessão expirada. Por favor, entre novamente.')),
                      );
                      return;
                    }

                    if (isEmail) {
                      if (!value.contains('@') || !value.contains('.')) {
                         ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('E-mail inválido.')),
                        );
                        return;
                      }
                    } else if (!isNome && !isCargo) {
                      final digits = value.replaceAll(RegExp(r'\D'), '');
                      if (digits.length != 11) {
                         ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Telefone inválido.')),
                        );
                        return;
                      }
                    }

                    Navigator.pop(context);
                    setState(() => _isUpdating = true);

                    try {
                      await _authService.updateProfile(
                        nome: isNome ? value : null,
                        cargo: isCargo ? value : null,
                        email: isEmail ? value : null,
                        telefone: (!isEmail && !isNome && !isCargo) ? value : null,
                      );

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Perfil atualizado!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        setState(() {});
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString()),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isUpdating = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    'Salvar',
                    style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2F5E46);
    const goldColor = Color(0xFFC7A36B);
    const backgroundColor = Color(0xFFF6F4EF);
    const softGreen = Color(0xFF6E8F7B);
    const premiumGray = Color(0xFF2B2B2B);

    final String userName = AuthService.currentUserNome ?? 'Profissional';
    final String userCargo = AuthService.currentUserCargo ?? 'Cargo não informado';

    return Stack(
      children: [
        Scaffold(
          backgroundColor: backgroundColor,
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  _construirSecaoFotoPerfil(userName, userCargo, softGreen, goldColor, premiumGray),
                  const SizedBox(height: 32),
                  _construirSecaoInformacoesPessoais(primaryColor, goldColor, premiumGray, softGreen),
                  const SizedBox(height: 16),
                  _construirSecaoConfiguracoes(context, primaryColor, goldColor, softGreen),
                  const SizedBox(height: 32),
                  _construirBotaoSair(context, primaryColor, goldColor, softGreen),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ),
        if (_isUpdating)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(color: goldColor),
            ),
          ),
      ],
    );
  }

  Widget _buildVerticalDivider(Color color) {
    return Container(width: 1, height: 10, color: color.withOpacity(0.2), margin: const EdgeInsets.symmetric(vertical: 2));
  }

  Widget _construirSecaoFotoPerfil(String userName, String userCargo, Color softGreen, Color goldColor, Color premiumGray) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
                image: AuthService.currentUserAvatarUrl != null
                    ? DecorationImage(
                        image: NetworkImage(AuthService.currentUserAvatarUrl!),
                        fit: BoxFit.cover,
                      )
                    : DecorationImage(
                        image: NetworkImage(
                          AuthService.defaultAvatarUrl.replaceAll('User', Uri.encodeComponent(userName)),
                        ),
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _mostrarOpcoesFonteImagem,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: goldColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          userName,
          style: TextStyle(fontFamily: 'Playfair Display', 
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: premiumGray,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          userCargo.toUpperCase(),
          style: TextStyle(fontSize: 12,
            fontWeight: FontWeight.bold,
            color: goldColor,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _construirSecaoInformacoesPessoais(
    Color primaryColor,
    Color goldColor,
    Color premiumGray,
    Color softGreen,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: goldColor.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.badge_outlined,
                    color: primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Dados Pessoais',
                  style: TextStyle(fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _construirItemInfo(
              'NOME COMPLETO',
              AuthService.currentUserNome ?? 'Não informado',
              premiumGray,
              softGreen,
              onEdit: () => _mostrarDialogoEdicao(
                'Nome',
                AuthService.currentUserNome ?? '',
                isNome: true,
              ),
              goldColor: goldColor,
            ),
             _construirItemInfo(
              'CARGO',
              AuthService.currentUserCargo ?? 'Não informado',
              premiumGray,
              softGreen,
              onEdit: () => _mostrarDialogoEdicao(
                'Cargo',
                AuthService.currentUserCargo ?? '',
                isCargo: true,
              ),
              goldColor: goldColor,
            ),
            _construirItemInfo(
              'E-MAIL',
              AuthService.currentUserEmail ?? 'Não informado',
              premiumGray,
              softGreen,
              onEdit: () => _mostrarDialogoEdicao(
                'E-mail',
                AuthService.currentUserEmail ?? '',
                isEmail: true,
              ),
              goldColor: goldColor,
            ),
            _construirItemInfo(
              'TELEFONE',
              AuthService.currentUserTelefone ?? 'Não informado',
              premiumGray,
              softGreen,
              isLast: true,
              onEdit: () => _mostrarDialogoEdicao(
                'Telefone',
                AuthService.currentUserTelefone ?? '',
              ),
              goldColor: goldColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirSecaoConfiguracoes(
    BuildContext context,
    Color primaryColor,
    Color goldColor,
    Color softGreen,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => context.push('/profissional/gerenciar-agenda?tab=0'),
            child: _construirItemAcao(
              icon: Icons.access_time,
              title: 'Horário de Trabalho',
              subtitle: 'Defina seus horários de trabalho',
              pColor: primaryColor,
              gColor: goldColor,
              softGreen: softGreen,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => context.push('/profissional/gerenciar-agenda?tab=1'),
            child: _construirItemAcao(
              icon: Icons.restaurant,
              title: 'Horário de Almoço',
              subtitle: 'Defina seu intervalo diário',
              pColor: primaryColor,
              gColor: goldColor,
              softGreen: softGreen,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => context.push('/profissional/gerenciar-agenda?tab=2'),
            child: _construirItemAcao(
              icon: Icons.block,
              title: 'Bloqueio de Agenda',
              subtitle: 'Bloquear horários específicos',
              pColor: primaryColor,
              gColor: goldColor,
              softGreen: softGreen,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => context.push('/alterar-senha'),
            child: _construirItemAcao(
              icon: Icons.lock_outline,
              title: 'Alterar Senha',
              subtitle: 'Mantenha sua conta segura',
              pColor: primaryColor,
              gColor: goldColor,
              softGreen: softGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirBotaoSair(
    BuildContext context,
    Color primaryColor,
    Color goldColor,
    Color softGreen,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: GestureDetector(
        onTap: () => context.push('/profissional/confirmacao-logout'),
        child: _construirItemAcao(
          icon: Icons.logout_rounded,
          title: 'Sair da conta',
          subtitle: 'Encerrar sessão no aplicativo',
          pColor: primaryColor,
          gColor: goldColor,
          softGreen: softGreen,
        ),
      ),
    );
  }

  Widget _construirItemInfo(
    String label,
    String value,
    Color premiumGray,
    Color softGreen, {
    bool isLast = false,
    VoidCallback? onEdit,
    Color? goldColor,
  }) {
    // Cálculo para alinhar ao FINAL do ícone (Container padding 8 + Icon size 20 = 36 + gap 12 = 48)
    return Padding(
      padding: EdgeInsets.only(left: 48, bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: softGreen,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(fontSize: 14, color: premiumGray),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            GestureDetector(
              onTap: onEdit,
              child: Text(
                'Editar',
                style: TextStyle(fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: goldColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _construirItemAcao({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color pColor,
    required Color gColor,
    required Color softGreen,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: pColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: pColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: pColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: softGreen),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: gColor),
        ],
      ),
    );
  }
}

