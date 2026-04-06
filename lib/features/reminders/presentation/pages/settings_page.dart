import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/settings/app_settings_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/reminder_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final firebaseAvailable = ref.watch(firebaseAvailableProvider);
    final settingsNotifier = ref.read(appSettingsProvider.notifier);
    final effectiveCloudEnabled = firebaseAvailable && settings.firebaseEnabled;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Configuraci\u00f3n'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            'Notificaciones',
            [
              _buildSettingTile(
                icon: Icons.notifications_active,
                title: 'Estilo del aviso',
                subtitle: 'Prioridad y sonido de las notificaciones en iPhone',
                trailing: Text(
                  settings.soundLabel,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                onTap: () => _showSoundPicker(
                  context,
                  settings,
                  settingsNotifier,
                  ref,
                ),
              ),
              _buildSettingTile(
                icon: Icons.vibration,
                title: 'Vibraci\u00f3n',
                subtitle: 'Activar vibraci\u00f3n',
                trailing: Switch(
                  value: settings.vibrationEnabled,
                  onChanged: (value) async {
                    final messenger = ScaffoldMessenger.of(context);
                    await settingsNotifier.setVibrationEnabled(value);
                    await ref
                        .read(remindersNotifierProvider.notifier)
                        .applyNotificationDefaults(
                          vibrationEnabled: value,
                          soundPath:
                              settings.useAlarmSound ? 'prominent' : null,
                        );
                    _showSnackOnMessenger(
                      messenger,
                      value
                          ? 'Vibraci\u00f3n activada'
                          : 'Vibraci\u00f3n desactivada',
                    );
                  },
                  activeThumbColor: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            'Sincronizaci\u00f3n',
            [
              _buildSettingTile(
                icon: Icons.storage,
                title: 'Isar (local)',
                subtitle: 'Guardar recordatorios en el dispositivo',
                trailing: Switch(
                  value: settings.isarEnabled,
                  onChanged: (value) async {
                    if (!_validateSyncChange(
                      context,
                      value,
                      effectiveCloudEnabled,
                    )) {
                      return;
                    }
                    await settingsNotifier.setIsarEnabled(value);
                  },
                  activeThumbColor: AppColors.accent,
                ),
              ),
              _buildSettingTile(
                icon: Icons.cloud_sync,
                title: 'Firebase (nube)',
                subtitle: firebaseAvailable
                    ? 'Sincronizar con la nube'
                    : 'No configurado en esta plataforma',
                trailing: Switch(
                  value: effectiveCloudEnabled,
                  onChanged: firebaseAvailable
                      ? (value) async {
                          if (!_validateSyncChange(
                            context,
                            value,
                            settings.isarEnabled,
                          )) {
                            return;
                          }
                          await settingsNotifier.setFirebaseEnabled(value);
                        }
                      : null,
                  activeThumbColor: AppColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _validateSyncChange(
    BuildContext context,
    bool newValue,
    bool otherEnabled,
  ) {
    if (!newValue && !otherEnabled) {
      _showSnack(
        context,
        'Debes mantener al menos una fuente activa',
      );
      return false;
    }
    return true;
  }

  Future<void> _showSoundPicker(
    BuildContext context,
    AppSettings settings,
    AppSettingsNotifier notifier,
    WidgetRef ref,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const Text(
                'Estilo de notificacion',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.notifications_active,
                    color: AppColors.textPrimary),
                title: const Text(
                  'Destacada',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                trailing: settings.useAlarmSound
                    ? const Icon(Icons.check, color: AppColors.accent)
                    : null,
                onTap: () async {
                  await notifier.setUseAlarmSound(true);
                  await ref
                      .read(remindersNotifierProvider.notifier)
                      .applyNotificationDefaults(
                        vibrationEnabled: settings.vibrationEnabled,
                        soundPath: 'prominent',
                      );
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.volume_up, color: AppColors.textPrimary),
                title: const Text(
                  'Estandar',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                trailing: !settings.useAlarmSound
                    ? const Icon(Icons.check, color: AppColors.accent)
                    : null,
                onTap: () async {
                  await notifier.setUseAlarmSound(false);
                  await ref
                      .read(remindersNotifierProvider.notifier)
                      .applyNotificationDefaults(
                        vibrationEnabled: settings.vibrationEnabled,
                        soundPath: null,
                      );
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.panelTop,
                AppColors.panelBottom,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.panelStroke),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textPrimary),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      trailing: trailing ??
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
      onTap: onTap,
    );
  }

  void _showSnack(BuildContext context, String message) {
    _showSnackOnMessenger(ScaffoldMessenger.of(context), message);
  }

  void _showSnackOnMessenger(
    ScaffoldMessengerState messenger,
    String message,
  ) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.panelTop,
        ),
      );
  }
}
