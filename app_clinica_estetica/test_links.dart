
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_clinica_estetica/core/app_config.dart';

void main() async {
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  
  final client = Supabase.instance.client;
  
  try {
    final countResponse = await client
        .from('profissional_servicos')
        .select('*', const FetchOptions(count: CountOption.exact));
    
    print('Total rows in profissional_servicos: ${countResponse.count}');
    if (countResponse.data != null && (countResponse.data as List).isNotEmpty) {
      print('First row: ${countResponse.data[0]}');
    }

    final servicesResponse = await client.from('servicos').select('id, nome').limit(5);
    print('Sample services: $servicesResponse');

    if (servicesResponse.isNotEmpty) {
      final sId = servicesResponse[0]['id'];
      final links = await client
          .from('profissional_servicos')
          .select('profissional_id')
          .eq('servico_id', sId);
      print('Links for service $sId (${servicesResponse[0]['nome']}): $links');
    }
  } catch (e) {
    print('Error: $e');
  }
}

