import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_clinica_estetica/core/app_config.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.initialize();
  
  final supabase = Supabase.instance.client;
  try {
    final response = await supabase.from('promocoes').select('*');
    print('PROMOCOES COUNT: ${response.length}');
    for (var p in response) {
      print('Promotion: ${p['titulo']} - Active: ${p['ativo']}');
    }
  } catch (e) {
    print('DB ERROR: $e');
  }
}

