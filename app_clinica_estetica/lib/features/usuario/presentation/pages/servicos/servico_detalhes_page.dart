import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_clinica_estetica/core/data/models/service_model.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class ServicoDetalhesPage extends StatelessWidget {
  final ServiceModel service;

  const ServicoDetalhesPage({super.key, required this.service});

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
            // Header customizado (เหมือน na tela de confirmação)
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
                    'Detalhes do Serviço',
                    style: TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 18,
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
                          // Imagem do Serviço
                          Hero(
                            tag: 'service_image_${service.id}',
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(30),
                              ),
                              child: service.imagemUrl != null &&
                                      service.imagemUrl!.isNotEmpty
                                  ? Image.network(
                                      service.imagemUrl!,
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
                                // Categoria e Badge de Oferta
                                Row(
                                  children: [
                                    if (service.categoriaNome != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: accentColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          service.categoriaNome!.toUpperCase(),
                                          style: TextStyle(fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: accentColor,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ),
                                    if (service.isPromocao) ...[
                                      if (service.categoriaNome != null) 
                                        const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          'OFERTA',
                                          style: TextStyle(fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Título
                                Text(
                                  service.nome,
                                  style: TextStyle(fontFamily: 'Playfair Display', 
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Detail rows (igual confirmação)
                                _buildDetailCard(
                                  icon: Icons.payments_outlined,
                                  label: 'INVESTIMENTO',
                                  value: service.isPromocao 
                                      ? service.formattedPromotionalPrice 
                                      : service.formattedPrice,
                                  subtitle: service.isPromocao 
                                      ? 'De ${service.formattedPrice}' 
                                      : null,
                                  primaryColor: primaryColor,
                                ),
                                if (service.isPromocao && service.dataInicioPromocao != null && service.dataFimPromocao != null) ...[
                                  const SizedBox(height: 12),
                                  _buildDetailCard(
                                    icon: Icons.calendar_month_outlined,
                                    label: 'PERÍODO PROMOCIONAL',
                                    value: '${DateFormat('dd/MM/yyyy').format(service.dataInicioPromocao!)} até ${DateFormat('dd/MM/yyyy').format(service.dataFimPromocao!)}',
                                    primaryColor: primaryColor,
                                  ),
                                ],
                                const SizedBox(height: 12),
                                _buildDetailCard(
                                  icon: Icons.schedule,
                                  label: 'DURAÇÃO ESTIMADA',
                                  value: '${service.duracaoMinutos} minutos',
                                  primaryColor: primaryColor,
                                ),

                                const SizedBox(height: 32),
                                const Divider(color: Color(0xFFF0F0F0)),
                                const SizedBox(height: 24),

                                // Descrição
                                Text(
                                  'Sobre o Procedimento',
                                  style: TextStyle(fontFamily: 'Playfair Display', 
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  service.descricao,
                                  style: TextStyle(fontSize: 15,
                                    height: 1.6,
                                    color:
                                        Colors.black87.withOpacity(0.7),
                                  ),
                                ),
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
            context.push(
              '/agendamento',
              extra: {'service': service},
            );
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
          child: Text(
            'Reservar Agora',
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
      child: Icon(Icons.spa, size: 80, color: primaryColor),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String label,
    required String value,
    required Color primaryColor,
    String? subtitle,
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
                  color: AppColors.accent,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12,
                    color: Colors.black26,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
