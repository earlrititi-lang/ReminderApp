# 🔔 Configuración de Notificaciones Invasivas - Guía Completa

## Fase 5: Notificaciones y Alarmas

### ¿Qué hemos implementado?

✅ **NotificationHelper** - Sistema de notificaciones invasivas
✅ **Alarmas programadas** - Con timezone support
✅ **Sonido personalizable** - Soporte para sonidos custom
✅ **Vibración invasiva** - Patrones de vibración configurables
✅ **Full Screen Intent** - Notificaciones en pantalla completa
✅ **Integración con Use Cases** - Automático al crear/actualizar/eliminar

---

## 🎵 Agregar Sonido Personalizado

### Paso 1: Preparar el archivo de audio

1. **Descarga o crea** un archivo WAV/MP3 de alarma (máx 2 segundos)
2. **Nómbralo**: `alarm.wav` (o similar)
3. **Colócalo en**: `android/app/src/main/res/raw/alarm.wav`

### Paso 2: Crear carpeta si no existe

```bash
# Windows (PowerShell)
New-Item -ItemType Directory -Force -Path "android/app/src/main/res/raw"

# Linux/Mac
mkdir -p android/app/src/main/res/raw
```

### Paso 3: Copiar el archivo

Mueve tu archivo `alarm.wav` a la carpeta creada.

### Paso 4: Agregar sonido personalizado al recordatorio

En la app, al crear un recordatorio, puedes especificar:

```dart
await ref.read(remindersNotifierProvider.notifier).addReminder(
  title: 'Mi tarea',
  description: 'Descripción',
  dateTime: DateTime.now().add(Duration(minutes: 5)),
  notificationEnabled: true,
  vibrationEnabled: true,
  // Sonido personalizado (si lo agregaste)
  soundPath: 'alarm', // Sin extensión
);
```

---

## 🔧 Configuración de AndroidManifest.xml

Asegúrate que `android/app/src/main/AndroidManifest.xml` tenga:

```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>
```

---

## ⚙️ Personalizar Configuración de Notificaciones

### En `notification_helper.dart`:

#### Cambiar sonido por defecto
```dart
sound: RawResourceAndroidNotificationSound('mi_sonido'),
```

#### Cambiar patrón de vibración
```dart
vibrationPattern: [0, 500, 250, 500], // [delay, vibrate, pause, vibrate...]
```

#### Cambiar importancia (máxima por defecto)
```dart
importance: Importance.max, // max, high, default, low, min
priority: Priority.max,
```

---

## 📱 Probar Notificaciones

### Crear un recordatorio para ahora + 5 segundos:

1. Abre la app
2. Toca el botón `+`
3. Titulo: "Test Notification"
4. Selecciona fecha/hora para 5 segundos en el futuro
5. Toca "Guardar"
6. **Debería aparecer una notificación invasiva**

---

## 🐛 Troubleshooting

### ❌ Las notificaciones no aparecen

**Soluciones:**
1. Verifica que el permiso POST_NOTIFICATIONS esté en AndroidManifest.xml
2. Acepte los permisos de notificación cuando la app los solicita
3. Verifica que el horario del recordatorio sea futuro
4. Prueba ejecutar `flutter clean && flutter run`

### ❌ No suena la alarma

**Soluciones:**
1. Verifica que `android/app/src/main/res/raw/alarm.wav` existe
2. Comprueba el volumen del dispositivo
3. Verifica que `enableVibration: true` en notificationDetails

### ❌ Error: "No se pudo programar notificación"

**Soluciones:**
1. Verifica que tienes permiso SCHEDULE_EXACT_ALARM
2. Algunos dispositivos/ROMs restringen notificaciones exactas
3. Prueba cambiar a `AndroidScheduleMode.inexactAndAllowWhileIdle`

---

## 📋 Lo que hace cada parte

### NotificationHelper

```dart
// Inicializar al inicio de la app
await notificationHelper.initialize();

// Programar notificación (automático al crear recordatorio)
await notificationHelper.scheduleReminderNotification(reminder: reminder);

// Mostrar inmediatamente
await notificationHelper.showInvasiveNotification(reminder);

// Cancelar notificación
await notificationHelper.cancelNotification(reminderId);

// Obtener pendientes
final pending = await notificationHelper.getPendingNotifications();
```

### CreateReminder UseCase

```dart
@override
Future<Either<Failure, Reminder>> call(CreateReminderParams params) async {
  final result = await repository.createReminder(params.reminder);
  
  // Si tiene notificaciones habilitadas, programa automáticamente
  result.fold(
    (failure) => null,
    (reminder) async {
      if (reminder.notificationEnabled) {
        await notificationHelper.scheduleReminderNotification(reminder: reminder);
      }
    },
  );
  
  return result;
}
```

---

## 🎯 Próximos Pasos (FASE 6)

- [ ] Página de Configuración avanzada de notificaciones
- [ ] Selector de sonidos personalizados
- [ ] Control de vibración por recordatorio
- [ ] Snooze automático
- [ ] Historial de notificaciones mostradas
- [ ] Notificaciones recurrentes (diarias, semanales, etc.)

---

## ✅ Verificación Final

Ejecuta estos comandos para verificar que todo funciona:

```bash
# Verificar análisis de código
flutter analyze

# Limpiar y compilar
flutter clean
flutter pub get

# Compilar APK
flutter build apk --release

# Ejecutar en emulador
flutter run
```

---

**¿Necesitas ayuda?** Cópiame los errores y los solucionamos. 🚀
