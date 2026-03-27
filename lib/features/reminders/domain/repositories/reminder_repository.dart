import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/reminder.dart';

/// Contrato abstracto del repositorio
/// Define QUÉ se puede hacer, pero no CÓMO
abstract class ReminderRepository {
  /// Obtiene todos los recordatorios
  Future<Either<Failure, List<Reminder>>> getReminders();
  
  /// Obtiene un recordatorio por ID
  Future<Either<Failure, Reminder>> getReminderById(String id);
  
  /// Crea un nuevo recordatorio
  Future<Either<Failure, Reminder>> createReminder(Reminder reminder);
  
  /// Actualiza un recordatorio existente
  Future<Either<Failure, Reminder>> updateReminder(Reminder reminder);
  
  /// Elimina un recordatorio
  Future<Either<Failure, void>> deleteReminder(String id);
  
  /// Sincroniza con la nube
  Future<Either<Failure, void>> syncWithCloud();
  
  /// Escucha cambios en tiempo real (Stream)
  Stream<Either<Failure, List<Reminder>>> watchReminders();
}