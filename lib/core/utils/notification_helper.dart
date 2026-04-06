import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../features/reminders/domain/entities/reminder.dart';

class ReminderNotificationResponse {
  final String? actionId;
  final String? payload;

  const ReminderNotificationResponse({
    required this.actionId,
    required this.payload,
  });
}

class NotificationHelper {
  static final NotificationHelper _instance = NotificationHelper._internal();

  factory NotificationHelper() => _instance;

  NotificationHelper._internal();

  static const _androidChannelId = 'reminder_alerts';
  static const _androidChannelName = 'Recordatorios';
  static const _androidChannelDescription =
      'Notificaciones de recordatorios pendientes';
  static const _iosReminderCategoryId = 'reminder_actions_v2';
  static const _defaultReminderBody = 'Tienes un recordatorio pendiente';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  void Function(ReminderNotificationResponse response)? _onTapHandler;

  AndroidFlutterLocalNotificationsPlugin? _androidPlugin() {
    try {
      return _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
    } catch (_) {
      return null;
    }
  }

  IOSFlutterLocalNotificationsPlugin? _iosPlugin() {
    try {
      return _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
    } catch (_) {
      return null;
    }
  }

  bool get _hasPlatformImplementation =>
      _androidPlugin() != null || _iosPlugin() != null;

  Future<void> initialize() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Madrid'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestSoundPermission: false,
      requestBadgePermission: false,
      defaultPresentAlert: true,
      defaultPresentSound: true,
      defaultPresentBadge: true,
      defaultPresentBanner: true,
      defaultPresentList: true,
      notificationCategories: <DarwinNotificationCategory>[
        DarwinNotificationCategory(
          _iosReminderCategoryId,
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain(
              'mark_done',
              'Completar',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'snooze_10',
              '+10 min',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
        ),
      ],
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    if (!_hasPlatformImplementation) {
      _initialized = true;
      return;
    }

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    await _requestPermissions();
    await _createNotificationChannel();

    _initialized = true;
  }

  Future<void> _createNotificationChannel() async {
    final androidPlugin = _androidPlugin();
    if (androidPlugin == null) {
      return;
    }

    const channel = AndroidNotificationChannel(
      _androidChannelId,
      _androidChannelName,
      description: _androidChannelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await androidPlugin.createNotificationChannel(channel);
  }

  Future<void> _requestPermissions() async {
    final androidPlugin = _androidPlugin();
    if (androidPlugin != null) {
      final notificationsGranted =
          await androidPlugin.requestNotificationsPermission();
      final exactAlarmGranted =
          await androidPlugin.requestExactAlarmsPermission();
      if (kDebugMode) {
        debugPrint(
          'Permisos Android -> notificaciones: '
          '${notificationsGranted ?? false}, exactas: '
          '${exactAlarmGranted ?? false}',
        );
      }
    }

    final iosPlugin = _iosPlugin();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (kDebugMode) {
        debugPrint('Permisos iOS -> notificaciones: ${granted ?? false}');
      }
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    if (_onTapHandler != null) {
      _onTapHandler!(
        ReminderNotificationResponse(
          actionId: response.actionId,
          payload: response.payload,
        ),
      );
    }
  }

  void setOnNotificationTap(
    void Function(ReminderNotificationResponse response)? handler,
  ) {
    _onTapHandler = handler;
  }

  static bool shouldScheduleReminder(
    Reminder reminder, {
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    return reminder.notificationEnabled &&
        !reminder.isCompleted &&
        reminder.dateTime.isAfter(currentTime);
  }

  Future<void> scheduleReminderNotification(Reminder reminder) async {
    final notificationId = generateNotificationId(reminder.id);
    if (!shouldScheduleReminder(reminder)) {
      await cancelNotification(notificationId);
      return;
    }

    await cancelNotification(notificationId);
    await scheduleNotification(
      id: notificationId,
      title: reminder.title,
      body: _buildReminderBody(reminder),
      scheduledDate: reminder.dateTime,
      payload: reminder.id,
      useCustomSound: _usesProminentDelivery(reminder.soundPath),
      customSoundPath: reminder.soundPath,
      vibrationEnabled: reminder.vibrationEnabled,
    );
  }

  Future<void> syncReminderNotifications(Iterable<Reminder> reminders) async {
    if (!_initialized) {
      await initialize();
    }

    final remindersToSchedule = reminders
        .where((reminder) => shouldScheduleReminder(reminder))
        .toList();
    final desiredIds = remindersToSchedule
        .map((reminder) => generateNotificationId(reminder.id))
        .toSet();

    final pendingNotifications = await getPendingNotifications();
    for (final pendingNotification in pendingNotifications) {
      if (!desiredIds.contains(pendingNotification.id)) {
        await cancelNotification(pendingNotification.id);
      }
    }

    for (final reminder in remindersToSchedule) {
      await scheduleReminderNotification(reminder);
    }
  }

  String _buildReminderBody(Reminder reminder) {
    final description = reminder.description?.trim();
    if (description == null || description.isEmpty) {
      return _defaultReminderBody;
    }
    return description;
  }

  bool _usesProminentDelivery(String? soundPath) {
    return soundPath != null && soundPath.trim().isNotEmpty;
  }

  DarwinNotificationDetails _buildDarwinDetails({
    required bool useProminentDelivery,
  }) {
    return DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
      categoryIdentifier: _iosReminderCategoryId,
      threadIdentifier: 'reminders',
      interruptionLevel: useProminentDelivery
          ? InterruptionLevel.timeSensitive
          : InterruptionLevel.active,
    );
  }

  AndroidNotificationDetails _buildAndroidDetails({
    required bool vibrationEnabled,
  }) {
    return AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: vibrationEnabled,
      category: AndroidNotificationCategory.reminder,
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'mark_done',
          'Completar',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'snooze_10',
          '+10 min',
          showsUserInterface: true,
        ),
      ],
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    bool useCustomSound = false,
    String? customSoundPath,
    bool loopSound = false,
    bool vibrationEnabled = true,
  }) async {
    if (!_initialized) {
      await initialize();
    }
    if (!_hasPlatformImplementation) {
      return;
    }
    if (customSoundPath != null && customSoundPath.isNotEmpty) {
      // El valor se conserva como preferencia de estilo, no como ruta nativa.
    }
    if (loopSound) {
      // iOS no mantiene un loop local; la preferencia se resuelve en la entrega.
    }

    if (!scheduledDate.isAfter(DateTime.now())) {
      if (kDebugMode) {
        debugPrint('No se puede programar una notificacion en el pasado.');
      }
      return;
    }

    final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);
    final notificationDetails = NotificationDetails(
      android: _buildAndroidDetails(vibrationEnabled: vibrationEnabled),
      iOS: _buildDarwinDetails(
        useProminentDelivery: useCustomSound,
      ),
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tzScheduledDate,
      notificationDetails,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    if (kDebugMode) {
      debugPrint('Notificacion programada para: $scheduledDate (ID: $id)');
    }
  }

  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool loopSound = false,
    bool useCustomSound = true,
    bool vibrationEnabled = true,
  }) async {
    if (!_initialized) {
      await initialize();
    }
    if (!_hasPlatformImplementation) {
      return;
    }
    if (loopSound) {
      // iOS no usa un servicio nativo extra para mantener audio en loop.
    }

    final notificationDetails = NotificationDetails(
      android: _buildAndroidDetails(vibrationEnabled: vibrationEnabled),
      iOS: _buildDarwinDetails(
        useProminentDelivery: useCustomSound,
      ),
    );

    await _notifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    if (kDebugMode) {
      debugPrint('Notificacion inmediata mostrada (ID: $id)');
    }
  }

  Future<void> cancelNotification(int id) async {
    if (!_initialized) {
      await initialize();
    }
    if (!_hasPlatformImplementation) {
      return;
    }
    await _notifications.cancel(id);
    if (kDebugMode) {
      debugPrint('Notificacion $id cancelada');
    }
  }

  Future<void> cancelAllNotifications() async {
    if (!_initialized) {
      await initialize();
    }
    if (!_hasPlatformImplementation) {
      return;
    }
    await _notifications.cancelAll();
    if (kDebugMode) {
      debugPrint('Todas las notificaciones canceladas');
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_initialized) {
      await initialize();
    }
    if (!_hasPlatformImplementation) {
      return const <PendingNotificationRequest>[];
    }
    return _notifications.pendingNotificationRequests();
  }

  Future<bool> hasPermissions() async {
    final androidPlugin = _androidPlugin();
    if (androidPlugin != null) {
      final notificationsEnabled =
          await androidPlugin.areNotificationsEnabled() ?? false;
      final canScheduleExact =
          await androidPlugin.canScheduleExactNotifications() ?? false;
      return notificationsEnabled && canScheduleExact;
    }

    final iosPlugin = _iosPlugin();
    if (iosPlugin != null) {
      final permissions = await iosPlugin.checkPermissions();
      return permissions?.isEnabled ?? false;
    }

    return false;
  }

  static int generateNotificationId(String reminderId) {
    var hash = 0x811C9DC5;
    for (final codeUnit in reminderId.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
