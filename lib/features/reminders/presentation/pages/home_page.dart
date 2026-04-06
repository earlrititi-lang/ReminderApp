import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:async';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/settings/app_settings_provider.dart';
import '../providers/reminder_provider.dart';
import '../utils/voice_reminder_parser.dart';
import '../widgets/add_reminder_dialog.dart';
import '../widgets/reminder_card.dart';
import 'settings_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  static const _voiceListenFor = Duration(seconds: 55);
  static const _voicePauseFor = Duration(seconds: 12);
  static const _voiceRestartDelay = Duration(milliseconds: 250);

  final SpeechToText _speechToText = SpeechToText();
  ProviderSubscription<RemindersState>? _remindersSubscription;
  bool _speechReady = false;
  bool _isListening = false;
  bool _isCreatingVoiceReminder = false;
  bool _voiceSessionActive = false;
  bool _voiceReviewPending = false;
  bool _voiceStopRequested = false;
  bool _speechHadError = false;
  String _lastRecognizedWords = '';
  String? _speechLocaleId;
  Timer? _voiceRestartTimer;

  @override
  void initState() {
    super.initState();
    _remindersSubscription = ref.listenManual<RemindersState>(
      remindersNotifierProvider,
      (previous, next) {
        final nextError = next.error;
        if (nextError == null || nextError == previous?.error || !mounted) {
          return;
        }
        if (next.reminders.isNotEmpty) {
          _showSnackBar(
            nextError,
            backgroundColor: AppColors.danger,
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _remindersSubscription?.close();
    _voiceRestartTimer?.cancel();
    _speechToText.cancel();
    super.dispose();
  }

  void _cancelVoiceRestart() {
    _voiceRestartTimer?.cancel();
    _voiceRestartTimer = null;
  }

  void _scheduleVoiceRestart() {
    _cancelVoiceRestart();
    _voiceRestartTimer = Timer(_voiceRestartDelay, () {
      if (!mounted ||
          !_voiceSessionActive ||
          _voiceStopRequested ||
          _isListening ||
          _isCreatingVoiceReminder) {
        return;
      }
      unawaited(_startVoiceListening());
    });
  }

  Future<int> _createReminders({
    required List<String> titles,
    String? description,
    required DateTime dateTime,
    bool notificationEnabled = true,
  }) async {
    final settings = ref.read(appSettingsProvider);
    var createdCount = 0;

    for (final title in titles) {
      final created =
          await ref.read(remindersNotifierProvider.notifier).addReminder(
                title: title,
                description: description != null && description.isNotEmpty
                    ? description
                    : null,
                dateTime: dateTime,
                notificationEnabled: notificationEnabled,
                vibrationEnabled: settings.vibrationEnabled,
                soundPath: notificationEnabled && settings.useAlarmSound
                    ? 'prominent'
                    : null,
              );
      if (created) {
        createdCount++;
      }
    }

    return createdCount;
  }

  Future<void> _showAddReminderDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddReminderDialog(),
    );

    if (result != null && mounted) {
      final titles = (result['titles'] as List<dynamic>).cast<String>();
      final description = result['description'] as String?;
      final dateTime = result['dateTime'] as DateTime;
      final createdCount = await _createReminders(
        titles: titles,
        description: description,
        dateTime: dateTime,
      );

      if (mounted) {
        final message = createdCount == titles.length
            ? (titles.length > 1
                ? 'Recordatorios creados ($createdCount)'
                : 'Recordatorio creado')
            : createdCount == 0
                ? 'No se pudo crear el recordatorio'
                : 'Se crearon $createdCount de ${titles.length} recordatorios';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: createdCount == titles.length
                ? AppColors.success
                : AppColors.danger,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<bool> _ensureSpeechReady() async {
    if (_speechReady) return true;

    try {
      final hasSpeech = await _speechToText.initialize(
        onError: _onSpeechError,
        onStatus: _onSpeechStatus,
        debugLogging: false,
      );

      if (hasSpeech) {
        final systemLocale = await _speechToText.systemLocale();
        _speechLocaleId = systemLocale?.localeId;
      }

      if (!mounted) return hasSpeech;
      setState(() {
        _speechReady = hasSpeech;
      });
      return hasSpeech;
    } catch (_) {
      if (!mounted) return false;
      setState(() {
        _speechReady = false;
        _isListening = false;
        _voiceSessionActive = false;
      });
      return false;
    }
  }

  Future<void> _toggleVoiceReminder() async {
    if (_isCreatingVoiceReminder) return;

    if (_voiceSessionActive) {
      _voiceStopRequested = true;
      _cancelVoiceRestart();
      if (_isListening) {
        await _speechToText.stop();
      } else {
        await _finishVoiceSession();
      }
      return;
    }

    final hasSpeech = await _ensureSpeechReady();
    if (!mounted) return;
    if (!hasSpeech) {
      _showSnackBar(
        'El reconocimiento de voz no esta disponible en este dispositivo',
        backgroundColor: AppColors.danger,
      );
      return;
    }

    _lastRecognizedWords = '';
    _speechHadError = false;
    _voiceStopRequested = false;
    _cancelVoiceRestart();
    setState(() {
      _voiceSessionActive = true;
      _voiceReviewPending = false;
      _isListening = false;
    });

    _showSnackBar(
      'Habla y pulsa el micro otra vez para revisar la transcripcion',
      backgroundColor: AppColors.success,
      duration: const Duration(seconds: 6),
    );

    await _startVoiceListening();
  }

  Future<void> _startVoiceListening() async {
    if (!_voiceSessionActive || _isCreatingVoiceReminder) {
      return;
    }

    await _speechToText.listen(
      onResult: _onSpeechResult,
      localeId: _speechLocaleId,
      listenFor: _voiceListenFor,
      pauseFor: _voicePauseFor,
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        cancelOnError: true,
        partialResults: true,
        autoPunctuation: true,
        enableHapticFeedback: true,
      ),
    );
  }

  Future<void> _finishVoiceSession() async {
    _cancelVoiceRestart();
    _voiceStopRequested = false;
    if (mounted) {
      setState(() {
        _voiceSessionActive = false;
        _isListening = false;
      });
    }

    final transcript = _lastRecognizedWords.trim();
    if (transcript.isEmpty) {
      setState(() {
        _voiceReviewPending = false;
      });
      _showSnackBar(
        'No se detecto ningun titulo',
        backgroundColor: AppColors.danger,
      );
      return;
    }

    setState(() {
      _voiceReviewPending = true;
    });
  }

  Future<void> _confirmVoiceReminder() async {
    if (_isCreatingVoiceReminder) {
      return;
    }

    final transcript = _lastRecognizedWords.trim();
    if (transcript.isEmpty) {
      _showSnackBar(
        'No hay transcripcion para crear la tarea',
        backgroundColor: AppColors.danger,
      );
      return;
    }

    await _createReminderFromVoice(transcript);
  }

  Future<void> _cancelVoiceCapture() async {
    _voiceStopRequested = true;
    _cancelVoiceRestart();

    try {
      if (_speechToText.isListening) {
        await _speechToText.cancel();
      }
    } catch (_) {
      // Ignoramos errores al cancelar una sesion ya cerrada.
    }

    if (!mounted) return;
    setState(() {
      _voiceSessionActive = false;
      _voiceReviewPending = false;
      _isListening = false;
      _isCreatingVoiceReminder = false;
      _speechHadError = false;
      _lastRecognizedWords = '';
    });

    _showSnackBar(
      'Captura por voz cancelada',
      backgroundColor: AppColors.panelTop,
    );
  }

  Future<void> _createReminderFromVoice(String transcript) async {
    final parsed = parseVoiceReminderCommand(transcript);
    final title = _normalizeVoiceTitle(parsed.title);
    if (title.isEmpty) {
      setState(() {
        _voiceReviewPending = true;
      });
      _showSnackBar(
        'No se reconocio ningun titulo valido',
        backgroundColor: AppColors.danger,
      );
      return;
    }

    setState(() {
      _isCreatingVoiceReminder = true;
      _isListening = false;
      _voiceSessionActive = false;
      _voiceReviewPending = false;
    });

    try {
      final notificationEnabled =
          parsed.hasSchedule && parsed.dateTime.isAfter(DateTime.now());
      final createdCount = await _createReminders(
        titles: [title],
        dateTime: parsed.dateTime,
        notificationEnabled: notificationEnabled,
      );

      if (!mounted) return;
      _showSnackBar(
        createdCount > 0
            ? notificationEnabled
                ? 'Recordatorio creado por voz'
                : 'Tarea creada por voz'
            : 'No se pudo crear la tarea por voz',
        backgroundColor:
            createdCount > 0 ? AppColors.success : AppColors.danger,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingVoiceReminder = false;
          _voiceReviewPending = false;
          _lastRecognizedWords = '';
        });
      }
    }
  }

  String _normalizeVoiceTitle(String transcript) {
    final normalized = transcript.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.replaceAll(RegExp(r'[.,;:!?]+$'), '').trim();
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final recognizedWords = result.recognizedWords.trim();
    if (recognizedWords.isNotEmpty && recognizedWords != _lastRecognizedWords) {
      setState(() {
        _lastRecognizedWords = recognizedWords;
      });
    }
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;

    final isActive = status == 'listening';
    if (_isListening != isActive) {
      setState(() {
        _isListening = isActive;
      });
    }

    final finished = status == 'done' || status == 'notListening';
    if (!finished || !_voiceSessionActive || _isCreatingVoiceReminder) {
      return;
    }

    if (_voiceStopRequested) {
      unawaited(_finishVoiceSession());
      return;
    }

    if (!_speechHadError) {
      _scheduleVoiceRestart();
      return;
    }

    setState(() {
      _voiceSessionActive = false;
    });
  }

  void _onSpeechError(SpeechRecognitionError error) {
    if (!mounted) return;

    final normalizedError = error.errorMsg.toLowerCase();
    final isPermissionError = normalizedError.contains('permission');
    final isRecoverable = normalizedError.contains('no_match') ||
        normalizedError.contains('no match') ||
        normalizedError.contains('speech_timeout') ||
        normalizedError.contains('speech timeout') ||
        normalizedError.contains('error 6') ||
        normalizedError.contains('error 7');

    _speechHadError = !(isRecoverable && _voiceSessionActive);
    setState(() {
      _isListening = false;
      if (_speechHadError) {
        _voiceSessionActive = false;
      }
    });

    if (!_speechHadError && !_voiceStopRequested) {
      return;
    }

    final message = isPermissionError
        ? 'No hay permiso para usar el microfono'
        : 'No se pudo reconocer la voz';
    _showSnackBar(
      message,
      backgroundColor: AppColors.danger,
    );
  }

  void _showSnackBar(
    String message, {
    Color backgroundColor = AppColors.panelBottom,
    Duration duration = const Duration(seconds: 2),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
      ),
    );
  }

  Widget _buildVoiceTranscriptCard() {
    final hasTranscript = _lastRecognizedWords.trim().isNotEmpty;
    final headline = _isCreatingVoiceReminder
        ? 'Creando tarea por voz'
        : _voiceReviewPending
            ? 'Revisar transcripcion'
            : _voiceSessionActive
                ? 'Escuchando'
                : 'Ultima transcripcion';
    final helperText = _isCreatingVoiceReminder
        ? 'Procesando el texto reconocido...'
        : _voiceReviewPending
            ? 'Si el texto no es correcto, cancela. Si esta bien, crea la tarea.'
            : _voiceSessionActive
                ? 'Pulsa el boton verde otra vez para detener y revisar la transcripcion'
                : 'Texto reconocido';
    final transcript = hasTranscript
        ? _lastRecognizedWords
        : _voiceSessionActive
            ? 'Habla ahora. Ire mostrando aqui lo que voy entendiendo.'
            : 'Sin texto reconocido';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panelBottom.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isCreatingVoiceReminder
              ? AppColors.accent
              : AppColors.success.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                _isCreatingVoiceReminder ? Icons.sync : Icons.mic,
                color: _isCreatingVoiceReminder
                    ? AppColors.accent
                    : AppColors.success,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                headline,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            transcript,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: hasTranscript
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              fontSize: 15,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            helperText,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
          if (!_isCreatingVoiceReminder &&
              (_voiceSessionActive || _voiceReviewPending)) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _cancelVoiceCapture,
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppColors.danger,
                  ),
                  label: const Text(
                    'Cancelar',
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
                if (_voiceReviewPending) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: hasTranscript ? _confirmVoiceReminder : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Crear'),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(remindersNotifierProvider);
    final visibleReminders = state.reminders;
    final showVoiceTranscript =
        _voiceSessionActive || _isCreatingVoiceReminder || _voiceReviewPending;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Recordatorios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.textPrimary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );
            },
            tooltip: 'Configuraci\u00f3n',
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.textPrimary,
              ),
            )
          : state.error != null && visibleReminders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.danger,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.error!,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref
                            .read(remindersNotifierProvider.notifier)
                            .loadReminders(),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : visibleReminders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.notifications_none,
                            size: 80,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No hay recordatorios',
                            style: TextStyle(
                              fontSize: 18,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Toca + o el microfono para crear uno',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 80),
                      itemCount: visibleReminders.length,
                      itemBuilder: (context, index) {
                        final reminder = visibleReminders[index];
                        return ReminderCard(
                          reminder: reminder,
                          onTap: () {
                            final scaffoldMessenger =
                                ScaffoldMessenger.of(context);
                            showDialog<Map<String, dynamic>>(
                              context: context,
                              builder: (context) =>
                                  EditReminderDialog(reminder: reminder),
                            ).then((result) async {
                              if (result == null || !mounted) return;
                              final updated = reminder.copyWith(
                                title: result['title'] as String,
                                description:
                                    (result['description'] as String).isEmpty
                                        ? null
                                        : result['description'] as String,
                                dateTime: result['dateTime'] as DateTime,
                                updatedAt: DateTime.now(),
                              );
                              final updatedOk = await ref
                                  .read(remindersNotifierProvider.notifier)
                                  .updateReminderItem(updated);

                              if (!mounted) return;
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    updatedOk
                                        ? 'Recordatorio actualizado'
                                        : 'No se pudo actualizar el recordatorio',
                                  ),
                                  backgroundColor: updatedOk
                                      ? AppColors.success
                                      : AppColors.danger,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            });
                          },
                          onDelete: () async {
                            final scaffoldMessenger =
                                ScaffoldMessenger.of(context);
                            final deleted = await ref
                                .read(remindersNotifierProvider.notifier)
                                .removeReminder(reminder.id);

                            if (!mounted) return;
                            if (deleted) {
                              SystemSound.play(SystemSoundType.click);
                            }
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  deleted
                                      ? 'Recordatorio eliminado'
                                      : 'No se pudo eliminar el recordatorio',
                                ),
                                backgroundColor: deleted
                                    ? AppColors.danger
                                    : AppColors.panelTop,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          onToggleComplete: () {
                            ref
                                .read(remindersNotifierProvider.notifier)
                                .toggleComplete(reminder.id);
                          },
                        );
                      },
                    ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width - 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showVoiceTranscript) ...[
                _buildVoiceTranscriptCard(),
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FloatingActionButton(
                    heroTag: 'voice_reminder_fab',
                    onPressed: _toggleVoiceReminder,
                    backgroundColor: AppColors.success,
                    tooltip: _voiceSessionActive
                        ? 'Detener y revisar'
                        : 'Crear por voz',
                    child: _isCreatingVoiceReminder
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : Icon(
                            _voiceSessionActive
                                ? Icons.stop
                                : Icons.keyboard_voice,
                            color: Colors.black,
                            size: 30,
                          ),
                  ),
                  FloatingActionButton(
                    heroTag: 'add_reminder_fab',
                    onPressed: _showAddReminderDialog,
                    backgroundColor: AppColors.accent,
                    tooltip: 'Crear recordatorio',
                    child: const Icon(Icons.add, color: Colors.black, size: 32),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
