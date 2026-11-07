package com.aquiset.app.alarm

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import com.aquiset.app.R
import java.text.DateFormat
import java.util.Date

private const val CHANNEL_ALARM = "aquiset_alarm"
private const val NOTIFICATION_ID = 4101
private const val ACTION_STOP = "com.aquiset.app.alarm.STOP"
private const val ACTION_SNOOZE = "com.aquiset.app.alarm.SNOOZE"

/** Fires at alarm time: rings, then re-arms the next weekly occurrence. */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra(Alarms.EXTRA_ID) ?: return
        val spec = AlarmStore.get(context, id) ?: return
        AlarmNotifier.ring(context, spec)
        if (spec.weekdays.isNotEmpty()) Alarms.schedule(context, spec) else AlarmStore.remove(context, id)
    }
}

class AlarmActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        context.getSystemService(NotificationManager::class.java).cancel(NOTIFICATION_ID)
        if (intent.action == ACTION_SNOOZE) {
            val id = intent.getStringExtra(Alarms.EXTRA_ID) ?: "wake"
            val spec = AlarmStore.get(context, id)
                ?: AlarmSpec(id = id, hour = 0, minute = 0, weekdays = emptySet())
            Alarms.snooze(context, spec)
        }
    }
}

/** Re-arms alarms after reboot, app update, time or time-zone change. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) = Alarms.rescheduleAll(context)
}

object AlarmNotifier {
    private fun ensureChannel(c: Context) {
        val nm = c.getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CHANNEL_ALARM) != null) return
        val channel = NotificationChannel(CHANNEL_ALARM, "Wake-up alarm", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Your wake-up alarm"
            setSound(
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
                AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build(),
            )
            enableVibration(true)
            setBypassDnd(true)
        }
        nm.createNotificationChannel(channel)
    }

    private fun action(c: Context, action: String, id: String) = PendingIntent.getBroadcast(
        c, (action + id).hashCode(),
        Intent(c, AlarmActionReceiver::class.java).setAction(action).putExtra(Alarms.EXTRA_ID, id),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    fun ring(c: Context, spec: AlarmSpec) {
        ensureChannel(c)
        val nm = c.getSystemService(NotificationManager::class.java)
        val fullScreen = PendingIntent.getActivity(
            c, 4102,
            Intent(c, AlarmActivity::class.java).putExtra(Alarms.EXTRA_ID, spec.id)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = Notification.Builder(c, CHANNEL_ALARM)
            .setSmallIcon(R.drawable.ic_stat_aquiset)
            .setContentTitle(spec.label)
            .setContentText(DateFormat.getTimeInstance(DateFormat.SHORT).format(Date()))
            .setCategory(Notification.CATEGORY_ALARM)
            .setOngoing(true)
            .addAction(Notification.Action.Builder(null, "Snooze ${spec.snoozeMinutes} min", action(c, ACTION_SNOOZE, spec.id)).build())
            .addAction(Notification.Action.Builder(null, "Stop", action(c, ACTION_STOP, spec.id)).build())
        // Android 14+: full-screen intents are limited to alarm/calling apps
        // and can be revoked; fall back to a heads-up notification.
        val canFullScreen = Build.VERSION.SDK_INT < 34 || nm.canUseFullScreenIntent()
        if (canFullScreen) builder.setFullScreenIntent(fullScreen, true) else builder.setContentIntent(fullScreen)
        val notification = builder.build().apply { flags = flags or Notification.FLAG_INSISTENT }
        nm.notify(NOTIFICATION_ID, notification)
    }
}

/** Minimal lock-screen alarm UI with large, clear Stop and Snooze targets. */
class AlarmActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setShowWhenLocked(true)
        setTurnScreenOn(true)
        val id = intent.getStringExtra(Alarms.EXTRA_ID) ?: "wake"
        val spec = AlarmStore.get(this, id)

        fun button(text: String, action: String) = Button(this).apply {
            this.text = text
            textSize = 20f
            minHeight = (64 * resources.displayMetrics.density).toInt()
            setOnClickListener {
                sendBroadcast(Intent(this@AlarmActivity, AlarmActionReceiver::class.java).setAction(action).putExtra(Alarms.EXTRA_ID, id))
                finish()
            }
        }

        setContentView(LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.rgb(13, 21, 32))
            val pad = (24 * resources.displayMetrics.density).toInt()
            setPadding(pad, pad, pad, pad)
            addView(TextView(context).apply {
                text = DateFormat.getTimeInstance(DateFormat.SHORT).format(Date())
                textSize = 64f
                setTextColor(Color.WHITE)
                gravity = Gravity.CENTER
            })
            addView(TextView(context).apply {
                text = spec?.label ?: "Good morning"
                textSize = 20f
                setTextColor(Color.rgb(187, 173, 244))
                gravity = Gravity.CENTER
            })
            addView(button("Snooze ${spec?.snoozeMinutes ?: 9} min", ACTION_SNOOZE))
            addView(button("Stop", ACTION_STOP))
        })
    }
}
