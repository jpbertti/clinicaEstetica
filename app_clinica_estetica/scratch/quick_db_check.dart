
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const url = 'https://ympcrqylvawtyahwmhqg.supabase.co';
  const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltcGNycXlsdmF3dHlhaHdtaHFnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1MzY4MjIsImV4cCI6MjA4OTExMjgyMn0.gQi6L3dOnpj8WpaQC9ymOvnNIkk58kR-3bkOxOKT8Zg';

  Future<dynamic> get(String table, String select) async {
    final response = await http.get(
      Uri.parse('$url/rest/v1/$table?select=$select'),
      headers: {
        'apikey': anonKey,
        'Authorization': 'Bearer $anonKey',
      },
    );
    if (response.statusCode != 200) {
      print('Error fetching $table: ${response.statusCode} - ${response.body}');
      return [];
    }
    return jsonDecode(response.body);
  }

  print('--- Quick DB Debug ---');
  
  final links = await get('profissional_servicos', '*');
  print('Found ${links.length} professional-service links.');

  final perfis = await get('perfis', '*');
  print('Total profiles: ${perfis.length}');
  
  final types = perfis.map((p) => p['tipo']).toSet();
  print('Unique profile types in DB: $types');

  final professionals = perfis.where((p) => p['tipo'].toString().toLowerCase() == 'profissional').toList();
  print('Professionals found (case-insensitive): ${professionals.length}');
  if (professionals.isNotEmpty) {
     print('Sample professional: ${professionals.first['nome_completo']} (tipo: ${professionals.first['tipo']}, ativo: ${professionals.first['ativo']})');
  }

  final admins = perfis.where((p) => p['tipo'].toString().toLowerCase() == 'admin').toList();
  print('Admins found (case-insensitive): ${admins.length}');

  if (links.isNotEmpty) {
    final serviceIds = links.map((l) => l['servico_id']).toSet();
    print('Services with links: $serviceIds');
    
    final profIdsInLinks = links.map((l) => l['profissional_id']).toSet();
    print('Professional IDs in links: $profIdsInLinks');
    
    final profIdsInPerfis = perfis.map((p) => p['id']).toSet();
    final missing = profIdsInLinks.difference(profIdsInPerfis);
    if (missing.isNotEmpty) {
      print('!!! CRITICAL: Professional IDs in links NOT FOUND in perfis: $missing');
    } else {
      print('All professional IDs in links are present in perfis.');
    }
  }

  final services = await get('servicos', 'id,nome');
  print('Available services: ${services.map((s) => '${s['id']}: ${s['nome']}').toList()}');
}
