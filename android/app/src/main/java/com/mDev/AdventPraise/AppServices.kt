package com.mDev.AdventPraise

import android.app.Application
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.audio.AccompanimentPlayer
import com.mDev.AdventPraise.audio.FreePlays
import com.mDev.AdventPraise.billing.PurchaseStore
import com.mDev.AdventPraise.reader.ReaderModel
import com.mDev.AdventPraise.settings.ReadingSettings
import com.mDev.AdventPraise.ui.design.Haptics
import com.mDev.AdventPraise.ui.root.RootNavigator
import kotlinx.coroutines.MainScope

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
    val player = AccompanimentPlayer(app)
    val settings = ReadingSettings(app)
    val store = PurchaseStore(app, scope)
    val freePlays = FreePlays(app)
    val reader = ReaderModel(app, scope)
    /** What is presented over the reader; the areas open each other through it. */
    val navigator = RootNavigator(reader)

    init {
        // The Haptics switch in More → Reading.
        Haptics.isEnabled = { settings.haptics }
    }

    fun start() {
        reader.start()
        store.start()
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
