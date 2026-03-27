import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/notification_helper.dart';
import '../entities/reminder.dart';
import '../repositories/reminder_repository.dart';

class CreateReminder implements UseCase<Reminder, CreateReminderParams> {
  final ReminderRepository repository;
  final NotificationHelper notificationHelper;

  CreateReminder(this.repository, this.notificationHelper);

  @override
  Future<Either<Failure, Reminder>> call(CreateReminderParams params) async {
    // Crear el recordatorio
    final result = await repository.createReminder(params.reminder);

    // Si se creó correctamente y tiene notificaciones habilitadas, programar alarma
    await result.fold(
      (failure) async {},
      (reminder) async {
        if (reminder.notificationEnabled &&
            reminder.dateTime.isAfter(DateTime.now())) {
          await notificationHelper.scheduleNotification(
            id: NotificationHelper.generateNotificationId(reminder.id),
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

class CreateReminderParams {
  final Reminder reminder;

  CreateReminderParams({required this.reminder});
}
