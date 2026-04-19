import 'package:app_clinica_estetica/core/data/models/notification_model.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_notification_repository.dart';
import 'package:app_clinica_estetica/features/auth/data/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NotificacoesPage extends StatefulWidget {
  const NotificacoesPage({super.key});

  @override
  State<NotificacoesPage> createState() => _NotificacoesPageState();
}

class _NotificacoesPageState extends State<NotificacoesPage> {
  final _repository = SupabaseNotificationRepository();
  List<NotificationModel> _notificacoes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (AuthService.currentUserId == null) return;
    try {
      final data = await _repository.getUserNotifications(AuthService.currentUserId!);
      if (mounted) {
        setState(() {
          _notificacoes = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _marcarTodasComoLidas() async {
    if (AuthService.currentUserId == null) return;
    try {
      await _repository.markAllAsRead(AuthService.currentUserId!);
      await _loadNotifications();
    } catch (e) {
      debugPrint('Erro ao marcar todas como lidas: $e');
    }
  }

  Future<void> _marcarComoLida(String id) async {
    try {
      await _repository.markAsRead(id);
      await _loadNotifications();
    } catch (e) {
      debugPrint('Erro ao marcar como lida: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF305F47);
    const accentColor = Color(0xFFC7A46B);
    const backgroundColor = Color(0xFFF9F7F2);

    // Separar novas de lidas
    final novas = _notificacoes.where((n) => !n.isLida).toList();
    final lidas = _notificacoes.where((n) => n.isLida).toList();

    // Agrupar lidas por data
    Map<String, List<NotificationModel>> lidasAgrupadas = {};
    for (var n in lidas) {
      final label = n.fullDateLabel;
      if (!lidasAgrupadas.containsKey(label)) {
        lidasAgrupadas[label] = [];
      }
      lidasAgrupadas[label]!.add(n);
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _construirCabecalho(context, primaryColor, accentColor),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _notificacoes.isEmpty
                      ? _construirVazio(primaryColor, accentColor)
                      : RefreshIndicator(
                          onRefresh: _loadNotifications,
                          color: primaryColor,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (novas.isNotEmpty) ...[
                                  _construirLabelSecao('Novas', primaryColor),
                                  const SizedBox(height: 16),
                                  ...novas.map((n) => _construirCardNotificacao(n, primaryColor, accentColor)),
                                  const SizedBox(height: 24),
                                ],
                                
                                if (lidas.isNotEmpty) ...[
                                  if (novas.isNotEmpty) 
                                    _construirLabelSecao('Anteriores', primaryColor),
                                  const SizedBox(height: 16),
                                  ...lidasAgrupadas.entries.expand((entry) => [
                                    if (novas.isEmpty && entry.key == lidasAgrupadas.keys.first) 
                                       Padding(
                                         padding: const EdgeInsets.only(bottom: 16.0),
                                         child: _construirLabelSecao(entry.key, primaryColor),
                                       )
                                    else
                                       Padding(
                                         padding: const EdgeInsets.only(top: 24.0, bottom: 16.0),
                                         child: Text(
                                           entry.key,
                                           style: TextStyle(
                                             fontFamily: 'Playfair Display',
                                             fontSize: 14,
                                             fontWeight: FontWeight.bold,
                                             color: primaryColor.withOpacity(0.4),
                                             letterSpacing: 1.0,
                                           ),
                                         ),
                                       ),
                                    ...entry.value.map((n) => _construirCardNotificacao(n, primaryColor, accentColor)),
                                    const SizedBox(height: 12),
                                  ]),
                                ],
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirVazio(Color primaryColor, Color accentColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_outlined, size: 64, color: accentColor.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            'Nenhuma notificação',
            style: TextStyle(fontSize: 18, color: primaryColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _construirCabecalho(BuildContext context, Color primaryColor, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                color: primaryColor,
              ),
              Text(
                'Notificações',
                style: TextStyle(fontFamily: 'Playfair Display', fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor),
              ),
              const SizedBox(width: 48), // Espaçador para centralizar
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _marcarTodasComoLidas,
            child: Text(
              'MARCAR TODAS COMO LIDAS',
              style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.bold,
                color: accentColor,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirLabelSecao(String label, Color primaryColor) {
    return Text(
      label,
      style: TextStyle(fontFamily: 'Playfair Display', fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
    );
  }

  Widget _construirCardNotificacao(NotificationModel n, Color primaryColor, Color accentColor) {
    return GestureDetector(
      onTap: n.isLida ? null : () => _marcarComoLida(n.id),
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
          border: !n.isLida
              ? Border(left: BorderSide(color: accentColor, width: 4))
              : Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(color: Color(0xFFF9F7F2), shape: BoxShape.circle),
                    child: Icon(_getIconForTipo(n.tipo), color: primaryColor, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.titulo,
                          style: TextStyle(
                            fontFamily: 'Playfair Display',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: n.isLida ? primaryColor.withOpacity(0.6) : primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          n.mensagem,
                          style: TextStyle(fontSize: 13,
                            color: n.isLida ? Colors.grey[400] : Colors.grey[600],
                            height: 1.4,
                          ),
                        ),
                        if (n.metadata != null && n.metadata!['changes'] != null)
                          _construirMetadataCards(n, primaryColor, accentColor),
                        const SizedBox(height: 12),
                        Text(
                          '${n.formattedTime} · ${_getCategoryForTipo(n.tipo)}',
                          style: TextStyle(fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[400],
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!n.isLida)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirMetadataCards(NotificationModel n, Color primaryColor, Color accentColor) {
    final List<dynamic> changes = n.metadata!['changes'] as List<dynamic>;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        ...changes.map((change) {
          final field = change['field'] ?? 'Alteração';
          final oldVal = change['old']?.toString() ?? '-';
          final newVal = change['new']?.toString() ?? '-';
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F7F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  field.toUpperCase(),
                  style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                // Bloco Antigo
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ANTIGO:',
                        style: TextStyle(fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        oldVal,
                        style: TextStyle(fontSize: 13,
                          color: Colors.grey[500],
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Bloco Novo
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: primaryColor.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NOVO:',
                        style: TextStyle(fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        newVal,
                        style: TextStyle(fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  IconData _getIconForTipo(String tipo) {
    switch (tipo) {
      case 'agendamento': return Icons.calendar_today_outlined;
      case 'cancelamento': return Icons.close;
      case 'reagendamento': return Icons.update_outlined;
      case 'confirmado':
      case 'concluido': return Icons.check_circle_outline;
      case 'status_change': return Icons.check_circle_outline;
      case 'avaliacao': return Icons.auto_awesome_rounded;
      case 'novo_usuario': return Icons.person_add_outlined;
      case 'novo_procedimento': return Icons.auto_awesome_mosaic_outlined;
      case 'novo_profissional': return Icons.badge_outlined;
      case 'config_change': return Icons.settings_suggest_outlined;
      case 'promocao': return Icons.local_offer_outlined;
      default: return Icons.notifications_none_outlined;
    }
  }

  String _getCategoryForTipo(String tipo) {
    switch (tipo) {
      case 'agendamento': return 'NOVO AGENDAMENTO';
      case 'cancelamento': return 'CANCELAMENTO';
      case 'reagendamento': return 'REAGENDAMENTO';
      case 'confirmado':
      case 'concluido':
      case 'status_change': return 'ATUALIZAÇÃO';
      case 'avaliacao': return 'AGRADECIMENTO';
      case 'novo_usuario': return 'NOVO CLIENTE';
      case 'novo_procedimento': return 'NOVO PROCEDIMENTO';
      case 'novo_profissional': return 'NOVA CONTRATAÇÃO';
      case 'config_change': return 'CONFIGURAÇÃO ALTERADA';
      case 'promocao': return 'PROMOÇÃO';
      default: return 'SISTEMA';
    }
  }
}

