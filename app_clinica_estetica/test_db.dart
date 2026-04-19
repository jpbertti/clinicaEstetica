
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_clinica_estetica/core/app_config.dart';

void main() async {
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  
  final client = Supabase.instance.client;
  
  try {
    final response = await client
        .from('profissional_servicos')
        .select('*')
        .limit(1);
    
    print('Sample data from profissional_servicos: $response');
  } catch (e) {
    print('Error accessing profissional_servicos: $e');
  }
}

