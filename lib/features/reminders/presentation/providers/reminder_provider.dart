import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/settings/app_settings_provider.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/notification_helper.dart';
import '../../data/datasources/reminder_local_datasource.dart';
import '../../data/datasources/reminder_remote_datasource.dart';
import '../../data/repositories/reminder_repository_impl.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../../domain/usecases/create_reminder.dart';
import '../../domain/usecases/delete_reminder.dart';
import '../../domain/usecases/get_reminders.dart';
import '../../domain/usecases/update_reminder.dart';

final isarProvider = Provider<Isar>((ref) {
  throw UnimplementedError('Isar debe ser inicializado en main.dart');
});

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final uuidProvider = Provider<Uuid>((ref) {
  return const Uuid();
});

final localDataSourceProvider = Provider<ReminderLocalDataSource>((ref) {
  final isar = ref.watch(isarProvider);
  return ReminderLocalDataSourceImpl(isar: isar);
});

final remoteDataSourceProvider = Provider<ReminderRemoteDataSource>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);
  return ReminderRemoteDataSourceImpl(
    firestore: firestore,
    auth: auth,
  );
});

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  final localDataSource = ref.watch(localDataSourceProvider);
  final remoteDataSource = ref.watch(remoteDataSourceProvider);
  final syncSettings = ref.watch(
    appSettingsProvider.select(
      (settings) => (settings.isarEnabled, settings.firebaseEnabled),
    ),
  );
  return ReminderRepositoryImpl(
    localDataSource: localDataSource,
    remoteDataSource: remoteDataSource,
    isLocalEnabled: syncSettings.$1,
    isCloudEnabled: syncSettings.$2,
  );
});

final notificationHelperProvider = Provider<NotificationHelper>((ref) {
  return NotificationHelper();
});

final getRemindersUseCaseProvider = Provider<GetReminders>((ref) {
  final repository = ref.watch(reminderRepositoryProvider);
  return GetReminders(repository);
});

final createReminderUseCaseProvider = Provider<CreateReminder>((ref) {
  final repository = ref.watch(reminderRepositoryProvider);
  final notificationHelper = ref.watch(notificationHelperProvider);
  return CreateReminder(repository, notificationHelper);
});

final updateReminderUseCaseProvider = Provider<UpdateReminder>((ref) {
  final repository = ref.watch(reminderRepositoryProvider);
  final notificationHelper = ref.watch(notificationHelperProvider);
  return UpdateReminder(repository, notificationHelper);
});

final deleteReminderUseCaseProvider = Provider<DeleteReminder>((ref) {
  final repository = ref.watch(reminderRepositoryProvider);
  final notificationHelper = ref.watch(notificationHelperProvider);
  return DeleteReminder(repository, notificationHelper);
});

@immutable
class RemindersState {
  final List<Reminder> reminders;
  final bool isLoading;
  final String? error;
  final bool isSyncing;

  const RemindersState({
    this.reminders = const [],
    this.isLoading = false,
    this.error,
    this.isSyncing = false,
  });

  RemindersState copyWith({
    List<Reminder>? reminders,
    bool? isLoading,
    String? error,
    bool? isSyncing,
  }) {
    return RemindersState(
      reminders: reminders ?? this.reminders,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}

class RemindersNotifier extends StateNotifier<RemindersState> {
  final ReminderRepository repository;
  final GetReminders getReminders;
  final CreateReminder createReminder;
  final UpdateReminder updateReminder;
  final DeleteReminder deleteReminder;
  final Uuid uuid;
  final bool isLocalEnabled;

  StreamSubscription<Either<Failure, List<Reminder>>>? _remindersSubscription;

  static const _reorderDelay = Duration(milliseconds: 350);

  RemindersNotifier({
    required this.repository,
    required this.getReminders,
    required this.createReminder,
    required this.updateReminder,
    required this.deleteReminder,
    required this.uuid,
    required this.isLocalEnabled,
  }) : super(const RemindersState()) {
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await loadReminders();
    await _bindReminderStream();
  }

  Future<void> _bindReminderStream() async {
    await _remindersSubscription?.cancel();
    if (!isLocalEnabled) {
      return;
    }

    _remindersSubscription = repository.watchReminders().listen(
      (result) {
        result.fold(
          (failure) {
            state = state.copyWith(
              isLoading: false,
              error: failure.message,
            );
          },
          _applyLoadedReminders,
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        state = state.copyWith(
          isLoading: false,
          error: 'Error al observar recordatorios: $error',
        );
      },
    );
  }

  List<Reminder> _sortReminders(List<Reminder> reminders) {
    final pending = reminders.where((r) => !r.isCompleted).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final completed = reminders.where((r) => r.isCompleted).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return [...pending, ...completed];
  }

  void _applyLoadedReminders(List<Reminder> reminders) {
    final sortedReminders = _sortReminders(reminders);
    if (listEquals(sortedReminders, state.reminders) &&
        state.error == null &&
        !state.isLoading) {
      return;
    }

    state = state.copyWith(
      reminders: sortedReminders,
      isLoading: false,
      error: null,
    );
  }

  Future<void> loadReminders({bool showLoading = true}) async {
    if (showLoading) {
      state = state.copyWith(isLoading: true, error: null);
    }

    final result = await getReminders(NoParams());
    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
      _applyLoadedReminders,
    );
  }

  Future<bool> addReminder({
    required String title,
    String? description,
    required DateTime dateTime,
    bool notificationEnabled = true,
    bool vibrationEnabled = true,
    String? soundPath,
  }) async {
    final reminder = Reminder(
      id: uuid.v4(),
      title: title,
      description: description,
      dateTime: dateTime,
      createdAt: DateTime.now(),
      notificationEnabled: notificationEnabled,
      vibrationEnabled: vibrationEnabled,
      soundPath: soundPath,
    );

    final result = await createReminder(
      CreateReminderParams(reminder: reminder),
    );

    result.fold(
      (failure) => state = state.copyWith(error: failure.message),
      (createdReminder) {
        final updatedList =
            _sortReminders([...state.reminders, createdReminder]);
        state = state.copyWith(reminders: updatedList, error: null);
      },
    );

    return result.isRight();
  }

  Future<bool> updateReminderItem(Reminder reminder) async {
    final result = await updateReminder(
      UpdateReminderParams(reminder: reminder),
    );

    result.fold(
      (failure) => state = state.copyWith(error: failure.message),
      (updatedReminder) {
        final existingIndex = state.reminders.indexWhere(
          (item) => item.id == updatedReminder.id,
        );
        final nextReminders = [...state.reminders];
        if (existingIndex == -1) {
          nextReminders.add(updatedReminder);
        } else {
          nextReminders[existingIndex] = updatedReminder;
        }
        state = state.copyWith(
          reminders: _sortReminders(nextReminders),
          error: null,
        );
      },
    );

    return result.isRight();
  }

  Future<void> toggleComplete(String id) async {
    final index = state.reminders.indexWhere((reminder) => reminder.id == id);
    if (index == -1) return;

    final currentReminder = state.reminders[index];
    final updatedReminder = currentReminder.copyWith(
      isCompleted: !currentReminder.isCompleted,
      updatedAt: DateTime.now(),
    );
    final previousList = state.reminders;
    final optimisticList = [...previousList];
    optimisticList[index] = updatedReminder;
    state = state.copyWith(reminders: optimisticList, error: null);

    final result = await updateReminder(
      UpdateReminderParams(reminder: updatedReminder),
    );

    result.fold(
      (failure) {
        state = state.copyWith(
          reminders: previousList,
          error: failure.message,
        );
      },
      (savedReminder) {
        final refreshedList = [...state.reminders];
        final refreshedIndex = refreshedList.indexWhere(
          (reminder) => reminder.id == savedReminder.id,
        );
        if (refreshedIndex != -1) {
          refreshedList[refreshedIndex] = savedReminder;
          state = state.copyWith(reminders: refreshedList, error: null);
        }
      },
    );

    await Future.delayed(_reorderDelay);
    final latestReminder = state.reminders.firstWhere(
      (reminder) => reminder.id == id,
      orElse: () => currentReminder,
    );
    if (latestReminder.isCompleted == updatedReminder.isCompleted) {
      state = state.copyWith(reminders: _sortReminders(state.reminders));
    }
  }

  Future<bool> removeReminder(String id) async {
    final result = await deleteReminder(
      DeleteReminderParams(id: id),
    );

    return result.fold(
      (failure) {
        state = state.copyWith(error: failure.message);
        return false;
      },
      (_) {
        final updatedList =
            state.reminders.where((reminder) => reminder.id != id).toList();
        state = state.copyWith(reminders: updatedList, error: null);
        return true;
      },
    );
  }

  Future<void> applyNotificationDefaults({
    required bool vibrationEnabled,
    required String? soundPath,
  }) async {
    final snapshot = List<Reminder>.from(state.reminders);
    for (final reminder in snapshot) {
      if (reminder.vibrationEnabled == vibrationEnabled &&
          reminder.soundPath == soundPath) {
        continue;
      }
      final updatedReminder = reminder.copyWith(
        vibrationEnabled: vibrationEnabled,
        soundPath: soundPath,
        updatedAt: DateTime.now(),
      );
      await updateReminderItem(updatedReminder);
    }
  }

  @override
  void dispose() {
    unawaited(_remindersSubscription?.cancel());
    super.dispose();
  }
}

final remindersNotifierProvider =
    StateNotifierProvider<RemindersNotifier, RemindersState>((ref) {
  return RemindersNotifier(
    repository: ref.watch(reminderRepositoryProvider),
    getReminders: ref.watch(getRemindersUseCaseProvider),
    createReminder: ref.watch(createReminderUseCaseProvider),
    updateReminder: ref.watch(updateReminderUseCaseProvider),
    deleteReminder: ref.watch(deleteReminderUseCaseProvider),
    uuid: ref.watch(uuidProvider),
    isLocalEnabled: ref.watch(
      appSettingsProvider.select((settings) => settings.isarEnabled),
    ),
  );
});

final pendingRemindersProvider = Provider<List<Reminder>>((ref) {
  final state = ref.watch(remindersNotifierProvider);
  return state.reminders.where((reminder) => !reminder.isCompleted).toList();
});

final completedRemindersProvider = Provider<List<Reminder>>((ref) {
  final state = ref.watch(remindersNotifierProvider);
  return state.reminders.where((reminder) => reminder.isCompleted).toList();
});
