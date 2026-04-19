class ProfessionalModel {
  final String id;
  final String nome;
  final String? email;
  final String? avatarUrl;
  final String tipo;
  final String? cargo;
  final String? telefone;
  final double comissaoProdutosPercentual;
  final double comissaoAgendamentosPercentual;

  ProfessionalModel({
    required this.id,
    required this.nome,
    this.email,
    this.avatarUrl,
    required this.tipo,
    this.cargo,
    this.telefone,
    required this.comissaoProdutosPercentual,
    required this.comissaoAgendamentosPercentual,
  });

  factory ProfessionalModel.fromMap(Map<String, dynamic> map) {
    return ProfessionalModel(
      id: map['id'] as String,
      nome: map['nome_completo'] as String,
      email: map['email'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      tipo: map['tipo'] as String,
      cargo: map['cargo'] as String?,
      telefone: map['telefone'] as String?,
      comissaoProdutosPercentual: (map['comissao_produtos_percentual'] ?? 0).toDouble(),
      comissaoAgendamentosPercentual: (map['comissao_agendamentos_percentual'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome_completo': nome,
      'email': email,
      'avatar_url': avatarUrl,
      'tipo': tipo,
      'cargo': cargo,
      'telefone': telefone,
      'comissao_produtos_percentual': comissaoProdutosPercentual,
      'comissao_agendamentos_percentual': comissaoAgendamentosPercentual,
    };
  }
}

