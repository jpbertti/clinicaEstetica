import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_clinica_estetica/core/data/repositories/dashboard_repository.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';

class AdminAtividadeDetalhesPage extends StatelessWidget {
  final DashboardAtividade atividade;

  const AdminAtividadeDetalhesPage({super.key, required this.atividade});

  @override
  Widget build(BuildContext context) {
    const primaryColor = AppColors.primary;
    const accentColor = AppColors.accent;
    const backgroundColor = AppColors.background;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, primaryColor),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMainCard(primaryColor, accentColor),
                    const SizedBox(height: 24),
                    if (atividade.metadata != null)
                      _buildMetadataSection(primaryColor, accentColor),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: primaryColor,
          ),
          Text(
            'Detalhes da Atividade',
            style: TextStyle(fontSize: 16,
              fontFamily: 'Playfair Display',
              fontWeight: FontWeight.bold,
              color: primaryColor,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 48), // Balancer
        ],
      ),
    );
  }

  Widget _buildMainCard(Color primaryColor, Color accentColor) {
    final dateFormat = DateFormat('dd/MM/yyyy \'às\' HH:mm');
    IconData icon;
    switch (atividade.tipo) {
      case 'agendamento':
        icon = Icons.calendar_today_rounded;
        break;
      case 'cliente':
        icon = Icons.person_rounded;
        break;
      case 'configuracao':
        icon = Icons.settings_rounded;
        break;
      case 'profissional':
        icon = Icons.work_rounded;
        break;
      default:
        icon = Icons.notifications_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: primaryColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      atividade.titulo,
                      style: TextStyle(fontFamily: 'Playfair Display', 
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    Text(
                      dateFormat.format(atividade.criadoEm),
                      style: const TextStyle(fontSize: 12,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 24),
          _buildInfoRow('Responsável', atividade.actorName ?? 'Sistema', primaryColor, accentColor),
          const SizedBox(height: 16),
          _buildInfoRow('Tipo', _getTipoLabel(atividade.tipo), primaryColor, accentColor),
          const SizedBox(height: 24),
          Text(
            'Descrição',
            style: TextStyle(fontSize: 12,
              fontWeight: FontWeight.bold,
              color: accentColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            atividade.displayDescription,
            style: TextStyle(fontSize: 15,
              color: primaryColor.withOpacity(0.8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color primaryColor, Color accentColor) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(fontSize: 12,
              fontWeight: FontWeight.bold,
              color: accentColor,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(fontSize: 14,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataSection(Color primaryColor, Color accentColor) {
    final metadata = atividade.metadata!;
    
    // Extraímos mudanças se existirem
    List<dynamic> changes = [];
    if (metadata.containsKey('changes')) {
      changes = metadata['changes'] is List ? metadata['changes'] : [];
    } else if (metadata.containsKey('alteracoes')) {
      changes = metadata['alteracoes'] is List ? metadata['alteracoes'] : [];
    }

    // Filtramos apenas o que realmente mudou
    final filteredChanges = changes.where((c) {
      if (c is! Map) return false;
      final oldVal = c['old'] ?? c['antigo'] ?? c['de'];
      final newVal = c['new'] ?? c['novo'] ?? c['para'];
      return oldVal.toString() != newVal.toString();
    }).toList();

    if (filteredChanges.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text(
            'Campos Alterados',
            style: TextStyle(fontSize: 12,
              fontWeight: FontWeight.bold,
              color: primaryColor.withOpacity(0.5),
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...filteredChanges.map((change) => _buildChangeCard(change, primaryColor, accentColor)),
      ],
    );
  }

  Widget _buildChangeCard(dynamic change, Color primaryColor, Color accentColor) {
    if (change is! Map) return const SizedBox.shrink();
    
    final field = change['field'] ?? change['campo'] ?? 'Campo';
    final oldVal = change['old'] ?? change['antigo'] ?? change['de'] ?? '-';
    final newVal = change['new'] ?? change['novo'] ?? change['para'] ?? '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
             _formatFieldLabel(field.toString()),
            style: TextStyle(fontSize: 14,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Como Era',
                      style: TextStyle(fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error.withOpacity(0.6),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      oldVal.toString(),
                      style: TextStyle(fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded, color: accentColor.withOpacity(0.3), size: 16),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Como Ficou',
                      style: TextStyle(fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: primaryColor.withOpacity(0.6),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      newVal.toString(),
                      style: TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatFieldLabel(String field) {
    // Tenta formatar nomes de campos snake_case para algo legível
    final parts = field.split('_');
    final formatted = parts.map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1)).join(' ');
    
    // Mapeamentos específicos comuns para a clínica
    final map = {
      'Nome Completo': 'Nome',
      'Valor Total': 'Valor',
      'Preco': 'Preço',
      'Preco Promocional': 'Preço Promocional',
      'Ativo': 'Status de Ativação',
      'Comissao Agendamentos': 'Comissão Agendamentos',
      'Comissao Produtos': 'Comissão Produtos',
      'Cpf': 'CPF',
      'Rg': 'RG',
      'Data Nascimento': 'Data de Nascimento',
      'Telefone': 'Telefone Responsável',
      'Celular': 'WhatsApp',
      'Email': 'E-mail',
      'Cep': 'CEP',
      'Endereco': 'Endereço',
      'Bairro': 'Bairro/Região',
      'Cidade': 'Cidade',
      'Uf': 'UF',
      'Referencia': 'Ponto de Referência',
      'Genero': 'Gênero',
      'Estado Civil': 'Estado Civil',
      'Profissao': 'Profissão',
      'Como Conheceu': 'Origem do Cliente',
      'Fumante': 'É Fumante?',
      'Pratica Exercicios': 'Pratica Exercícios?',
      'Alimentacao Balanceada': 'Dieta Equilibrada?',
      'Ingestao Agua': 'Ingestão de Água',
      'Uso Anticoncepcional': 'Anticoncepcional?',
      'Gestante': 'Está Gestante?',
      'Historico Cirurgico': 'Cirurgias Previas',
      'Alergias': 'Restrições Alérgicas',
      'Medicacoes': 'Medicamentos em Uso',
      'Observacoes': 'Notas Adicionais',
    };
    
    return map[formatted] ?? formatted;
  }

  String _getTipoLabel(String tipo) {
    switch (tipo) {
      case 'agendamento': return 'Agendamento';
      case 'confirmacao': return 'Confirmação';
      case 'reagendamento': return 'Reagendamento';
      case 'cancelamento': return 'Cancelamento';
      case 'cliente': return 'Cliente';
      case 'configuracao': return 'Configuração';
      case 'profissional': return 'Profissional';
      case 'edicao': return 'Edição';
      default: return tipo[0].toUpperCase() + tipo.substring(1);
    }
  }
}
