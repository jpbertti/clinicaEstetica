import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_clinica_estetica/core/data/models/service_model.dart';
import 'package:app_clinica_estetica/core/data/repositories/service_repository.dart';

class SupabaseServiceRepository implements IServiceRepository {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  Future<List<ServiceModel>> getActiveServices() async {
    final response = await _client
        .from('servicos')
        .select('*, categorias(nome), admin_perfil:admin_promocao_id(nome_completo)')
        .eq('ativo', true)
        .order('nome');

    return (response as List)
        .map((json) => ServiceModel.fromJson(json))
        .toList();
  }

  Future<List<ServiceModel>> getServicesByProfessional(String professionalId) async {
    // 1. Get linked service IDs
    final linksResponse = await _client
        .from('profissional_servicos')
        .select('servico_id')
        .eq('profissional_id', professionalId);
    
    final List<String> linkedIds = (linksResponse as List)
        .map((e) => e['servico_id'].toString())
        .toList();

    if (linkedIds.isEmpty) return [];

    // 2. Get services matching those IDs
    final response = await _client
        .from('servicos')
        .select('*, categorias(nome), admin_perfil:admin_promocao_id(nome_completo)')
        .eq('ativo', true)
        .inFilter('id', linkedIds)
        .order('nome');

    return (response as List)
        .map((json) => ServiceModel.fromJson(json))
        .toList();
  }

  @override
  Future<List<ServiceModel>> searchServices(String query) async {
    if (query.isEmpty) return [];
    
    final response = await _client
        .from('servicos')
        .select('*, categorias(nome), admin_perfil:admin_promocao_id(nome_completo)')
        .eq('ativo', true)
        .ilike('nome', '%$query%')
        .order('nome');

    return (response as List)
        .map((json) => ServiceModel.fromJson(json))
        .toList();
  }


  @override
  Future<List<Map<String, dynamic>>> getCategories() async {
    final response = await _client
        .from('categorias')
        .select()
        .order('ordem', ascending: true);
    
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Future<bool> canDeleteService(String serviceId) async {
    try {
      // 1. Verificar agendamentos
      final appointments = await _client
          .from('agendamentos')
          .select('id')
          .eq('servico_id', serviceId)
          .neq('status', 'cancelado')
          .limit(1);
      
      if ((appointments as List).isNotEmpty) return false;

      // 2. Verificar pacotes ativos vinculados
      final activePackages = await _client
          .from('pacote_servicos')
          .select('pacote_id, pacotes_templates!inner(ativo)')
          .eq('servico_id', serviceId)
          .eq('pacotes_templates.ativo', true)
          .limit(1);

      if ((activePackages as List).isNotEmpty) return false;

      // 3. Verificar profissionais vinculados
      try {
        final profLinks = await _client
            .from('profissional_servicos')
            .select('id')
            .eq('servico_id', serviceId)
            .limit(1);
        
        if ((profLinks as List).isNotEmpty) return false;
      } catch (e) {
        // Ignorar se a tabela não existir ou outro erro
      }

      return true;
    } catch (e) {
      // Em caso de erro, por segurança, impedimos a exclusão
      return false;
    }
  }
}

