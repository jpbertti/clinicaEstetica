class ProfileModel {
  final String id;
  final String nomeCompleto;
  final String email;
  final String? telefone;
  final String tipo; // 'cliente', 'profissional', 'admin'
  final String? avatarUrl;
  final DateTime criadoEm;

  ProfileModel({
    required this.id,
    required this.nomeCompleto,
    required this.email,
    this.telefone,
    required this.tipo,
    this.avatarUrl,
    required this.criadoEm,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'],
      nomeCompleto: json['nome_completo'],
      email: json['email'],
      telefone: json['telefone'],
      tipo: json['tipo'],
      avatarUrl: json['avatar_url'],
      criadoEm: DateTime.parse(json['criado_em']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome_completo': nomeCompleto,
      'email': email,
      'telefone': telefone,
      'tipo': tipo,
      'avatar_url': avatarUrl,
      'criado_em': criadoEm.toIso8601String(),
    };
  }
}

