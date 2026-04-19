
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_clinica_estetica/core/app_config.dart';

void main() async {
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  
  final client = Supabase.instance.client;
  
  try {
    print('--- Checking profissional_servicos ---');
    final links = await client
        .from('profissional_servicos')
        .select('*');
    print('Found ${links.length} links.');
    if (links.isNotEmpty) {
      print('First 5 links: ${links.take(5).toList()}');
    }

    print('\n--- Checking perfis for profissionais ---');
    final profs = await client
        .from('perfis')
        .select('*')
        .eq('tipo', 'profissional');
    print('Found ${profs.length} professionals in perfis.');
    if (profs.isNotEmpty) {
      print('Professional IDs in perfis: ${profs.map((p) => p['id']).toList()}');
    }

    print('\n--- Verifying ID consistency ---');
    if (links.isNotEmpty && profs.isNotEmpty) {
      final profIdsInPerfis = profs.map((p) => p['id']).toSet();
      final profIdsInLinks = links.map((l) => l['profissional_id']).toSet();
      
      final missingInPerfis = profIdsInLinks.difference(profIdsInPerfis);
      if (missingInPerfis.isNotEmpty) {
        print('CRITICAL: These IDs are in profissional_servicos but NOT in perfis: $missingInPerfis');
      } else {
        print('All professional IDs in links are present in perfis.');
      }
    }

    print('\n--- Checking services ---');
    final services = await client.from('servicos').select('id, nome');
    print('Services: $services');

  } catch (e) {
    print('Error during debug: $e');
  }
}
