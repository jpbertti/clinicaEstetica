
class ProductModel {
  final String id;
  final String nome;
  final String? descricao;
  final double precoVenda;
  final double? precoCusto;
  final double comissaoPercentual;
  final int estoqueAtual;
  final int estoqueMinimo;
  final String? imagemUrl;
  final bool ativo;
  final DateTime? criadoEm;
  final DateTime? dataVencimento;

  final String? categoria;

  ProductModel({
    required this.id,
    required this.nome,
    this.descricao,
    required this.precoVenda,
    this.precoCusto,
    this.comissaoPercentual = 0,
    this.estoqueAtual = 0,
    this.estoqueMinimo = 5,
    this.imagemUrl,
    this.ativo = true,
    this.criadoEm,
    this.dataVencimento,
    this.categoria,
  });

  bool get isLowStock => estoqueAtual <= estoqueMinimo;

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'],
      nome: map['nome'],
      descricao: map['descricao'],
      precoVenda: (map['preco_venda'] ?? 0.0).toDouble(),
      precoCusto: map['preco_custo'] != null ? (map['preco_custo'] as num).toDouble() : null,
      comissaoPercentual: (map['comissao_percentual'] ?? 0.0).toDouble(),
      estoqueAtual: map['estoque_atual'] ?? 0,
      estoqueMinimo: map['estoque_minimo'] ?? 5,
      imagemUrl: map['imagem_url'],
      ativo: map['ativo'] ?? true,
      criadoEm: map['criado_em'] != null ? DateTime.parse(map['criado_em']) : null,
      dataVencimento: map['data_vencimento'] != null ? DateTime.parse(map['data_vencimento']) : null,
      categoria: map['categoria'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'descricao': descricao,
      'preco_venda': precoVenda,
      'preco_custo': precoCusto,
      'comissao_percentual': comissaoPercentual,
      'estoque_atual': estoqueAtual,
      'estoque_minimo': estoqueMinimo,
      'data_vencimento': dataVencimento?.toIso8601String().split('T')[0],
      'imagem_url': imagemUrl,
      'ativo': ativo,
      'categoria': categoria,
    };
  }
}

class ProductSaleModel {
  final String? id;
  final String produtoId;
  final int quantidade;
  final double valorUnitario;
  final double valorTotal;
  final String? caixaId;
  final String? clienteId;
  final String? profissionalId;
  final String? formaPagamento;
  final DateTime? criadoEm;

  ProductSaleModel({
    this.id,
    required this.produtoId,
    required this.quantidade,
    required this.valorUnitario,
    required this.valorTotal,
    this.caixaId,
    this.clienteId,
    this.profissionalId,
    this.formaPagamento,
    this.criadoEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'produto_id': produtoId,
      'quantidade': quantidade,
      'valor_unitario': valorUnitario,
      'valor_total': valorTotal,
      'caixa_id': caixaId,
      'cliente_id': clienteId,
      'profissional_id': profissionalId,
      'forma_pagamento': formaPagamento,
    };
  }
}

