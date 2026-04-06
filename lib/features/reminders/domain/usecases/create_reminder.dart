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
    final result = await repository.createReminder(params.reminder);

    await result.fold(
      (failure) async {},
      (reminder) async {
        await notificationHelper.scheduleReminderNotification(reminder);
      },
    );

    return result;
  }
}

class CreateReminderParams {
  final Reminder reminder;

  CreateReminderParams({required this.reminder});
}
