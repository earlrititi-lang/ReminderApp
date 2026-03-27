package com.example.reminder_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class AlarmSoundService : Service() {
  companion object {
    const val ACTION_START = "com.example.reminder_app.action.START_ALARM"
    const val ACTION_STOP = "com.example.reminder_app.action.STOP_ALARM"
    private const val CHANNEL_ID = "alarm_sound_service"
    private const val NOTIFICATION_ID = 1002
  }

  private var mediaPlayer: MediaPlayer? = null

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onCreate() {
    super.onCreate()
    createNotificationChannel()
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    when (intent?.action) {
      ACTION_STOP -> {
        stopSelf()
        return START_NOT_STICKY
      }
      else -> startAlarm()
    }
    return START_STICKY
  }

  private fun startAlarm() {
    if (mediaPlayer == null) {
      mediaPlayer = MediaPlayer.create(this, R.raw.alarm)?.apply {
        isLooping = true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
          setAudioAttributes(
            AudioAttributes.Builder()
              .setUsage(AudioAttributes.USAGE_ALARM)
              .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
              .build()
          )
        }
      }
    }

    val stopIntent = Intent(this, AlarmSoundService::class.java).apply {
      action = ACTION_STOP
    }
    val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    } else {
      PendingIntent.FLAG_UPDATE_CURRENT
    }
    val stopPendingIntent = PendingIntent.getService(this, 0, stopIntent, pendingFlags)

    val notification = NotificationCompat.Builder(this, CHANNEL_ID)
      .setSmallIcon(R.mipmap.ic_launcher)
      .setContentTitle("Alarma activa")
      .setContentText("Toca Detener para apagar el sonido")
      .setOngoing(true)
      .addAction(0, "Detener", stopPendingIntent)
      .build()

    startForeground(NOTIFICATION_ID, notification)
    mediaPlayer?.start()
  }

  private fun createNotificationChannel() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel = NotificationChannel(
        CHANNEL_ID,
        "Alarma en bucle",
        NotificationManager.IMPORTANCE_HIGH
      )
      channel.description = "Reproduccion de alarma en bucle"
      val manager = getSystemService(NotificationManager::class.java)
      manager.createNotificationChannel(channel)
    }
  }

  override fun onDestroy() {
    mediaPlayer?.stop()
    mediaPlayer?.release()
    mediaPlayer = null
    stopForeground(STOP_FOREGROUND_REMOVE)
    super.onDestroy()
  }
}
