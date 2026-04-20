import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/auth_service.dart';
import 'package:go_router/go_router.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class CadastroPage extends StatefulWidget {
  const CadastroPage({super.key});

  @override
  State<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  final _nomeController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  final _telefoneFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  final _nomeFocusNode = FocusNode();
  final _telefoneFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _isNomeFocused = false;
  bool _isTelefoneFocused = false;
  bool _isEmailFocused = false;
  bool _isPasswordFocused = false;

  @override
  void initState() {
    super.initState();
    _nomeFocusNode.addListener(() => setState(() => _isNomeFocused = _nomeFocusNode.hasFocus));
    _telefoneFocusNode.addListener(() => setState(() => _isTelefoneFocused = _telefoneFocusNode.hasFocus));
    _emailFocusNode.addListener(() => setState(() => _isEmailFocused = _emailFocusNode.hasFocus));
    _passwordFocusNode.addListener(() => setState(() => _isPasswordFocused = _passwordFocusNode.hasFocus));
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _telefoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nomeFocusNode.dispose();
    _telefoneFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_nomeController.text.isEmpty ||
        _telefoneController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, preencha todos os campos obrigatórios.'),
        ),
      );
      return;
    }

    final String unmaskedPhone = _telefoneFormatter.getUnmaskedText();
    if (unmaskedPhone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, insira um telefone válido com DDD.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.register(
        nome: _nomeController.text,
        email: _emailController.text,
        telefone: _telefoneFormatter.getUnmaskedText(),
        password: _passwordController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conta criada com sucesso! Faça login.'),
            backgroundColor: Color(0xFF305F47),
          ),
        );
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF305F47);
    const backgroundColor = Color(0xFFF9F7F2);
    const softGreen = Color(0xFF6E8F7B);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Text(
                'Registrar-se',
                style: TextStyle(fontFamily: 'Playfair Display', 
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                child: Text(
                  'Crie sua conta para uma experiência exclusiva e personalizada em nossa clínica.',
                  style: TextStyle(fontSize: 14,
                    color: softGreen,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              _construirRotuloCampo('NOME COMPLETO'),
              _construirCampoTexto(
                _nomeController,
                'Como gostaria de ser chamada(o)?',
                focusNode: _nomeFocusNode,
                isFocused: _isNomeFocused,
                icon: Icons.person_outline,
              ),

              const SizedBox(height: 16),
              _construirRotuloCampo('TELEFONE'),
              _construirCampoTexto(
                _telefoneController,
                '(00) 00000-0000',
                focusNode: _telefoneFocusNode,
                isFocused: _isTelefoneFocused,
                keyboardType: TextInputType.phone,
                icon: Icons.phone_outlined,
                inputFormatters: [_telefoneFormatter],
              ),

              const SizedBox(height: 16),
              _construirRotuloCampo('E-MAIL'),
              _construirCampoTexto(
                _emailController,
                'seuemail@exemplo.com',
                focusNode: _emailFocusNode,
                isFocused: _isEmailFocused,
                keyboardType: TextInputType.emailAddress,
                icon: Icons.email_outlined,
              ),

              const SizedBox(height: 16),
              _construirRotuloCampo('SENHA'),
              _construirCampoSenha(),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Criar Conta',
                          style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 32),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Já possui uma conta? ',
                      style: TextStyle(color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Text(
                        'Faça Login',
                        style: TextStyle(color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
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

  Widget _construirRotuloCampo(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFFC7A46B), // Gold
          letterSpacing: 2.0,
          fontFamily: 'Inter',
        ),
      ),
    );
  }

  Widget _construirCampoTexto(
    TextEditingController controller,
    String hint, {
    TextInputType? keyboardType,
    List<dynamic>? inputFormatters,
    IconData? icon,
    FocusNode? focusNode,
    bool isFocused = false,
  }) {
    const accentColor = Color(0xFFC7A46B);
    const primaryColor = Color(0xFF305F47);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isFocused ? accentColor : primaryColor.withOpacity(0.1),
          width: isFocused ? 2 : 1,
        ),
        boxShadow: [
          if (isFocused)
            BoxShadow(
              color: accentColor.withValues(alpha: 0.2),
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters != null ? List<TextInputFormatter>.from(inputFormatters) : null,
        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          prefixIcon: icon != null ? Icon(icon, color: primaryColor, size: 20) : null,
          hintText: hint,
          hintStyle: TextStyle(color: const Color(0xFF6E8F7B).withOpacity(0.4),
            fontSize: 14,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _construirCampoSenha() {
    const accentColor = Color(0xFFC7A46B);
    const primaryColor = Color(0xFF305F47);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: _isPasswordFocused ? accentColor : primaryColor.withOpacity(0.1),
          width: _isPasswordFocused ? 2 : 1,
        ),
        boxShadow: [
          if (_isPasswordFocused)
            BoxShadow(
              color: accentColor.withValues(alpha: 0.2),
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
        ],
      ),
        child: TextField(
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          obscureText: !_isPasswordVisible,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline, color: primaryColor, size: 20),
            hintText: 'Crie a sua senha',
            hintStyle: TextStyle(color: const Color(0xFF6E8F7B).withOpacity(0.4),
              fontSize: 14,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
            border: InputBorder.none,
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: primaryColor,
              ),
              onPressed: () =>
                  setState(() => _isPasswordVisible = !_isPasswordVisible),
            ),
          ),
        ),
    );
  }

  Widget _construirDivisor() {
    return Row(
      children: [
        Expanded(
          child: Divider(color: const Color(0xFF305F47).withOpacity(0.1)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OU CONTINUE COM',
            style: TextStyle(color: Colors.grey[400],
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: const Color(0xFF305F47).withOpacity(0.1)),
        ),
      ],
    );
  }

  // _handleGoogleLogin e _construirBotaoGoogle removidos.
}

