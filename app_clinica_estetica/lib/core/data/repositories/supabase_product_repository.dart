import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';

class SupabaseProductRepository {
  final _supabase = Supabase.instance.client;

  Future<List<ProductModel>> getProducts({bool onlyActive = true}) async {
    try {
      var query = _supabase.from('produtos').select();
      
      if (onlyActive) {
        query = query.eq('ativo', true);
      }

      final response = await query.order('nome');
      return (response as List).map((m) => ProductModel.fromMap(m)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createProduct(ProductModel product) async {
    try {
      await _supabase.from('produtos').insert(product.toMap());
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateProduct(String id, ProductModel product) async {
    try {
      await _supabase.from('produtos').update(product.toMap()).eq('id', id);
    } catch (e) {
      rethrow;
    }
  }

  /// Verifica se há um caixa aberto e retorna seu ID
  Future<String?> getActiveCaixaId() async {
    try {
      final res = await _supabase
          .from('caixas')
          .select('id')
          .eq('status', 'aberto')
          .maybeSingle();
      return res?['id'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Registra uma venda direta de produto
  Future<void> registerSale(ProductSaleModel sale) async {
    try {
      // A trigger trg_venda_produto_processamento cuidará de:
      // 1. Decrementar o estoque
      // 2. Criar registro em 'contas' (financeiro)
      // 3. Registrar no historico_estoque
      // 4. Logar no dashboard
      await _supabase.from('vendas_produtos').insert(sale.toMap());
    } catch (e) {
      rethrow;
    }
  }

  /// Busca o histórico de movimentações (vendas e entradas manuais)
  Future<List<Map<String, dynamic>>> getProductMovements({String? type}) async {
    try {
      var query = _supabase.from('historico_estoque').select('*, produtos(nome, imagem_url, categoria), profissional:perfis!historico_estoque_criado_por_fkey(nome_completo)');
      
      if (type != null && type != 'todos') {
        query = query.eq('tipo_movimentacao', type);
      }
      
      final res = await query.order('criado_em', ascending: false);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      rethrow;
    }
  }

  /// Upload de imagem para o bucket 'produtos'
  Future<String?> uploadProductImage(String fileName, Uint8List bytes) async {
    try {
      final extension = fileName.split('.').last;
      final uniqueName = 'prod_${DateTime.now().millisecondsSinceEpoch}.$extension';
      
      await _supabase.storage.from('produtos').uploadBinary(
        uniqueName, 
        bytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );
      
      return _supabase.storage.from('produtos').getPublicUrl(uniqueName);
    } catch (e) {
      debugPrint('Erro upload imagem produto: $e');
      return null;
    }
  }

  /// Remove imagem do storage
  Future<void> deleteProductImage(String url) async {
    try {
      final uri = Uri.parse(url);
      final fileName = uri.pathSegments.last;
      await _supabase.storage.from('produtos').remove([fileName]);
    } catch (e) {
      debugPrint('Erro deletar imagem produto: $e');
    }
  }
  /// Busca histórico de compras de produtos de um cliente
  Future<List<Map<String, dynamic>>> getProductPurchasesByClient(String clientId) async {
    try {
      final res = await _supabase
          .from('vendas_produtos')
          .select('*, produtos(nome, imagem_url, categoria), profissional:perfis!vendas_produtos_profissional_id_fkey(nome_completo)')
          .eq('cliente_id', clientId)
          .order('criado_em', ascending: false);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      rethrow;
    }
  }
  /// Busca os detalhes de uma venda específica
  Future<Map<String, dynamic>?> getSaleDetails(String saleId) async {
    try {
      final res = await _supabase
          .from('vendas_produtos')
          .select('*, produtos(nome, imagem_url), cliente:perfis!vendas_produtos_cliente_id_fkey(nome_completo), profissional:perfis!vendas_produtos_profissional_id_fkey(nome_completo)')
          .eq('id', saleId)
          .maybeSingle();
      return res;
    } catch (e) {
      debugPrint('Erro ao buscar detalhes da venda: $e');
      return null;
    }
  }
}

