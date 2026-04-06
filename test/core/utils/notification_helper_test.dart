import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_app/core/utils/notification_helper.dart';
import 'package:reminder_app/features/reminders/domain/entities/reminder.dart';

void main() {
  group('NotificationHelper.shouldScheduleReminder', () {
    final now = DateTime(2026, 4, 6, 10);

    Reminder buildReminder({
      bool notificationEnabled = true,
      bool isCompleted = false,
      DateTime? dateTime,
    }) {
      return Reminder(
        id: 'reminder-1',
        title: 'Llamar al dentista',
        dateTime: dateTime ?? now.add(const Duration(hours: 2)),
        createdAt: now.subtract(const Duration(hours: 1)),
        notificationEnabled: notificationEnabled,
        isCompleted: isCompleted,
      );
    }

    test('programa solo recordatorios futuros, activos y no completados', () {
      final reminder = buildReminder();

      expect(
        NotificationHelper.shouldScheduleReminder(reminder, now: now),
        isTrue,
      );
    });

    test('no programa recordatorios con notificaciones desactivadas', () {
      final reminder = buildReminder(notificationEnabled: false);

      expect(
        NotificationHelper.shouldScheduleReminder(reminder, now: now),
        isFalse,
      );
    });

    test('no programa recordatorios ya completados', () {
      final reminder = buildReminder(isCompleted: true);

      expect(
        NotificationHelper.shouldScheduleReminder(reminder, now: now),
        isFalse,
      );
    });

    test('no programa recordatorios en el pasado', () {
      final reminder = buildReminder(
        dateTime: now.subtract(const Duration(minutes: 1)),
      );

      expect(
        NotificationHelper.shouldScheduleReminder(reminder, now: now),
        isFalse,
      );
    });
  });
}
