import 'package:flutter/material.dart';

class UsuarioShellPage extends StatefulWidget {
  final Widget child;
  final String currentPath;

  const UsuarioShellPage({
    super.key,
    required this.child,
    required this.currentPath,
  });

  @override
  State<UsuarioShellPage> createState() => _UsuarioShellPageState();
}

class _UsuarioShellPageState extends State<UsuarioShellPage> {
  @override
  Widget build(BuildContext context) {
    // Retornamos apenas o child pois cada página agora gerencia seu próprio Scaffold, 
    // AppBar e BottomNavigationBar, evitando redundância na interface.
    return widget.child;
  }
}
