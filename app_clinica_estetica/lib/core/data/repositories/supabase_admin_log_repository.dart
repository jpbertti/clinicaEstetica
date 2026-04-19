import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_clinica_estetica/core/data/models/admin_log_model.dart';

class SupabaseAdminLogRepository {
  final _supabase = Supabase.instance.client;

  Future<void> saveLog(AdminLogModel log) async {
    try {
      await _supabase.from('logs_admin').insert(log.toMap());
    } catch (e) {
      // Falha silenciosa para não quebrar o fluxo principal, mas loga no console
      debugPrint('Erro ao salvar log de auditoria: $e');
    }
  }

  Future<void> logAction({
    required String acao,
    String? detalhes,
    String? tabelaAfetada,
    String? itemId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Tenta buscar o nome do admin no perfil
      final profile = await _supabase
          .from('perfis')
          .select('nome')
          .eq('id', user.id)
          .single();
      
      final log = AdminLogModel(
        adminId: user.id,
        adminNome: profile['nome'],
        acao: acao,
        detalhes: detalhes,
        tabelaAfetada: tabelaAfetada,
        itemId: itemId,
      );

      await saveLog(log);
    } catch (e) {
      // Fallback se não conseguir pegar o nome
      final log = AdminLogModel(
        adminId: user.id,
        acao: acao,
        detalhes: detalhes,
        tabelaAfetada: tabelaAfetada,
        itemId: itemId,
      );
      await saveLog(log);
    }
  }
}

