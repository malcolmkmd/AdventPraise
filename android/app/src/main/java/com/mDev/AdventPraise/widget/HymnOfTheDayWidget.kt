package com.mDev.AdventPraise.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.datastore.preferences.core.Preferences
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.LocalContext
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import com.mDev.AdventPraise.data.HymnOfTheDay
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Hymn of the Day (free): a new hymn every day with its first verse, on
 * evergreen. Small, medium and large as on iOS; a tap opens exactly that
 * hymn in its hymnal (`adventpraise://hymn/<n>?hymnal=<id>`). The app
 * writes the coming 30 days; the widget picks today's.
 */
class HymnOfTheDayWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Responsive(WidgetSizes.all)

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val prefs = currentState<Preferences>()
            // The widget's own copy (written by the sync), else what the app last wrote.
            val json = prefs[WidgetStore.daysKey] ?: WidgetStore.daysJson(LocalContext.current)
            val hymn = WidgetStore.today(HymnOfTheDay.decodeAll(json)) ?: HymnOfTheDay.placeholder
            HymnOfTheDayContent(hymn)
        }
    }
}

@Composable
internal fun HymnOfTheDayContent(hymn: HymnOfTheDay) {
    val context = LocalContext.current
    val family = currentFamily()
    val small = family == WidgetFamily.Small
    val large = family == WidgetFamily.Large
    val lineCount = when (family) { WidgetFamily.Small -> 2; WidgetFamily.Medium -> 3; WidgetFamily.Large -> 8 }
    val gap = if (small) 4.dp else 8.dp
    Column(
        GlanceModifier
            .fillMaxSize()
            .appWidgetBackground()
            .background(WidgetColors.evergreen)
            .cornerRadius(22.dp)
            .padding(16.dp)
            .clickable(openLink(context, hymn.url)),
    ) {
        Text("HYMN OF THE DAY", style = style(Caption2, WidgetColors.brass, FontWeight.Bold))
        Spacer(GlanceModifier.height(gap))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(hymn.number.toString(), style = style(if (small) Title2 else Title, WidgetColors.brass, FontWeight.Medium, serif = true), maxLines = 1)
            Spacer(GlanceModifier.width(6.dp))
            Text(hymn.title, style = style(Headline, WidgetColors.white, serif = true), maxLines = 2)
        }
        Spacer(GlanceModifier.height(gap))
        Column {
            hymn.lines.take(lineCount).forEach { line ->
                Text(line, style = style(if (large) Body else Caption, WidgetColors.white.copy(alpha = 0.85f), serif = true),
                    maxLines = if (large) 2 else 1)
            }
        }
        Spacer(GlanceModifier.defaultWeight())
        if (large) Text(hymn.hymnal, style = style(Caption, WidgetColors.white.copy(alpha = 0.6f)), maxLines = 1)
    }
}

/** Hymn of the Day's receiver; also wakes just after midnight for the new day's hymn. */
class HymnOfTheDayWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = HymnOfTheDayWidget()

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        ChurchWidgetSync.scheduleMidnight(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_NEW_DAY) {
            val pending = goAsync()
            CoroutineScope(SupervisorJob() + Dispatchers.Default).launch {
                try {
                    ChurchWidgetSync.refreshHymnOfTheDay(context)
                    ChurchWidgetSync.scheduleMidnight(context)
                } finally {
                    pending.finish()
                }
            }
            return
        }
        super.onReceive(context, intent)
    }

    companion object {
        const val ACTION_NEW_DAY = "com.mDev.AdventPraise.widget.HYMN_OF_THE_DAY_NEW_DAY"
    }
}
