import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_clinica_estetica/core/data/models/pacote_template_model.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';
import 'package:intl/intl.dart';

class PacoteDetalhesPage extends StatelessWidget {
  final PacoteTemplateModel pacote;

  const PacoteDetalhesPage({super.key, required this.pacote});

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppColors.primary;
    final accentColor = AppColors.accent;
    final backgroundColor = AppColors.background;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header customizado (igual confirmação)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(
                        Icons.chevron_left,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                  ),
                  Text(
                    'Detalhes do Pacote',
                    style: TextStyle(fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Main Card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Imagem do Pacote
                          Hero(
                            tag: 'pacote_image_${pacote.id}',
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(30),
                              ),
                              child: pacote.imagemUrl != null &&
                                      pacote.imagemUrl!.isNotEmpty
                                  ? Image.network(
                                      pacote.imagemUrl!,
                                      height: 250,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              _buildImagePlaceholder(
                                                  primaryColor),
                                    )
                                  : _buildImagePlaceholder(primaryColor),
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: (pacote.isPromocao ? Colors.red : accentColor).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    pacote.isPromocao ? 'OFERTA' : 'PACOTE EXCLUSIVO',
                                    style: TextStyle(fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: pacote.isPromocao ? Colors.red : accentColor,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Título
                                Text(
                                  pacote.titulo,
                                  style: TextStyle(fontFamily: 'Playfair Display', 
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Detail rows
                                _buildDetailCard(
                                  icon: Icons.payments_outlined,
                                  label: 'INVESTIMENTO TOTAL',
                                  value: pacote.isPromocao 
                                      ? pacote.formattedPromotionalPrice 
                                      : pacote.formattedPrice,
                                  subtitle: pacote.isPromocao 
                                      ? 'De ${pacote.formattedPrice}' 
                                      : null,
                                  primaryColor: primaryColor,
                                ),
                                if (pacote.isPromocao && pacote.dataInicioPromocao != null && pacote.dataFimPromocao != null) ...[
                                  const SizedBox(height: 12),
                                  _buildDetailCard(
                                    icon: Icons.calendar_month_outlined,
                                    label: 'PERÍODO PROMOCIONAL',
                                    value: '${DateFormat('dd/MM/yyyy').format(pacote.dataInicioPromocao!)} até ${DateFormat('dd/MM/yyyy').format(pacote.dataFimPromocao!)}',
                                    primaryColor: primaryColor,
                                  ),
                                ],
                                const SizedBox(height: 12),
                                _buildDetailCard(
                                  icon: Icons.repeat,
                                  label: 'SESSÕES TOTAIS',
                                  value: '${pacote.quantidadeSessoes} sessões',
                                  primaryColor: primaryColor,
                                ),

                                const SizedBox(height: 32),
                                const Divider(color: Color(0xFFF0F0F0)),
                                const SizedBox(height: 24),

                                // Descrição
                                Text(
                                  'Sobre este Pacote',
                                  style: TextStyle(fontFamily: 'Playfair Display', 
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  pacote.descricao ??
                                      'Aproveite este pacote exclusivo com condições especiais para você.',
                                  style: TextStyle(fontSize: 15,
                                    height: 1.6,
                                    color:
                                        Colors.black87.withOpacity(0.7),
                                  ),
                                ),

                                // Lista de Serviços
                                if (pacote.servicos != null &&
                                    pacote.servicos!.isNotEmpty) ...[
                                  const SizedBox(height: 32),
                                  Text(
                                    'O que está incluído:',
                                    style: TextStyle(fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ...pacote.servicos!.map(
                                      (s) => _buildServicoItem(s, primaryColor)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(color: AppColors.background),
        child: ElevatedButton(
          onPressed: () {
            context.push('/pacote-confirmacao', extra: pacote);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Escolher este pacote',
            style: TextStyle(fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(Color primaryColor) {
    return Container(
      height: 250,
      width: double.infinity,
      color: primaryColor.withOpacity(0.1),
      child: Icon(Icons.inventory_2_outlined, size: 80, color: primaryColor),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String label,
    required String value,
    String? subtitle,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primaryColor, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: Colors.black26,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: TextStyle(fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: subtitle != null ? AppColors.accent : Colors.black87,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 10,
                        decoration: TextDecoration.lineThrough,
                        color: Colors.black26,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServicoItem(PacoteServicoItem item, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF0F0F0)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: AppColors.accent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.nomeServico ?? "Sessão de Procedimento",
                    style: TextStyle(fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  Text(
                    '${item.quantidadeSessoes} sessões',
                    style: TextStyle(fontSize: 12,
                      color: Colors.black45,
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
}

