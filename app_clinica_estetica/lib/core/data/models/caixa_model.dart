class CaixaModel {
  final String id;
  final String usuarioId;
  final DateTime abertoEm;
  final DateTime? fechadoEm;
  final double saldoInicial;
  final double totalEntradas;
  final double totalSaidas;
  final double? saldoFinalReal;
  final String status; // 'aberto', 'fechado'
  final String? observacoes;

  CaixaModel({
    required this.id,
    required this.usuarioId,
    required this.abertoEm,
    this.fechadoEm,
    required this.saldoInicial,
    this.totalEntradas = 0,
    this.totalSaidas = 0,
    this.saldoFinalReal,
    required this.status,
    this.observacoes,
  });

  factory CaixaModel.fromMap(Map<String, dynamic> map) {
    return CaixaModel(
      id: map['id'],
      usuarioId: map['usuario_id'],
      abertoEm: DateTime.parse(map['aberto_em']),
      fechadoEm: map['fechado_em'] != null ? DateTime.parse(map['fechado_em']) : null,
      saldoInicial: (map['saldo_inicial'] as num).toDouble(),
      totalEntradas: (map['total_entradas'] as num).toDouble(),
      totalSaidas: (map['total_saidas'] as num).toDouble(),
      saldoFinalReal: map['saldo_final_real'] != null ? (map['saldo_final_real'] as num).toDouble() : null,
      status: map['status'],
      observacoes: map['observacoes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'usuario_id': usuarioId,
      'aberto_em': abertoEm.toIso8601String(),
      'fechado_em': fechadoEm?.toIso8601String(),
      'saldo_inicial': saldoInicial,
      'total_entradas': totalEntradas,
      'total_saidas': totalSaidas,
      'saldo_final_real': saldoFinalReal,
      'status': status,
      'observacoes': observacoes,
    };
  }
}

