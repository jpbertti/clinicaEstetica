import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_clinica_estetica/features/auth/data/auth_service.dart';
import 'package:app_clinica_estetica/core/data/repositories/supabase_notification_repository.dart';
import 'package:app_clinica_estetica/core/data/models/notification_model.dart';
import 'package:app_clinica_estetica/features/profissional/presentation/widgets/profissional_app_bar.dart';

class ProfissionalNotificacoesPage extends StatefulWidget {
  const ProfissionalNotificacoesPage({super.key});

  @override
  State<ProfissionalNotificacoesPage> createState() => _ProfissionalNotificacoesPageState();
}

class _ProfissionalNotificacoesPageState extends State<ProfissionalNotificacoesPage> {
  final _notificationRepo = SupabaseNotificationRepository();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  final Color primaryGreen = const Color(0xFF2F5E46);
  final Color accent = const Color(0xFFC7A36B);
  final Color bgColor = const Color(0xFFF6F4EF);

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final userId = AuthService.currentUserId;
      if (userId == null) return;
      final notifications = await _notificationRepo.getUserNotifications(userId);
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar notificações: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      await _notificationRepo.markAsRead(id);
      _loadNotifications();
    } catch (e) {
      debugPrint('Erro ao marcar como lida: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final userId = AuthService.currentUserId;
      if (userId == null) return;
      await _notificationRepo.markAllAsRead(userId);
      _loadNotifications();
    } catch (e) {
      debugPrint('Erro ao marcar todas como lidas: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Separar novas de lidas
    final novas = _notifications.where((n) => !n.isLida).toList();
    final lidas = _notifications.where((n) => n.isLida).toList();

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
      backgroundColor: bgColor,
      appBar: const ProfissionalAppBar(title: 'Notificações', showBackButton: true),
      body: SafeArea(
        child: Column(
          children: [
            _buildSimplifiedHeader(),
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: primaryGreen))
              : _notifications.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadNotifications,
                      color: primaryGreen,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (novas.isNotEmpty) ...[
                              _buildSectionLabel('Novas'),
                              const SizedBox(height: 16),
                              ...novas.map((n) => _buildNotificationCard(n)),
                              const SizedBox(height: 24),
                            ],
                            
                            if (lidas.isNotEmpty) ...[
                              if (novas.isNotEmpty) 
                                _buildSectionLabel('Anteriores'),
                              const SizedBox(height: 16),
                              ...lidasAgrupadas.entries.expand((entry) => [
                                if (novas.isEmpty && entry.key == lidasAgrupadas.keys.first) 
                                   Padding(
                                     padding: const EdgeInsets.only(bottom: 16.0),
                                     child: _buildSectionLabel(entry.key),
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
                                         color: primaryGreen.withOpacity(0.4),
                                         letterSpacing: 1.0,
                                       ),
                                     ),
                                   ),
                                ...entry.value.map((n) => _buildNotificationCard(n)),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_outlined, size: 64, color: accent.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            'Nenhuma notificação',
            style: TextStyle(fontSize: 18, color: primaryGreen, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSimplifiedHeader() {
    final hasUnread = _notifications.any((n) => !n.isLida);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Center(
        child: GestureDetector(
          onTap: hasUnread ? _markAllAsRead : null,
          child: Text(
            'MARCAR TODAS COMO LIDAS',
            style: TextStyle(fontSize: 11,
              fontWeight: FontWeight.bold,
              color: hasUnread ? accent : Colors.black26,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(fontFamily: 'Playfair Display', fontSize: 18, fontWeight: FontWeight.w800, color: primaryGreen, letterSpacing: -0.5),
    );
  }

  Widget _buildNotificationCard(NotificationModel n) {
    return GestureDetector(
      onTap: n.isLida ? null : () => _markAsRead(n.id),
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
              ? Border(left: BorderSide(color: accent, width: 4))
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
                    decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                    child: Icon(_getIconForTipo(n.tipo), color: primaryGreen, size: 20),
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
                              fontWeight: FontWeight.w800,
                              color: n.isLida ? primaryGreen.withOpacity(0.6) : primaryGreen,
                              letterSpacing: -0.2,
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
                        const SizedBox(height: 12),
                        Text(
                          '${DateFormat('HH:mm').format(n.dataCriacao)} · ${_getCategoryForTipo(n.tipo).toUpperCase()}',
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
                    decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForTipo(String tipo) {
    switch (tipo) {
      case 'agendamento': return Icons.calendar_today_outlined;
      case 'cancelamento': return Icons.close;
      case 'reagendamento': return Icons.update_outlined;
      case 'confirmado':
      case 'concluido':
      case 'status_change': return Icons.check_circle_outline;
      case 'avaliacao': return Icons.auto_awesome_rounded;
      case 'novo_usuario': return Icons.person_add_outlined;
      case 'novo_procedimento': return Icons.auto_awesome_mosaic_outlined;
      case 'novo_profissional': return Icons.badge_outlined;
      default: return Icons.notifications_none_outlined;
    }
  }

  String _getCategoryForTipo(String tipo) {
    switch (tipo) {
      case 'agendamento': return 'Novo Agendamento';
      case 'cancelamento': return 'Cancelamento';
      case 'reagendamento': return 'Reagendamento';
      case 'confirmado':
      case 'concluido':
      case 'status_change': return 'Atualização';
      case 'avaliacao': return 'Agradecimento';
      case 'novo_usuario': return 'Novo Cliente';
      case 'novo_procedimento': return 'Novo Procedimento';
      case 'novo_profissional': return 'Nova Contratação';
      default: return 'Sistema';
    }
  }
}

