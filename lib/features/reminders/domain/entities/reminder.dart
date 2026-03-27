import 'package:equatable/equatable.dart';

/// Entidad de dominio - Representa un recordatorio
/// Esta es la representación pura del negocio, sin dependencias externas
class Reminder extends Equatable {
  final String id;
  final String title;
  final String? description;
  final DateTime dateTime;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // Configuración de notificación
  final bool notificationEnabled;
  final String? soundPath; // Path al sonido personalizado
  final bool vibrationEnabled;
  final int? snoozeMinutes;

  const Reminder({
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

  /// Copia la entidad con modificaciones
  Reminder copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dateTime,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? notificationEnabled,
    String? soundPath,
    bool? vibrationEnabled,
    int? snoozeMinutes,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      soundPath: soundPath ?? this.soundPath,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        dateTime,
        isCompleted,
        createdAt,
        updatedAt,
        notificationEnabled,
        soundPath,
        vibrationEnabled,
        snoozeMinutes,
      ];
}