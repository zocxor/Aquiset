package com.aquiset.app.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.LinearProgressIndicator
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.Button
import com.aquiset.app.MainActivity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * "Today" home-screen widget (Jetpack Glance): water so far, bedtime and
 * alarm, and a one-tap +250 ml button that works without opening the app.
 * Uses GlanceTheme so it follows Material You / dynamic colour.
 */
class TodayWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val s = RhythmStore.snapshot(context)
        provideContent { GlanceTheme { Content(s) } }
    }

    @Composable
    private fun Content(s: RhythmStore.Snapshot) {
        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(GlanceTheme.colors.widgetBackground)
                .cornerRadius(24.dp)
                .padding(14.dp)
                .clickable(actionStartActivity<MainActivity>()),
            verticalAlignment = Alignment.Top,
        ) {
            Text(
                "TODAY",
                style = TextStyle(fontSize = 11.sp, fontWeight = FontWeight.Bold, color = GlanceTheme.colors.onSurfaceVariant),
            )
            Text(
                "${s.totalMl} ml",
                style = TextStyle(fontSize = 26.sp, fontWeight = FontWeight.Medium, color = GlanceTheme.colors.onSurface),
            )
            Text(
                "of ${s.goalMl} ml · your goal",
                style = TextStyle(fontSize = 12.sp, color = GlanceTheme.colors.onSurfaceVariant),
            )
            Spacer(GlanceModifier.height(8.dp))
            LinearProgressIndicator(
                progress = s.progress,
                modifier = GlanceModifier.fillMaxWidth(),
                color = GlanceTheme.colors.primary,
                backgroundColor = GlanceTheme.colors.surfaceVariant,
            )
            Spacer(GlanceModifier.height(8.dp))
            Text(
                "Bed ${s.bedtimeLabel} · ${if (s.alarmOn) "Alarm ${s.wakeLabel}" else "Alarm off"}",
                style = TextStyle(fontSize = 12.sp, color = GlanceTheme.colors.onSurfaceVariant),
            )
            Spacer(GlanceModifier.defaultWeight())
            Row(modifier = GlanceModifier.fillMaxWidth()) {
                Button(
                    text = "+ 250 ml",
                    onClick = actionRunCallback<LogDrinkCallback>(actionParametersOf(LogDrinkCallback.ML to 250)),
                    modifier = GlanceModifier.fillMaxWidth(),
                )
            }
        }
    }
}

class TodayWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = TodayWidget()
}

/** Runs in the widget process: queues the drink and refreshes the widget. */
class LogDrinkCallback : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val ml = parameters[ML] ?: 250
        RhythmStore.appendPendingLog(context, ml, "widget")
        TodayWidget().update(context, glanceId)
    }

    companion object {
        val ML = ActionParameters.Key<Int>("ml")
    }
}

object WidgetUpdater {
    fun updateAll(context: Context) {
        CoroutineScope(Dispatchers.Default).launch {
            if (GlanceAppWidgetManager(context).getGlanceIds(TodayWidget::class.java).isNotEmpty()) {
                TodayWidget().updateAll(context)
            }
        }
    }
}
