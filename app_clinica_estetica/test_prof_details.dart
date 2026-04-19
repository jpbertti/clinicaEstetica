
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_clinica_estetica/core/app_config.dart';

void main() async {
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  
  final client = Supabase.instance.client;
  
  try {
    final prof = await client
        .from('perfis')
        .select('*')
        .eq('nome_completo', 'João Admin')
        .maybeSingle();
    
    print('João Admin profile: $prof');
  } catch (e) {
    print('Error: $e');
  }
}

