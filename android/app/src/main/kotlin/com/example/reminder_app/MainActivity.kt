package com.example.reminder_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private val channel = "com.example.reminder_app/alarm_sound"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
      when (call.method) {
        "startAlarm" -> {
          startAlarmService()
          result.success(null)
        }
        "stopAlarm" -> {
          stopAlarmService()
          result.success(null)
        }
        "scheduleAlarm" -> {
          val id = call.argument<Int>("id")
          val timestamp = call.argument<Long>("timestamp")
          if (id == null || timestamp == null) {
            result.error("invalid_args", "Missing id or timestamp", null)
            return@setMethodCallHandler
          }
          scheduleAlarm(id, timestamp)
          result.success(null)
        }
        "cancelAlarm" -> {
          val id = call.argument<Int>("id")
          if (id == null) {
            result.error("invalid_args", "Missing id", null)
            return@setMethodCallHandler
          }
          cancelAlarm(id)
          result.success(null)
        }
        else -> result.notImplemented()
      }
    }
  }

  private fun startAlarmService() {
    val intent = Intent(this, AlarmSoundService::class.java).apply {
      action = AlarmSoundService.ACTION_START
    }
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      ContextCompat.startForegroundService(this, intent)
    } else {
      startService(intent)
    }
  }

  private fun stopAlarmService() {
    val intent = Intent(this, AlarmSoundService::class.java).apply {
      action = AlarmSoundService.ACTION_STOP
    }
    startService(intent)
  }

  private fun scheduleAlarm(id: Int, triggerAtMillis: Long) {
    val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
    val intent = Intent(this, AlarmSoundReceiver::class.java)
    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    } else {
      PendingIntent.FLAG_UPDATE_CURRENT
    }
    val pendingIntent = PendingIntent.getBroadcast(this, id, intent, flags)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
    } else {
      alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
    }
  }

  private fun cancelAlarm(id: Int) {
    val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
    val intent = Intent(this, AlarmSoundReceiver::class.java)
    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    } else {
      PendingIntent.FLAG_UPDATE_CURRENT
    }
    val pendingIntent = PendingIntent.getBroadcast(this, id, intent, flags)
    alarmManager.cancel(pendingIntent)
    pendingIntent.cancel()
  }

}