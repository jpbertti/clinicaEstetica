import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  await Supabase.initialize(
    url: 'https://ympcrqylvawtyahwmhqg.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltcGNycXlsdmF3dHlhaHdtaHFnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1MzY4MjIsImV4cCI6MjA4OTExMjgyMn0.gQi6L3dOnpj8WpaQC9ymOvnNIkk58kR-3bkOxOKT8Zg',
  );
  
  final db = Supabase.instance.client;
  
  print("--- bloqueios_agenda ---");
  try {
    final res = await db.from('bloqueios_agenda').select().limit(1);
    if((res as List).isNotEmpty) {
      print(res.first.keys);
      print(res.first);
    } else {
      print("No rows via select");
    }
  } catch (e) {
    print(e);
  }

  print("--- disponibilidade_profissional ---");
  try {
    final res2 = await db.from('disponibilidade_profissional').select().limit(1);
    if((res2 as List).isNotEmpty) {
      print(res2.first.keys);
      print(res2.first);
    } else {
      print("No rows via select");
    }
  } catch (e) {
    print(e);
  }
}

