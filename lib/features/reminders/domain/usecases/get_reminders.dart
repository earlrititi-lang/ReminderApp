import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/reminder.dart';
import '../repositories/reminder_repository.dart';

class GetReminders implements UseCase<List<Reminder>, NoParams> {
  final ReminderRepository repository;

  GetReminders(this.repository);

  @override
  Future<Either<Failure, List<Reminder>>> call(NoParams params) async {
    return await repository.getReminders();
  }
}