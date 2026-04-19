import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://ympcrqylvawtyahwmhqg.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltcGNycXlsdmF3dHlhaHdtaHFnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1MzY4MjIsImV4cCI6MjA4OTExMjgyMn0.gQi6L3dOnpj8WpaQC9ymOvnNIkk58kR-3bkOxOKT8Zg',
  );

  print('--- Testando Join contas -> perfis via criado_por ---');
  try {
    // 1. Tentar com perfis!criado_por
    print('Tentando: .select("*, perfis!criado_por(nome_completo)")');
    final res1 = await supabase
        .from('contas')
        .select('*, perfis!criado_por(nome_completo)')
        .limit(1);
    print('Sucesso 1: ${res1.isNotEmpty ? res1.first : "Vazio"}');
  } catch (e) {
    print('Erro 1: $e');
  }

  try {
    // 2. Tentar com perfis:criado_por (alias) - o que usei antes
    print('\nTentando: .select("*, perfis:criado_por(nome_completo)")');
    final res2 = await supabase
        .from('contas')
        .select('*, perfis:criado_por(nome_completo)')
        .limit(1);
    print('Sucesso 2: ${res2.isNotEmpty ? res2.first : "Vazio"}');
  } catch (e) {
    print('Erro 2: $e');
  }

  try {
    // 3. Tentar com fkey explicita (se soubermos o nome, assumindo contas_criado_por_fkey)
    print('\nTentando: .select("*, perfis!contas_criado_por_fkey(nome_completo)")');
    final res3 = await supabase
        .from('contas')
        .select('*, perfis!contas_criado_por_fkey(nome_completo)')
        .limit(1);
    print('Sucesso 3: ${res3.isNotEmpty ? res3.first : "Vazio"}');
  } catch (e) {
    print('Erro 3: $e');
  }

  try {
     print('\n--- Testando Join caixas -> perfis via usuario_id ---');
     final res4 = await supabase
        .from('caixas')
        .select('*, perfis!usuario_id(nome_completo)')
        .limit(1);
     print('Sucesso 4: ${res4.isNotEmpty ? res4.first : "Vazio"}');
  } catch (e) {
    print('Erro 4: $e');
  }
}

