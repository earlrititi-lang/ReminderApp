import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_app/core/error/exceptions.dart';
import 'package:reminder_app/features/reminders/data/datasources/reminder_local_datasource.dart';
import 'package:reminder_app/features/reminders/data/datasources/reminder_remote_datasource.dart';
import 'package:reminder_app/features/reminders/data/models/reminder_model.dart';
import 'package:reminder_app/features/reminders/data/repositories/reminder_repository_impl.dart';

void main() {
  group('ReminderRepositoryImpl', () {
    test('mezcla recordatorios locales y remotos sin perder datos', () async {
      final localReminder = _buildReminder(
        id: 'local-1',
        title: 'Solo local',
        dateTime: DateTime(2026, 3, 26, 10),
      );
      final remoteReminder = _buildReminder(
        id: 'remote-1',
        title: 'Solo remoto',
        dateTime: DateTime(2026, 3, 27, 12),
      );
      final local = _FakeLocalDataSource([localReminder]);
      final remote = _FakeRemoteDataSource([remoteReminder]);
      final repository = ReminderRepositoryImpl(
        localDataSource: local,
        remoteDataSource: remote,
      );

      final result = await repository.getReminders();

      expect(result.isRight(), isTrue);
      final reminders = result.getOrElse(() => []);
      expect(
          reminders.map((r) => r.id), unorderedEquals(['local-1', 'remote-1']));
      expect(local.cachedSnapshot.map((r) => r.id),
          unorderedEquals(['local-1', 'remote-1']));
      expect(remote.createdIds, contains('local-1'));
    });

    test('prefiere la version local si es mas reciente y la empuja a la nube',
        () async {
      final localReminder = _buildReminder(
        id: 'shared-1',
        title: 'Version local nueva',
        dateTime: DateTime(2026, 3, 26, 10),
        updatedAt: DateTime(2026, 3, 26, 12),
      );
      final remoteReminder = _buildReminder(
        id: 'shared-1',
        title: 'Version remota antigua',
        dateTime: DateTime(2026, 3, 26, 10),
        updatedAt: DateTime(2026, 3, 26, 11),
      );
      final local = _FakeLocalDataSource([localReminder]);
      final remote = _FakeRemoteDataSource([remoteReminder]);
      final repository = ReminderRepositoryImpl(
        localDataSource: local,
        remoteDataSource: remote,
      );

      final result = await repository.getReminders();

      expect(result.isRight(), isTrue);
      final reminders = result.getOrElse(() => []);
      expect(reminders.single.title, 'Version local nueva');
      expect(remote.updatedIds, contains('shared-1'));
      expect(remote.remindersById['shared-1']?.title, 'Version local nueva');
    });

    test('si borrar en remoto falla no elimina localmente ni reporta exito',
        () async {
      final reminder = _buildReminder(
        id: 'shared-1',
        title: 'Pendiente',
        dateTime: DateTime(2026, 3, 26, 10),
      );
      final local = _FakeLocalDataSource([reminder]);
      final remote = _FakeRemoteDataSource([reminder], failDelete: true);
      final repository = ReminderRepositoryImpl(
        localDataSource: local,
        remoteDataSource: remote,
      );

      final result = await repository.deleteReminder(reminder.id);

      expect(result.isLeft(), isTrue);
      expect(local.remindersById.containsKey(reminder.id), isTrue);
      expect(local.deleteCalls, 0);
      expect(remote.remindersById.containsKey(reminder.id), isTrue);
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
  List<ReminderModel> cachedSnapshot = const [];
  int deleteCalls = 0;

  @override
  Future<void> cacheReminders(List<ReminderModel> reminders) async {
    remindersById
      ..clear()
      ..addEntries(
          reminders.map((reminder) => MapEntry(reminder.id, reminder)));
    cachedSnapshot = List<ReminderModel>.from(reminders);
  }

  @override
  Future<ReminderModel> createReminder(ReminderModel reminder) async {
    remindersById[reminder.id] = reminder;
    return reminder;
  }

  @override
  Future<void> deleteReminder(String id) async {
    deleteCalls++;
    final removed = remindersById.remove(id);
    if (removed == null) {
      throw CacheException('Recordatorio no encontrado');
    }
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

class _FakeRemoteDataSource implements ReminderRemoteDataSource {
  _FakeRemoteDataSource(
    Iterable<ReminderModel> reminders, {
    this.failDelete = false,
  }) : remindersById = {
          for (final reminder in reminders) reminder.id: reminder,
        };

  final Map<String, ReminderModel> remindersById;
  final List<String> createdIds = [];
  final List<String> updatedIds = [];
  final bool failDelete;

  @override
  Future<ReminderModel> createReminder(ReminderModel reminder) async {
    createdIds.add(reminder.id);
    remindersById[reminder.id] = reminder;
    return reminder;
  }

  @override
  Future<void> deleteReminder(String id) async {
    if (failDelete) {
      throw ServerException('Fallo remoto al borrar');
    }
    remindersById.remove(id);
  }

  @override
  Future<ReminderModel> getReminderById(String id) async {
    final reminder = remindersById[id];
    if (reminder == null) {
      throw ServerException('Recordatorio remoto no encontrado');
    }
    return reminder;
  }

  @override
  Future<List<ReminderModel>> getReminders() async {
    return remindersById.values.toList();
  }

  @override
  Future<ReminderModel> updateReminder(ReminderModel reminder) async {
    updatedIds.add(reminder.id);
    remindersById[reminder.id] = reminder;
    return reminder;
  }

  @override
  Stream<List<ReminderModel>> watchReminders() {
    return Stream.value(remindersById.values.toList());
  }
}
