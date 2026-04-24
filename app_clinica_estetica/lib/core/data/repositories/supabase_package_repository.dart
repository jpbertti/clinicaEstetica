import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pacote_contratado_model.dart';
import '../models/pacote_template_model.dart';
import 'package_repository.dart';

class SupabasePackageRepository implements PackageRepository {
  final SupabaseClient _supabase;

  SupabasePackageRepository(this._supabase);

  @override
  Future<List<PacoteTemplateModel>> getTemplates() async {
    final response = await _supabase
        .from('pacotes_templates')
        .select('*, admin_perfil:admin_promocao_id(nome_completo), pacote_servicos(servico_id, quantidade_sessoes, servicos(nome))')
        .order('titulo', ascending: true);

    return (response as List).map((e) => PacoteTemplateModel.fromJson(e)).toList();
  }

  @override
  Future<PacoteTemplateModel> getTemplateById(String id) async {
    final response = await _supabase
        .from('pacotes_templates')
        .select('*, admin_perfil:admin_promocao_id(nome_completo), pacote_servicos(servico_id, quantidade_sessoes, servicos(nome))')
        .eq('id', id)
        .single();
    return PacoteTemplateModel.fromJson(response);
  }

  @override
  Future<PacoteTemplateModel> createTemplate(PacoteTemplateModel template) async {
    final data = template.toJson();
    data.remove('id'); // Supabase will assign the UUID

    final response = await _supabase
        .from('pacotes_templates')
        .insert(data)
        .select()
        .single();
    
    final newTemplate = PacoteTemplateModel.fromJson(response);

    // Insert services into junction table
    if (template.servicos != null && template.servicos!.isNotEmpty) {
      final junctionData = template.servicos!.map((item) => {
        'pacote_id': newTemplate.id,
        'servico_id': item.servicoId,
        'quantidade_sessoes': item.quantidadeSessoes,
      }).toList();
      
      await _supabase.from('pacote_servicos').insert(junctionData);
    }

    return newTemplate;
  }

  @override
  Future<void> updateTemplate(PacoteTemplateModel template) async {
    await _supabase
        .from('pacotes_templates')
        .update(template.toJson())
        .eq('id', template.id);

    // Update services in junction table
    // 1. Clear existing
    await _supabase.from('pacote_servicos').delete().eq('pacote_id', template.id);

    // 2. Insert new ones
    if (template.servicos != null && template.servicos!.isNotEmpty) {
      final junctionData = template.servicos!.map((item) => {
        'pacote_id': template.id,
        'servico_id': item.servicoId,
        'quantidade_sessoes': item.quantidadeSessoes,
      }).toList();
      
      await _supabase.from('pacote_servicos').insert(junctionData);
    }
  }

  @override
  Future<void> deleteTemplate(String id) async {
    // Verifica se existem contratos vinculados ao pacote
    final response = await _supabase
        .from('pacotes_contratados')
        .select('id')
        .eq('pacote_id', id);
    
    final hasContracts = (response as List).isNotEmpty;

    if (hasContracts) {
      // Se houver contratos, apenas desativa o pacote para manter a integridade dos dados históricos
      await _supabase
          .from('pacotes_templates')
          .update({'ativo': false})
          .eq('id', id);
    } else {
      // Se não houver contratos, exclui permanentemente
      // Primeiro removemos os vínculos na tabela intermediária (se houver)
      await _supabase.from('pacote_servicos').delete().eq('pacote_id', id);
      // Depois removemos o template
      await _supabase.from('pacotes_templates').delete().eq('id', id);
    }
  }

  @override
  Future<List<PacoteContratadoModel>> getContratados({String? clienteId}) async {
    var query = _supabase
        .from('pacotes_contratados')
        .select('*, pacotes_templates!template_id(*, pacote_servicos(servico_id, quantidade_sessoes, servicos(nome))), perfis!cliente_id(*), profissional:perfis!profissional_id(*)'); // Include template, services, client & professional info
        
    if (clienteId != null) {
      query = query.eq('cliente_id', clienteId);
    }

    final response = await query.order('criado_em', ascending: false);
    return (response as List).map((e) => PacoteContratadoModel.fromJson(e)).toList();
  }

  Future<List<PacoteTemplateModel>> getTemplatesByProfessional(String profId) async {
    final linksResponse = await _supabase
        .from('profissional_pacotes')
        .select('pacote_id')
        .eq('profissional_id', profId);
    
    final List<String> linkedIds = (linksResponse as List)
        .map((e) => e['pacote_id'].toString())
        .toList();

    if (linkedIds.isEmpty) return [];

    final response = await _supabase
        .from('pacotes_templates')
        .select('*, admin_perfil:admin_promocao_id(nome_completo), pacote_servicos(servico_id, quantidade_sessoes, servicos(nome))')
        .eq('ativo', true)
        .inFilter('id', linkedIds)
        .order('titulo', ascending: true);

    return (response as List).map((e) => PacoteTemplateModel.fromJson(e)).toList();
  }

  @override
  Future<PacoteContratadoModel> getContratadoById(String id) async {
    final response = await _supabase
        .from('pacotes_contratados')
        .select('*, pacotes_templates!template_id(*, pacote_servicos(servico_id, quantidade_sessoes, servicos(nome))), perfis!cliente_id(*), profissional:perfis!profissional_id(*)')
        .eq('id', id)
        .single();
    return PacoteContratadoModel.fromJson(response);
  }

  @override
  Future<PacoteContratadoModel> createContratado(PacoteContratadoModel pacote) async {
    final data = pacote.toJson();
    data.remove('id'); // let Supabase handle UUID

    final response = await _supabase
        .from('pacotes_contratados')
        .insert(data)
        .select('*, pacotes_templates!template_id(*, pacote_servicos(servico_id, quantidade_sessoes, servicos(nome))), perfis!cliente_id(*), profissional:perfis!profissional_id(*)')
        .single();
        
    return PacoteContratadoModel.fromJson(response);
  }

  @override
  Future<void> updateContratoStatus(String id, String status) async {
     await _supabase
        .from('pacotes_contratados')
        .update({'status': status})
        .eq('id', id);
  }

  @override
  Future<void> cancelContract(String id) async {
    // 1. Cancel the contract
    await _supabase
        .from('pacotes_contratados')
        .update({'status': 'cancelado'})
        .eq('id', id);

    // 2. Cancel all future/reserved appointments associated with this contract
    await _supabase
        .from('agendamentos')
        .update({'status': 'cancelado'})
        .eq('pacote_contratado_id', id)
        .inFilter('status', ['reservado', 'pendente']);
  }
}

