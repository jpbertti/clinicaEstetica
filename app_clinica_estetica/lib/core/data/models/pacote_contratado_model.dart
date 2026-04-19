import 'pacote_template_model.dart';
import 'profile_model.dart';

class PacoteContratadoModel {
  final String id;
  final String templateId;
  final String clienteId;
  final double valorPago;
  final int sessoesTotais;
  final int sessoesRealizadas;
  final String status;
  final String? profissionalId;
  final String? caixaId;
  final DateTime criadoEm;
  final double? comissaoPercentual;
  final PacoteTemplateModel? template; // Optional nested object
  final ProfileModel? cliente; // Optional nested object
  final ProfileModel? profissional; // Optional nested object

  PacoteContratadoModel({
    required this.id,
    required this.templateId,
    required this.clienteId,
    this.profissionalId,
    required this.valorPago,
    required this.sessoesTotais,
    required this.sessoesRealizadas,
    required this.status,
    this.caixaId,
    required this.criadoEm,
    this.comissaoPercentual,
    this.template,
    this.cliente,
    this.profissional,
  });

  factory PacoteContratadoModel.fromJson(Map<String, dynamic> json) {
    return PacoteContratadoModel(
      id: json['id'] as String,
      templateId: json['template_id'] as String,
      clienteId: json['cliente_id'] as String,
      valorPago: (json['valor_pago'] as num).toDouble(),
      sessoesTotais: (json['sessoes_totais'] as num).toInt(),
      sessoesRealizadas: (json['sessoes_realizadas'] as num).toInt(),
      status: json['status'] as String,
      caixaId: json['caixa_id'] as String?,
      profissionalId: json['profissional_id'] as String?,
      comissaoPercentual: json['comissao_percentual'] != null ? (json['comissao_percentual'] as num).toDouble() : null,
      criadoEm: DateTime.parse(json['criado_em'] as String).toLocal(),
      template: json['pacotes_templates'] != null ? PacoteTemplateModel.fromJson(json['pacotes_templates']) : null,
      cliente: json['perfis'] != null ? ProfileModel.fromJson(json['perfis']) : null,
      profissional: json['profissional'] != null ? ProfileModel.fromJson(json['profissional']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'template_id': templateId,
      'cliente_id': clienteId,
      'valor_pago': valorPago,
      'sessoes_totais': sessoesTotais,
      'sessoes_realizadas': sessoesRealizadas,
      'status': status,
      'caixa_id': caixaId,
      'profissional_id': profissionalId,
      'comissao_percentual': comissaoPercentual,
      // 'criado_em' is generally handled by the database
    };
  }
}

