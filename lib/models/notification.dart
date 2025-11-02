import 'package:flutter/material.dart';

enum NotificationType { system, maintenance, operational, weather }

class Notification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType type;
  bool isRead;

  Notification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    this.isRead = false,
  });

  IconData get icon {
    switch (type) {
      case NotificationType.system:
        return Icons.power_settings_new;
      case NotificationType.maintenance:
        return Icons.battery_alert;
      case NotificationType.operational:
        return Icons.water_drop;
      case NotificationType.weather:
        return Icons.wb_sunny;
    }
  }

  Color get color {
    switch (type) {
      case NotificationType.system:
        return Colors.red;
      case NotificationType.maintenance:
        return Colors.orange;
      case NotificationType.operational:
        return Colors.blue;
      case NotificationType.weather:
        return Colors.amber;
    }
  }

  String get typeName {
    return type.toString().split('.').last;
  }
}
