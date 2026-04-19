import 'package:app_clinica_estetica/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:app_clinica_estetica/core/widgets/app_bottom_nav_bar.dart';
import 'package:app_clinica_estetica/features/auth/data/auth_service.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  final _authService = AuthService();
  bool _isUpdating = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
  }

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
          setState(() {
            _isUpdating = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto de perfil atualizada!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isUpdating = false);
      if (mounted) {
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
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Escolher da Galeria'),
              onTap: () {
                Navigator.pop(context);
                _selecionarImagem(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
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

  // _vincularGoogle removido.

  void _mostrarDialogoEdicao(String title, String currentValue, bool isEmail, {bool isNome = false}) {

    final phoneFormatter = MaskTextInputFormatter(
      mask: '(##) #####-####',
      filter: {"#": RegExp(r'[0-9]')},
      type: MaskAutoCompletionType.lazy,
    );

    final controller = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Editar $title',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: isEmail
              ? TextInputType.emailAddress
              : (isNome ? TextInputType.name : TextInputType.phone),
          inputFormatters: (!isEmail && !isNome) ? [phoneFormatter] : null,
          decoration: InputDecoration(
            hintText: 'Digite o novo $title',
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.accent),
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
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.accent,
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
                        const SnackBar(
                          content: Text(
                            'Sessão expirada. Por favor, saia e entre novamente no aplicativo.',
                          ),
                        ),
                      );
                      return;
                    }

                    if (isEmail) {
                      if (!value.contains('@') || !value.contains('.')) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('E-mail inválido.')),
                          );
                        }
                        return;
                      }
                    } else if (!isNome) {
                      final digits = value.replaceAll(RegExp(r'\D'), '');
                      if (digits.length != 11) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Telefone inválido.')),
                          );
                        }
                        return;
                      }
                    }

                    Navigator.pop(context);
                    setState(() => _isUpdating = true);

                    try {
                      await _authService.updateProfile(
                        nome: isNome ? value : null,
                        email: isEmail ? value : null,
                        telefone: (!isEmail && !isNome) ? phoneFormatter.getUnmaskedText() : null,
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
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    'Salvar',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Colors.white,
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

    final userName = AuthService.currentUserNome ?? 'Usuário';

    String formatDate(String? dateStr) {
      if (dateStr == null) return 'Cliente desde 14 de Março de 2024';
      try {
        final date = DateTime.parse(dateStr);
        final months = [
          'Janeiro',
          'Fevereiro',
          'Março',
          'Abril',
          'Maio',
          'Junho',
          'Julho',
          'Agosto',
          'Setembro',
          'Outubro',
          'Novembro',
          'Dezembro',
        ];
        final day = date.day.toString().padLeft(2, '0');
        return 'Cliente desde $day de ${months[date.month - 1]} de ${date.year}';
      } catch (e) {
        return 'Cliente desde 14 de Março de 2024';
      }
    }

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _construirCabecalhoPerfil(),
                  _construirSecaoFotoPerfil(
                    userName,
                    formatDate,
                  ),
                  const SizedBox(height: 32),
                  _construirSecaoInformacoesPessoais(),
                  const SizedBox(height: 16),
                  _construirSecaoConfiguracoes(context),
                  const SizedBox(height: 32),
                  _construirBotaoSair(context),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
          bottomNavigationBar: const AppBottomNavigationBar(activeIndex: 3),
        ),
        if (_isUpdating)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
          ),
      ],
    );
  }

  Widget _construirCabecalhoPerfil() {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 8),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => context.canPop() ? context.pop() : context.go('/inicio'),
                child: Icon(Icons.arrow_back, color: AppColors.primary, size: 24),
              ),
              Expanded(
                child: Text(
                  'Perfil',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontFamily: 'Playfair Display',
                    fontSize: 24,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: AppColors.accent.withOpacity(0.2), thickness: 1),
        ],
      ),
    );
  }

  Widget _construirSecaoFotoPerfil(
    String userName,
    Function formatDate,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
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
                      color: AppColors.accent,
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
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontFamily: 'Playfair Display',
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: AppColors.primary, // Primary green color
            ),
          ),
          const SizedBox(height: 12),
          Text(
            formatDate(AuthService.currentUserCriadoEm),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary.withOpacity(0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirSecaoInformacoesPessoais() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent.withOpacity(0.1)),
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
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.person_outline,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Informações Pessoais',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFamily: 'Playfair Display',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _construirItemInfo(
              'NOME COMPLETO',
              AuthService.currentUserNome ?? 'Não informado',
              onEdit: () => _mostrarDialogoEdicao(
                'Nome',
                AuthService.currentUserNome ?? '',
                false,
                isNome: true,
              ),
            ),
            _construirItemInfo(
              'E-MAIL',
              AuthService.currentUserEmail ?? 'Não informado',
              onEdit: () => _mostrarDialogoEdicao(
                'E-mail',
                AuthService.currentUserEmail ?? '',
                true,
              ),
            ),
            _construirItemInfo(
              'TELEFONE',
              AuthService.currentUserTelefone ?? 'Não informado',
              isLast: true,
              onEdit: () => _mostrarDialogoEdicao(
                'Telefone',
                AuthService.currentUserTelefone ?? '',
                false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirSecaoConfiguracoes(
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _construirTituloSecao('Configurações'),
          const SizedBox(height: 16),
          // Meus Pacotes (Visível para todos)
            GestureDetector(
              onTap: () => context.push('/meus-pacotes'),
              child: _construirItemAcao(
                icon: Icons.inventory_2_outlined,
                title: 'Meus Pacotes',
                subtitle: 'Visualize seus pacotes e sessões',
                pColor: AppColors.primary,
                gColor: AppColors.accent,
                softColor: AppColors.textSecondary,
              ),
            ),
          const SizedBox(height: 16),

          if (AuthService.isProfissional) ...[
            GestureDetector(
              onTap: () => context.push('/profissional/gerenciar-agenda'),
              child: _construirItemAcao(
                icon: Icons.calendar_month_outlined,
                title: 'Gerenciar Agenda',
                subtitle: 'Configurar horário de almoço e bloqueios',
                pColor: AppColors.primary,
                gColor: AppColors.accent,
                softColor: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (AuthService.isAdmin) ...[
            GestureDetector(
              onTap: () => context.push('/admin/promocoes'),
              child: _construirItemAcao(
                icon: Icons.campaign_outlined,
                title: 'Gerenciador de Promoções',
                subtitle: 'Gerencie os banners da tela inicial',
                pColor: AppColors.primary,
                gColor: AppColors.accent,
                softColor: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => context.go('/admin'),
              child: _construirItemAcao(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Continuar no Painel',
                subtitle: 'Voltar ao menu administrativo',
                pColor: AppColors.primary,
                gColor: AppColors.accent,
                softColor: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
          ],
          GestureDetector(
            onTap: () => context.push('/alterar-senha'),
            child: _construirItemAcao(
              icon: Icons.lock_outline,
              title: 'Alterar Senha',
              subtitle: 'Mantenha sua conta segura',
              pColor: AppColors.primary,
              gColor: AppColors.accent,
              softColor: AppColors.textSecondary,
            ),
          ),
          // Vincular Google removido.
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => context.push('/historico-avaliacoes'),
            child: _construirItemAcao(
              icon: Icons.rate_review_outlined,
              title: 'Histórico de Avaliações',
              subtitle: 'Minhas notas e comentários',
              pColor: AppColors.primary,
              gColor: AppColors.accent,
              softColor: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => context.push('/ajuda-suporte'),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accent.withOpacity(0.1)),
              ),
              child: _construirItemAcao(
                icon: Icons.help_outline,
                title: 'Ajuda & Suporte',
                subtitle: '',
                pColor: AppColors.primary,
                gColor: AppColors.accent,
                softColor: AppColors.textSecondary,
                hasSubtitle: false,
                noShadow: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirBotaoSair(
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: GestureDetector(
        onTap: () => context.push('/confirmacao-logout'),
        child: _construirItemAcao(
          icon: Icons.logout_rounded,
          title: 'Sair da conta',
          subtitle: 'Encerrar sessão no aplicativo',
          pColor: AppColors.primary,
          gColor: AppColors.accent,
          softColor: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _construirTituloSecao(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontFamily: 'Playfair Display',
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      ),
    );
  }

  Widget _construirItemInfo(
    String label,
    String value, {
    bool isLast = false,
    VoidCallback? onEdit,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: 40, bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            GestureDetector(
              onTap: onEdit,
              child: Text(
                'Editar',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
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
    required Color softColor,
    bool hasSubtitle = true,
    bool noShadow = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: noShadow
            ? null
            : Border.all(color: gColor.withOpacity(0.1)),
        boxShadow: noShadow
            ? null
            : [
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFamily: 'Playfair Display',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: pColor,
                  ),
                ),
                if (hasSubtitle) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 14,
                      color: softColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: gColor),
        ],
      ),
    );
  }
}

