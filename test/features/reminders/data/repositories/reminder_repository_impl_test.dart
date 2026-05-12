import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_app/core/error/exceptions.dart';
import 'package:reminder_app/features/reminders/data/datasources/reminder_local_datasource.dart';
import 'package:reminder_app/features/reminders/data/models/reminder_model.dart';
import 'package:reminder_app/features/reminders/data/repositories/reminder_repository_impl.dart';

void main() {
  group('ReminderRepositoryImpl', () {
    test('obtiene recordatorios desde almacenamiento local', () async {
      final reminder = _buildReminder(
        id: 'local-1',
        title: 'Solo local',
        dateTime: DateTime(2026, 3, 26, 10),
      );
      final local = _FakeLocalDataSource([reminder]);
      final repository = ReminderRepositoryImpl(localDataSource: local);

      final result = await repository.getReminders();

      expect(result.isRight(), isTrue);
      expect(result.getOrElse(() => []).single.id, 'local-1');
    });

    test('crea, actualiza y borra recordatorios localmente', () async {
      final local = _FakeLocalDataSource([]);
      final repository = ReminderRepositoryImpl(localDataSource: local);
      final reminder = _buildReminder(
        id: 'local-1',
        title: 'Pendiente',
        dateTime: DateTime(2026, 3, 26, 10),
      );

      final created = await repository.createReminder(reminder.toEntity());
      final updated = await repository.updateReminder(
        reminder.toEntity().copyWith(
              title: 'Actualizado',
              updatedAt: DateTime(2026, 3, 26, 11),
            ),
      );
      final deleted = await repository.deleteReminder(reminder.id);

      expect(created.isRight(), isTrue);
      expect(updated.getOrElse(() => reminder.toEntity()).title, 'Actualizado');
      expect(deleted.isRight(), isTrue);
      expect(local.remindersById.containsKey(reminder.id), isFalse);
    });
  });
}

ReminderModel _buildReminder({
  required String id,
  required String title,
  required DateTime dateTime,
  DateTime? updatedAt,
}) {
  return ReminderModel(
    id: id,
    title: title,
    dateTime: dateTime,
    createdAt: DateTime(2026, 3, 25, 9),
    updatedAt: updatedAt,
  );
}

class _FakeLocalDataSource implements ReminderLocalDataSource {
  _FakeLocalDataSource(Iterable<ReminderModel> reminders)
      : remindersById = {
          for (final reminder in reminders) reminder.id: reminder,
        };

  final Map<String, ReminderModel> remindersById;

  @override
  Future<void> cacheReminders(List<ReminderModel> reminders) async {
    remindersById
      ..clear()
      ..addEntries(
        reminders.map((reminder) => MapEntry(reminder.id, reminder)),
      );
  }

  @override
  Future<ReminderModel> createReminder(ReminderModel reminder) async {
    remindersById[reminder.id] = reminder;
    return reminder;
  }

  @override
  Future<void> deleteReminder(String id) async {
    remindersById.remove(id);
  }

  @override
  Future<ReminderModel> getReminderById(String id) async {
    final reminder = remindersById[id];
    if (reminder == null) {
      throw CacheException('Recordatorio no encontrado');
    }
    return reminder;
  }

  @override
  Future<List<ReminderModel>> getReminders() async {
    return remindersById.values.toList();
  }

  @override
  Future<ReminderModel> updateReminder(ReminderModel reminder) async {
    remindersById[reminder.id] = reminder;
    return reminder;
  }

  @override
  Stream<List<ReminderModel>> watchReminders() {
    return Stream.value(remindersById.values.toList());
  }
}
