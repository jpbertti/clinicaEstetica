import 'package:app_clinica_estetica/core/data/models/evaluation_model.dart';

class AppointmentModel {
  final String id;
  final String clienteId;
  final String profissionalId;
  final String servicoId;
  final DateTime dataHora;
  final String status; // 'pendente', 'confirmado', 'cancelado', 'concluido'
  final String? observacoes;
  final DateTime criadoEm;

  // Campos estendidos para exibição
  final String? serviceName;
  final String? professionalName;
  final String? serviceImageUrl;
  final String? professionalAvatarUrl;
  final String? professionalCargo;
  final double? valorTotal;
  final int? serviceDuration;
  final EvaluationModel? evaluation;
  
  // Campos de Pacote
  final String? pacoteContratadoId;
  final String? pacoteNome;
  final int? sessaoNumero;

  AppointmentModel({
    required this.id,
    required this.clienteId,
    required this.profissionalId,
    required this.servicoId,
    required this.dataHora,
    required this.status,
    this.observacoes,
    required this.criadoEm,
    this.serviceName,
    this.professionalName,
    this.serviceImageUrl,
    this.professionalAvatarUrl,
    this.professionalCargo,
    this.valorTotal,
    this.serviceDuration,
    this.evaluation,
    this.pacoteContratadoId,
    this.pacoteNome,
    this.sessaoNumero,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: json['id'],
      clienteId: json['cliente_id'],
      profissionalId: json['profissional_id'],
      servicoId: json['servico_id'],
      dataHora: DateTime.parse(json['data_hora']).toLocal(),
      status: json['status'],
      observacoes: json['observacoes'],
      criadoEm: DateTime.parse(json['criado_em']).toLocal(),
      serviceName: json['servicos']?['nome'],
      professionalName: json['profissional']?['nome_completo'],
      serviceImageUrl: json['servicos']?['imagem_url'],
      professionalAvatarUrl: json['profissional']?['avatar_url'],
      professionalCargo: json['profissional']?['cargo'],
      valorTotal: json['valor_total'] != null
          ? (json['valor_total'] as num).toDouble()
          : null,
      serviceDuration: json['servicos']?['duracao_minutos'] != null
          ? (json['servicos']?['duracao_minutos'] as num).toInt()
          : null,
      evaluation: _parseEvaluation(json['evaluation']),
      pacoteContratadoId: json['pacote_contratado_id'],
      pacoteNome: json['pacotes_contratados']?['pacotes_templates']?['titulo'],
      sessaoNumero: json['sessao_numero'] != null ? (json['sessao_numero'] as num).toInt() : null,
    );
  }

static EvaluationModel? _parseEvaluation(dynamic evaluationJson) {
  if (evaluationJson == null) return null;
  
  if (evaluationJson is List && evaluationJson.isNotEmpty) {
    return EvaluationModel.fromMap(evaluationJson[0]);
  } else if (evaluationJson is Map<String, dynamic>) {
    return EvaluationModel.fromMap(evaluationJson);
  }
  
  return null;
}

Map<String, dynamic> toJson() {
  return {
    'id': id,
    'cliente_id': clienteId,
    'profissional_id': profissionalId,
    'servico_id': servicoId,
    'data_hora': dataHora.toIso8601String(),
    'status': status,
    'observacoes': observacoes,
    'criado_em': criadoEm.toIso8601String(),
    'valor_total': valorTotal,
    'pacote_contratado_id': pacoteContratadoId,
    'sessao_numero': sessaoNumero,
  };
}
}

