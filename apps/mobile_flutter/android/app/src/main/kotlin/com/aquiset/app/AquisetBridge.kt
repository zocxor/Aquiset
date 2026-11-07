package com.aquiset.app

import android.app.Activity
import android.content.Intent
import com.aquiset.app.alarm.AlarmSpec
import com.aquiset.app.alarm.Alarms
import com.aquiset.app.live.WindDownLiveUpdate
import com.aquiset.app.nudge.Nudges
import com.aquiset.app.widget.RhythmStore
import com.aquiset.app.widget.WidgetUpdater
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter ⇄ Android bridge for channel "aquiset/platform".
 * Alarms are scheduled with AlarmManager on the device and never depend on
 * the network, backend or AI services.
 */
class AquisetBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val context = activity.applicationContext
    private val channel = MethodChannel(messenger, "aquiset/platform").also { it.setMethodCallHandler(this) }
    private var launchAction: Map<String, Any?>? = null

    fun captureLaunch(intent: Intent?) {
        launchAction = Launch.actionFrom(intent)
    }

    fun deliver(intent: Intent?) {
        Launch.actionFrom(intent)?.let { channel.invokeMethod("action", it) }
    }

    fun onResume() {
        if (RhythmStore.hasPendingLogs(context)) channel.invokeMethod("externalLogsAvailable", null)
    }

    @Suppress("UNCHECKED_CAST")
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val args = (call.arguments as? Map<String, Any?>) ?: emptyMap()
        when (call.method) {
            "alarm.capability" -> result.success(Alarms.capability(context))
            "alarm.requestPermission" -> {
                Alarms.requestPermission(activity)
                result.success(Alarms.capability(context))
            }
            "alarm.schedule" -> result.success(Alarms.schedule(context, AlarmSpec.from(args)))
            "alarm.cancel" -> {
                Alarms.cancel(context, args["id"] as? String ?: "wake")
                result.success(null)
            }
            "alarm.test" -> result.success(Alarms.test(context, (args["seconds"] as? Number)?.toInt() ?: 10))
            "alarm.openSettings" -> {
                Alarms.openSettings(activity)
                result.success(null)
            }
            "nudge.schedule" -> {
                Nudges.schedule(
                    context,
                    (args["epochMs"] as? Number)?.toLong() ?: return result.success(null),
                    args["title"] as? String ?: "A gentle nudge",
                    args["body"] as? String ?: "",
                )
                result.success(null)
            }
            "nudge.cancelAll" -> {
                Nudges.cancelAll(context)
                result.success(null)
            }
            "widgets.publish" -> {
                RhythmStore.saveSnapshot(context, args)
                WidgetUpdater.updateAll(context)
                result.success(null)
            }
            "widgets.drainLogs" -> result.success(RhythmStore.drainPendingLogs(context))
            "live.start" -> result.success(WindDownLiveUpdate.post(context, args))
            "live.update" -> {
                WindDownLiveUpdate.post(context, args)
                result.success(null)
            }
            "live.end" -> {
                WindDownLiveUpdate.end(context)
                result.success(null)
            }
            "launch.take" -> {
                result.success(launchAction)
                launchAction = null
            }
            else -> result.notImplemented()
        }
    }
}

/** Static app shortcuts and widget taps arrive as intent extras. */
object Launch {
    const val EXTRA_ACTION = "aquiset_action"
    const val EXTRA_ML = "aquiset_ml"
    const val EXTRA_TAB = "aquiset_tab"

    fun actionFrom(intent: Intent?): Map<String, Any?>? {
        val type = intent?.getStringExtra(EXTRA_ACTION) ?: return null
        intent.removeExtra(EXTRA_ACTION)
        return when (type) {
            "logDrink" -> mapOf(
                "type" to "logDrink",
                "ml" to (intent.getStringExtra(EXTRA_ML)?.toIntOrNull() ?: 250),
                "source" to "shortcut",
            )
            "startWindDown" -> mapOf("type" to "startWindDown")
            "open" -> mapOf("type" to "open", "tab" to (intent.getStringExtra(EXTRA_TAB) ?: "hydrate"))
            else -> null
        }
    }
}
