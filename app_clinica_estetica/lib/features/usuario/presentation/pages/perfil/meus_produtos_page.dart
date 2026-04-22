import 'package:app_clinica_estetica/core/data/repositories/supabase_product_repository.dart';
import 'package:app_clinica_estetica/features/auth/data/auth_service.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class MeusProdutosPage extends StatefulWidget {
  const MeusProdutosPage({super.key});

  @override
  State<MeusProdutosPage> createState() => _MeusProdutosPageState();
}

class _MeusProdutosPageState extends State<MeusProdutosPage> {
  final _repository = SupabaseProductRepository();
  bool _isLoading = true;
  List<Map<String, dynamic>> _purchases = [];

  @override
  void initState() {
    super.initState();
    _loadPurchases();
  }

  Future<void> _loadPurchases() async {
    setState(() => _isLoading = true);
    try {
      final userId = AuthService.currentUserId;
      if (userId != null) {
        final data = await _repository.getProductPurchasesByClient(userId);
        setState(() {
          _purchases = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar produtos: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Produtos Comprados',
          style: GoogleFonts.playfairDisplay(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _purchases.isEmpty
              ? _buildEmptyState()
              : _buildList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 80, color: AppColors.primary.withOpacity(0.1)),
          const SizedBox(height: 24),
          Text(
            'Nenhuma compra encontrada',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Seus produtos aparecerão aqui após a compra.',
            style: GoogleFonts.manrope(
              color: AppColors.primary.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _purchases.length,
      itemBuilder: (context, index) {
        final purchase = _purchases[index];
        final product = purchase['produtos'] ?? {};
        final date = DateTime.parse(purchase['criado_em']).toLocal();
        
        return InkWell(
          onTap: () => _showPurchaseDetails(purchase),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['nome'] ?? 'Produto',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Quantidade: ${purchase['quantidade']}',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            if (purchase['profissional'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Vendedor: ${purchase['profissional']['nome_completo']}',
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                            if (purchase['forma_pagamento'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Pagamento: ${purchase['forma_pagamento'].toString().replaceAll('_', ' ').toUpperCase()}',
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        NumberFormat.simpleCurrency(locale: 'pt_BR').format(purchase['valor_total'] ?? 0),
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade400),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(date),
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'PAGO',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPurchaseDetails(Map<String, dynamic> purchase) {
    final product = purchase['produtos'] ?? {};
    final date = DateTime.parse(purchase['criado_em']).toLocal();
    final status = purchase['status_pagamento'] ?? 'pago';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cabeçalho elegante
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.04),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shopping_bag_rounded,
                      color: AppColors.accent,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Detalhes da Compra',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ID da Transação: #${purchase['id'].toString().substring(0, 8).toUpperCase()}',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Conteúdo
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildDetailRow(
                    label: 'Produto',
                    value: product['nome'] ?? 'Indefinido',
                    icon: Icons.inventory_2_outlined,
                  ),
                  const Divider(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailRow(
                          label: 'Quantidade',
                          value: '${purchase['quantidade']} un',
                          icon: Icons.tag,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDetailRow(
                          label: 'Valor Total',
                          value: NumberFormat.simpleCurrency(locale: 'pt_BR').format(purchase['valor_total'] ?? 0),
                          icon: Icons.payments_outlined,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  _buildDetailRow(
                    label: 'Vendedor',
                    value: purchase['profissional']?['nome_completo'] ?? 'Não informado',
                    icon: Icons.badge_outlined,
                  ),
                  const Divider(height: 32),
                  _buildDetailRow(
                    label: 'Forma de Pagamento',
                    value: (purchase['forma_pagamento'] ?? 'Não informada').toString().replaceAll('_', ' ').toUpperCase(),
                    icon: Icons.credit_card_outlined,
                  ),
                  const Divider(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailRow(
                          label: 'Data',
                          value: DateFormat('dd/MM/yyyy').format(date),
                          icon: Icons.calendar_today_outlined,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDetailRow(
                          label: 'Hora',
                          value: DateFormat('HH:mm').format(date),
                          icon: Icons.schedule_outlined,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Footer / Status
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Fechar',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
