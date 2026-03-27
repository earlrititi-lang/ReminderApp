import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../datasources/reminder_local_datasource.dart';
import '../datasources/reminder_remote_datasource.dart';
import '../models/reminder_model.dart';

class ReminderRepositoryImpl implements ReminderRepository {
  final ReminderLocalDataSource localDataSource;
  final ReminderRemoteDataSource remoteDataSource;
  final bool isLocalEnabled;
  final bool isCloudEnabled;

  ReminderRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    this.isLocalEnabled = true,
    this.isCloudEnabled = true,
  });

  @override
  Future<Either<Failure, List<Reminder>>> getReminders() async {
    if (!isLocalEnabled && !isCloudEnabled) {
      return const Left(CacheFailure('No hay fuentes de datos habilitadas.'));
    }

    List<ReminderModel>? localReminders;
    List<ReminderModel>? remoteReminders;
    Failure? localFailure;
    Failure? remoteFailure;

    if (isLocalEnabled) {
      try {
        localReminders = await localDataSource.getReminders();
      } on CacheException catch (e) {
        localFailure = CacheFailure(e.message);
      } catch (e) {
        localFailure =
            CacheFailure('Error al obtener recordatorios locales: $e');
      }
    }

    if (isCloudEnabled) {
      try {
        remoteReminders = await remoteDataSource.getReminders();
      } on ServerException catch (e) {
        remoteFailure = ServerFailure(e.message);
      } catch (e) {
        remoteFailure = ServerFailure('Error inesperado: $e');
      }
    }

    if (localReminders != null && remoteReminders != null) {
      final mergedReminders = _mergeReminderModels(
        localReminders: localReminders,
        remoteReminders: remoteReminders,
      );
      await _reconcileSources(
        localReminders: localReminders,
        remoteReminders: remoteReminders,
        mergedReminders: mergedReminders,
      );
      return Right(mergedReminders.map((model) => model.toEntity()).toList());
    }

    if (remoteReminders != null) {
      if (isLocalEnabled) {
        try {
          await localDataSource.cacheReminders(remoteReminders);
        } catch (_) {
          // El retorno al usuario no depende de la caché local.
        }
      }
      return Right(remoteReminders.map((model) => model.toEntity()).toList());
    }

    if (localReminders != null) {
      return Right(localReminders.map((model) => model.toEntity()).toList());
    }

    return Left(
      remoteFailure ??
          localFailure ??
          const ServerFailure('No se pudieron cargar los recordatorios.'),
    );
  }

  @override
  Future<Either<Failure, Reminder>> getReminderById(String id) async {
    if (!isLocalEnabled && !isCloudEnabled) {
      return const Left(CacheFailure('No hay fuentes de datos habilitadas.'));
    }

    if (isLocalEnabled) {
      try {
        final reminder = await localDataSource.getReminderById(id);
        return Right(reminder.toEntity());
      } on CacheException {
        // Continuar con respaldo remoto si estÃ¡ habilitado.
      } catch (_) {
        // Continuar con respaldo remoto si estÃ¡ habilitado.
      }
    }

    if (isCloudEnabled) {
      try {
        final reminder = await remoteDataSource.getReminderById(id);
        if (isLocalEnabled) {
          await localDataSource.createReminder(reminder);
        }
        return Right(reminder.toEntity());
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Error al obtener recordatorio remoto: $e'));
      }
    }

    return const Left(CacheFailure('Recordatorio no disponible localmente.'));
  }

  @override
  Future<Either<Failure, Reminder>> createReminder(Reminder reminder) async {
    if (!isLocalEnabled && !isCloudEnabled) {
      return const Left(CacheFailure('No hay fuentes de datos habilitadas.'));
    }

    final model = ReminderModel.fromEntity(reminder);
    Failure? localFailure;
    Failure? remoteFailure;
    var localSuccess = false;
    var remoteSuccess = false;

    if (isLocalEnabled) {
      try {
        await localDataSource.createReminder(model);
        localSuccess = true;
      } on CacheException catch (e) {
        localFailure = CacheFailure(e.message);
      } catch (e) {
        localFailure = CacheFailure('Error al crear recordatorio local: $e');
      }
    }

    if (isCloudEnabled) {
      try {
        await remoteDataSource.createReminder(model);
        remoteSuccess = true;
      } on ServerException catch (e) {
        remoteFailure = ServerFailure(e.message);
      } catch (e) {
        remoteFailure = ServerFailure('Error al crear recordatorio remoto: $e');
      }
    }

    if (localSuccess || remoteSuccess) {
      return Right(model.toEntity());
    }

    return Left(
      localFailure ??
          remoteFailure ??
          const ServerFailure('Error al crear recordatorio.'),
    );
  }

  @override
  Future<Either<Failure, Reminder>> updateReminder(Reminder reminder) async {
    if (!isLocalEnabled && !isCloudEnabled) {
      return const Left(CacheFailure('No hay fuentes de datos habilitadas.'));
    }

    final model = ReminderModel.fromEntity(reminder);
    Failure? localFailure;
    Failure? remoteFailure;
    var localSuccess = false;
    var remoteSuccess = false;

    if (isLocalEnabled) {
      try {
        await localDataSource.updateReminder(model);
        localSuccess = true;
      } on CacheException catch (e) {
        localFailure = CacheFailure(e.message);
      } catch (e) {
        localFailure =
            CacheFailure('Error al actualizar recordatorio local: $e');
      }
    }

    if (isCloudEnabled) {
      try {
        await remoteDataSource.updateReminder(model);
        remoteSuccess = true;
      } on ServerException catch (e) {
        remoteFailure = ServerFailure(e.message);
      } catch (e) {
        remoteFailure =
            ServerFailure('Error al actualizar recordatorio remoto: $e');
      }
    }

    if (localSuccess || remoteSuccess) {
      return Right(model.toEntity());
    }

    return Left(
      localFailure ??
          remoteFailure ??
          const ServerFailure('Error al actualizar recordatorio.'),
    );
  }

  @override
  Future<Either<Failure, void>> deleteReminder(String id) async {
    if (!isLocalEnabled && !isCloudEnabled) {
      return const Left(CacheFailure('No hay fuentes de datos habilitadas.'));
    }

    ReminderModel? localSnapshot;
    if (isLocalEnabled) {
      try {
        localSnapshot = await localDataSource.getReminderById(id);
      } on CacheException {
        localSnapshot = null;
      } catch (_) {
        localSnapshot = null;
      }
    }

    Failure? localFailure;
    Failure? remoteFailure;
    var localSuccess = false;
    var remoteSuccess = false;

    if (isCloudEnabled) {
      try {
        await remoteDataSource.deleteReminder(id);
        remoteSuccess = true;
      } on ServerException catch (e) {
        remoteFailure = ServerFailure(e.message);
      } catch (e) {
        remoteFailure =
            ServerFailure('Error al eliminar recordatorio remoto: $e');
      }
    }

    if (isLocalEnabled && (!isCloudEnabled || remoteSuccess)) {
      try {
        await localDataSource.deleteReminder(id);
        localSuccess = true;
      } on CacheException catch (e) {
        if (_isNotFoundError(e.message)) {
          localSuccess = true;
        } else {
          localFailure = CacheFailure(e.message);
        }
      } catch (e) {
        if (e is CacheException && _isNotFoundError(e.message)) {
          localSuccess = true;
        } else {
          localFailure =
              CacheFailure('Error al eliminar recordatorio local: $e');
        }
      }
    }

    if (isLocalEnabled && isCloudEnabled) {
      if (remoteSuccess && localSuccess) {
        return const Right(null);
      }

      if (remoteSuccess && !localSuccess && localSnapshot != null) {
        try {
          await remoteDataSource.createReminder(localSnapshot);
        } catch (_) {
          // Se mantiene el fallo principal para informar al usuario.
        }
      }

      return Left(
        remoteFailure ??
            localFailure ??
            const ServerFailure('Error al eliminar recordatorio.'),
      );
    }

    if (localSuccess || remoteSuccess) {
      return const Right(null);
    }

    return Left(
      localFailure ??
          remoteFailure ??
          const ServerFailure('Error al eliminar recordatorio.'),
    );
  }

  @override
  Future<Either<Failure, void>> syncWithCloud() async {
    if (!isCloudEnabled) {
      return const Left(
        ServerFailure('Sincronizacion con la nube desactivada.'),
      );
    }
    if (!isLocalEnabled) {
      return const Left(
        CacheFailure('Sincronizacion local desactivada.'),
      );
    }
    try {
      final localReminders = await localDataSource.getReminders();
      final remoteReminders = await remoteDataSource.getReminders();
      final mergedReminders = _mergeReminderModels(
        localReminders: localReminders,
        remoteReminders: remoteReminders,
      );
      await _reconcileSources(
        localReminders: localReminders,
        remoteReminders: remoteReminders,
        mergedReminders: mergedReminders,
      );

      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Error al sincronizar: $e'));
    }
  }

  @override
  Stream<Either<Failure, List<Reminder>>> watchReminders() async* {
    if (!isLocalEnabled) {
      yield const Left(CacheFailure('Almacenamiento local desactivado.'));
      return;
    }
    try {
      yield* localDataSource.watchReminders().map(
            (reminders) => Right<Failure, List<Reminder>>(
              reminders.map((model) => model.toEntity()).toList(),
            ),
          );
    } catch (e) {
      yield Left(CacheFailure('Error al observar recordatorios: $e'));
    }
  }

  bool _isNotFoundError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('no encontrado');
  }

  List<ReminderModel> _mergeReminderModels({
    required List<ReminderModel> localReminders,
    required List<ReminderModel> remoteReminders,
  }) {
    final localById = {
      for (final reminder in localReminders) reminder.id: reminder,
    };
    final remoteById = {
      for (final reminder in remoteReminders) reminder.id: reminder,
    };

    final merged = <ReminderModel>[];
    for (final id in {...localById.keys, ...remoteById.keys}) {
      final preferred = _pickPreferredModel(
        localById[id],
        remoteById[id],
      );
      if (preferred != null) {
        merged.add(preferred);
      }
    }

    merged.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return merged;
  }

  Future<void> _reconcileSources({
    required List<ReminderModel> localReminders,
    required List<ReminderModel> remoteReminders,
    required List<ReminderModel> mergedReminders,
  }) async {
    if (isLocalEnabled) {
      try {
        await localDataSource.cacheReminders(mergedReminders);
      } catch (_) {
        // El merge ya se devuelve al usuario aunque la caché falle.
      }
    }

    if (!isCloudEnabled) {
      return;
    }

    final remoteById = {
      for (final reminder in remoteReminders) reminder.id: reminder,
    };

    for (final localReminder in localReminders) {
      final remoteReminder = remoteById[localReminder.id];
      if (remoteReminder == null) {
        try {
          await remoteDataSource.createReminder(localReminder);
        } catch (_) {
          // La siguiente sincronizacion volvera a intentarlo.
        }
        continue;
      }

      if (_isLocalNewer(localReminder, remoteReminder)) {
        try {
          await remoteDataSource.updateReminder(localReminder);
        } catch (_) {
          // La siguiente sincronizacion volvera a intentarlo.
        }
      }
    }
  }

  ReminderModel? _pickPreferredModel(
    ReminderModel? localReminder,
    ReminderModel? remoteReminder,
  ) {
    if (localReminder == null) return remoteReminder;
    if (remoteReminder == null) return localReminder;

    final localStamp = _lastModifiedAt(localReminder);
    final remoteStamp = _lastModifiedAt(remoteReminder);

    if (localStamp.isAfter(remoteStamp)) {
      return localReminder;
    }

    if (remoteStamp.isAfter(localStamp)) {
      return remoteReminder;
    }

    return remoteReminder;
  }

  bool _isLocalNewer(
    ReminderModel localReminder,
    ReminderModel remoteReminder,
  ) {
    final localStamp = _lastModifiedAt(localReminder);
    final remoteStamp = _lastModifiedAt(remoteReminder);
    return localStamp.isAfter(remoteStamp);
  }

  DateTime _lastModifiedAt(ReminderModel reminder) {
    return reminder.updatedAt ?? reminder.createdAt;
  }
}
