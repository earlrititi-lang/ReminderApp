import 'package:isar/isar.dart';
import '../../domain/entities/reminder.dart';

part 'reminder_model.g.dart';

/// Modelo de datos para persistencia con Isar
@collection
class ReminderModel {
  Id isarId = Isar.autoIncrement;
  
  late String id;
  late String title;
  String? description;
  late DateTime dateTime;
  late bool isCompleted;
  late DateTime createdAt;
  DateTime? updatedAt;
  late bool notificationEnabled;
  String? soundPath;
  late bool vibrationEnabled;
  int? snoozeMinutes;

  ReminderModel({
    required this.id,
    required this.title,
    this.description,
    required this.dateTime,
    this.isCompleted = false,
    required this.createdAt,
    this.updatedAt,
    this.notificationEnabled = true,
    this.soundPath,
    this.vibrationEnabled = true,
    this.snoozeMinutes,
  });

  /// Convierte de Entidad a Modelo
  factory ReminderModel.fromEntity(Reminder reminder) {
    return ReminderModel(
      id: reminder.id,
      title: reminder.title,
      description: reminder.description,
      dateTime: reminder.dateTime,
      isCompleted: reminder.isCompleted,
      createdAt: reminder.createdAt,
      updatedAt: reminder.updatedAt,
      notificationEnabled: reminder.notificationEnabled,
      soundPath: reminder.soundPath,
      vibrationEnabled: reminder.vibrationEnabled,
      snoozeMinutes: reminder.snoozeMinutes,
    );
  }

  /// Convierte desde JSON (para Firebase)
  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    return ReminderModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      dateTime: DateTime.parse(json['dateTime'] as String),
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      notificationEnabled: json['notificationEnabled'] as bool? ?? true,
      soundPath: json['soundPath'] as String?,
      vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
      snoozeMinutes: json['snoozeMinutes'] as int?,
    );
  }

  /// Convierte a JSON (para Firebase)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dateTime': dateTime.toIso8601String(),
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'notificationEnabled': notificationEnabled,
      'soundPath': soundPath,
      'vibrationEnabled': vibrationEnabled,
      'snoozeMinutes': snoozeMinutes,
    };
  }

  /// Convierte a Entidad de dominio
  Reminder toEntity() {
    return Reminder(
      id: id,
      title: title,
      description: description,
      dateTime: dateTime,
      isCompleted: isCompleted,
      createdAt: createdAt,
      updatedAt: updatedAt,
      notificationEnabled: notificationEnabled,
      soundPath: soundPath,
      vibrationEnabled: vibrationEnabled,
      snoozeMinutes: snoozeMinutes,
    );
  }
}