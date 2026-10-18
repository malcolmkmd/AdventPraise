package com.mDev.AdventPraise.widget

import android.content.Intent
import androidx.compose.runtime.snapshotFlow
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.church.AppLink
import com.mDev.AdventPraise.church.WidgetLink
import com.mDev.AdventPraise.data.HymnOfTheDayFeed
import com.mDev.AdventPraise.reader.LecternState
import com.mDev.AdventPraise.ui.root.Destination
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

/**
 * `adventpraise://…` from the widgets (WidgetLinks on iOS): a hymn in its
 * hymnal (Hymn of the Day), church mode, the paywall, Favourites, the
 * number pad. MainActivity hands every VIEW intent here.
 */
object WidgetLinks {
    /** True when [intent] was one of the app's links. */
    fun handle(intent: Intent?, services: AppServices): Boolean {
        val url = intent?.takeIf { it.action == Intent.ACTION_VIEW }?.dataString ?: return false
        val link = AppLink.parse(url) ?: return false
        val navigator = services.navigator
        val reader = services.reader
        fun leaveChurchMode() = navigator.stack.firstOrNull { it is Destination.ChurchMode }?.let(navigator::dismiss)
        services.scope.launch {
            // A cold start: wait for the hymnal before opening anything in it.
            val hymnal = withTimeoutOrNull(10_000) { snapshotFlow { reader.hymnal }.filterNotNull().first() } ?: return@launch
            when (link) {
                is AppLink.OpenHymn -> {
                    leaveChurchMode()
                    // The number is only meaningful in its own hymnal.
                    val target = link.hymnalId
                    if (target != null && target != hymnal.id) {
                        val info = reader.catalogue.firstOrNull { it.id == target }
                        if (info != null) {
                            reader.switchHymnal(info, "lectern")
                            withTimeoutOrNull(10_000) { snapshotFlow { reader.hymnal?.id }.first { it == target } }
                        }
                    }
                    open(services, link.number)
                }
                is AppLink.Widget -> when (link.link) {
                    WidgetLink.Present ->
                        if (services.store.isPro) navigator.openChurchMode("tray") else navigator.openPaywall(ProFeature.AirPlay)
                    WidgetLink.Paywall -> navigator.openPaywall(ProFeature.AirPlay)
                    WidgetLink.Favourites -> { leaveChurchMode(); reader.openLectern(LecternState.Library) }
                    WidgetLink.NumberPad -> { leaveChurchMode(); reader.openLectern(LecternState.Pad) }
                    WidgetLink.HymnOfTheDay -> {
                        leaveChurchMode()
                        HymnOfTheDayFeed.hymn(java.time.LocalDate.now(), hymnal)?.let { open(services, it.number) }
                    }
                }
            }
        }
        return true
    }

    /** Opened by number from outside: off any running list, as the number pad opens it. */
    private fun open(services: AppServices, number: Int) {
        val reader = services.reader
        if (reader.open(number, "numpad")) services.queue.stop()
    }
}
