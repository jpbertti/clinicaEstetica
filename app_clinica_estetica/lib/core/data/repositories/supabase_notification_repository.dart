import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:app_clinica_estetica/core/data/models/notification_model.dart';
import 'package:app_clinica_estetica/core/data/repositories/notification_repository.dart';

class SupabaseNotificationRepository implements INotificationRepository {
  final _supabase = Supabase.instance.client;

  @override
  Future<List<NotificationModel>> getUserNotifications(String userId) async {
    final response = await _supabase
        .from('notificacoes')
        .select()
        .eq('user_id', userId)
        .order('data_criacao', ascending: false);

    return (response as List)
        .map((map) => NotificationModel.fromMap(map))
        .toList();
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await _supabase
        .from('notificacoes')
        .update({'is_lida': true})
        .eq('id', notificationId);
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    await _supabase
        .from('notificacoes')
        .update({'is_lida': true})
        .eq('user_id', userId)
        .eq('is_lida', false);
  }

  @override
  Future<int> getUnreadCount(String userId) async {
    final response = await _supabase
        .from('notificacoes')
        .select('id')
        .eq('user_id', userId)
        .eq('is_lida', false);


    return (response as List).length;
  }

  @override
  Future<void> saveNotification(NotificationModel notification) async {
    try {
      await _supabase.from('notificacoes').insert(notification.toJson());
    } catch (e) {
      debugPrint('Erro ao salvar notificação: $e');
      rethrow;
    }
  }

  @override
  Future<void> sendNotification({
    required String userId,
    required String titulo,
    required String mensagem,
    required String tipo,
    Map<String, dynamic>? metadata,
  }) async {
    final notification = NotificationModel(
      userId: userId,
      titulo: titulo,
      mensagem: mensagem,
      tipo: tipo,
      isLida: false,
      dataCriacao: DateTime.now(),
      metadata: metadata,
    );
    await saveNotification(notification);
  }

  @override
  Future<void> notifyAllAdmins({
    required String titulo,
    required String mensagem,
    required String tipo,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final adminsResponse = await _supabase
          .from('perfis')
          .select('id')
          .eq('tipo', 'admin');
          
      for (var admin in adminsResponse) {
        final notification = NotificationModel(
          userId: admin['id'],
          titulo: titulo,
          mensagem: mensagem,
          tipo: tipo,
          isLida: false,
          dataCriacao: DateTime.now(),
          metadata: metadata,
        );
        await saveNotification(notification);
      }
    } catch (e) {
      debugPrint('Erro ao notificar admins: $e');
    }
  }

  @override
  Future<void> notifyAllClients({
    required String titulo,
    required String mensagem,
    required String tipo,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final clientsResponse = await _supabase
          .from('perfis')
          .select('id')
          .eq('tipo', 'cliente');
          
      for (var client in clientsResponse) {
        final notification = NotificationModel(
          userId: client['id'],
          titulo: titulo,
          mensagem: mensagem,
          tipo: tipo,
          isLida: false,
          dataCriacao: DateTime.now(),
          metadata: metadata,
        );
        await saveNotification(notification);
      }
    } catch (e) {
      debugPrint('Erro ao notificar todos os clientes: $e');
    }
  }

  Future<void> notifyAffectedClients({
    required String? professionalId,
    required DateTime date,
    String? startStr,
    String? endStr,
    required String message,
  }) async {
    try {
      final dateOnly = DateFormat('yyyy-MM-dd').format(date);
      var query = _supabase
          .from('agendamentos')
          .select('cliente_id')
          .eq('data_hora::date', dateOnly) // Case-insensitive date match if supported, or matching parts
          .inFilter('status', ['pendente', 'confirmado']);

      if (professionalId != null) {
        query = query.eq('professional_id', professionalId);
      }

      // If partial range is specified
      if (startStr != null && endStr != null) {
        final fullStart = '${dateOnly}T$startStr';
        final fullEnd = '${dateOnly}T$endStr';
        query = query.gte('data_hora', fullStart).lte('data_hora', fullEnd);
      }

      final affected = await query;
      final uniqueClientIds = (affected as List).map((a) => a['cliente_id'].toString()).toSet();

      for (var clientId in uniqueClientIds) {
        await sendNotification(
          userId: clientId,
          titulo: 'Alteração na Agenda',
          mensagem: message,
          tipo: 'agenda',
        );
      }
    } catch (e) {
      debugPrint('Erro ao notificar clientes afetados: $e');
    }
  }
}


