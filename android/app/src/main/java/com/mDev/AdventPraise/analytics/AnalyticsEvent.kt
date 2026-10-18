package com.mDev.AdventPraise.analytics

import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.extras.ExtraSheet
import com.mDev.AdventPraise.extras.MemoryLevel
import com.mDev.AdventPraise.extras.ScriptureConfidence
import com.mDev.AdventPraise.extras.SheetMusicAccess
import com.mDev.AdventPraise.settings.LineSpacing
import com.mDev.AdventPraise.settings.PlaybackTempo
import com.mDev.AdventPraise.settings.ReadingFont
import com.mDev.AdventPraise.settings.ReadingSurface

// Property values: the iOS enums' raw values (Services/AnalyticsEvent.swift), as `key`.

/** How a hymn came to be on screen. */
enum class HymnSource(val key: String) {
    Numpad("numpad"), Search("search"), Favourites("favourites"), Playlist("playlist"),
    /** The accompaniment finished and the playlist (or service plan) moved on. */
    PlaylistAdvance("playlist_advance"),
    /** Page swipe in the reader, or the accessibility next / previous actions. */
    Swipe("swipe"),
    /** Next / previous in church mode, past the last verse. */
    ChurchMode("church_mode"),
    Keyboard("keyboard"), Siri("siri"),
    LockScreen("lock_screen"),
    /** The wide layout's sidebar hymn list. */
    Sidebar("sidebar"),
    Collection("collection"),
    /** A hymn citing the same passage. */
    Scripture("scripture"),
    ServicePlan("service_plan"),
}

/** Where a hymnal was chosen. */
enum class HymnalSource(val key: String) { Lectern("lectern"), Sidebar("sidebar"), Translation("translation"), ChurchMode("church_mode") }

/** Which screen the Pro paywall covered. */
enum class PaywallContext(val key: String) { Reader("reader"), ChurchMode("church_mode"), SheetMusic("sheet_music") }

enum class RestoreSource(val key: String) { More("more"), Paywall("paywall") }

enum class ChurchModeSource(val key: String) {
    Tray("tray"), More("more"), WhatsNew("whats_new"), Siri("siri"), Keyboard("keyboard"), Voiceover("voiceover"),
    ServicePlan("service_plan"), Collection("collection"),
}

/** How a free user's screen reached another: an external display mirrored, or a capture. */
enum class MirroringRoute(val key: String) { ExternalDisplay("external_display"), Capture("capture") }

enum class SearchScope(val key: String) { Lyrics("lyrics"), Titles("titles") }
enum class SearchSurface(val key: String) { Lectern("lectern"), Sidebar("sidebar") }

enum class PlaylistEdit(val key: String) { HymnAdded("hymn_added"), HymnRemoved("hymn_removed"), Reordered("reordered"), Renamed("renamed") }

enum class ServicePlanEdit(val key: String) { HymnAdded("hymn_added"), HymnRemoved("hymn_removed"), Reordered("reordered"), RoleSet("role_set") }

enum class TextSizeContext(val key: String) { Reader("reader"), ChurchMode("church_mode") }

enum class TextSizeMethod(val key: String) {
    Pinch("pinch"),
    /** The Appearance size slider or its − / + buttons. */
    Slider("slider"),
    /** Church mode's A− / A+ buttons. */
    Buttons("buttons"),
    /** Double-tap back to the default size. */
    Reset("reset"),
}

/** One Appearance setting and its new value. */
sealed class AppearanceChange(val setting: String, val value: String) {
    class Surface(surface: ReadingSurface) : AppearanceChange("surface", surface.key)
    class Font(font: ReadingFont) : AppearanceChange("font", font.key)
    class Spacing(spacing: LineSpacing) : AppearanceChange("line_spacing", spacing.key)
    class Centered(on: Boolean) : AppearanceChange("alignment", if (on) "centered" else "leading")
    class LargePrint(on: Boolean) : AppearanceChange("large_print", if (on) "on" else "off")
}

enum class ToggleSetting(val key: String) { Haptics("haptics"), RepeatChorus("repeat_chorus") }

enum class PurchaseFailure(val key: String) {
    /** The product hadn't loaded from the store (offline, or not set up). */
    Unavailable("unavailable"),
    StoreError("store_error"),
    /** The store took the purchase but Pro isn't among the entitlements. */
    NotActivated("not_activated"),
    /** A pending payment (a family approval, a bank check): it may still go through. */
    Pending("pending"),
    /** The store couldn't verify the purchase. */
    Unverified("unverified"),
    /** Purchases are turned off on the device. */
    NotAllowed("not_allowed"),
}

enum class PaywallOutcome(val key: String) { Unlocked("unlocked"), Closed("closed") }

enum class WhatsNewAction(val key: String) { Primary("primary"), Continue("continue"), Dismissed("dismissed") }

enum class ExternalLink(val key: String) { RateApp("rate_app") }

enum class IntentKind(val key: String) { OpenHymn("open_hymn"), PlayHymn("play_hymn"), NextHymn("next_hymn"), ChurchMode("church_mode") }

enum class PitchPipeAction(val key: String) {
    /** The big button, sounding the hymnal's published note. */
    PublishedNote("published_note"),
    /** The big button, sounding the singer's own note. */
    CustomNote("custom_note"),
    /** A key on the chromatic keyboard (chooses and sounds it). */
    KeyChosen("key_chosen"),
}

enum class MemoryPart(val key: String) { Verse("verse"), Chorus("chorus") }

/** Which button on Memorise's completion card started the next round. */
enum class MemoryReplay(val key: String) { Again("again"), NextLevel("next_level"), NextBlock("next_block"), StartOver("start_over") }

/** Where a scripture chip was tapped. */
enum class ScriptureSurface(val key: String) { AboutHymn("about_hymn"), Passage("passage"), ReaderMenu("reader_menu") }

/** Where a Tools sheet was opened from. */
enum class ToolSource(val key: String) { More("more"), Tray("tray"), ReaderMenu("reader_menu") }

/** A non-fatal failure. The code is ours or a framework error code, never a message. */
enum class ErrorDomain(val key: String) { Audio("audio"), Purchase("purchase"), Restore("restore"), Products("products"), HymnalLoad("hymnal_load") }

enum class LaunchKind(val key: String) { Cold("cold"), Warm("warm") }

/** Where the onboarding tour was started. */
enum class TourSource(val key: String) { WhatsNew("whats_new"), More("more"), Debug("debug") }

/**
 * Every event the app sends, with the iOS names and properties. Values are
 * enums' raw strings, numbers and booleans: nothing typed by the person, no
 * hymn text, no price.
 */
sealed class AnalyticsEvent(val name: String, val properties: Map<String, Any>) {
    override fun toString() = "$name $properties"

    // App
    class AppOpened(launch: LaunchKind) : AnalyticsEvent("app_opened", mapOf("launch" to launch.key))
    class AppBackgrounded(foregroundSeconds: Int) : AnalyticsEvent("app_backgrounded", mapOf("foreground_seconds" to foregroundSeconds))

    // Reading
    class HymnOpened : AnalyticsEvent {
        constructor(hymnal: String, number: Int, source: HymnSource) : super("hymn_opened", hymnOpened(hymnal, number, source.key))
        @Deprecated("Use HymnSource", ReplaceWith("HymnOpened(hymnal, number, HymnSource)"))
        constructor(hymnal: String, number: Int, source: String) : super("hymn_opened", hymnOpened(hymnal, number, source))
    }

    class HymnalSwitched : AnalyticsEvent {
        constructor(from: String, to: String, source: HymnalSource) : super("hymnal_switched", switched(from, to, source.key))
        @Deprecated("Use HymnalSource", ReplaceWith("HymnalSwitched(from, to, HymnalSource)"))
        constructor(from: String, to: String, source: String) : super("hymnal_switched", switched(from, to, source))
    }

    class SearchPerformed : AnalyticsEvent {
        constructor(surface: SearchSurface, scope: SearchScope, queryLength: Int, resultCount: Int, isNumber: Boolean) :
            super("search_performed", searched(surface.key, scope.key, queryLength, resultCount, isNumber))
        @Deprecated("Use SearchSurface and SearchScope")
        constructor(surface: String, scope: String, queryLength: Int, resultCount: Int, isNumber: Boolean) :
            super("search_performed", searched(surface, scope, queryLength, resultCount, isNumber))
    }

    class SearchResultOpened : AnalyticsEvent {
        constructor(surface: SearchSurface, scope: SearchScope, rank: Int) :
            super("search_result_opened", mapOf("surface" to surface.key, "scope" to scope.key, "rank" to rank))
        @Deprecated("Use SearchSurface and SearchScope")
        constructor(surface: String, scope: String, rank: Int) :
            super("search_result_opened", mapOf("surface" to surface, "scope" to scope, "rank" to rank))
    }

    class FavouriteToggled(number: Int, isFavourite: Boolean) :
        AnalyticsEvent("favourite_toggled", mapOf("hymn_number" to number, "is_favourite" to isFavourite))
    /** The globe grew into the reader menu; `panel` is the key of the one open under it ("translation", "theme", "text", "about"). */
    class ReaderMenuOpened(panel: String?) : AnalyticsEvent("reader_menu_opened", mapOf("panel" to (panel ?: "none")))
    class ReaderMenuPanelOpened(panel: String) : AnalyticsEvent("reader_menu_panel_opened", mapOf("panel" to panel))
    class ToolOpened(tool: ExtraSheet, source: ToolSource) :
        AnalyticsEvent("tool_opened", mapOf("tool" to tool.key, "source" to source.key))

    // Playlists
    class PlaylistCreated(hymnCount: Int) : AnalyticsEvent("playlist_created", mapOf("hymn_count" to hymnCount))
    class PlaylistEdited(action: PlaylistEdit, hymnCount: Int) :
        AnalyticsEvent("playlist_edited", mapOf("action" to action.key, "hymn_count" to hymnCount))
    class PlaylistDeleted(hymnCount: Int) : AnalyticsEvent("playlist_deleted", mapOf("hymn_count" to hymnCount))
    class PlaylistPlayed(hymnCount: Int, startIndex: Int) :
        AnalyticsEvent("playlist_played", mapOf("hymn_count" to hymnCount, "start_index" to startIndex))

    // Service planner
    class ServicePlanCreated(hymnCount: Int) : AnalyticsEvent("service_plan_created", mapOf("hymn_count" to hymnCount))
    class ServicePlanEdited(action: ServicePlanEdit, hymnCount: Int) :
        AnalyticsEvent("service_plan_edited", mapOf("action" to action.key, "hymn_count" to hymnCount))
    class ServicePlanDeleted(hymnCount: Int) : AnalyticsEvent("service_plan_deleted", mapOf("hymn_count" to hymnCount))
    class ServicePlanStarted(hymnCount: Int) : AnalyticsEvent("service_plan_started", mapOf("hymn_count" to hymnCount))
    class CollectionStarted(hymnCount: Int) : AnalyticsEvent("collection_started", mapOf("hymn_count" to hymnCount))

    // Church mode
    class ChurchModeEntered(source: ChurchModeSource) : AnalyticsEvent("church_mode_entered", mapOf("source" to source.key))
    class ChurchModeExited(seconds: Int, versesShown: Int, hymnsShown: Int) :
        AnalyticsEvent("church_mode_exited", mapOf("duration_seconds" to seconds, "verses_shown" to versesShown, "hymns_shown" to hymnsShown))
    class ChurchModeCastChanged(isConnected: Boolean, showsHymn: Boolean) :
        AnalyticsEvent("church_mode_cast_changed", mapOf("is_connected" to isConnected, "shows_hymn" to showsHymn))
    /** A free user's screen is being mirrored or captured, so the Go Pro banner shows. Once per session. */
    class MirroringDetected(via: MirroringRoute, inChurchMode: Boolean) :
        AnalyticsEvent("mirroring_detected", mapOf("via" to via.key, "in_church_mode" to inChurchMode))

    // Appearance
    class AppearanceChanged : AnalyticsEvent {
        constructor(change: AppearanceChange) : super("appearance_changed", mapOf("setting" to change.setting, "value" to change.value))
        @Deprecated("Use AppearanceChange", ReplaceWith("AppearanceChanged(AppearanceChange)"))
        constructor(setting: String, value: String) : super("appearance_changed", mapOf("setting" to setting, "value" to value))
    }

    class TextSizeChanged : AnalyticsEvent {
        constructor(context: TextSizeContext, method: TextSizeMethod, pointSize: Int) :
            super("text_size_changed", mapOf("context" to context.key, "method" to method.key, "point_size" to pointSize))
        @Deprecated("Use TextSizeContext and TextSizeMethod")
        constructor(context: String, method: String, pointSize: Int) :
            super("text_size_changed", mapOf("context" to context, "method" to method, "point_size" to pointSize))
    }

    class SettingChanged : AnalyticsEvent {
        constructor(setting: ToggleSetting, isOn: Boolean) : super("setting_changed", mapOf("setting" to setting.key, "is_on" to isOn))
        @Deprecated("Use ToggleSetting", ReplaceWith("SettingChanged(ToggleSetting, isOn)"))
        constructor(setting: String, isOn: Boolean) : super("setting_changed", mapOf("setting" to setting, "is_on" to isOn))
    }

    // Accompaniment
    class AccompanimentPlayed(number: Int, tempo: PlaybackTempo = PlaybackTempo.Medium, resumed: Boolean) :
        AnalyticsEvent("accompaniment_played", mapOf("hymn_number" to number, "tempo" to tempo.key, "resumed" to resumed))
    class AccompanimentPaused(number: Int, progressPercent: Int) :
        AnalyticsEvent("accompaniment_paused", mapOf("hymn_number" to number, "progress_percent" to progressPercent))
    class AccompanimentCompleted(number: Int, tempo: PlaybackTempo = PlaybackTempo.Medium, verses: Int) :
        AnalyticsEvent("accompaniment_completed", mapOf("hymn_number" to number, "tempo" to tempo.key, "verses" to verses)) {
        @Deprecated("Pass the tempo", ReplaceWith("AccompanimentCompleted(number, PlaybackTempo.Medium, verses)"))
        constructor(number: Int, verses: Int) : this(number, PlaybackTempo.Medium, verses)
    }
    class AccompanimentTempoChanged(tempo: PlaybackTempo) : AnalyticsEvent("accompaniment_tempo_changed", mapOf("tempo" to tempo.key))
    /** A free user started a new play; `remaining` is what's left after it. */
    class FreePlayUsed(number: Int, remaining: Int) :
        AnalyticsEvent("free_play_used", mapOf("hymn_number" to number, "remaining" to remaining))
    /** A new play was refused because the free plays are used up; the paywall opens. */
    class PlayLimitPaywallShown(number: Int) : AnalyticsEvent("play_limit_paywall_shown", mapOf("hymn_number" to number))

    // Sheet music
    class SheetMusicOpened(number: Int, access: SheetMusicAccess) :
        AnalyticsEvent("sheet_music_opened", mapOf("hymn_number" to number, "access" to access.key))
    class SheetMusicPaywallOpened(number: Int) : AnalyticsEvent("sheet_music_paywall_opened", mapOf("hymn_number" to number))

    // Pro paywall and purchases
    class PaywallViewed : AnalyticsEvent {
        constructor(feature: ProFeature, context: PaywallContext) :
            super("paywall_viewed", mapOf("feature" to feature.analyticsName, "context" to context.key))
        @Deprecated("Use ProFeature and PaywallContext")
        constructor(feature: String, context: String) : super("paywall_viewed", mapOf("feature" to feature, "context" to context))
    }

    class PaywallDismissed : AnalyticsEvent {
        constructor(feature: ProFeature, context: PaywallContext, outcome: PaywallOutcome) :
            super("paywall_dismissed", mapOf("feature" to feature.analyticsName, "context" to context.key, "outcome" to outcome.key))
        @Deprecated("Use ProFeature, PaywallContext and PaywallOutcome")
        constructor(feature: String, context: String, outcome: String) :
            super("paywall_dismissed", mapOf("feature" to feature, "context" to context, "outcome" to outcome))
    }

    class PurchaseStarted(product: String, feature: ProFeature) :
        AnalyticsEvent("purchase_started", mapOf("product" to product, "feature" to feature.analyticsName))
    class PurchaseCompleted(product: String, feature: ProFeature) :
        AnalyticsEvent("purchase_completed", mapOf("product" to product, "feature" to feature.analyticsName))
    class PurchaseCancelled(product: String, feature: ProFeature) :
        AnalyticsEvent("purchase_cancelled", mapOf("product" to product, "feature" to feature.analyticsName))
    class PurchaseFailed(product: String, feature: ProFeature, reason: PurchaseFailure) :
        AnalyticsEvent("purchase_failed", mapOf("product" to product, "feature" to feature.analyticsName, "reason" to reason.key))
    class RestoreStarted(source: RestoreSource) : AnalyticsEvent("restore_started", mapOf("source" to source.key))
    class RestoreCompleted(foundPurchases: Boolean, proActive: Boolean) :
        AnalyticsEvent("restore_completed", mapOf("found_purchases" to foundPurchases, "pro_active" to proActive))
    object RestoreFailed : AnalyticsEvent("restore_failed", emptyMap())

    // Tips: the product ID, never the amount
    class TipStarted(product: String) : AnalyticsEvent("tip_started", mapOf("product" to product))
    class TipCompleted(product: String) : AnalyticsEvent("tip_completed", mapOf("product" to product))
    class TipCancelled(product: String) : AnalyticsEvent("tip_cancelled", mapOf("product" to product))
    class TipFailed(product: String, reason: PurchaseFailure) :
        AnalyticsEvent("tip_failed", mapOf("product" to product, "reason" to reason.key))

    // Tools
    class MemoryGameStarted(part: MemoryPart, level: MemoryLevel, wordCount: Int) :
        AnalyticsEvent("memory_game_started", mapOf("part" to part.key, "level" to level.analyticsName, "word_count" to wordCount))
    class MemoryGameCompleted(part: MemoryPart, level: MemoryLevel, score: Int, bestStreak: Int, firstTryPercent: Int, hintsUsed: Int, stars: Int) :
        AnalyticsEvent("memory_game_completed", mapOf("part" to part.key, "level" to level.analyticsName, "score" to score,
            "best_streak" to bestStreak, "first_try_percent" to firstTryPercent, "hints_used" to hintsUsed, "stars" to stars))
    /** A hint spent (a letter shown, chips that can't fit ruled out). */
    class MemoryHintUsed(part: MemoryPart, level: MemoryLevel, hintsLeft: Int) :
        AnalyticsEvent("memory_hint_used", mapOf("part" to part.key, "level" to level.analyticsName, "hints_left" to hintsLeft))
    /** A streak reached a hint-earning length (3, 6, 9…). */
    class MemoryStreakReached(part: MemoryPart, level: MemoryLevel, streak: Int) :
        AnalyticsEvent("memory_streak_reached", mapOf("part" to part.key, "level" to level.analyticsName, "streak" to streak))
    /** A stanza finished with every word hidden. */
    class MemoryVerseLearned(part: MemoryPart, stars: Int) :
        AnalyticsEvent("memory_verse_learned", mapOf("part" to part.key, "stars" to stars))
    /** A new round chosen from the completion card. */
    class MemoryRoundReplayed(part: MemoryPart, level: MemoryLevel, reason: MemoryReplay) :
        AnalyticsEvent("memory_round_replayed", mapOf("part" to part.key, "level" to level.analyticsName, "reason" to reason.key))
    class PitchPipeUsed(action: PitchPipeAction) : AnalyticsEvent("pitch_pipe_used", mapOf("action" to action.key))
    /** A passage opened on bible.com / in YouVersion. `number` and `confidence` are null from a passage page. */
    class ScriptureOpened(hymnal: String, number: Int?, book: String, confidence: ScriptureConfidence?, surface: ScriptureSurface) :
        AnalyticsEvent("scripture_opened", buildMap<String, Any> {
            put("hymnal", hymnal); put("book", book); put("surface", surface.key)
            number?.let { put("hymn_number", it) }
            confidence?.let { put("confidence", it.key) }
        })

    // Feedback, sharing, system
    class FeatureBoardOpened(disclosed: Boolean) : AnalyticsEvent("feature_board_opened", mapOf("disclosed" to disclosed))
    object FeatureBoardDisclosureAccepted : AnalyticsEvent("feature_board_disclosure_accepted", emptyMap())
    class FeatureBoardClosed(seconds: Int, showedBoard: Boolean) :
        AnalyticsEvent("feature_board_closed", mapOf("duration_seconds" to seconds, "showed_board" to showedBoard))
    class WhatsNewViewed(version: String) : AnalyticsEvent("whats_new_viewed", mapOf("version" to version))
    class WhatsNewDismissed(version: String, action: WhatsNewAction) :
        AnalyticsEvent("whats_new_dismissed", mapOf("version" to version, "action" to action.key))
    class TourStarted(source: TourSource) : AnalyticsEvent("tour_started", mapOf("source" to source.key))
    /** A step's control was used (or Next taken) and the next step opened. */
    class TourStepCompleted(step: Int) : AnalyticsEvent("tour_step_completed", mapOf("step" to step))
    /** `completed`: Done on the last card; false for Skip tour. `lastStep`: the step reached. */
    class TourFinished(completed: Boolean, lastStep: Int) :
        AnalyticsEvent("tour_finished", mapOf("completed" to completed, "last_step" to lastStep))
    object ShareOpened : AnalyticsEvent("share_opened", emptyMap())
    /** `activity`: the chosen target's package (iOS sends its activity type); null is "none". */
    class ShareFinished(completed: Boolean, activity: String?) :
        AnalyticsEvent("share_finished", mapOf("completed" to completed, "activity" to (activity ?: "none")))
    class ExternalLinkOpened(link: ExternalLink) : AnalyticsEvent("external_link_opened", mapOf("link" to link.key))
    class IntentRun(intent: IntentKind, succeeded: Boolean) :
        AnalyticsEvent("intent_run", mapOf("intent" to intent.key, "succeeded" to succeeded))
    class ErrorOccurred : AnalyticsEvent {
        constructor(domain: ErrorDomain, code: String) : super("error_occurred", mapOf("domain" to domain.key, "code" to code))
        @Deprecated("Use ErrorDomain")
        constructor(domain: String, code: String) : super("error_occurred", mapOf("domain" to domain, "code" to code))
    }

    private companion object {
        fun hymnOpened(hymnal: String, number: Int, source: String) =
            mapOf("hymnal" to hymnal, "hymn_number" to number, "source" to source)
        fun switched(from: String, to: String, source: String) =
            mapOf("from_hymnal" to from, "to_hymnal" to to, "source" to source)
        fun searched(surface: String, scope: String, length: Int, results: Int, isNumber: Boolean) =
            mapOf("surface" to surface, "scope" to scope, "query_length" to length, "result_count" to results, "is_number" to isNumber)
    }
}

/**
 * Screens, sent as PostHog `$screen` events (AnalyticsScreen on iOS).
 * PostHog stamps the latest on every later event as `$screen_name`.
 */
enum class AnalyticsScreen(val key: String) {
    Reader("reader"), ChurchMode("church_mode"), More("more"), Appearance("appearance"), Hymnals("hymnals"),
    Translations("translations"), Paywall("paywall"), SheetMusic("sheet_music"), Support("support"), Search("search"),
    Library("library"), NumberPad("number_pad"), WhatsNew("whats_new"), PlaylistEditor("playlist_editor"),
    PlaylistHymnPicker("playlist_hymn_picker"), AboutHymn("about_hymn"), AboutHymnPanel("about_hymn_panel"),
    ScriptureIndex("scripture_index"), Collections("collections"), PitchPipe("pitch_pipe"), MemoryGame("memory_game"),
    ServicePlanner("service_planner"), ServicePlan("service_plan"), AboutApp("about_app"), Privacy("privacy"),
    Terms("terms"), Share("share"), FeatureBoard("feature_board"),
}
