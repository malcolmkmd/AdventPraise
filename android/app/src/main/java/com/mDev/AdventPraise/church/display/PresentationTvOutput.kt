package com.mDev.AdventPraise.church.display

import android.app.Activity
import android.app.Application
import android.app.Presentation
import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Display
import android.view.ViewGroup
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import com.mDev.AdventPraise.ui.theme.DS
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach

/** The second displays Android offers for a Presentation, and their comings and goings. */
interface DisplaySource {
    /** Displays that can show a presentation, best first. */
    fun displays(): List<TvRoute>
    /** Calls [onChange] whenever a display is added, removed or changed; returns the unsubscribe. */
    fun listen(onChange: () -> Unit): () -> Unit
}

/** Shows the worship display on a display, and takes it down (a `Presentation` in the app). */
interface WorshipWindow {
    /** False when it couldn't be shown (no activity to own it, or the display went). */
    fun show(displayId: String): Boolean
    fun dismiss()
}

/**
 * The second-display state machine (ExternalDisplaySceneDelegate on iOS),
 * pure so the tests drive it: a display connected is "TV connected" at
 * once; the worship display is up on it while there is Pro and an activity
 * in the foreground to own the window. Buying Pro with the display connected
 * puts it up at once; losing Pro takes it down, and Android goes back to
 * mirroring the phone.
 */
class SecondDisplayMachine(private val window: WorshipWindow) {
    var displays: List<TvRoute> = emptyList()
        private set
    var isPro = false
        private set
    var hasHost = false
        private set
    /** The display the worship display is on, or null. */
    var shownOn: String? = null
        private set

    val state: TvOutputState
        get() = TvOutputState(routes = displays, connected = displays.firstOrNull(), showsWorshipDisplay = shownOn != null)

    fun displaysChanged(now: List<TvRoute>) { displays = now; settle() }
    fun proChanged(value: Boolean) { isPro = value; settle() }
    /** An activity started (true) or the last one stopped (false); a new host means a new window. */
    fun hostChanged(available: Boolean, isNewHost: Boolean = false) {
        hasHost = available
        if (isNewHost && shownOn != null) { window.dismiss(); shownOn = null }
        settle()
    }

    private fun settle() {
        val target = displays.firstOrNull()?.id?.takeIf { isPro && hasHost }
        if (target == shownOn) return
        if (shownOn != null) window.dismiss()
        shownOn = if (target != null && window.show(target)) target else null
    }
}

/**
 * Church mode on a second display: a cable or a screen cast from Android's
 * Cast settings. Watches DisplayManager; with Pro the worship display
 * ([WorshipDisplay], always dark) goes up as a `Presentation` owned by the
 * foreground activity, following [ChurchSession]'s state. Without Pro
 * nothing is drawn, Android mirrors the phone and church mode shows the Go
 * Pro banner.
 */
class PresentationTvOutput(
    private val displaySource: DisplaySource,
    private val isPro: Flow<Boolean>,
    private val scope: CoroutineScope,
    private val window: WorshipWindow,
    private val hosts: HostTracker? = null,
) : TvOutput {
    private val machine = SecondDisplayMachine(window)
    private val mutable = MutableStateFlow(TvOutputState())
    override val state: StateFlow<TvOutputState> = mutable.asStateFlow()
    private var unlisten: (() -> Unit)? = null

    override fun start() {
        if (unlisten != null) return
        unlisten = displaySource.listen { update { machine.displaysChanged(displaySource.displays()) } }
        update { machine.displaysChanged(displaySource.displays()) }
        isPro.distinctUntilChanged().onEach { pro -> update { machine.proChanged(pro) } }.launchIn(scope)
        hosts?.onChange = { available, isNew -> update { machine.hostChanged(available, isNew) } }
        hosts?.let { update { machine.hostChanged(it.current != null) } }
    }

    override fun stop() {
        unlisten?.invoke()
        unlisten = null
        hosts?.onChange = null
        window.dismiss()
    }

    /** A second display is in use as soon as Android connects it: nothing to pick. */
    override fun select(route: TvRoute) = Unit

    /** Only unplugging (or stopping the cast in Android's settings) ends it. */
    override fun disconnect() = Unit

    private fun update(change: () -> Unit) {
        change()
        mutable.value = machine.state
    }
}

/** Android's presentation displays (DisplayManager), on the main thread. */
class SystemDisplays(context: Context) : DisplaySource {
    private val manager = context.getSystemService(DisplayManager::class.java)

    override fun displays(): List<TvRoute> =
        manager?.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION).orEmpty()
            .filter { it.isValid && it.displayId != Display.DEFAULT_DISPLAY }
            .map { TvRoute(it.displayId.toString(), it.name ?: "TV", TvRouteKind.SecondDisplay) }

    override fun listen(onChange: () -> Unit): () -> Unit {
        val manager = manager ?: return {}
        val listener = object : DisplayManager.DisplayListener {
            override fun onDisplayAdded(displayId: Int) = onChange()
            override fun onDisplayRemoved(displayId: Int) = onChange()
            override fun onDisplayChanged(displayId: Int) = onChange()
        }
        manager.registerDisplayListener(listener, Handler(Looper.getMainLooper()))
        return { manager.unregisterDisplayListener(listener) }
    }
}

/**
 * The activity in the foreground, which owns the Presentation's window
 * (a Presentation is a dialog of an activity). Started → it hosts; its stop
 * takes the worship display down until an activity starts again.
 */
class HostTracker(app: Application) {
    var current: ComponentActivity? = null
        private set
    /** (an activity can host, the host is a different activity than before). */
    var onChange: ((Boolean, Boolean) -> Unit)? = null

    init {
        app.registerActivityLifecycleCallbacks(object : Application.ActivityLifecycleCallbacks {
            override fun onActivityStarted(activity: Activity) {
                val host = activity as? ComponentActivity ?: return
                val isNew = current !== host
                current = host
                onChange?.invoke(true, isNew)
            }
            override fun onActivityStopped(activity: Activity) {
                if (activity !== current) return
                current = null
                onChange?.invoke(false, false)
            }
            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit
            override fun onActivityResumed(activity: Activity) = Unit
            override fun onActivityPaused(activity: Activity) = Unit
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
            override fun onActivityDestroyed(activity: Activity) = Unit
        })
    }
}

/**
 * The worship display as a `Presentation` on a second display, owned by the
 * host activity. Compose draws [content] in it; the window is always dark
 * (the Stage), whatever the phone's appearance, and keeps the TV awake.
 */
class PresentationWindow(
    private val hosts: HostTracker,
    private val content: @androidx.compose.runtime.Composable () -> Unit,
) : WorshipWindow {
    private var presentation: Presentation? = null

    override fun show(displayId: String): Boolean {
        val activity = hosts.current ?: return false
        val manager = activity.getSystemService(DisplayManager::class.java) ?: return false
        val display = displayId.toIntOrNull()?.let(manager::getDisplay) ?: return false
        return runCatching {
            val p = Presentation(activity, display)
            val view = ComposeView(p.context).apply {
                setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnDetachedFromWindow)
                setContent(content)
            }
            p.window?.let { w ->
                w.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                w.setBackgroundDrawable(android.graphics.drawable.ColorDrawable(DS.Palette.stage.toArgb()))
                w.decorView.setViewTreeLifecycleOwner(activity)
                w.decorView.setViewTreeSavedStateRegistryOwner(activity)
                w.decorView.setViewTreeViewModelStoreOwner(activity)
            }
            p.setContentView(view, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
            p.setOnDismissListener { if (presentation === p) presentation = null }
            p.show()
            presentation = p
            true
        }.getOrElse { false }
    }

    override fun dismiss() {
        val p = presentation ?: return
        presentation = null
        runCatching { p.dismiss() }
    }
}
