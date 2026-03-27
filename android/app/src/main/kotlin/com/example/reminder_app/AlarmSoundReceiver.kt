package com.example.reminder_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.content.ContextCompat

class AlarmSoundReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    val serviceIntent = Intent(context, AlarmSoundService::class.java).apply {
      action = AlarmSoundService.ACTION_START
    }
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      ContextCompat.startForegroundService(context, serviceIntent)
    } else {
      context.startService(serviceIntent)
    }
  }
}
