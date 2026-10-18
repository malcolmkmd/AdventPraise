package com.mDev.AdventPraise.analytics

import android.app.Application
import android.content.Context
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import com.mDev.AdventPraise.BuildConfig
import com.mDev.AdventPraise.billing.Entitlements
import com.mDev.AdventPraise.settings.ReadingSurface
import com.posthog.PersonProfiles
import com.posthog.PostHog
import com.posthog.android.PostHogAndroid
import com.posthog.android.PostHogAndroidConfig

/**
 * The one place the app sends product analytics: PostHog, EU, the same
 * project and the same event names as iOS (Services/Analytics.swift). Call
 * sites say what happened (`Analytics.track(AnalyticsEvent.HymnOpened(…))`).
 *
 * Privacy, as on iOS:
 * - Anonymous: never identified, no person profiles; the distinct ID is a
 *   random ID PostHog keeps on the device.
 * - "Share anonymous usage" in More ([isEnabled]). Off: PostHog is opted
 *   out and reset (the anonymous ID and super properties go); on again
 *   starts a new ID that can't be joined to the old one.
 * - No autocapture, screen-view or lifecycle capture, session replay,
 *   surveys, feature flags or GeoIP (`$geoip_disable` on every event).
 * - Debug builds log every event to Logcat and send nothing, unless built
 *   with -Panalytics.debugSend=true.
 *
 * Also here: app open / background (with time in the foreground), screen
 * views, super properties (hymnal, surface, large print, Pro) and non-fatal
 * errors, which are logged and counted as `error_occurred`.
 */
object Analytics {
    /** The Advent Praise project (EU), the iOS app's token. Client-side, safe to ship. */
    const val PROJECT_TOKEN = "phc_q4UXqrdUfkDuo4F7U6bDsTS9tL3WqeBuGUXK4Wwx8iki"
    const val HOST = "https://eu.i.posthog.com"
    /** Whether a new install shares usage until the person says otherwise. */
    const val DEFAULT_ENABLED = true
    /** The consent switch's key, as on iOS. */
    const val ENABLED_KEY = "analytics.enabled"
    private const val TAG = "Analytics"

    private var prefs: android.content.SharedPreferences? = null
    private var isSending = false
    private var hasStarted = false
    /** Super properties, kept so they can be registered again after an opt-in. */
    private val context = linkedMapOf<String, Any>()
    /** Tracked before [start] (the shared models are built first); sent by it. */
    private val early = mutableListOf<AnalyticsEvent>()
    private var foregroundSince: Long? = null

    /** Tests: every event that would be sent, in order. */
    internal var testSink: ((AnalyticsEvent) -> Unit)? = null

    private var enabledState by mutableStateOf(DEFAULT_ENABLED)

    /** The person's "Share anonymous usage" switch. Observable from Compose. */
    var isEnabled: Boolean
        get() = enabledState
        set(value) {
            if (enabledState == value) return
            enabledState = value
            prefs?.edit()?.putBoolean(ENABLED_KEY, value)?.apply()
            Log.i(TAG, "Usage sharing ${if (value) "on" else "off"}")
            applyConsent()
        }

    /** Once, at launch (Application.onCreate). Sends the cold `app_opened` when the app first shows. */
    fun start(app: Application) {
        if (hasStarted) return
        val p = app.getSharedPreferences("analytics", Context.MODE_PRIVATE)
        prefs = p
        enabledState = if (p.contains(ENABLED_KEY)) p.getBoolean(ENABLED_KEY, DEFAULT_ENABLED) else DEFAULT_ENABLED
        val sends = PROJECT_TOKEN.isNotEmpty() && (!BuildConfig.DEBUG || BuildConfig.ANALYTICS_DEBUG_SEND)
        if (sends) {
            val config = PostHogAndroidConfig(
                apiKey = PROJECT_TOKEN,
                host = HOST,
                captureApplicationLifecycleEvents = false,
                captureDeepLinks = false,
                captureScreenViews = false,
            ).apply {
                personProfiles = PersonProfiles.NEVER
                sessionReplay = false
                preloadFeatureFlags = false
                sendFeatureFlagEvent = false
                remoteConfig = false
                surveys = false
                optOut = !enabledState
            }
            PostHogAndroid.setup(app, config)
            isSending = true
            // PostHog keeps its own copy of the opt-out; ours is the truth.
            if (enabledState) PostHog.optIn() else PostHog.optOut()
            // 7.0.1 registered `owns_midi` on iOS; never on Android, but kept clean the same way.
            PostHog.unregister("owns_midi")
            context["\$geoip_disable"] = true
            if (enabledState) context.forEach { (k, v) -> PostHog.register(k, v) }
        }
        hasStarted = true
        ProcessLifecycleOwner.get().lifecycle.addObserver(object : DefaultLifecycleObserver {
            private var cold = true
            override fun onStart(owner: LifecycleOwner) {
                if (cold) {
                    cold = false
                    foregroundSince = System.currentTimeMillis()
                    track(AnalyticsEvent.AppOpened(LaunchKind.Cold))
                    val pending = early.toList()
                    early.clear()
                    pending.forEach(::track)
                    return
                }
                // Back from the background, once per app.
                if (foregroundSince != null) return
                foregroundSince = System.currentTimeMillis()
                track(AnalyticsEvent.AppOpened(LaunchKind.Warm))
            }

            override fun onStop(owner: LifecycleOwner) {
                foregroundSince?.let { since ->
                    track(AnalyticsEvent.AppBackgrounded(((System.currentTimeMillis() - since) / 1000).toInt()))
                }
                foregroundSince = null
                if (isSending && enabledState) PostHog.flush()
            }
        })
    }

    private fun applyConsent() {
        if (!isSending) return
        if (enabledState) {
            PostHog.optIn()
            context.forEach { (k, v) -> PostHog.register(k, v) }
            foregroundSince = System.currentTimeMillis()
        } else {
            PostHog.optOut()
            PostHog.reset()
        }
    }

    // Sending

    fun track(event: AnalyticsEvent) {
        if (!enabledState) return
        testSink?.invoke(event)
        if (!hasStarted) {
            if (testSink == null) early += event
            return
        }
        if (BuildConfig.DEBUG) Log.d(TAG, "${event.name} ${event.properties}")
        if (isSending) PostHog.capture(event = event.name, properties = event.properties)
    }

    fun screen(screen: AnalyticsScreen) = screen(screen.key)

    /** A screen by its iOS name; prefer [AnalyticsScreen]. */
    fun screen(name: String) {
        if (!enabledState) return
        if (BuildConfig.DEBUG) Log.d(TAG, "screen $name")
        if (isSending) PostHog.screen(screenTitle = name)
    }

    /** A non-fatal failure: logged in full on the device, counted by code in PostHog. */
    fun error(domain: ErrorDomain, code: String, cause: Throwable? = null) {
        if (cause != null) Log.e(TAG, "${domain.key} $code", cause) else Log.e(TAG, "${domain.key} $code")
        track(AnalyticsEvent.ErrorOccurred(domain, code))
    }

    /** The code is the error's class (never its message). */
    fun error(domain: ErrorDomain, cause: Throwable) = error(domain, cause.javaClass.simpleName, cause)

    @Deprecated("Use ErrorDomain", ReplaceWith("error(ErrorDomain, code)"))
    fun error(domain: String, code: String) {
        Log.w(TAG, "$domain $code")
        val typed = ErrorDomain.entries.firstOrNull { it.key == domain }
        @Suppress("DEPRECATION")
        track(if (typed != null) AnalyticsEvent.ErrorOccurred(typed, code) else AnalyticsEvent.ErrorOccurred(domain, code))
    }

    // Super properties

    /** The open hymnal, sent with every later event as `hymnal`. */
    fun setHymnal(id: String) = register(mapOf("hymnal" to id))

    /** The reading surface and large print, sent with every later event. */
    fun setAppearance(surface: ReadingSurface, largePrint: Boolean) = setAppearance(surface.key, largePrint)
    fun setAppearance(surface: String, largePrint: Boolean) = register(mapOf("surface" to surface, "large_print" to largePrint))

    /** Whether Pro is active (`is_pro`), sent with every later event. */
    fun setEntitlements(entitlements: Entitlements) = setPro(entitlements.isPro)
    fun setPro(isPro: Boolean) = register(mapOf("is_pro" to isPro))

    /** The super properties registered so far (tests). */
    internal val superProperties: Map<String, Any> get() = context.toMap()

    private fun register(properties: Map<String, Any>) {
        context.putAll(properties)
        if (!isSending || !enabledState) return
        properties.forEach { (k, v) -> PostHog.register(k, v) }
    }
}
