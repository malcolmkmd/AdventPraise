package com.mDev.AdventPraise

import android.content.Intent
import android.os.Bundle
import android.view.KeyEvent
import android.view.KeyboardShortcutGroup
import android.view.Menu
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.mDev.AdventPraise.shortcuts.AppShortcuts
import com.mDev.AdventPraise.ui.design.Haptics
import com.mDev.AdventPraise.ui.root.AdventPraiseRoot
import com.mDev.AdventPraise.ui.root.ReaderCommands
import com.mDev.AdventPraise.widget.WidgetLinks

class MainActivity : ComponentActivity() {
    private val services get() = (application as AdventPraiseApp).services

    override fun onCreate(savedInstanceState: Bundle?) {
        // The system splash shows the logo on evergreen (the Stage in dark mode); the
        // Compose splash takes over from the same frame and reveals the app.
        val splash = installSplashScreen()
        splash.setOnExitAnimationListener { it.remove() }
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        Haptics.attach(window.decorView)
        services.navigator.restore(savedInstanceState?.getString(KEY_NAVIGATION))
        setContent { AdventPraiseRoot(services, splash = savedInstanceState == null) }
        // A long-pressed icon's shortcut (res/xml/shortcuts.xml), or adventpraise:// from the widgets, on a cold start.
        if (savedInstanceState == null && !WidgetLinks.handle(intent, services)) AppShortcuts.handle(intent, services)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (!WidgetLinks.handle(intent, services)) AppShortcuts.handle(intent, services)
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putString(KEY_NAVIGATION, services.navigator.save())
    }

    /** The reader's keyboard commands (ReaderCommands on iOS). */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean =
        ReaderCommands.handle(event, services) || super.dispatchKeyEvent(event)

    override fun onProvideKeyboardShortcuts(data: MutableList<KeyboardShortcutGroup>, menu: Menu?, deviceId: Int) {
        super.onProvideKeyboardShortcuts(data, menu, deviceId)
        data += ReaderCommands.shortcutGroup()
    }

    override fun onStop() {
        super.onStop()
        // No background playback yet: the accompaniment pauses when the app leaves the screen.
        if (!isChangingConfigurations) services.player.pause()
    }

    private companion object {
        const val KEY_NAVIGATION = "navigation.stack"
    }
}
