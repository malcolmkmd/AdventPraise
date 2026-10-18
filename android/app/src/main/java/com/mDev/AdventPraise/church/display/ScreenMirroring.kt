package com.mDev.AdventPraise.church.display

import android.app.Activity
import android.app.Application
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.analytics.MirroringRoute
import java.util.function.Consumer

/**
 * Without Pro a TV gets no worship display of its own, so Android mirrors
 * the phone; mirroring and recording show the phone as it is. While one is
 * on, a free user's screen carries the small Go Pro banner (ScreenMirroring
 * on iOS). A connected second display without Pro counts at once; a screen
 * recording (Android 15's screen recording callback) counts as a capture.
 */
class ScreenMirroring(app: Application?, private val track: (AnalyticsEvent) -> Unit = Analytics::track) {
    /** The app's window is being recorded or cast. */
    var isCaptured by mutableStateOf(false)
        private set
    /** `mirroring_detected` goes once per session (process). */
    private var hasTracked = false

    init {
        if (app != null && Build.VERSION.SDK_INT >= 35) watchRecording(app)
    }

    /** The banner appeared: `mirroring_detected`, the first time this session. */
    fun bannerShown(route: MirroringRoute, inChurchMode: Boolean) {
        if (hasTracked) return
        hasTracked = true
        track(AnalyticsEvent.MirroringDetected(route, inChurchMode))
    }

    private fun watchRecording(app: Application) {
        val callbacks = HashMap<Activity, Consumer<Int>>()
        app.registerActivityLifecycleCallbacks(object : Application.ActivityLifecycleCallbacks {
            override fun onActivityStarted(activity: Activity) {
                if (Build.VERSION.SDK_INT < 35) return
                val wm = activity.getSystemService(WindowManager::class.java) ?: return
                val consumer = Consumer<Int> { state -> isCaptured = state == WindowManager.SCREEN_RECORDING_STATE_VISIBLE }
                runCatching {
                    val initial = wm.addScreenRecordingCallback(activity.mainExecutor, consumer)
                    isCaptured = initial == WindowManager.SCREEN_RECORDING_STATE_VISIBLE
                    callbacks[activity] = consumer
                }
            }
            override fun onActivityStopped(activity: Activity) {
                if (Build.VERSION.SDK_INT < 35) return
                val consumer = callbacks.remove(activity) ?: return
                runCatching { activity.getSystemService(WindowManager::class.java)?.removeScreenRecordingCallback(consumer) }
            }
            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit
            override fun onActivityResumed(activity: Activity) = Unit
            override fun onActivityPaused(activity: Activity) = Unit
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
            override fun onActivityDestroyed(activity: Activity) = Unit
        })
    }

    companion object {
        /**
         * Why the banner shows, or null when it doesn't: Pro never sees it. A
         * second display (which, without Pro, Android mirrors) wins over a capture.
         */
        fun bannerRoute(isPro: Boolean, isCaptured: Boolean, hasExternalDisplay: Boolean): MirroringRoute? = when {
            isPro -> null
            hasExternalDisplay -> MirroringRoute.ExternalDisplay
            isCaptured -> MirroringRoute.Capture
            else -> null
        }
    }
}
