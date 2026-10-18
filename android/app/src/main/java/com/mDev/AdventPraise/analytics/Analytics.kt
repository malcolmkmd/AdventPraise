package com.mDev.AdventPraise.analytics

import android.app.Application
import android.content.Context
import android.util.Log
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import com.mDev.AdventPraise.BuildConfig
import com.posthog.PersonProfiles
import com.posthog.PostHog
import com.posthog.android.PostHogAndroid
import com.posthog.android.PostHogAndroidConfig

/**
 * The one place the app sends product analytics: PostHog, EU, the same
 * project and the same event names as iOS (Services/Analytics.swift).
 *
 * Anonymous: never identified, no person profiles, no autocapture, no
 * screen-view or lifecycle autocapture, no session replay, no surveys and
 * no feature flags. "Share anonymous usage" in More turns it off: PostHog is
 * opted out and reset. Debug builds log events and send nothing unless
 * built with -Panalytics.debugSend=true.
 */
object Analytics {
    /** The Advent Praise project (EU), the iOS app's token. Client-side, safe to ship. */
    const val PROJECT_TOKEN = "phc_q4UXqrdUfkDuo4F7U6bDsTS9tL3WqeBuGUXK4Wwx8iki"
    const val HOST = "https://eu.i.posthog.com"
    private const val TAG = "Analytics"

    private var prefs: android.content.SharedPreferences? = null
    private var isSending = false
    private var hasStarted = false
    private val context = mutableMapOf<String, Any>()
    private val early = mutableListOf<AnalyticsEvent>()
    private var foregroundSince: Long? = null

    var isEnabled: Boolean = true
        set(value) {
            if (field == value) return
            field = value
            prefs?.edit()?.putBoolean("analytics.enabled", value)?.apply()
            applyConsent()
        }

    fun start(app: Application) {
        if (hasStarted) return
        hasStarted = true
        val p = app.getSharedPreferences("analytics", Context.MODE_PRIVATE)
        prefs = p
        isEnabled = p.getBoolean("analytics.enabled", true)
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
                optOut = !Analytics.isEnabled
            }
            PostHogAndroid.setup(app, config)
            isSending = true
            if (isEnabled) PostHog.optIn() else PostHog.optOut()
            if (isEnabled) context.forEach { (k, v) -> PostHog.register(k, v) }
        }
        ProcessLifecycleOwner.get().lifecycle.addObserver(object : DefaultLifecycleObserver {
            private var cold = true
            override fun onStart(owner: LifecycleOwner) {
                foregroundSince = System.currentTimeMillis()
                track(AnalyticsEvent.AppOpened(if (cold) "cold" else "warm"))
                if (cold) {
                    cold = false
                    early.forEach(::track)
                    early.clear()
                }
            }

            override fun onStop(owner: LifecycleOwner) {
                foregroundSince?.let { since ->
                    val seconds = ((System.currentTimeMillis() - since) / 1000).toInt()
                    track(AnalyticsEvent.AppBackgrounded(seconds))
                }
                foregroundSince = null
                if (isSending && isEnabled) PostHog.flush()
            }
        })
    }

    private fun applyConsent() {
        if (!isSending) return
        if (isEnabled) {
            PostHog.optIn()
            context.forEach { (k, v) -> PostHog.register(k, v) }
        } else {
            PostHog.optOut()
            PostHog.reset()
        }
    }

    fun track(event: AnalyticsEvent) {
        if (!isEnabled) return
        if (!hasStarted) { early += event; return }
        if (BuildConfig.DEBUG) Log.d(TAG, "${event.name} ${event.properties}")
        if (isSending) PostHog.capture(event = event.name, properties = event.properties)
    }

    fun screen(name: String) {
        if (!isEnabled) return
        if (BuildConfig.DEBUG) Log.d(TAG, "screen $name")
        if (isSending) PostHog.screen(screenTitle = name)
    }

    /** A non-fatal failure, counted by code (never a message). */
    fun error(domain: String, code: String) {
        Log.w(TAG, "$domain $code")
        track(AnalyticsEvent.ErrorOccurred(domain, code))
    }

    fun setHymnal(id: String) = register(mapOf("hymnal" to id))
    fun setAppearance(surface: String, largePrint: Boolean) = register(mapOf("surface" to surface, "large_print" to largePrint))
    fun setPro(isPro: Boolean) = register(mapOf("is_pro" to isPro))

    private fun register(properties: Map<String, Any>) {
        context.putAll(properties)
        if (!isSending || !isEnabled) return
        properties.forEach { (k, v) -> PostHog.register(k, v) }
    }
}

/**
 * Every event the Android app sends, with the iOS names and properties
 * (Services/AnalyticsEvent.swift). Values are enums' raw strings, numbers
 * and booleans: nothing typed by the person, no hymn text, no price.
 */
sealed class AnalyticsEvent(val name: String, val properties: Map<String, Any>) {
    class AppOpened(launch: String) : AnalyticsEvent("app_opened", mapOf("launch" to launch))
    class AppBackgrounded(seconds: Int) : AnalyticsEvent("app_backgrounded", mapOf("foreground_seconds" to seconds))

    class HymnOpened(hymnal: String, number: Int, source: String) :
        AnalyticsEvent("hymn_opened", mapOf("hymnal" to hymnal, "hymn_number" to number, "source" to source))
    class HymnalSwitched(from: String, to: String, source: String) :
        AnalyticsEvent("hymnal_switched", mapOf("from_hymnal" to from, "to_hymnal" to to, "source" to source))
    class SearchPerformed(surface: String, scope: String, queryLength: Int, resultCount: Int, isNumber: Boolean) :
        AnalyticsEvent("search_performed", mapOf("surface" to surface, "scope" to scope, "query_length" to queryLength,
            "result_count" to resultCount, "is_number" to isNumber))
    class SearchResultOpened(surface: String, scope: String, rank: Int) :
        AnalyticsEvent("search_result_opened", mapOf("surface" to surface, "scope" to scope, "rank" to rank))
    class FavouriteToggled(number: Int, isFavourite: Boolean) :
        AnalyticsEvent("favourite_toggled", mapOf("hymn_number" to number, "is_favourite" to isFavourite))
    class ReaderMenuOpened(panel: String?) : AnalyticsEvent("reader_menu_opened", mapOf("panel" to (panel ?: "none")))
    class ReaderMenuPanelOpened(panel: String) : AnalyticsEvent("reader_menu_panel_opened", mapOf("panel" to panel))

    class AppearanceChanged(setting: String, value: String) :
        AnalyticsEvent("appearance_changed", mapOf("setting" to setting, "value" to value))
    class TextSizeChanged(context: String, method: String, pointSize: Int) :
        AnalyticsEvent("text_size_changed", mapOf("context" to context, "method" to method, "point_size" to pointSize))
    class SettingChanged(setting: String, isOn: Boolean) :
        AnalyticsEvent("setting_changed", mapOf("setting" to setting, "is_on" to isOn))

    class AccompanimentPlayed(number: Int, resumed: Boolean) :
        AnalyticsEvent("accompaniment_played", mapOf("hymn_number" to number, "tempo" to "normal", "resumed" to resumed))
    class AccompanimentPaused(number: Int, progressPercent: Int) :
        AnalyticsEvent("accompaniment_paused", mapOf("hymn_number" to number, "progress_percent" to progressPercent))
    class AccompanimentCompleted(number: Int, verses: Int) :
        AnalyticsEvent("accompaniment_completed", mapOf("hymn_number" to number, "tempo" to "normal", "verses" to verses))
    class FreePlayUsed(number: Int, remaining: Int) :
        AnalyticsEvent("free_play_used", mapOf("hymn_number" to number, "remaining" to remaining))
    class PlayLimitPaywallShown(number: Int) : AnalyticsEvent("play_limit_paywall_shown", mapOf("hymn_number" to number))

    class PaywallViewed(feature: String, context: String) :
        AnalyticsEvent("paywall_viewed", mapOf("feature" to feature, "context" to context))
    class PaywallDismissed(feature: String, context: String, outcome: String) :
        AnalyticsEvent("paywall_dismissed", mapOf("feature" to feature, "context" to context, "outcome" to outcome))
    class PurchaseStarted(product: String, feature: String) :
        AnalyticsEvent("purchase_started", mapOf("product" to product, "feature" to feature))
    class PurchaseCompleted(product: String, feature: String) :
        AnalyticsEvent("purchase_completed", mapOf("product" to product, "feature" to feature))
    class PurchaseCancelled(product: String, feature: String) :
        AnalyticsEvent("purchase_cancelled", mapOf("product" to product, "feature" to feature))
    class PurchaseFailed(product: String, feature: String, reason: String) :
        AnalyticsEvent("purchase_failed", mapOf("product" to product, "feature" to feature, "reason" to reason))
    class RestoreStarted(source: String) : AnalyticsEvent("restore_started", mapOf("source" to source))
    class RestoreCompleted(foundPurchases: Boolean, proActive: Boolean) :
        AnalyticsEvent("restore_completed", mapOf("found_purchases" to foundPurchases, "pro_active" to proActive))
    object RestoreFailed : AnalyticsEvent("restore_failed", emptyMap())

    class ErrorOccurred(domain: String, code: String) :
        AnalyticsEvent("error_occurred", mapOf("domain" to domain, "code" to code))
}
