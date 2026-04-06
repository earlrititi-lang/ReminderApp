import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/utils/firebase_support.dart';
import 'core/utils/notification_helper.dart';
import 'core/theme/app_colors.dart';
import 'features/reminders/data/models/reminder_model.dart';
import 'features/reminders/domain/entities/reminder.dart';
import 'features/reminders/presentation/pages/home_page.dart';
import 'features/reminders/presentation/providers/reminder_provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configurar orientación (solo portrait)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Configurar barra de estado
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const AppBootstrap());
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  Isar? _isar;
  ProviderContainer? _container;
  Object? _bootstrapError;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    NotificationHelper().setOnNotificationTap(null);
    _container?.dispose();
    final isar = _isar;
    if (isar != null && isar.isOpen) {
      unawaited(isar.close());
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final firebaseReady = await _initializeFirebase();
      if (firebaseReady) {
        await _signInAnonymouslySafe();
      }
      await _initializeNotifications();
      await initializeDateFormatting('es_ES');

      final dir = await getApplicationDocumentsDirectory();
      final isar = await Isar.open(
        [ReminderModelSchema],
        directory: dir.path,
      );
      final container = ProviderContainer(
        overrides: [
          isarProvider.overrideWithValue(isar),
        ],
      );
      await _restorePendingNotifications(container);
      _configureNotificationHandling(container);

      if (!mounted) return;
      setState(() {
        _isar = isar;
        _container = container;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bootstrapError = e;
      });
    }
  }

  Future<bool> _initializeFirebase() async {
    if (!isFirebaseConfiguredForCurrentPlatform()) {
      if (kDebugMode) {
        debugPrint('Firebase no configurado para esta plataforma.');
      }
      return false;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Firebase no disponible: $e');
      }
      return Firebase.apps.isNotEmpty;
    }
  }

  Future<void> _initializeNotifications() async {
    final notificationHelper = NotificationHelper();
    await notificationHelper.initialize();
  }

  Future<void> _restorePendingNotifications(ProviderContainer container) async {
    try {
      final localDataSource = container.read(localDataSourceProvider);
      final notificationHelper = container.read(notificationHelperProvider);
      final reminders = (await localDataSource.getReminders())
          .map((model) => model.toEntity())
          .toList();
      await notificationHelper.syncReminderNotifications(reminders);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('No se pudieron reprogramar recordatorios locales: $e');
      }
    }
  }

  Future<void> _signInAnonymouslySafe() async {
    if (Firebase.apps.isEmpty) {
      return;
    }

    final auth = FirebaseAuth.instance;
    if (auth.currentUser != null) return;
    try {
      await auth.signInAnonymously().timeout(const Duration(seconds: 8));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Auth anónima falló o no disponible: $e');
      }
    }
  }

  void _configureNotificationHandling(ProviderContainer container) {
    NotificationHelper().setOnNotificationTap(
      (response) => unawaited(
        _handleNotificationResponse(container, response),
      ),
    );
  }

  Future<void> _handleNotificationResponse(
    ProviderContainer container,
    ReminderNotificationResponse response,
  ) async {
    final reminderId = response.payload;
    if (reminderId == null || reminderId.isEmpty) {
      return;
    }

    switch (response.actionId) {
      case 'mark_done':
        await _updateReminderFromNotification(
          container,
          reminderId,
          (reminder) => reminder.isCompleted
              ? null
              : reminder.copyWith(
                  isCompleted: true,
                  updatedAt: DateTime.now(),
                ),
        );
        break;
      case 'snooze_10':
        await _updateReminderFromNotification(
          container,
          reminderId,
          (reminder) => reminder.copyWith(
            isCompleted: false,
            dateTime: DateTime.now().add(const Duration(minutes: 10)),
            updatedAt: DateTime.now(),
          ),
        );
        break;
      default:
        break;
    }
  }

  Future<void> _updateReminderFromNotification(
    ProviderContainer container,
    String reminderId,
    Reminder? Function(Reminder reminder) buildUpdatedReminder,
  ) async {
    final repository = container.read(reminderRepositoryProvider);
    final notifier = container.read(remindersNotifierProvider.notifier);
    final result = await repository.getReminderById(reminderId);

    await result.fold(
      (failure) async {
        if (kDebugMode) {
          debugPrint(
              'No se pudo resolver recordatorio desde notificacion: ${failure.message}');
        }
      },
      (reminder) async {
        final updatedReminder = buildUpdatedReminder(reminder);
        if (updatedReminder == null) {
          return;
        }
        await notifier.updateReminderItem(updatedReminder);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_bootstrapError != null) {
      return MyApp(
        home: _ErrorScreen(error: _bootstrapError!),
      );
    }

    if (_isar == null || _container == null) {
      return const MyApp(
        home: _SplashScreen(),
      );
    }

    return UncontrolledProviderScope(
      container: _container!,
      child: const MyApp(
        home: HomePage(),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final Widget home;
  const MyApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recordatorios',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          secondary: AppColors.panelTop,
          surface: AppColors.panelBottom,
          onSurface: AppColors.textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
          surfaceTintColor: Colors.transparent,
        ),
        dividerColor: AppColors.divider,
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.black,
          surfaceTintColor: Colors.transparent,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: AppColors.panelTop,
          contentTextStyle: TextStyle(color: AppColors.textPrimary),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.panelInset,
          labelStyle: const TextStyle(color: AppColors.textMuted),
          helperStyle: const TextStyle(color: AppColors.textMuted),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.panelStroke),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.accent, width: 2),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
        ),
        useMaterial3: true,
      ),
      locale: const Locale('es'),
      supportedLocales: const [
        Locale('es'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final Object error;
  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.danger,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Error al iniciar la app',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
