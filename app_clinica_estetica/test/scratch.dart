import 'package:flutter/material.dart';
import 'package:app_clinica_estetica/main.dart' as app_main;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // We don't fully init the app, but we can initialize Supabase if we know the URL and Anon Key.
  // Actually, let's just use the Supabase init from main.dart
  app_main.main();
}

