
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_clinica_estetica/core/app_config.dart';

void main() async {
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  
  final client = Supabase.instance.client;
  
  try {
    print('Testing database connection...');
    
    // Check if we can see any professionals
    final profs = await client.from('perfis').select('id, email, nome_completo').limit(1);
    print('Sample professional: $profs');

    // Check if we can see any services
    final services = await client.from('servicos').select('id, nome').limit(1);
    print('Sample service: $services');

    if (profs.isNotEmpty && services.isNotEmpty) {
      final pId = profs[0]['id'];
      final sId = services[0]['id'];
      
      print('Attempting to insert test link: prof=$pId, service=$sId');
      
      final insertResponse = await client.from('profissional_servicos').insert({
        'profissional_id': pId,
        'servico_id': sId,
      }).select();
      
      print('Insert response: $insertResponse');
      
      final check = await client.from('profissional_servicos').select('*');
      print('All links now: $check');
    } else {
      print('Could not find enough data to test link insertion.');
    }
  } catch (e) {
    print('Error: $e');
  }
}

