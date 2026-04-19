
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_clinica_estetica/core/app_config.dart';

void main() async {
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  
  final client = Supabase.instance.client;
  
  try {
    final services = await client.from('servicos').select('id, nome').limit(1);
    if (services.isEmpty) {
      print('No services found.');
      return;
    }
    final sId = services[0]['id'];
    print('Testing join for service: ${services[0]['nome']} ($sId)');

    // Join query
    final response = await client
        .from('perfis')
        .select('*, profissional_servicos!inner(servico_id)')
        .eq('profissional_servicos.servico_id', sId)
        .or('tipo.eq.profissional,tipo.eq.admin');
    
    print('Join response count: ${response.length}');
    if (response.isNotEmpty) {
      print('First professional found: ${response[0]['nome_completo']}');
    }
  } catch (e) {
    print('Join failed: $e');
    print('Trying alternative join syntax...');
    try {
      final response = await client
          .from('perfis')
          .select('*, profissional_servicos!profissional_servicos_profissional_id_fkey!inner(servico_id)')
          .eq('profissional_servicos.servico_id', services[0]['id'])
          .or('tipo.eq.profissional,tipo.eq.admin');
       print('Alternative join response count: ${response.length}');
    } catch (e2) {
      print('Alternative join failed: $e2');
    }
  }
}

