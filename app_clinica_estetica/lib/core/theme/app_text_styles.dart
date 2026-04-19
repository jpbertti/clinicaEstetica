import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  /// interSub: Inter style for premium subtitles
  static const TextStyle interSub = TextStyle(
    fontFamily: 'Inter',
    fontSize: 9,
    fontWeight: FontWeight.w400,
    letterSpacing: 3.0,
    color: AppColors.accent,
  );

  /// playfairTitle: Elegant Playfair Display for headers
  static const TextStyle playfairTitle = TextStyle(
    fontFamily: 'Playfair Display',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );
}
