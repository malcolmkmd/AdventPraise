// OWNER: reader
package com.mDev.AdventPraise.ui.reader

import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.church.AppLink
import com.mDev.AdventPraise.church.WidgetLink
import com.mDev.AdventPraise.data.HymnOfTheDayFeed
import com.mDev.AdventPraise.reader.LecternState
import com.mDev.AdventPraise.reader.LibraryTab
import com.mDev.AdventPraise.ui.root.Destination
import java.time.LocalDate

/**
 * `adventpraise://…` links (WidgetLinks.handle on iOS): a hymn by number in
 * its own hymnal (Hymn of the Day, shortcuts), and the widgets' links. Each
 * leaves church mode first, as iOS does, except Present, which opens it.
 */
object ReaderLinks {
    /** True when [url] was one of the app's links. */
    fun handle(url: String, services: AppServices): Boolean {
        val link = AppLink.parse(url) ?: return false
        val reader = services.reader
        val navigator = services.navigator
        fun leaveChurchMode() = navigator.stack.filterIsInstance<Destination.ChurchMode>().firstOrNull()?.let(navigator::dismiss)
        when (link) {
            is AppLink.OpenHymn -> {
                leaveChurchMode()
                reader.openLink(link.number, link.hymnalId)
            }
            is AppLink.Widget -> when (link.link) {
                WidgetLink.Present ->
                    if (services.store.isPro) navigator.openChurchMode("tray") else navigator.openPaywall(ProFeature.AirPlay, "reader")
                WidgetLink.Paywall -> navigator.openPaywall(ProFeature.AirPlay, "reader")
                WidgetLink.Favourites -> {
                    leaveChurchMode()
                    reader.libraryTab = LibraryTab.Favourites
                    reader.openLectern(LecternState.Library)
                }
                WidgetLink.NumberPad -> {
                    leaveChurchMode()
                    reader.openLectern(LecternState.Pad)
                }
                WidgetLink.HymnOfTheDay -> {
                    leaveChurchMode()
                    val hymnal = reader.hymnal ?: return true
                    HymnOfTheDayFeed.hymn(LocalDate.now(), hymnal)?.let { reader.openLink(it.number, null) }
                }
            }
        }
        return true
    }
}
