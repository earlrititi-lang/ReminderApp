import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../../core/error/exceptions.dart';
import '../models/reminder_model.dart';

abstract class ReminderLocalDataSource {
  Future<List<ReminderModel>> getReminders();
  Future<ReminderModel> getReminderById(String id);
  Future<ReminderModel> createReminder(ReminderModel reminder);
  Future<ReminderModel> updateReminder(ReminderModel reminder);
  Future<void> deleteReminder(String id);
  Future<void> cacheReminders(List<ReminderModel> reminders);
  Stream<List<ReminderModel>> watchReminders();
}

class ReminderLocalDataSourceImpl implements ReminderLocalDataSource {
  ReminderLocalDataSourceImpl({required this.file});

  final File file;
  final _changes = StreamController<List<ReminderModel>>.broadcast();
  List<ReminderModel>? _cache;
  Future<void> _writeQueue = Future<void>.value();

  DateTime _lastModifiedAt(ReminderModel reminder) {
    return reminder.updatedAt ?? reminder.createdAt;
  }

  List<ReminderModel> _dedupeReminders(Iterable<ReminderModel> reminders) {
    final remindersById = <String, ReminderModel>{};

    for (final reminder in reminders) {
      final existing = remindersById[reminder.id];
      if (existing == null ||
          !_lastModifiedAt(existing).isAfter(_lastModifiedAt(reminder))) {
        remindersById[reminder.id] = reminder;
      }
    }

    return remindersById.values.toList();
  }

  Future<T> _serializeWrite<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _writeQueue = _writeQueue.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<List<ReminderModel>> _readReminders() async {
    if (_cache != null) {
      return List<ReminderModel>.from(_cache!);
    }

    try {
      if (!await file.exists()) {
        _cache = <ReminderModel>[];
        return <ReminderModel>[];
      }

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        _cache = <ReminderModel>[];
        return <ReminderModel>[];
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        throw const FormatException('El archivo local no contiene una lista.');
      }

      final reminders = _dedupeReminders(
        decoded
            .whereType<Map>()
            .map((item) => ReminderModel.fromJson(
                  item.cast<String, dynamic>(),
                )),
      );
      _cache = reminders;
      return List<ReminderModel>.from(reminders);
    } catch (e) {
      throw CacheException('Error al leer recordatorios locales: $e');
    }
  }

  Future<void> _writeReminders(List<ReminderModel> reminders) async {
    try {
      final uniqueReminders = _dedupeReminders(reminders)
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
      await file.parent.create(recursive: true);
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(
        encoder.convert(uniqueReminders.map((item) => item.toJson()).toList()),
        flush: true,
      );
      _cache = uniqueReminders;
      _changes.add(List<ReminderModel>.from(uniqueReminders));
    } catch (e) {
      throw CacheException('Error al guardar recordatorios locales: $e');
    }
  }

  @override
  Future<List<ReminderModel>> getReminders() async {
    return _readReminders();
  }

  @override
  Future<ReminderModel> getReminderById(String id) async {
    final reminders = await _readReminders();
    final matches = reminders.where((reminder) => reminder.id == id);
    if (matches.isEmpty) {
      throw CacheException('Recordatorio no encontrado');
    }
    return matches.last;
  }

  @override
  Future<ReminderModel> createReminder(ReminderModel reminder) {
    return _serializeWrite(() async {
      final reminders = await _readReminders();
      reminders
        ..removeWhere((item) => item.id == reminder.id)
        ..add(reminder);
      await _writeReminders(reminders);
      return reminder;
    });
  }

  @override
  Future<ReminderModel> updateReminder(ReminderModel reminder) {
    return _serializeWrite(() async {
      final reminders = await _readReminders();
      reminders
        ..removeWhere((item) => item.id == reminder.id)
        ..add(reminder);
      await _writeReminders(reminders);
      return reminder;
    });
  }

  @override
  Future<void> deleteReminder(String id) {
    return _serializeWrite(() async {
      final reminders = await _readReminders();
      reminders.removeWhere((reminder) => reminder.id == id);
      await _writeReminders(reminders);
    });
  }

  @override
  Future<void> cacheReminders(List<ReminderModel> reminders) {
    return _serializeWrite(() => _writeReminders(reminders));
  }

  @override
  Stream<List<ReminderModel>> watchReminders() async* {
    yield await _readReminders();
    yield* _changes.stream;
  }
}
