import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_clinica_estetica/core/data/models/promotion_model.dart';

class SupabasePromotionRepository {
  final _supabase = Supabase.instance.client;

  Future<List<PromotionModel>> getPromotions() async {
    try {
      // Usando query simplificada para evitar erro de relacionamento Postgrest (PGRST200)
      // Se o join falhar, buscamos apenas os dados da promoção e o servico_id
      final response = await _supabase
          .from('promocoes')
          .select('*, servicos(*, categorias(nome)), pacotes_templates(*, categorias(nome))')
          .eq('ativo', true)
          .order('ordem', ascending: true);

      return (response as List).map((p) => PromotionModel.fromMap(p)).toList();
    } catch (e) {
      if (e.toString().contains('PGRST200')) {
        // Fallback caso o relacionamento não exista no schema cache
        final fallback = await _supabase
            .from('promocoes')
            .select('*')
            .eq('ativo', true)
            .order('ordem', ascending: true);
        return (fallback as List).map((p) => PromotionModel.fromMap(p)).toList();
      }
      throw Exception('Erro ao carregar promoções: $e');
    }
  }

  Future<List<PromotionModel>> getAllPromotionsAdmin() async {
    try {
      final response = await _supabase
          .from('promocoes')
          .select('*, servicos(*), pacotes_templates(*)')
          .order('ordem', ascending: true);

      return (response as List).map((p) => PromotionModel.fromMap(p)).toList();
    } catch (e) {
      if (e.toString().contains('PGRST200')) {
        final fallback = await _supabase
            .from('promocoes')
            .select('*')
            .order('ordem', ascending: true);
        return (fallback as List).map((p) => PromotionModel.fromMap(p)).toList();
      }
      throw Exception('Erro ao carregar todas as promoções: $e');
    }
  }

  Future<void> updatePromotion(PromotionModel promotion) async {
    try {
      await _supabase
          .from('promocoes')
          .update(promotion.toMap())
          .eq('id', promotion.id);
    } catch (e) {
      throw Exception('Erro ao atualizar promoção: $e');
    }
  }

  Future<void> insertPromotion(PromotionModel promotion) async {
    try {
      final data = promotion.toMap();
      // Não enviamos o ID se for novo para deixar o DB gerar (UUID)
      // Mas se o modelo já tiver um ID temporário ou for necessário, removemos aqui
      await _supabase.from('promocoes').insert(data);
    } catch (e) {
      throw Exception('Erro ao criar promoção: $e');
    }
  }

  Future<void> deletePromotion(String id) async {
    try {
      await _supabase.from('promocoes').delete().eq('id', id);
    } catch (e) {
      throw Exception('Erro ao excluir promoção: $e');
    }
  }

  /// Upload de imagem para o bucket 'promocoes' (ou 'perfis' se não existir/configurado)
  Future<String?> uploadPromotionImage(String fileName, Uint8List bytes) async {
    try {
      final extension = fileName.split('.').last;
      final uniqueName = 'promo_${DateTime.now().millisecondsSinceEpoch}.$extension';
      
      // Tentamos o bucket 'promocoes', se falhar tentamos o 'perfis' (que sabemos que existe)
      try {
        await _supabase.storage.from('promocoes').uploadBinary(
          uniqueName, 
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );
        return _supabase.storage.from('promocoes').getPublicUrl(uniqueName);
      } catch (e) {
        debugPrint('Erro no bucket promocoes, tentando perfis: $e');
        await _supabase.storage.from('perfis').uploadBinary(
          uniqueName, 
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );
        return _supabase.storage.from('perfis').getPublicUrl(uniqueName);
      }
    } catch (e) {
      debugPrint('Erro upload imagem promoção: $e');
      return null;
    }
  }

  /// Remove imagem do storage
  Future<void> deletePromotionImage(String url) async {
    try {
      if (url.isEmpty || !url.startsWith('http')) return;
      
      final uri = Uri.parse(url);
      final fileName = uri.pathSegments.last;
      
      // Tenta remover de ambos se não tiver certeza de qual bucket foi
      try {
        await _supabase.storage.from('promocoes').remove([fileName]);
      } catch (_) {}
      
      try {
        await _supabase.storage.from('perfis').remove([fileName]);
      } catch (_) {}
    } catch (e) {
      debugPrint('Erro deletar imagem promoção: $e');
    }
  }
}

