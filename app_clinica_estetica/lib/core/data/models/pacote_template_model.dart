class PacoteServicoItem {
  final String servicoId;
  final String? nomeServico;
  final int quantidadeSessoes;

  PacoteServicoItem({
    required this.servicoId,
    this.nomeServico,
    required this.quantidadeSessoes,
  });

  factory PacoteServicoItem.fromJson(Map<String, dynamic> json) {
    String? servicoNome;
    if (json['servicos'] != null) {
      servicoNome = json['servicos']['nome'] as String?;
    }

    return PacoteServicoItem(
      servicoId: json['servico_id'] as String,
      nomeServico: servicoNome,
      quantidadeSessoes: (json['quantidade_sessoes'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'servico_id': servicoId,
      'quantidade_sessoes': quantidadeSessoes,
    };
  }
}

class PacoteTemplateModel {
  final String id;
  final String titulo;
  final String? descricao;
  final double valorTotal;
  final int quantidadeSessoes; // Total sessions (sum of service sessions or aggregate)
  final String? imagemUrl;
  final String? categoriaId;
  final String? categoriaNome;
  final List<PacoteServicoItem>? servicos;
  final bool ativo;
  final double? comissaoPercentual;
  final double? valorPromocional;
  final DateTime? dataInicioPromocao;
  final DateTime? dataFimPromocao;
  final String? adminPromocaoId;
  final String? adminPromocaoNome;

  String get formattedPrice => 'R\$ ${valorTotal.toStringAsFixed(2).replaceAll('.', ',')}';
  String get formattedPromotionalPrice => 
      valorPromocional != null ? 'R\$ ${valorPromocional!.toStringAsFixed(2).replaceAll('.', ',')}' : '';
  
  bool get isPromocao {
    if (valorPromocional == null || valorPromocional! >= valorTotal) return false;
    
    final now = DateTime.now();
    
    if (dataInicioPromocao != null && now.isBefore(dataInicioPromocao!)) return false;
    
    if (dataFimPromocao != null) {
      final endOfDay = DateTime(
        dataFimPromocao!.year,
        dataFimPromocao!.month,
        dataFimPromocao!.day,
        23, 59, 59
      );
      if (now.isAfter(endOfDay)) return false;
    }
    
    return true;
  }

  PacoteTemplateModel({
    required this.id,
    required this.titulo,
    this.descricao,
    required this.valorTotal,
    required this.quantidadeSessoes,
    this.imagemUrl,
    this.categoriaId,
    this.categoriaNome,
    this.servicos,
    this.ativo = true,
    this.comissaoPercentual,
    this.valorPromocional,
    this.dataInicioPromocao,
    this.dataFimPromocao,
    this.adminPromocaoId,
    this.adminPromocaoNome,
  });

  factory PacoteTemplateModel.fromJson(Map<String, dynamic> json) {
    String? catNome;
    if (json['categorias'] != null && json['categorias'] is Map) {
      catNome = json['categorias']['nome'];
    }

    String? admNome;
    if (json['admin_perfil'] != null && json['admin_perfil'] is Map) {
      admNome = json['admin_perfil']['nome_completo'];
    }

    return PacoteTemplateModel(
      id: json['id'] as String,
      titulo: json['titulo'] as String,
      descricao: json['descricao'] as String?,
      valorTotal: (json['valor_total'] as num).toDouble(),
      quantidadeSessoes: (json['quantidade_sessoes'] as num).toInt(),
      imagemUrl: json['imagem_url'] as String?,
      categoriaId: json['categoria_id'] as String?,
      categoriaNome: catNome,
      servicos: (json['pacote_servicos'] as List?)
          ?.map((e) => PacoteServicoItem.fromJson(e))
          .toList(),
      ativo: json['ativo'] as bool? ?? true,
      comissaoPercentual: (json['comissao_percentual'] as num?)?.toDouble(),
      valorPromocional: json['valor_promocional'] != null ? (json['valor_promocional'] as num).toDouble() : null,
      dataInicioPromocao: json['data_inicio_promocao'] != null ? DateTime.parse(json['data_inicio_promocao']).toLocal() : null,
      dataFimPromocao: json['data_fim_promocao'] != null ? DateTime.parse(json['data_fim_promocao']).toLocal() : null,
      adminPromocaoId: json['admin_promocao_id'] as String?,
      adminPromocaoNome: admNome,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'titulo': titulo,
      'descricao': descricao,
      'valor_total': valorTotal,
      'quantidade_sessoes': quantidadeSessoes,
      'imagem_url': imagemUrl,
      'categoria_id': categoriaId,
      'ativo': ativo,
      'comissao_percentual': comissaoPercentual,
      'valor_promocional': valorPromocional,
      'data_inicio_promocao': dataInicioPromocao?.toIso8601String(),
      'data_fim_promocao': dataFimPromocao?.toIso8601String(),
      'admin_promocao_id': adminPromocaoId,
    };
  }

  PacoteTemplateModel copyWith({
    String? id,
    String? titulo,
    String? descricao,
    double? valorTotal,
    int? quantidadeSessoes,
    String? imagemUrl,
    String? categoriaId,
    List<PacoteServicoItem>? servicos,
    bool? ativo,
    double? comissaoPercentual,
    double? valorPromocional,
  }) {
    return PacoteTemplateModel(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      descricao: descricao ?? this.descricao,
      valorTotal: valorTotal ?? this.valorTotal,
      quantidadeSessoes: quantidadeSessoes ?? this.quantidadeSessoes,
      imagemUrl: imagemUrl ?? this.imagemUrl,
      categoriaId: categoriaId ?? this.categoriaId,
      categoriaNome: categoriaNome ?? categoriaNome,
      servicos: servicos ?? this.servicos,
      ativo: ativo ?? this.ativo,
      comissaoPercentual: comissaoPercentual ?? this.comissaoPercentual,
      valorPromocional: valorPromocional ?? this.valorPromocional,
      dataInicioPromocao: dataInicioPromocao ?? dataInicioPromocao,
      dataFimPromocao: dataFimPromocao ?? dataFimPromocao,
      adminPromocaoId: adminPromocaoId ?? adminPromocaoId,
      adminPromocaoNome: adminPromocaoNome ?? adminPromocaoNome,
    );
  }
}

