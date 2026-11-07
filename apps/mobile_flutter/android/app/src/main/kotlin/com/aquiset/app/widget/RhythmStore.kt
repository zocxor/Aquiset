package com.aquiset.app.widget

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.UUID

/**
 * Small store shared by the Flutter app, the Glance widget and shortcuts.
 * The app writes the snapshot; widgets queue drinks for the app to import.
 */
object RhythmStore {
    private const val PREFS = "aquiset_rhythm"
    private const val KEY_SNAPSHOT = "snapshot"
    private const val KEY_PENDING = "pending"

    data class Snapshot(
        val totalMl: Int,
        val goalMl: Int,
        val drinksToday: Int,
        val bedtimeLabel: String,
        val wakeLabel: String,
        val alarmOn: Boolean,
        val updatedEpochMs: Long,
    ) {
        val progress: Float get() = if (goalMl > 0) (totalMl.toFloat() / goalMl).coerceIn(0f, 1f) else 0f
    }

    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun sameDay(a: Long, b: Long): Boolean {
        val ca = Calendar.getInstance().apply { timeInMillis = a }
        val cb = Calendar.getInstance().apply { timeInMillis = b }
        return ca.get(Calendar.YEAR) == cb.get(Calendar.YEAR) && ca.get(Calendar.DAY_OF_YEAR) == cb.get(Calendar.DAY_OF_YEAR)
    }

    fun saveSnapshot(c: Context, m: Map<String, Any?>) {
        val o = JSONObject()
        for ((k, v) in m) if (v != null) o.put(k, v)
        prefs(c).edit().putString(KEY_SNAPSHOT, o.toString()).apply()
    }

    fun snapshot(c: Context): Snapshot {
        val o = prefs(c).getString(KEY_SNAPSHOT, null)?.let { JSONObject(it) } ?: JSONObject()
        val updated = o.optLong("updatedEpochMs", System.currentTimeMillis())
        val today = sameDay(updated, System.currentTimeMillis())
        return Snapshot(
            totalMl = if (today) o.optInt("totalMl", 0) else 0,
            goalMl = o.optInt("goalMl", 2000),
            drinksToday = if (today) o.optInt("drinksToday", 0) else 0,
            bedtimeLabel = o.optString("bedtimeLabel", "11:00 pm"),
            wakeLabel = o.optString("wakeLabel", "6:45 am"),
            alarmOn = o.optBoolean("alarmOn", false),
            updatedEpochMs = updated,
        )
    }

    /** Queues a drink and bumps the snapshot so the widget updates instantly. */
    @Synchronized
    fun appendPendingLog(c: Context, ml: Int, source: String) {
        val p = prefs(c)
        val queue = JSONArray(p.getString(KEY_PENDING, "[]"))
        queue.put(
            JSONObject()
                .put("id", UUID.randomUUID().toString().replace("-", ""))
                .put("ml", ml)
                .put("kind", mapOf(100 to "sip", 200 to "cup", 250 to "glass", 500 to "bottle")[ml] ?: "custom")
                .put("epochMs", System.currentTimeMillis())
                .put("source", source),
        )
        val s = snapshot(c)
        val snap = JSONObject(p.getString(KEY_SNAPSHOT, "{}"))
            .put("totalMl", s.totalMl + ml)
            .put("drinksToday", s.drinksToday + 1)
            .put("updatedEpochMs", System.currentTimeMillis())
        p.edit().putString(KEY_PENDING, queue.toString()).putString(KEY_SNAPSHOT, snap.toString()).apply()
    }

    fun hasPendingLogs(c: Context): Boolean = JSONArray(prefs(c).getString(KEY_PENDING, "[]")).length() > 0

    @Synchronized
    fun drainPendingLogs(c: Context): List<Map<String, Any?>> {
        val queue = JSONArray(prefs(c).getString(KEY_PENDING, "[]"))
        prefs(c).edit().remove(KEY_PENDING).apply()
        return (0 until queue.length()).map { i ->
            val o = queue.getJSONObject(i)
            mapOf(
                "id" to o.optString("id"),
                "ml" to o.optInt("ml"),
                "kind" to o.optString("kind"),
                "epochMs" to o.optLong("epochMs"),
                "source" to o.optString("source"),
            )
        }
    }
}
