package com.mDev.AdventPraise.widget

import android.app.AlarmManager
import android.app.Application
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.compose.runtime.snapshotFlow
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.state.updateAppWidgetState
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.church.ChurchWidgetState
import com.mDev.AdventPraise.data.HymnOfTheDay
import com.mDev.AdventPraise.data.HymnOfTheDayFeed
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.onEach
import java.time.LocalDate
import java.time.ZoneId

/**
 * What the widgets show, written by the app (the App Group's UserDefaults
 * on iOS): the Church Remote's state under "churchWidget.state.v1" and the
 * next 30 days of Hymn of the Day under "hymnOfTheDay.days.v1", in the
 * app's "widgets" preferences, with the iOS JSON.
 */
object WidgetStore {
    private const val PREFS = "widgets"
    const val DAYS_KEY = "hymnOfTheDay.days.v1"

    /** Each widget's Glance state holds the same JSON, so writing it recomposes the widget. */
    val churchKey = stringPreferencesKey(ChurchWidgetState.KEY)
    val daysKey = stringPreferencesKey(DAYS_KEY)
    /** The day a Hymn of the Day widget last drew, so midnight changes it. */
    val dayKey = stringPreferencesKey("hymnOfTheDay.today")

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun churchJson(context: Context): String? = prefs(context).getString(ChurchWidgetState.KEY, null)
    fun saveChurch(context: Context, json: String) = prefs(context).edit().putString(ChurchWidgetState.KEY, json).apply()

    fun daysJson(context: Context): String? = prefs(context).getString(DAYS_KEY, null)
    fun saveDays(context: Context, json: String) = prefs(context).edit().putString(DAYS_KEY, json).apply()

    /** Today's onwards, else the last day written, else nothing (the widget shows its placeholder). */
    fun today(days: List<HymnOfTheDay>, today: LocalDate = LocalDate.now()): HymnOfTheDay? {
        val upcoming = days.filter { !it.date.isBefore(today) }.sortedBy { it.date }
        return upcoming.firstOrNull() ?: days.maxByOrNull { it.date }
    }
}

/**
 * Keeps the widgets current (ChurchWidgetSync on iOS): the Church Remote's
 * state whenever [com.mDev.AdventPraise.church.ChurchState.widgetState]
 * changes (a burst of changes, one update), and Hymn of the Day's next 30
 * days whenever the reader's hymnal changes. The widgets' buttons are wired
 * through [com.mDev.AdventPraise.church.notification.ChurchRemoteReceiver].
 */
@OptIn(FlowPreview::class)
object ChurchWidgetSync {
    fun start(app: Application, services: AppServices) {
        services.church.state
            .map { it.widgetState.toJson() }
            .distinctUntilChanged()
            .onEach { WidgetStore.saveChurch(app, it) }
            .debounce(150)
            .onEach { push(app, ChurchRemoteWidget(), WidgetStore.churchKey, it) }
            .launchIn(services.scope)

        snapshotFlow { services.reader.hymnal }
            .filterNotNull()
            .map { hymnal ->
                val days = HymnOfTheDayFeed.days(hymnal, LocalDate.now(), 30)
                "${hymnal.id}|${LocalDate.now()}" to HymnOfTheDay.encodeAll(days)
            }
            .distinctUntilChanged { a, b -> a.first == b.first }
            .onEach { (_, json) ->
                WidgetStore.saveDays(app, json)
                refreshHymnOfTheDay(app)
                scheduleMidnight(app)
            }
            .launchIn(services.scope)
    }

    /** Hymn of the Day redrawn (a new day, or new days written). */
    suspend fun refreshHymnOfTheDay(context: Context) {
        push(context, HymnOfTheDayWidget(), WidgetStore.daysKey, WidgetStore.daysJson(context).orEmpty())
        push(context, HymnOfTheDayWidget(), WidgetStore.dayKey, LocalDate.now().toString())
    }

    /** Writes [value] into every placed widget's state and redraws it. */
    private suspend fun push(context: Context, widget: GlanceAppWidget, key: androidx.datastore.preferences.core.Preferences.Key<String>, value: String) {
        runCatching {
            val ids = GlanceAppWidgetManager(context).getGlanceIds(widget.javaClass)
            ids.forEach { id ->
                updateAppWidgetState(context, id) { it[key] = value }
                widget.update(context, id)
            }
        }
    }

    /** A new day starts a new Hymn of the Day: wake the widget just after midnight (inexact, no permission). */
    fun scheduleMidnight(context: Context) {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        val midnight = LocalDate.now().plusDays(1).atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli() + 60_000
        val intent = Intent(context, HymnOfTheDayWidgetReceiver::class.java).setAction(HymnOfTheDayWidgetReceiver.ACTION_NEW_DAY)
        val pending = PendingIntent.getBroadcast(context, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        runCatching { alarms.set(AlarmManager.RTC, midnight, pending) }
    }
}
