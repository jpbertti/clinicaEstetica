
class EvaluationModel {
  final String? id;
  final String agendamentoId;
  final String clienteId;
  final String profissionalId;
  final int nota;
  final String? comentario;
  final List<String> tags;
  final List<String> fotos;
  final DateTime? criadoEm;
  final String? serviceName;
  final String? professionalName;
  final DateTime? appointmentDate;

  EvaluationModel({
    this.id,
    required this.agendamentoId,
    required this.clienteId,
    required this.profissionalId,
    required this.nota,
    this.comentario,
    this.tags = const [],
    this.fotos = const [],
    this.criadoEm,
    this.serviceName,
    this.professionalName,
    this.appointmentDate,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'agendamento_id': agendamentoId,
      'cliente_id': clienteId,
      'profissional_id': profissionalId,
      'nota': nota,
      'comentario': comentario,
      'tags': tags,
      'fotos': fotos,
      if (criadoEm != null) 'criado_em': criadoEm!.toIso8601String(),
    };
  }

  factory EvaluationModel.fromMap(Map<String, dynamic> map) {
    return EvaluationModel(
      id: map['id'],
      agendamentoId: map['agendamento_id'],
      clienteId: map['cliente_id'],
      profissionalId: map['profissional_id'],
      nota: map['nota'],
      comentario: map['comentario'],
      tags: map['tags'] != null 
          ? List<String>.from(map['tags'])
          : [],
      fotos: map['fotos'] != null 
          ? List<String>.from(map['fotos'])
          : [],
      criadoEm: map['criado_em'] != null 
          ? DateTime.parse(map['criado_em'])
          : null,
      serviceName: map['agendamentos']?['servicos']?['nome'],
      professionalName: map['profissional']?['nome_completo'],
      appointmentDate: map['agendamentos']?['data_hora'] != null
          ? DateTime.parse(map['agendamentos']['data_hora'])
          : null,
    );
  }
}

