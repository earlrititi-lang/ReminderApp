import 'package:isar/isar.dart';
import '../../../../core/error/exceptions.dart';
import '../models/reminder_model.dart';

/// Contrato del Data Source Local
abstract class ReminderLocalDataSource {
  Future<List<ReminderModel>> getReminders();
  Future<ReminderModel> getReminderById(String id);
  Future<ReminderModel> createReminder(ReminderModel reminder);
  Future<ReminderModel> updateReminder(ReminderModel reminder);
  Future<void> deleteReminder(String id);
  Future<void> cacheReminders(List<ReminderModel> reminders);
  Stream<List<ReminderModel>> watchReminders();
}

/// Implementación con Isar
class ReminderLocalDataSourceImpl implements ReminderLocalDataSource {
  final Isar isar;

  ReminderLocalDataSourceImpl({required this.isar});

  @override
  Future<List<ReminderModel>> getReminders() async {
    try {
      final reminders = await isar.reminderModels.where().findAll();
      return reminders;
    } catch (e) {
      throw CacheException('Error al obtener recordatorios: $e');
    }
  }

  @override
  Future<ReminderModel> getReminderById(String id) async {
    try {
      final reminder = await isar.reminderModels
          .filter()
          .idEqualTo(id)
          .findFirst();
      
      if (reminder == null) {
        throw CacheException('Recordatorio no encontrado');
      }
      
      return reminder;
    } on CacheException {
      rethrow;
    } catch (e) {
      throw CacheException('Error al obtener recordatorio: $e');
    }
  }

  @override
  Future<ReminderModel> createReminder(ReminderModel reminder) async {
    try {
      await isar.writeTxn(() async {
        await isar.reminderModels.put(reminder);
      });
      return reminder;
    } on CacheException {
      rethrow;
    } catch (e) {
      throw CacheException('Error al crear recordatorio: $e');
    }
  }

  @override
  Future<ReminderModel> updateReminder(ReminderModel reminder) async {
    try {
      await isar.writeTxn(() async {
        await isar.reminderModels.put(reminder);
      });
      return reminder;
    } on CacheException {
      rethrow;
    } catch (e) {
      throw CacheException('Error al actualizar recordatorio: $e');
    }
  }

  @override
  Future<void> deleteReminder(String id) async {
    try {
      await isar.writeTxn(() async {
        final deleted = await isar.reminderModels
            .filter()
            .idEqualTo(id)
            .deleteFirst();
        
        if (!deleted) {
          // Si ya no existe localmente, tratamos el delete como idempotente.
          return;
        }
      });
    } on CacheException {
      rethrow;
    } catch (e) {
      throw CacheException('Error al eliminar recordatorio: $e');
    }
  }

  @override
  Future<void> cacheReminders(List<ReminderModel> reminders) async {
    try {
      await isar.writeTxn(() async {
        await isar.reminderModels.clear();
        await isar.reminderModels.putAll(reminders);
      });
    } on CacheException {
      rethrow;
    } catch (e) {
      throw CacheException('Error al cachear recordatorios: $e');
    }
  }

  @override
  Stream<List<ReminderModel>> watchReminders() {
    try {
      return isar.reminderModels
          .where()
          .watch(fireImmediately: true);
    } catch (e) {
      throw CacheException('Error al observar recordatorios: $e');
    }
  }
}
