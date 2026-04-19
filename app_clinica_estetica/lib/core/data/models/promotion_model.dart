import 'package:app_clinica_estetica/core/data/models/service_model.dart';
import 'package:app_clinica_estetica/core/data/models/pacote_template_model.dart';

class PromotionModel {
  final String id;
  final String titulo;
  final String subtitulo;
  final String imagemUrl;
  final String? servicoId;
  final String? pacoteId;
  final int ordem;
  final bool ativo;
  final ServiceModel? servico;
  final PacoteTemplateModel? pacote;

  PromotionModel({
    required this.id,
    required this.titulo,
    required this.subtitulo,
    required this.imagemUrl,
    this.servicoId,
    this.pacoteId,
    this.ordem = 0,
    this.ativo = true,
    this.servico,
    this.pacote,
  });

  factory PromotionModel.fromMap(Map<String, dynamic> map) {
    return PromotionModel(
      id: map['id'] as String,
      titulo: map['titulo'] as String,
      subtitulo: map['subtitulo'] as String,
      imagemUrl: map['imagem_url'] as String,
      servicoId: map['servico_id'] as String?,
      pacoteId: map['pacote_id'] as String?,
      ordem: (map['ordem'] as num?)?.toInt() ?? 0,
      ativo: map['ativo'] as bool? ?? true,
      servico: map['servicos'] != null 
          ? ServiceModel.fromJson(map['servicos'] as Map<String, dynamic>)
          : null,
      pacote: map['pacotes_templates'] != null
          ? PacoteTemplateModel.fromJson(map['pacotes_templates'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'subtitulo': subtitulo,
      'imagem_url': imagemUrl,
      'servico_id': servicoId,
      'pacote_id': pacoteId,
      'ordem': ordem,
      'ativo': ativo,
    };
  }

  PromotionModel copyWith({
    String? titulo,
    String? subtitulo,
    String? imagemUrl,
    String? servicoId,
    String? pacoteId,
    int? ordem,
    bool? ativo,
    bool clearServico = false,
    bool clearPacote = false,
  }) {
    return PromotionModel(
      id: id,
      titulo: titulo ?? this.titulo,
      subtitulo: subtitulo ?? this.subtitulo,
      imagemUrl: imagemUrl ?? this.imagemUrl,
      servicoId: clearServico ? null : (servicoId ?? this.servicoId),
      pacoteId: clearPacote ? null : (pacoteId ?? this.pacoteId),
      ordem: ordem ?? this.ordem,
      ativo: ativo ?? this.ativo,
      servico: clearServico ? null : (servicoId == null ? servico : null),
      pacote: clearPacote ? null : (pacoteId == null ? pacote : null),
    );
  }
}

