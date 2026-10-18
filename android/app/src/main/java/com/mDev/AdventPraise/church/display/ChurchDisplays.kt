package com.mDev.AdventPraise.church.display

import android.app.Application
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.church.ChurchReaderLink
import com.mDev.AdventPraise.church.ChurchSession
import com.mDev.AdventPraise.church.notification.ChurchNotifier
import com.mDev.AdventPraise.settings.ReadingSettings
import com.mDev.AdventPraise.widget.ChurchWidgetSync
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.map

/**
 * Everything church mode shows outside the phone's own screen: the TV
 * ([tv]: a second display now, Cast later), its pictures, the mirroring
 * banner's watcher, and (started with the app) the reader link, the
 * widgets' sync and the ongoing notification.
 */
class ChurchDisplays(
    private val app: Application,
    session: ChurchSession,
    settings: ReadingSettings,
    scope: CoroutineScope,
    /** More ways to a TV after the second display: the Cast receiver (cast/ChurchCast). */
    castOutputs: List<TvOutput> = emptyList(),
) {
    val images = ChurchImages(app)
    val mirroring = ScreenMirroring(app)
    private val hosts = HostTracker(app)

    /** A second display: the worship display as a Presentation, with Pro. */
    private val secondDisplay = PresentationTvOutput(
        displaySource = SystemDisplays(app),
        isPro = session.state.map { it.isPro },
        scope = scope,
        window = PresentationWindow(hosts) {
            val state by session.state.collectAsState()
            WorshipDisplay(state, settings.worshipPointSize, settings.largePrint, image = images::image)
        },
        hosts = hosts,
    )

    /**
     * Every way to a TV, in the chooser's order. Cast: add the Cast output
     * here (after the second display, so a cable wins); church mode, the
     * chooser and the session's "TV connected" follow on their own.
     */
    val tv = TvOutputs(session, scope, listOf(secondDisplay) + castOutputs)

    private var started = false

    fun start(services: AppServices) {
        if (started) return
        started = true
        ChurchReaderLink.start(services.church, services.scope, { services.reader.hymnal }, { services.reader.hymn }, services.queue)
        tv.start()
        ChurchWidgetSync.start(app, services)
        ChurchNotifier.start(app, services)
    }
}
