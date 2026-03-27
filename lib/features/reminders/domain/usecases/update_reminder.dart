import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/notification_helper.dart';
import '../entities/reminder.dart';
import '../repositories/reminder_repository.dart';

class UpdateReminder implements UseCase<Reminder, UpdateReminderParams> {
  final ReminderRepository repository;
  final NotificationHelper notificationHelper;

  UpdateReminder(this.repository, this.notificationHelper);

  @override
  Future<Either<Failure, Reminder>> call(UpdateReminderParams params) async {
    final notificationId =
        NotificationHelper.generateNotificationId(params.reminder.id);
    final result = await repository.updateReminder(params.reminder);

    await result.fold(
      (failure) async {},
      (reminder) async {
        await notificationHelper.cancelNotification(notificationId);
        if (reminder.notificationEnabled &&
            reminder.dateTime.isAfter(DateTime.now()) &&
            !reminder.isCompleted) {
          await notificationHelper.scheduleNotification(
            id: notificationId,
            title: reminder.title,
            body: reminder.description ?? 'Tienes un recordatorio pendiente',
            scheduledDate: reminder.dateTime,
            payload: reminder.id,
            useCustomSound: reminder.soundPath != null,
            customSoundPath: reminder.soundPath,
            loopSound: true,
            vibrationEnabled: reminder.vibrationEnabled,
          );
        }
      },
    );

    return result;
  }
}

class UpdateReminderParams {
  final Reminder reminder;

  UpdateReminderParams({required this.reminder});
}
