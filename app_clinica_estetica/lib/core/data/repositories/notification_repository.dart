import 'package:app_clinica_estetica/core/data/models/notification_model.dart';

abstract class INotificationRepository {
  Future<List<NotificationModel>> getUserNotifications(String userId);
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead(String userId);
  Future<int> getUnreadCount(String userId);
  Future<void> saveNotification(NotificationModel notification);
  Future<void> sendNotification({
    required String userId,
    required String titulo,
    required String mensagem,
    required String tipo,
    Map<String, dynamic>? metadata,
  });
  Future<void> notifyAllAdmins({
    required String titulo,
    required String mensagem,
    required String tipo,
    Map<String, dynamic>? metadata,
  });
  Future<void> notifyAllClients({
    required String titulo,
    required String mensagem,
    required String tipo,
    Map<String, dynamic>? metadata,
  });
}

