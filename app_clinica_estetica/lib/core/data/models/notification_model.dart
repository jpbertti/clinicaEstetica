import 'package:intl/intl.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String titulo;
  final String mensagem;
  final String tipo;
  final bool isLida;
  final DateTime dataCriacao;
  final Map<String, dynamic>? metadata;

  NotificationModel({
    this.id = '',
    required this.userId,
    required this.titulo,
    required this.mensagem,
    required this.tipo,
    required this.isLida,
    required this.dataCriacao,
    this.metadata,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] ?? '',
      userId: map['user_id'],
      titulo: map['titulo'],
      mensagem: map['mensagem'],
      tipo: map['tipo'],
      isLida: map['is_lida'] ?? false,
      dataCriacao: DateTime.parse(map['data_criacao']).toLocal(),
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(map['metadata'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> map = {
      'user_id': userId,
      'titulo': titulo,
      'mensagem': mensagem,
      'tipo': tipo,
      'is_lida': isLida,
      'data_criacao': dataCriacao.toUtc().toIso8601String(),
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    if (metadata != null) {
      map['metadata'] = metadata;
    }
    return map;
  }

  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(dataCriacao);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m atrás';
    } else if (difference.inHours < 24 && dataCriacao.day == now.day) {
      return DateFormat('HH:mm').format(dataCriacao);
    } else if (difference.inDays == 1 ||
        (difference.inHours < 48 &&
            dataCriacao.day == now.subtract(const Duration(days: 1)).day)) {
      return 'Ontem';
    } else {
      return DateFormat('dd/MM').format(dataCriacao);
    }
  }

  String get fullDateLabel {
    final now = DateTime.now();
    if (dataCriacao.year == now.year &&
        dataCriacao.month == now.month &&
        dataCriacao.day == now.day) {
      return 'HOJE';
    } else if (dataCriacao.year == now.year &&
        dataCriacao.month == now.month &&
        dataCriacao.day == now.subtract(const Duration(days: 1)).day) {
      return 'ONTEM';
    } else {
      String formatted = DateFormat(
        'EEEE, d \'de\' MMMM \'de\' y',
        'pt_BR',
      ).format(dataCriacao);
      List<String> parts = formatted.split(',');
      if (parts.length > 1) {
        String dayOfWeek = parts[0];
        dayOfWeek = dayOfWeek
            .split('-')
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w)
            .join('-');
        return '$dayOfWeek,${parts[1]}';
      }
      return formatted;
    }
  }
}
