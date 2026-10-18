package com.mDev.AdventPraise

import android.app.Application
import androidx.compose.runtime.snapshotFlow
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.audio.AccompanimentPlayer
import com.mDev.AdventPraise.billing.FreePlays
import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.billing.PurchaseStore
import com.mDev.AdventPraise.church.ChurchHost
import com.mDev.AdventPraise.church.ChurchSession
import com.mDev.AdventPraise.data.Catalogs
import com.mDev.AdventPraise.data.HymnQueue
import com.mDev.AdventPraise.data.PlaylistBook
import com.mDev.AdventPraise.extras.ServicePlanner
import com.mDev.AdventPraise.reader.ReaderModel
import com.mDev.AdventPraise.settings.AppSettings
import com.mDev.AdventPraise.settings.ReaderHistory
import com.mDev.AdventPraise.settings.ReadingSettings
import com.mDev.AdventPraise.settings.SharedPreferencesStore
import com.mDev.AdventPraise.ui.design.Haptics
import com.mDev.AdventPraise.ui.root.RootNavigator
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.launch

/**
 * The app's shared models, built once (AppServices on iOS), so the UI, the
 * widgets and the notification actions drive the same reader.
 *
 * iOS builds, in order: the player, reading settings, the purchase store, free
 * plays, the reader, church presentation, screen mirroring and the tour, then
 * wires the player to the playlist and the free plays. The areas add theirs here
 * in that order (church, mirroring, tour) as they land.
 */
class AppServices(app: Application) {
    val scope = MainScope()
    /** Every bundled catalogue (hymnals, MIDI, sheet music, collections, stories, scripture), read lazily. */
    val catalogs = Catalogs(app.assets)
    val analytics = Analytics
    val player = AccompanimentPlayer(app)
    val settings = ReadingSettings(app)
    /** Tour and What's New seen, sheet music mode, tempo, announcement recents. */
    val appSettings = AppSettings(app)
    /** Last hymnal, last hymn and recents per numbering. */
    val history = ReaderHistory(app)
    val store = PurchaseStore(app, scope)
    val freePlays = FreePlays(app)
    val reader = ReaderModel(app, scope)
    /** Playlists and service plans live beside the reader's own keys, as in iOS's UserDefaults. */
    private val readerStore = SharedPreferencesStore(app, ReaderHistory.PREFS_NAME)
    val playlists = PlaylistBook(readerStore)
    val queue = HymnQueue(playlists)
    val planner = ServicePlanner(readerStore)
    /** Church mode's one state holder: presenter, remote, TV and Cast all read it. */
    val church = ChurchSession(object : ChurchHost {
        override fun goToNextHymn(): Boolean = reader.goToNext("church_mode") != null
        override fun showPaywall(feature: ProFeature) = reader.showPaywall(feature, "church_mode")
    })
    /** What is presented over the reader; the areas open each other through it. */
    val navigator = RootNavigator(reader)

    init {
        // The Haptics switch in More → Reading.
        Haptics.isEnabled = { settings.haptics }
    }

    fun start() {
        reader.start()
        store.start()
        // Pro unlocks church mode on a TV.
        scope.launch { snapshotFlow { store.isPro }.collect(church::setPro) }
        Analytics.setAppearance(settings.surface.key, settings.largePrint)
    }
}

/**
 * Entry point (AdventPraiseApp): analytics first, then the shared models, then
 * the store starts listening (`AppServices.shared.store.start()` on iOS).
 */
class AdventPraiseApp : Application() {
    lateinit var services: AppServices
        private set

    override fun onCreate() {
        super.onCreate()
        Analytics.start(this)
        services = AppServices(this)
        services.start()
    }
}
