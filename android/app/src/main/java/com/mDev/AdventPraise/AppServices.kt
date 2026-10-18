package com.mDev.AdventPraise

import android.app.Application
import androidx.compose.runtime.snapshotFlow
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.HymnSource
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.audio.AccompanimentPlayer
import com.mDev.AdventPraise.audio.AccompanimentTransport
import com.mDev.AdventPraise.audio.LocalAccompaniment
import com.mDev.AdventPraise.audio.NowPlaying
import com.mDev.AdventPraise.billing.FreePlays
import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.billing.PurchaseStore
import com.mDev.AdventPraise.billing.StoreFeedback
import com.mDev.AdventPraise.church.ChurchHost
import com.mDev.AdventPraise.church.ChurchSession
import com.mDev.AdventPraise.church.display.ChurchDisplays
import com.mDev.AdventPraise.data.Catalogs
import com.mDev.AdventPraise.data.Hymn
import com.mDev.AdventPraise.data.HymnQueue
import com.mDev.AdventPraise.data.PlaylistBook
import com.mDev.AdventPraise.extras.ServicePlanner
import com.mDev.AdventPraise.reader.ReaderModel
import com.mDev.AdventPraise.settings.AppSettings
import com.mDev.AdventPraise.settings.PlaybackTempo
import com.mDev.AdventPraise.settings.ReaderHistory
import com.mDev.AdventPraise.settings.ReadingSettings
import com.mDev.AdventPraise.settings.SharedPreferencesStore
import com.mDev.AdventPraise.ui.design.HapticEvent
import com.mDev.AdventPraise.ui.design.Haptics
import com.mDev.AdventPraise.ui.root.RootNavigator
import com.mDev.AdventPraise.ui.tour.TourModel
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
    /** Tour and What's New seen, sheet music mode, tempo, announcement recents. */
    val appSettings = AppSettings(app)
    /**
     * The accompaniment's sound and clock: the phone's piano. Everything that
     * follows the music reads the position from here (via [player]); a Cast
     * receiver replaces it with `player.use(...)`.
     */
    val accompaniment: AccompanimentTransport = LocalAccompaniment(app, scope)
    val player = AccompanimentPlayer(accompaniment, scope, object : AccompanimentPlayer.TempoStore {
        override val tempo: PlaybackTempo get() = appSettings.tempo
        override fun updateTempo(value: PlaybackTempo) = appSettings.updateTempo(value)
    })
    /** The lock screen and notification controls. */
    val nowPlaying = NowPlaying(app, player)
    val settings = ReadingSettings(app)
    /** Last hymnal, last hymn and recents per numbering. */
    val history = ReaderHistory(app)
    val store = PurchaseStore(app, scope)
    val freePlays = FreePlays(app)
    /** Playlists and service plans live beside the reader's own keys, as in iOS's UserDefaults. */
    private val readerStore = SharedPreferencesStore(app, ReaderHistory.PREFS_NAME)
    val playlists = PlaylistBook(readerStore)
    val queue = HymnQueue(playlists)
    val planner = ServicePlanner(readerStore)
    /** The reader, on the history, queue and playlists above (one of each, shared). */
    val reader = ReaderModel(catalogs, history, queue, playlists, scope)
    /** Church mode's one state holder: presenter, remote, TV and Cast all read it. */
    val church = ChurchSession(object : ChurchHost {
        // The running playlist or service plan's next entry, else the next number.
        override fun goToNextHymn(): Boolean {
            val hymnal = reader.hymnal ?: return false
            val hymn = reader.hymn ?: return false
            val next = queue.goToNext(hymnal, hymn) ?: return false
            reader.show(next, "church_mode")
            return true
        }
        override fun showPaywall(feature: ProFeature) = reader.showPaywall(feature, "church_mode")
    })
    /** Church mode beyond the phone: the TV (`displays.tv`), pictures, the mirroring banner, widgets, the notification. */
    val displays = ChurchDisplays(app, church, settings, scope)
    /** What is presented over the reader; the areas open each other through it. */
    val navigator = RootNavigator(reader)
    /** The onboarding tour (TourModel), once after What's New or from More. */
    val tour = TourModel(appSettings)

    init {
        // The Haptics switch in More → Reading.
        Haptics.isEnabled = { settings.haptics }
        // Free users get a few plays of the accompaniment, then it is Pro. A locked
        // play asks for the paywall instead (AdventPraiseApp.swift).
        player.isLocked = { !store.isPlayerUnlocked && freePlays.locksNewPlay }
        player.onLocked = {
            navigator.openPaywall(ProFeature.Player, "reader")
            Analytics.track(AnalyticsEvent.PlayLimitPaywallShown(player.hymn?.number ?: reader.hymn?.number ?: 0))
        }
        player.onNewPlay = {
            // The tour's plays are a demonstration: never counted.
            val hymn = player.hymn
            if (!store.isPlayerUnlocked && !freePlays.isUsedUp && !freePlays.isTourActive && hymn != null) {
                Analytics.track(AnalyticsEvent.FreePlayUsed(hymn.number, freePlays.spend()))
            }
        }
        // Playlist Play starts the accompaniment; each hymn hands on to the next
        // when it finishes. Wired here, not in a view, so it carries on in church
        // mode and with the screen locked (AdventPraiseApp.swift).
        reader.onPlaylistStarted = { hymn -> reader.hymnal?.let { player.start(hymn, it.info) } }
        player.onFinish = {
            reader.advancePlaylist()?.let { next -> reader.hymnal?.let { player.start(next, it.info) } }
        }
        player.onNextTrack = { goToNextHymn(HymnSource.LockScreen) }
        // While the tour runs, its Play step is free (FreePlays.isTourActive).
        tour.onActiveChanged = { active -> freePlays.isTourActive = active }
        // Purchases are felt, as iOS's store plays them.
        store.onFeedback = { feedback ->
            Haptics.play(when (feedback) {
                StoreFeedback.PurchaseComplete -> HapticEvent.PurchaseComplete
                StoreFeedback.Success -> HapticEvent.Success
                StoreFeedback.Warning -> HapticEvent.Warning
                StoreFeedback.Error -> HapticEvent.Error
            })
        }
    }

    /**
     * Next hymn (or next playlist entry); keeps playing if it was. For the lock
     * screen and the assistant, so no haptic.
     */
    fun goToNextHymn(source: HymnSource): Hymn? {
        val wasPlaying = player.isPlaying
        val next = reader.goToNext(source, feedback = null) ?: return null
        val info = reader.hymnal?.info ?: return next
        if (wasPlaying) player.start(next, info) else player.cue(next, info)
        return next
    }

    fun start() {
        reader.start()
        store.start()
        // Pro unlocks church mode on a TV.
        scope.launch { snapshotFlow { store.isPro }.collect(church::setPro) }
        displays.start(this)
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
