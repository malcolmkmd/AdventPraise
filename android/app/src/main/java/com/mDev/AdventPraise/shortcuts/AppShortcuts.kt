// OWNER: shell
package com.mDev.AdventPraise.shortcuts

import android.content.Intent
import androidx.compose.runtime.snapshotFlow
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.analytics.IntentKind
import com.mDev.AdventPraise.data.HymnOfTheDayFeed
import com.mDev.AdventPraise.reader.LecternState
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import java.time.LocalDate

/**
 * The app shortcuts on a long-press of the icon (res/xml/shortcuts.xml): the
 * Android side of iOS's App Shortcuts (HymnIntents.swift). Each is an
 * `adventpraise://shortcut/<name>` link to MainActivity:
 *
 * - `open-hymn`: Open Hymn. iOS asks "Which hymn number?"; here the number pad opens.
 * - `hymn-of-the-day`: today's hymn in the hymnal being read.
 * - `church-mode`: Start Church Mode on the open hymn.
 *
 * `intent_run` is sent as for the Siri intents. The widgets' own links
 * (adventpraise://present, …) are the church area's and are left alone.
 */
enum class AppShortcut(val key: String) {
    OpenHymn("open-hymn"),
    HymnOfTheDay("hymn-of-the-day"),
    ChurchMode("church-mode");

    val url: String get() = "$PREFIX$key"

    companion object {
        const val PREFIX = "adventpraise://shortcut/"

        /** The shortcut a link names, or null for any other link. */
        fun parse(url: String?): AppShortcut? {
            if (url == null || !url.startsWith(PREFIX)) return null
            val key = url.removePrefix(PREFIX).substringBefore('?').trimEnd('/')
            return entries.firstOrNull { it.key == key }
        }
    }
}

object AppShortcuts {
    /**
     * Runs the shortcut [intent] carries, once the reader has its hymnal.
     * True when it was one of ours (the caller then clears the intent's data).
     */
    fun handle(intent: Intent?, services: AppServices): Boolean {
        val shortcut = AppShortcut.parse(intent?.dataString) ?: return false
        services.scope.launch {
            val reader = services.reader
            val hymnal = snapshotFlow { reader.hymnal }.filterNotNull().first()
            val navigator = services.navigator
            when (shortcut) {
                AppShortcut.OpenHymn -> {
                    navigator.dismissAll()
                    reader.closeMenu()
                    reader.openLectern(LecternState.Pad)
                    Analytics.track(AnalyticsEvent.IntentRun(IntentKind.OpenHymn, true))
                }
                AppShortcut.HymnOfTheDay -> {
                    navigator.dismissAll()
                    val hymn = HymnOfTheDayFeed.hymn(LocalDate.now(), hymnal)
                    if (hymn != null) navigator.openHymn(hymn.number, "numpad")
                }
                AppShortcut.ChurchMode -> {
                    Analytics.track(AnalyticsEvent.IntentRun(IntentKind.ChurchMode, true))
                    navigator.openChurchMode("siri")
                }
            }
        }
        return true
    }
}
