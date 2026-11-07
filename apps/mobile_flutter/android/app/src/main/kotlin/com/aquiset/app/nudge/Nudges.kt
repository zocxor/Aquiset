package com.aquiset.app.nudge

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.aquiset.app.MainActivity
import com.aquiset.app.R

/**
 * Gentle hydration nudges. Deliberately inexact (no exact-alarm permission
 * needed) and on a default-importance channel the person can silence.
 */
object Nudges {
    private const val CHANNEL = "aquiset_nudges"
    private const val REQUEST = 4301
    private const val NOTIFICATION_ID = 4302

    private fun pending(c: Context, title: String = "", body: String = "") = PendingIntent.getBroadcast(
        c, REQUEST,
        Intent(c, NudgeReceiver::class.java).putExtra("title", title).putExtra("body", body),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    fun schedule(c: Context, epochMs: Long, title: String, body: String) {
        c.getSystemService(AlarmManager::class.java)
            .setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, epochMs, pending(c, title, body))
    }

    fun cancelAll(c: Context) {
        c.getSystemService(AlarmManager::class.java).cancel(pending(c))
    }

    fun show(c: Context, title: String, body: String) {
        val nm = c.getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "Hydration nudges", NotificationManager.IMPORTANCE_DEFAULT).apply {
                    description = "Gentle reminders inside your waking hours"
                },
            )
        }
        val open = PendingIntent.getActivity(
            c, NOTIFICATION_ID,
            Intent(c, MainActivity::class.java).putExtra("aquiset_action", "open").putExtra("aquiset_tab", "hydrate"),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val log = PendingIntent.getActivity(
            c, NOTIFICATION_ID + 1,
            Intent(c, MainActivity::class.java).putExtra("aquiset_action", "logDrink").putExtra("aquiset_ml", "250"),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        nm.notify(
            NOTIFICATION_ID,
            Notification.Builder(c, CHANNEL)
                .setSmallIcon(R.drawable.ic_stat_aquiset)
                .setContentTitle(title)
                .setContentText(body)
                .setContentIntent(open)
                .setAutoCancel(true)
                .addAction(Notification.Action.Builder(null, "Log a glass", log).build())
                .build(),
        )
    }
}

class NudgeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Nudges.show(context, intent.getStringExtra("title") ?: "A gentle nudge", intent.getStringExtra("body") ?: "")
    }
}
