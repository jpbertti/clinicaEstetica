class ServiceModel {
  final String id;
  final String nome;
  final String descricao;
  final double preco;
  final int duracaoMinutos;
  final String categoriaId;
  final String? categoriaNome;
  final String? imagemUrl;
  final bool ativo;
  final double? precoPromocional;
  final DateTime? dataInicioPromocao;
  final DateTime? dataFimPromocao;
  final String? adminPromocaoId;
  final String? adminPromocaoNome;

  String get formattedPrice => 'R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}';
  String get formattedPromotionalPrice => 
      precoPromocional != null ? 'R\$ ${precoPromocional!.toStringAsFixed(2).replaceAll('.', ',')}' : '';
  
  bool get isPromocao {
    if (precoPromocional == null || precoPromocional! >= preco) return false;
    
    final now = DateTime.now();
    
    // Se houver data de início e ainda não chegou, não é promoção
    if (dataInicioPromocao != null && now.isBefore(dataInicioPromocao!)) return false;
    
    // Se houver data de fim e já passou do dia, não é promoção
    // Usamos um ajuste para que a promoção valha até o final do dia configurado
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

  ServiceModel({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.preco,
    required this.duracaoMinutos,
    required this.categoriaId,
    this.categoriaNome,
    this.imagemUrl,
    this.ativo = true,
    this.precoPromocional,
    this.dataInicioPromocao,
    this.dataFimPromocao,
    this.adminPromocaoId,
    this.adminPromocaoNome,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    // Busca o nome da categoria se houver join, ou usa o campo categoria antigo se ainda existir
    String? catNome;
    if (json['categorias'] != null && json['categorias'] is Map) {
      catNome = json['categorias']['nome'];
    }

    // Busca o nome do admin que criou a promoção
    String? admNome;
    if (json['admin_perfil'] != null && json['admin_perfil'] is Map) {
      admNome = json['admin_perfil']['nome_completo'];
    }

    return ServiceModel(
      id: json['id'] as String,
      nome: json['nome'] as String,
      descricao: json['descricao'] as String,
      preco: (json['preco'] as num).toDouble(),
      duracaoMinutos: (json['duracao_minutos'] as num).toInt(),
      categoriaId: (json['categoria_id'] ?? json['categoria']) as String,
      categoriaNome: catNome,
      imagemUrl: json['imagem_url'] as String?,
      ativo: json['ativo'] as bool? ?? true,
      precoPromocional: json['preco_promocional'] != null ? (json['preco_promocional'] as num).toDouble() : null,
      dataInicioPromocao: json['data_inicio_promocao'] != null ? DateTime.parse(json['data_inicio_promocao']).toLocal() : null,
      dataFimPromocao: json['data_fim_promocao'] != null ? DateTime.parse(json['data_fim_promocao']).toLocal() : null,
      adminPromocaoId: json['admin_promocao_id'] as String?,
      adminPromocaoNome: admNome,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'descricao': descricao,
      'preco': preco,
      'duracao_minutos': duracaoMinutos,
      'categoria_id': categoriaId,
      'imagem_url': imagemUrl,
      'ativo': ativo,
      'preco_promocional': precoPromocional,
      'data_inicio_promocao': dataInicioPromocao?.toIso8601String(),
      'data_fim_promocao': dataFimPromocao?.toIso8601String(),
      'admin_promocao_id': adminPromocaoId,
    };
  }
}


