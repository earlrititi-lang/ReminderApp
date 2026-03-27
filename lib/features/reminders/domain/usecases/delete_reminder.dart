import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/notification_helper.dart';
import '../repositories/reminder_repository.dart';

class DeleteReminder implements UseCase<void, DeleteReminderParams> {
  final ReminderRepository repository;
  final NotificationHelper notificationHelper;

  DeleteReminder(this.repository, this.notificationHelper);

  @override
  Future<Either<Failure, void>> call(DeleteReminderParams params) async {
    final result = await repository.deleteReminder(params.id);

    await result.fold(
      (failure) async {},
      (_) async {
        await notificationHelper.cancelNotification(
          NotificationHelper.generateNotificationId(params.id),
        );
      },
    );

    return result;
  }
}

class DeleteReminderParams {
  final String id;

  DeleteReminderParams({required this.id});
}
