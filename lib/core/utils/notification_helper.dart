import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

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

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const MethodChannel _alarmChannel =
      MethodChannel('com.example.reminder_app/alarm_sound');

  bool _initialized = false;
  void Function(ReminderNotificationResponse response)? _onTapHandler;

  /// Inicializa el sistema de notificaciones
  Future<void> initialize() async {
    if (_initialized) return;

    // Inicializar zonas horarias
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Madrid'));

    // Configuracion para Android
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Solicitar permisos
    await _requestPermissions();

    // Crear canal de notificacion base
    await _createNotificationChannel();

    _initialized = true;
  }

  /// Crea el canal de notificacion con maxima prioridad
  Future<void> _createNotificationChannel() async {
    await _ensureAndroidChannel(
      useCustomSound: true,
      vibrationEnabled: true,
    );
    debugPrint('Canal de notificacion creado');
  }

  Future<String> _ensureAndroidChannel({
    required bool useCustomSound,
    required bool vibrationEnabled,
  }) async {
    final soundTag = useCustomSound ? 'alarm' : 'system';
    final vibTag = vibrationEnabled ? 'vib' : 'novib';
    final channelId = 'critical_alarms_${soundTag}_$vibTag';
    final channelName =
        useCustomSound ? 'Alarmas (alarma)' : 'Alarmas (sistema)';
    final channelDescription = vibrationEnabled
        ? 'Notificaciones de alarma con vibracion'
        : 'Notificaciones de alarma sin vibracion';

    final androidChannel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: vibrationEnabled,
      vibrationPattern: vibrationEnabled
          ? Int64List.fromList([0, 1000, 500, 1000, 500, 1000])
          : null,
      enableLights: true,
      showBadge: true,
      sound: useCustomSound
          ? const RawResourceAndroidNotificationSound('alarm')
          : null,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    return channelId;
  }

  /// Solicita permisos necesarios para notificaciones invasivas
  Future<void> _requestPermissions() async {
    // Permiso de notificaciones (Android 13+)
    final notificationStatus = await Permission.notification.request();
    debugPrint('Permiso notificaciones: ${notificationStatus.isGranted}');

    // Permiso para alarmas exactas (Android 12+)
    final alarmStatus = await Permission.scheduleExactAlarm.request();
    debugPrint('Permiso alarmas exactas: ${alarmStatus.isGranted}');
  }

  /// Maneja el tap en la notificacion
  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notificacion tocada: ${response.payload}');
    if (response.actionId == 'stop_alarm') {
      stopAlarmSound();
      return;
    }
    stopAlarmSound();
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

  Future<void> startAlarmSound() async {
    try {
      await _alarmChannel.invokeMethod('startAlarm');
    } on PlatformException catch (e) {
      debugPrint('Error al iniciar sonido de alarma: $e');
    }
  }

  Future<void> stopAlarmSound() async {
    try {
      await _alarmChannel.invokeMethod('stopAlarm');
    } on PlatformException catch (e) {
      debugPrint('Error al detener sonido de alarma: $e');
    }
  }

  Future<void> _scheduleAlarmSound({
    required int id,
    required DateTime scheduledDate,
  }) async {
    try {
      await _alarmChannel.invokeMethod('scheduleAlarm', {
        'id': id,
        'timestamp': scheduledDate.millisecondsSinceEpoch,
      });
    } on PlatformException catch (e) {
      debugPrint('Error al programar sonido de alarma: $e');
    }
  }

  Future<void> _cancelAlarmSound(int id) async {
    try {
      await _alarmChannel.invokeMethod('cancelAlarm', {'id': id});
    } on PlatformException catch (e) {
      debugPrint('Error al cancelar sonido de alarma: $e');
    }
  }

  bool _isInvalidSoundException(Object error) {
    return error is PlatformException && error.code == 'invalid_sound';
  }

  /// Programa una notificacion para una fecha especifica
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
    if (!_initialized) await initialize();
    if (customSoundPath != null && customSoundPath.isNotEmpty) {
      // Placeholder para soporte futuro de sonidos personalizados por ruta.
    }

    // Verificar que la fecha sea futura
    if (scheduledDate.isBefore(DateTime.now())) {
      debugPrint('No se puede programar alarma en el pasado');
      return;
    }

    // Convertir a TZDateTime
    final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

    final channelId = await _ensureAndroidChannel(
      useCustomSound: useCustomSound,
      vibrationEnabled: vibrationEnabled,
    );
    final channelName =
        useCustomSound ? 'Alarmas (alarma)' : 'Alarmas (sistema)';
    final channelDescription = vibrationEnabled
        ? 'Notificaciones de alarma con vibracion'
        : 'Notificaciones de alarma sin vibracion';

    // Detalles de Android (configuracion invasiva)
    AndroidNotificationDetails buildAndroidDetails({
      required bool useCustomSound,
      required String channelId,
    }) {
      return AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,

        // Prioridad maxima
        importance: Importance.max,
        priority: Priority.max,

        // Sonido y vibracion
        playSound: true,
        sound: useCustomSound
            ? const RawResourceAndroidNotificationSound('alarm')
            : null,
        enableVibration: vibrationEnabled,
        vibrationPattern: vibrationEnabled
            ? Int64List.fromList([
                0,
                1000,
                500,
                1000,
                500,
                1000,
                500,
                1000,
              ])
            : null,

        // Intentos de pantalla completa
        fullScreenIntent: true,

        // Comportamiento persistente
        autoCancel: false,
        ongoing: true,

        // Visibilidad
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.alarm,

        // Iconos y colores
        color: const Color.fromARGB(255, 13, 33, 184),
        colorized: true,
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),

        // Informacion temporal
        showWhen: true,
        when: scheduledDate.millisecondsSinceEpoch,

        // Estilo de texto expandido
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: 'Recordatorio',
          htmlFormatBigText: true,
          htmlFormatContentTitle: true,
        ),

        // Acciones rapidas
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            'stop_alarm',
            'Detener',
            showsUserInterface: false,
          ),
          const AndroidNotificationAction(
            'mark_done',
            'Completar',
            showsUserInterface: true,
          ),
          const AndroidNotificationAction(
            'snooze_10',
            '+10 min',
            showsUserInterface: true,
          ),
        ],
      );
    }

    final notificationDetails = NotificationDetails(
      android: buildAndroidDetails(
        useCustomSound: useCustomSound,
        channelId: channelId,
      ),
    );

    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tzScheduledDate,
        notificationDetails,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      if (loopSound) {
        await _scheduleAlarmSound(id: id, scheduledDate: scheduledDate);
      }
      debugPrint('Notificacion programada para: $scheduledDate (ID: $id)');
    } on PlatformException catch (e) {
      if (useCustomSound && _isInvalidSoundException(e)) {
        debugPrint(
          'Sonido no encontrado, reintentando sin sonido personalizado.',
        );
        final fallbackChannelId = await _ensureAndroidChannel(
          useCustomSound: false,
          vibrationEnabled: vibrationEnabled,
        );
        final fallbackDetails = NotificationDetails(
          android: buildAndroidDetails(
            useCustomSound: false,
            channelId: fallbackChannelId,
          ),
        );
        try {
          await _notifications.zonedSchedule(
            id,
            title,
            body,
            tzScheduledDate,
            fallbackDetails,
            payload: payload,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );

          if (loopSound) {
            await _scheduleAlarmSound(id: id, scheduledDate: scheduledDate);
          }
          debugPrint(
            'Notificacion programada sin sonido personalizado (ID: $id)',
          );
        } catch (e) {
          debugPrint('Error al programar notificacion: $e');
        }
        return;
      }
      debugPrint('Error al programar notificacion: $e');
    } catch (e) {
      debugPrint('Error al programar notificacion: $e');
    }
  }

  /// Muestra una notificacion inmediata INVASIVA (para testing)
  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool loopSound = false,
    bool useCustomSound = true,
    bool vibrationEnabled = true,
  }) async {
    if (!_initialized) await initialize();

    if (loopSound) {
      await startAlarmSound();
    }

    final channelId = await _ensureAndroidChannel(
      useCustomSound: useCustomSound,
      vibrationEnabled: vibrationEnabled,
    );
    final channelName =
        useCustomSound ? 'Alarmas (alarma)' : 'Alarmas (sistema)';
    final channelDescription = vibrationEnabled
        ? 'Notificaciones de alarma con vibracion'
        : 'Notificaciones de alarma sin vibracion';

    AndroidNotificationDetails buildAndroidDetails({
      required bool useCustomSound,
      required String channelId,
    }) {
      return AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: useCustomSound
            ? const RawResourceAndroidNotificationSound('alarm')
            : null,
        enableVibration: vibrationEnabled,
        vibrationPattern: vibrationEnabled
            ? Int64List.fromList([0, 1000, 500, 1000, 500, 1000])
            : null,
        fullScreenIntent: true,
        autoCancel: false,
        ongoing: true,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.alarm,
        color: const Color(0xFFFF0000),
        colorized: true,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: 'Notificacion de prueba',
        ),
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            'stop_alarm',
            'Detener',
            showsUserInterface: false,
          ),
        ],
      );
    }

    final notificationDetails = NotificationDetails(
      android: buildAndroidDetails(
        useCustomSound: useCustomSound,
        channelId: channelId,
      ),
    );

    try {
      await _notifications.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      debugPrint('Notificacion inmediata mostrada (ID: $id)');
    } on PlatformException catch (e) {
      if (useCustomSound && _isInvalidSoundException(e)) {
        debugPrint(
          'Sonido no encontrado, reintentando sin sonido personalizado.',
        );
        final fallbackChannelId = await _ensureAndroidChannel(
          useCustomSound: false,
          vibrationEnabled: vibrationEnabled,
        );
        final fallbackDetails = NotificationDetails(
          android: buildAndroidDetails(
            useCustomSound: false,
            channelId: fallbackChannelId,
          ),
        );
        try {
          await _notifications.show(
            id,
            title,
            body,
            fallbackDetails,
            payload: payload,
          );
          debugPrint(
            'Notificacion inmediata mostrada sin sonido personalizado (ID: $id)',
          );
        } catch (e) {
          debugPrint('Error al mostrar notificacion: $e');
        }
        return;
      }
      debugPrint('Error al mostrar notificacion: $e');
    } catch (e) {
      debugPrint('Error al mostrar notificacion: $e');
    }
  }

  /// Cancela una notificacion especifica
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
    await _cancelAlarmSound(id);
    debugPrint('Notificacion $id ha sido cancelada');
  }

  /// Cancela todas las notificaciones
  Future<void> cancelAllNotifications() async {
    final pending = await _notifications.pendingNotificationRequests();
    for (final notification in pending) {
      await _cancelAlarmSound(notification.id);
    }
    await _notifications.cancelAll();
    await stopAlarmSound();
    debugPrint('Todas las notificaciones canceladas');
  }

  /// Obtiene notificaciones pendientes
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Verifica si tiene permisos
  Future<bool> hasPermissions() async {
    final notification = await Permission.notification.isGranted;
    final exactAlarm = await Permission.scheduleExactAlarm.isGranted;
    return notification && exactAlarm;
  }

  /// Genera un ID unico para la notificacion
  static int generateNotificationId(String reminderId) {
    var hash = 0x811C9DC5;
    for (final codeUnit in reminderId.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
