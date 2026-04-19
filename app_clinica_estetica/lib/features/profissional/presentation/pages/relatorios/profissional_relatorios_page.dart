import 'package:flutter/material.dart';

class ProfissionalRelatoriosPage extends StatelessWidget {
  const ProfissionalRelatoriosPage({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF2F5E46);
    const accent = Color(0xFFC7A36B);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DESEMPENHO',
            style: TextStyle(fontSize: 12,
              fontWeight: FontWeight.bold,
              color: accent,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Seus Indicadores',
            style: TextStyle(fontFamily: 'Playfair Display', 
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: primaryGreen,
            ),
          ),
          const SizedBox(height: 24),
          _buildStatCard(
            title: 'Atendimentos este mês',
            value: '0',
            icon: Icons.calendar_today,
          ),
          const SizedBox(height: 16),
          _buildStatCard(
            title: 'Comissões estimadas',
            value: 'R\$ 0,00',
            icon: Icons.payments_outlined,
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Icon(Icons.analytics_outlined, size: 64, color: primaryGreen.withOpacity(0.1)),
                const SizedBox(height: 16),
                Text(
                  'Os dados de desempenho estarão disponíveis em breve.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black38,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({required String title, required String value, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2F5E46).withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: const Color(0xFF2F5E46)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(fontFamily: 'Playfair Display', 
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2F5E46),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

