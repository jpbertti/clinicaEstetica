import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  print('Iniciando inserção de agendamento de teste...');

  final supabase = SupabaseClient(
    'https://ympcrqylvawtyahwmhqg.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltcGNycXlsdmF3dHlhaHdtaHFnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1MzY4MjIsImV4cCI6MjA4OTExMjgyMn0.gQi6L3dOnpj8WpaQC9ymOvnNIkk58kR-3bkOxOKT8Zg',
  );

  try {
    // 1. Buscar um cliente
    final clientes = await supabase
        .from('perfis')
        .select('id')
        .eq('tipo', 'cliente')
        .limit(1);

    if (clientes.isEmpty) {
      print('Erro: Nenhum cliente encontrado no banco de dados.');
      return;
    }

    final clienteId = clientes.first['id'];
    const profissionalId =
        'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1'; // Dra. Gabriela
    const servicoId = '660e8400-e29b-41d4-a716-446655440001'; // Limpeza de Pele

    // 2. Inserir agendamento
    await supabase.from('agendamentos').insert({
      'cliente_id': clienteId,
      'profissional_id': profissionalId,
      'servico_id': servicoId,
      'data_hora': DateTime.now()
          .subtract(const Duration(days: 2))
          .toIso8601String(),
      'valor_total': 150.00,
      'status': 'concluido',
      'observacoes': 'Agendamento de teste finalizado.',
    });

    print('Sucesso: Agendamento concluído inserido para o cliente $clienteId');
  } catch (e) {
    print('Erro ao inserir agendamento: $e');
  }
}

