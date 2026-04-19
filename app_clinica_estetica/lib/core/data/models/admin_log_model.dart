class AdminLogModel {
  final String? id;
  final String adminId;
  final String? adminNome;
  final String acao;
  final String? detalhes;
  final String? tabelaAfetada;
  final String? itemId;
  final DateTime? criadoEm;

  AdminLogModel({
    this.id,
    required this.adminId,
    this.adminNome,
    required this.acao,
    this.detalhes,
    this.tabelaAfetada,
    this.itemId,
    this.criadoEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'admin_id': adminId,
      'admin_nome': adminNome,
      'acao': acao,
      'detalhes': detalhes,
      'tabela_afetada': tabelaAfetada,
      'item_id': itemId,
    };
  }

  factory AdminLogModel.fromMap(Map<String, dynamic> map) {
    return AdminLogModel(
      id: map['id'],
      adminId: map['admin_id'],
      adminNome: map['admin_nome'],
      acao: map['acao'],
      detalhes: map['detalhes'],
      tabelaAfetada: map['tabela_afetada'],
      itemId: map['item_id'],
      criadoEm: map['criado_em'] != null ? DateTime.parse(map['criado_em']) : null,
    );
  }
}

