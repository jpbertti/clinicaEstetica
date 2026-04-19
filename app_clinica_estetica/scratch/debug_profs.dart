import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final supabase = SupabaseClient('YOUR_URL', 'YOUR_KEY'); // These are injected by the environment usually or managed by the app
  
  try {
    final profs = await supabase.from('perfis').select().limit(5);
    print('Professionals: $profs');
    
    final links = await supabase.from('profissional_servicos').select().limit(5);
    print('Links: $links');
    
    final services = await supabase.from('servicos').select().limit(5);
    print('Services: $services');
  } catch (e) {
    print('Error: $e');
  }
}
