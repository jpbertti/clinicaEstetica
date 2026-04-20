import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppButtonStyles {
  /// Retorna o estilo de texto usado nos botões pequenos
  static TextStyle smallTextStyle({Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontSize: 13,
      fontWeight: fontWeight ?? FontWeight.bold,
      letterSpacing: 0.3,
      color: color,
    );
  }

  /// Retorna o estilo de texto usado nos botões primários
  static TextStyle primaryTextStyle({Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontSize: 16,
      fontWeight: fontWeight ?? FontWeight.bold,
      letterSpacing: 0.5,
      color: color,
    );
  }

  /// Padrão de botão "small" solicitado pelo usuário
  static ButtonStyle small({Color? backgroundColor, Color? foregroundColor}) {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor ?? AppColors.primary,
      foregroundColor: foregroundColor ?? Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      minimumSize: const Size(80, 36),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      elevation: 0,
      textStyle: smallTextStyle(),
    );
  }

  /// Padrão de botão primário (normal) solicitado pelo usuário
  static ButtonStyle primary({Color? backgroundColor, Color? foregroundColor}) {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor ?? AppColors.primary,
      foregroundColor: foregroundColor ?? Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      minimumSize: const Size(120, 52),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      elevation: 2,
      textStyle: primaryTextStyle(),
    );
  }
  /// Padrão de estilo de texto para botões de cancelamento
  static TextStyle cancelTextStyle() {
    return const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: Colors.black54,
    );
  }

  /// Padrão de estilo para botões de cancelamento (Outlined/Text)
  static ButtonStyle cancelButtonStyle() {
    return TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

