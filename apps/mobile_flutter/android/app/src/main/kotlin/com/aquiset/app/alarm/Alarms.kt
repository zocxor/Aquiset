package com.aquiset.app.alarm

import android.Manifest
import android.app.Activity
import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import com.aquiset.app.MainActivity
import org.json.JSONArray
import org.json.JSONObject
import java.time.ZonedDateTime

data class AlarmSpec(
    val id: String,
    val hour: Int,
    val minute: Int,
    /** ISO weekdays, 1 = Monday. Empty = one time. */
    val weekdays: Set<Int>,
    val label: String = "Good morning",
    val snoozeMinutes: Int = 9,
    val vibrate: Boolean = true,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("id", id).put("hour", hour).put("minute", minute)
        .put("weekdays", JSONArray(weekdays.sorted()))
        .put("label", label).put("snoozeMinutes", snoozeMinutes).put("vibrate", vibrate)

    companion object {
        fun from(m: Map<String, Any?>) = AlarmSpec(
            id = m["id"] as? String ?: "wake",
            hour = (m["hour"] as? Number)?.toInt() ?: 7,
            minute = (m["minute"] as? Number)?.toInt() ?: 0,
            weekdays = (m["weekdays"] as? List<*>)?.mapNotNull { (it as? Number)?.toInt() }?.toSet() ?: emptySet(),
            label = m["label"] as? String ?: "Good morning",
            snoozeMinutes = (m["snoozeMinutes"] as? Number)?.toInt() ?: 9,
            vibrate = m["vibrate"] as? Boolean ?: true,
        )

        fun fromJson(o: JSONObject): AlarmSpec {
            val days = o.optJSONArray("weekdays") ?: JSONArray()
            return AlarmSpec(
                id = o.getString("id"),
                hour = o.getInt("hour"),
                minute = o.getInt("minute"),
                weekdays = (0 until days.length()).map { days.getInt(it) }.toSet(),
                label = o.optString("label", "Good morning"),
                snoozeMinutes = o.optInt("snoozeMinutes", 9),
                vibrate = o.optBoolean("vibrate", true),
            )
        }
    }
}

/** Persists alarm specs so they can be re-armed after reboot or a time change. */
object AlarmStore {
    private const val PREFS = "aquiset_alarms"

    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun put(c: Context, spec: AlarmSpec) = prefs(c).edit().putString(spec.id, spec.toJson().toString()).apply()
    fun get(c: Context, id: String): AlarmSpec? = prefs(c).getString(id, null)?.let { AlarmSpec.fromJson(JSONObject(it)) }
    fun remove(c: Context, id: String) = prefs(c).edit().remove(id).apply()
    fun all(c: Context): List<AlarmSpec> = prefs(c).all.values.mapNotNull { (it as? String)?.let { s -> AlarmSpec.fromJson(JSONObject(s)) } }
}

object Alarms {
    const val EXTRA_ID = "alarm_id"

    private fun manager(c: Context) = c.getSystemService(AlarmManager::class.java)

    fun canScheduleExact(c: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S || manager(c).canScheduleExactAlarms()

    fun capability(c: Context): Map<String, Any> = mapOf(
        "backend" to "alarmManager",
        "authorized" to c.getSystemService(NotificationManager::class.java).areNotificationsEnabled(),
        "exactAllowed" to canScheduleExact(c),
        "canRequest" to true,
    )

    /** Notifications first (Android 13+), then exact alarms (Android 12+). */
    fun requestPermission(activity: Activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7101)
            return
        }
        if (!canScheduleExact(activity)) openSettings(activity)
    }

    fun openSettings(activity: Activity) {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !canScheduleExact(activity)) {
            Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:${activity.packageName}"))
        } else {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
        }
        activity.startActivity(intent)
    }

    fun nextTrigger(spec: AlarmSpec, now: ZonedDateTime = ZonedDateTime.now()): ZonedDateTime {
        var t = now.withHour(spec.hour).withMinute(spec.minute).withSecond(0).withNano(0)
        if (!t.isAfter(now)) t = t.plusDays(1)
        if (spec.weekdays.isEmpty()) return t
        repeat(7) {
            if (t.dayOfWeek.value in spec.weekdays) return t
            t = t.plusDays(1)
        }
        return t
    }

    private fun operation(c: Context, id: String): PendingIntent = PendingIntent.getBroadcast(
        c, id.hashCode(),
        Intent(c, AlarmReceiver::class.java).putExtra(EXTRA_ID, id),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    fun schedule(c: Context, spec: AlarmSpec, at: Long? = null): Boolean {
        AlarmStore.put(c, spec)
        val trigger = at ?: nextTrigger(spec).toInstant().toEpochMilli()
        val op = operation(c, spec.id)
        val am = manager(c)
        return try {
            if (canScheduleExact(c)) {
                val show = PendingIntent.getActivity(
                    c, 0, Intent(c, MainActivity::class.java).putExtra("aquiset_action", "open").putExtra("aquiset_tab", "sleep"),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                am.setAlarmClock(AlarmManager.AlarmClockInfo(trigger, show), op)
            } else {
                // Honest fallback: may be delayed by Doze; the app says so.
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, op)
            }
            true
        } catch (e: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, op)
            true
        }
    }

    fun cancel(c: Context, id: String) {
        manager(c).cancel(operation(c, id))
        AlarmStore.remove(c, id)
    }

    fun test(c: Context, seconds: Int): Boolean =
        schedule(c, AlarmSpec(id = "test", hour = 0, minute = 0, weekdays = emptySet(), label = "Test alarm"),
            at = System.currentTimeMillis() + seconds * 1000L)

    fun snooze(c: Context, spec: AlarmSpec) {
        schedule(c, spec.copy(id = "snooze", weekdays = emptySet()), at = System.currentTimeMillis() + spec.snoozeMinutes * 60_000L)
    }

    /** Re-arms everything after reboot, app update or a time/zone change. */
    fun rescheduleAll(c: Context) {
        AlarmStore.all(c).forEach { spec ->
            if (spec.id == "test" || spec.id == "snooze") AlarmStore.remove(c, spec.id) else schedule(c, spec)
        }
    }
}
