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
    final result = await repository.updateReminder(params.reminder);

    await result.fold(
      (failure) async {},
      (reminder) async {
        await notificationHelper.scheduleReminderNotification(reminder);
      },
    );

    return result;
  }
}

class UpdateReminderParams {
  final Reminder reminder;

  UpdateReminderParams({required this.reminder});
}
