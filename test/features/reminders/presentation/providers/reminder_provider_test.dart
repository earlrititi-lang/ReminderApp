import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_app/core/error/failures.dart';
import 'package:reminder_app/core/utils/notification_helper.dart';
import 'package:reminder_app/features/reminders/domain/entities/reminder.dart';
import 'package:reminder_app/features/reminders/domain/repositories/reminder_repository.dart';
import 'package:reminder_app/features/reminders/domain/usecases/create_reminder.dart';
import 'package:reminder_app/features/reminders/domain/usecases/delete_reminder.dart';
import 'package:reminder_app/features/reminders/domain/usecases/get_reminders.dart';
import 'package:reminder_app/features/reminders/domain/usecases/update_reminder.dart';
import 'package:reminder_app/features/reminders/presentation/providers/reminder_provider.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RemindersNotifier', () {
    test(
      'no duplica una tarea cuando el stream local la emite durante el alta',
      () async {
        final repository = _FakeReminderRepository();
        final notifier = _buildNotifier(repository);

        await _settleNotifier();

        final created = await notifier.addReminder(
          title: 'Comprar pan',
          dateTime: DateTime.now().subtract(const Duration(minutes: 1)),
          notificationEnabled: false,
        );

        await _settleNotifier();

        expect(created, isTrue);
        expect(notifier.state.reminders, hasLength(1));
        expect(notifier.state.reminders.single.title, 'Comprar pan');

        notifier.dispose();
        await repository.dispose();
      },
    );

    test('deduplica recordatorios ya repetidos y conserva la version mas nueva',
        () async {
      final reminderOld = Reminder(
        id: 'shared-1',
        title: 'Version vieja',
        dateTime: DateTime(2026, 4, 4, 10),
        createdAt: DateTime(2026, 4, 4, 9),
        updatedAt: DateTime(2026, 4, 4, 10),
      );
      final reminderNew = reminderOld.copyWith(
        title: 'Version nueva',
        updatedAt: DateTime(2026, 4, 4, 11),
      );

      final repository = _FakeReminderRepository(
        initialReminders: [reminderOld, reminderNew],
      );
      final notifier = _buildNotifier(repository);

      await _settleNotifier();

      expect(notifier.state.reminders, hasLength(1));
      expect(notifier.state.reminders.single.title, 'Version nueva');

      notifier.dispose();
      await repository.dispose();
    });
  });
}

RemindersNotifier _buildNotifier(_FakeReminderRepository repository) {
  final notificationHelper = NotificationHelper();

  return RemindersNotifier(
    repository: repository,
    getReminders: GetReminders(repository),
    createReminder: CreateReminder(repository, notificationHelper),
    updateReminder: UpdateReminder(repository, notificationHelper),
    deleteReminder: DeleteReminder(repository, notificationHelper),
    uuid: const Uuid(),
    isLocalEnabled: true,
  );
}

Future<void> _settleNotifier() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _FakeReminderRepository implements ReminderRepository {
  _FakeReminderRepository({
    List<Reminder>? initialReminders,
  }) : _reminders = List<Reminder>.from(initialReminders ?? const []),
       _controller = StreamController<Either<Failure, List<Reminder>>>.broadcast(
         sync: true,
       );

  final List<Reminder> _reminders;
  final StreamController<Either<Failure, List<Reminder>>> _controller;

  Future<void> dispose() async {
    await _controller.close();
  }

  @override
  Future<Either<Failure, Reminder>> createReminder(Reminder reminder) async {
    _reminders
      ..removeWhere((item) => item.id == reminder.id)
      ..add(reminder);
    _controller.add(Right(List<Reminder>.from(_reminders)));
    return Right(reminder);
  }

  @override
  Future<Either<Failure, void>> deleteReminder(String id) async {
    _reminders.removeWhere((item) => item.id == id);
    _controller.add(Right(List<Reminder>.from(_reminders)));
    return const Right(null);
  }

  @override
  Future<Either<Failure, Reminder>> getReminderById(String id) async {
    final reminder = _reminders.where((item) => item.id == id).lastOrNull;
    if (reminder == null) {
      return const Left(CacheFailure('Recordatorio no encontrado'));
    }
    return Right(reminder);
  }

  @override
  Future<Either<Failure, List<Reminder>>> getReminders() async {
    return Right(List<Reminder>.from(_reminders));
  }

  @override
  Future<Either<Failure, void>> syncWithCloud() async {
    return const Right(null);
  }

  @override
  Future<Either<Failure, Reminder>> updateReminder(Reminder reminder) async {
    _reminders
      ..removeWhere((item) => item.id == reminder.id)
      ..add(reminder);
    _controller.add(Right(List<Reminder>.from(_reminders)));
    return Right(reminder);
  }

  @override
  Stream<Either<Failure, List<Reminder>>> watchReminders() {
    return _controller.stream;
  }
}
