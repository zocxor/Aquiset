package com.aquiset.app.live

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import com.aquiset.app.MainActivity
import com.aquiset.app.R
import java.text.DateFormat
import java.util.Date

/**
 * Wind-down countdown as an Android Live Update.
 *
 * Android 16+ (API 36): a promoted ongoing notification with ProgressStyle,
 * shown as a status-bar chip with the bedtime and on the lock screen. It
 * meets the promotion rules: ongoing, has a title, no custom views, not
 * colorized, channel above IMPORTANCE_MIN, POST_PROMOTED_NOTIFICATIONS
 * declared. Earlier versions get a regular ongoing countdown notification.
 *
 * Android 17 adds MetricStyle (bedtime / wake / steps as three metrics);
 * adopt it once the API 37 reference is final in your toolchain.
 */
object WindDownLiveUpdate {
    private const val CHANNEL = "aquiset_wind_down"
    private const val ID = 4201
    private const val API_BAKLAVA = 36

    private fun ensureChannel(c: Context) {
        val nm = c.getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CHANNEL) != null) return
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL, "Wind-down", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "Countdown to your bedtime while you wind down"
                setSound(null, null)
            },
        )
    }

    fun post(c: Context, args: Map<String, Any?>): Boolean {
        ensureChannel(c)
        val bed = (args["bedtimeEpochMs"] as? Number)?.toLong() ?: return false
        val done = (args["stepsDone"] as? Number)?.toInt() ?: 0
        val total = ((args["stepsTotal"] as? Number)?.toInt() ?: 4).coerceAtLeast(1)
        val bedLabel = DateFormat.getTimeInstance(DateFormat.SHORT).format(Date(bed))
        val open = PendingIntent.getActivity(
            c, ID,
            Intent(c, MainActivity::class.java).putExtra("aquiset_action", "open").putExtra("aquiset_tab", "sleep"),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = Notification.Builder(c, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_aquiset)
            .setContentTitle("Wind-down · bed at $bedLabel")
            .setContentText("$done of $total steps done")
            .setContentIntent(open)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setWhen(bed)
            .setShowWhen(true)
            .setUsesChronometer(true)
            .setChronometerCountdown(true)
            .setTimeoutAfter((bed - System.currentTimeMillis()).coerceAtLeast(60_000L) + 30 * 60_000L)

        if (Build.VERSION.SDK_INT >= API_BAKLAVA) {
            builder
                .setRequestPromotedOngoing(true)
                .setShortCriticalText(bedLabel)
                .setStyle(
                    Notification.ProgressStyle()
                        .addProgressSegment(Notification.ProgressStyle.Segment(total).setColor(Color.rgb(187, 173, 244)))
                        .setProgress(done),
                )
        } else {
            builder.setProgress(total, done, false)
        }

        c.getSystemService(NotificationManager::class.java).notify(ID, builder.build())
        return true
    }

    fun end(c: Context) {
        c.getSystemService(NotificationManager::class.java).cancel(ID)
    }
}
