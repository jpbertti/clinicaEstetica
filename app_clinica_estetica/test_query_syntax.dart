
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_clinica_estetica/core/app_config.dart';

void main() async {
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  
  final client = Supabase.instance.client;
  
  try {
    final id = '792b512e-13c2-48a0-9831-c42385bda61b';
    
    print('Testing query NO QUOTES: .filter("id", "in", "($id)")');
    final res1 = await client.from('perfis').select().filter('id', 'in', '($id)');
    print('Result count NO QUOTES: ${res1.length}');

    print('Testing query WITH QUOTES: .filter("id", "in", "("$id")")');
    final res2 = await client.from('perfis').select().filter('id', 'in', '("$id")');
    print('Result count WITH QUOTES: ${res2.length}');

    print('Testing query with inFilter method: .inFilter("id", ["$id"])');
    try {
      final res3 = await client.from('perfis').select().inFilter('id', [id]);
      print('Result count with inFilter: ${res3.length}');
    } catch (e) {
      print('in_ failed: $e');
    }
  } catch (e) {
    print('Error: $e');
  }
}

