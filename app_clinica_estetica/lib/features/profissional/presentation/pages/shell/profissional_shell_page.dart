import 'package:flutter/material.dart';

class ProfissionalShellPage extends StatefulWidget {
  final Widget child;
  final String currentPath;

  const ProfissionalShellPage({
    super.key,
    required this.child,
    required this.currentPath,
  });

  // Notificador para disparar atualização nas páginas filhas (ex: Agenda)
  // Mantido aqui para compatibilidade com as páginas que já o utilizam
  static final refreshNotifier = ValueNotifier<int>(0);

  @override
  State<ProfissionalShellPage> createState() => _ProfissionalShellPageState();
}

class _ProfissionalShellPageState extends State<ProfissionalShellPage> {
  @override
  Widget build(BuildContext context) {
    // Retornamos apenas o child pois cada página agora gerencia seu próprio Scaffold, 
    // AppBar e BottomNavigationBar, evitando redundância na interface e permitindo
    // maior controle sobre o layout de cada tela.
    return widget.child;
  }
}
