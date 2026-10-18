package com.mDev.AdventPraise

import android.app.Application
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.audio.AccompanimentPlayer
import com.mDev.AdventPraise.audio.FreePlays
import com.mDev.AdventPraise.billing.PurchaseStore
import com.mDev.AdventPraise.reader.ReaderModel
import com.mDev.AdventPraise.settings.ReadingSettings
import kotlinx.coroutines.MainScope

/** The app's shared models, built once (AppServices on iOS). */
class AppServices(app: Application) {
    val scope = MainScope()
    val settings = ReadingSettings(app)
    val reader = ReaderModel(app, scope)
    val store = PurchaseStore(app, scope)
    val freePlays = FreePlays(app)
    val player = AccompanimentPlayer(app)

    fun start() {
        reader.start()
        store.start()
        Analytics.setAppearance(settings.surface.key, settings.largePrint)
    }
}

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
