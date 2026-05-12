import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../datasources/reminder_local_datasource.dart';
import '../models/reminder_model.dart';

class ReminderRepositoryImpl implements ReminderRepository {
  ReminderRepositoryImpl({required this.localDataSource});

  final ReminderLocalDataSource localDataSource;

  @override
  Future<Either<Failure, List<Reminder>>> getReminders() async {
    try {
      final reminders = await localDataSource.getReminders();
      return Right(reminders.map((model) => model.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(CacheFailure('Error al obtener recordatorios locales: $e'));
    }
  }

  @override
  Future<Either<Failure, Reminder>> getReminderById(String id) async {
    try {
      final reminder = await localDataSource.getReminderById(id);
      return Right(reminder.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(CacheFailure('Error al obtener recordatorio local: $e'));
    }
  }

  @override
  Future<Either<Failure, Reminder>> createReminder(Reminder reminder) async {
    try {
      final model = ReminderModel.fromEntity(reminder);
      await localDataSource.createReminder(model);
      return Right(model.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(CacheFailure('Error al crear recordatorio local: $e'));
    }
  }

  @override
  Future<Either<Failure, Reminder>> updateReminder(Reminder reminder) async {
    try {
      final model = ReminderModel.fromEntity(reminder);
      await localDataSource.updateReminder(model);
      return Right(model.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(CacheFailure('Error al actualizar recordatorio local: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteReminder(String id) async {
    try {
      await localDataSource.deleteReminder(id);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(CacheFailure('Error al eliminar recordatorio local: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> syncWithCloud() async {
    return const Left(ServerFailure('La sincronizacion en la nube fue eliminada.'));
  }

  @override
  Stream<Either<Failure, List<Reminder>>> watchReminders() async* {
    try {
      yield* localDataSource.watchReminders().map(
            (reminders) => Right<Failure, List<Reminder>>(
              reminders.map((model) => model.toEntity()).toList(),
            ),
          );
    } catch (e) {
      yield Left(CacheFailure('Error al observar recordatorios locales: $e'));
    }
  }
}
