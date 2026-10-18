package com.mDev.AdventPraise

import android.content.Intent
import android.os.Bundle
import androidx.compose.runtime.snapshotFlow
import com.mDev.AdventPraise.analytics.TourSource
import com.mDev.AdventPraise.billing.Entitlements
import com.mDev.AdventPraise.billing.PreviewPurchasesClient
import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.billing.PurchaseConfig
import com.mDev.AdventPraise.data.SheetMusicViewMode
import com.mDev.AdventPraise.reader.LecternState
import com.mDev.AdventPraise.reader.ReaderMenuPanel
import com.mDev.AdventPraise.settings.ReadingSurface
import com.mDev.AdventPraise.ui.root.DebugOptions
import com.mDev.AdventPraise.ui.root.Destination
import com.mDev.AdventPraise.ui.tour.TourStep
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

/**
 * DEBUG builds only (iOS's App/DebugLaunch.swift): launch extras that open a
 * screen straight away, so emulator screenshots can be taken without tapping
 * through the app. The extras have the iOS argument names:
 *
 *     adb shell am start -S -n com.mDev.AdventPraise/.MainActivity \
 *       --es uiDebugSheet sheetMusic --es sheetMusic.viewMode system --ez uiDebugPro true --ei uiDebugHymn 1
 *
 * Booleans may be `--ez name true` or `--es name YES`; numbers `--ei` or `--es`.
 *
 *     uiDebugSurface sepia        reading surface (paper, parchment, sepia, muted, black), this launch only
 *     uiDebugSheet memory         about, memory, sheetMusic, support; More's pages: scripture, collections,
 *                                 pitch, planner, aboutApp, privacy, terms
 *     uiDebugCollection gospel    a collection's hymns (with uiDebugSheet collections)
 *     uiDebugPlan Vespers         a service plan by name (with uiDebugSheet planner)
 *     uiDebugTranslations YES     the reader menu, on Translation
 *     uiDebugMenu theme           the reader menu (translation, theme, text, about; "bar": no panel)
 *     uiDebugMore YES             More
 *     uiDebugPro YES              Pro, whatever RevenueCat says
 *     uiDebugFree YES             free, whatever RevenueCat says
 *     uiDebugFreePlaysUsed 4      free plays already used (stored)
 *     uiDebugPaywall YES          the paywall (YES/player, airplay, mirroring, sheetmusic, support), priced
 *                                 by the preview store: R199.99/year with a 3-day free trial
 *     uiDebugTour step-3          the tour at step 3 (1…8), set up for its screenshot
 *     uiDebugChurch YES           church mode
 *     uiDebugChurchControls YES   church mode's controls never auto-hide
 *     uiDebugExternal verse       the worship display on the phone (verse 2, "title", or "blank")
 *     uiDebugHymn 412             opens this hymn number
 *     uiDebugLectern hymn         a Lectern panel open (hymn, library)
 *     uiDebugDigits 100           the number pad open with these digits typed
 *     uiDebugPlay YES             the accompaniment playing
 *     uiDebugNoSplash YES         no launch splash
 *     uiDebugSplashSpeed 0.05     the splash reveal slowed down
 *     sheetMusic.viewMode system  the sheet music's Page | System choice (stored)
 *     tourSeen YES                the tour has been taken (stored)
 *     whatsNew.lastSeenVersion 7.0  skips What's New (stored)
 *     reader.hymnal tswana        opens this hymnal (key from hymnals.json)
 *
 * The release build has a no-op DebugLaunch (src/release), so it ignores them.
 */
object DebugLaunch {
    fun apply(intent: Intent?, services: AppServices) {
        val extras = intent?.extras ?: return
        if (extras.keySet().none { it.startsWith("uiDebug") || it in STORED }) return
        val a = Args(extras)

        // Before the first frame: what the root, the store and What's New read as they draw.
        if (a.bool("uiDebugNoSplash")) DebugOptions.skipsSplash = true
        a.float("uiDebugSplashSpeed")?.takeIf { it > 0 }?.let { DebugOptions.splashSpeed = it }
        if (a.bool("uiDebugChurchControls")) DebugOptions.keepsChurchControls = true
        DebugOptions.external = a.string("uiDebugExternal")
        if (a.bool("tourSeen")) services.appSettings.markTourSeen()
        a.string("whatsNew.lastSeenVersion")?.let(services.appSettings::markWhatsNewSeen)
        SheetMusicViewMode.of(a.string("sheetMusic.viewMode"))?.let(services.appSettings::updateSheetMusicViewMode)
        a.int("uiDebugFreePlaysUsed")?.let { used -> repeat(used.coerceIn(0, 5)) { services.freePlays.spend() } }
        val paywall = paywallFeature(a.string("uiDebugPaywall"))
        val pro = a.bool("uiDebugPro")
        val free = a.bool("uiDebugFree")
        if (pro || free || paywall != null) {
            services.store.useForDebug(
                PreviewPurchasesClient(),
                when {
                    pro -> Entitlements(setOf(PurchaseConfig.PRO_ENTITLEMENT), setOf(PurchaseConfig.PRO_PRODUCT_ID))
                    free -> Entitlements.none
                    else -> null
                },
            )
        }

        // Once the first hymnal has loaded, in RootView's order.
        val reader = services.reader
        val navigator = services.navigator
        services.scope.launch {
            snapshotFlow { reader.hymnal }.filterNotNull().first()
            ReadingSurface.entries.firstOrNull { it.key == a.string("uiDebugSurface") }?.let(services.settings::debugSurface)
            val hymnalKey = a.string("reader.hymnal")
            val number = a.int("uiDebugHymn")
            if (number != null) {
                reader.openLink(number, hymnalKey)
            } else if (hymnalKey != null && hymnalKey != reader.hymnal?.id) {
                services.catalogs.hymnal(hymnalKey)?.let { reader.switchHymnal(it, "debug") }
            }
            if (hymnalKey != null) snapshotFlow { reader.hymnal?.id }.first { it == hymnalKey || services.catalogs.hymnal(hymnalKey) == null }
            if (number != null) snapshotFlow { reader.hymn?.number }.first { it == number || reader.hymnal?.hymn(number) == null }

            when (val sheet = a.string("uiDebugSheet")) {
                null -> Unit
                "support" -> { navigator.openMore(); delay(600); navigator.openSupport() }
                "about" -> navigator.openAboutHymn()
                "memory" -> navigator.openMemorise()
                "sheetMusic" -> navigator.openSheetMusic()
                else -> morePage(sheet, a, services)?.let { pages -> pages.forEach(navigator::navigate) }
            }
            if (a.bool("uiDebugMore")) navigator.openMore()
            paywall?.let { navigator.openPaywall(it) }
            if (a.bool("uiDebugTranslations")) reader.openMenu(ReaderMenuPanel.Translation)
            a.string("uiDebugMenu")?.let { key -> reader.openMenu(ReaderMenuPanel.entries.firstOrNull { it.key == key }) }
            if (a.bool("uiDebugChurch")) navigator.openChurchMode("debug")
            when (a.string("uiDebugLectern")) {
                "hymn" -> reader.openLectern(LecternState.Hymn)
                "library" -> reader.openLectern(LecternState.Library)
            }
            a.string("uiDebugDigits")?.let { digits ->
                reader.openLectern(LecternState.Pad)
                reader.digits = digits
            }
            if (a.bool("uiDebugPlay")) {
                val hymn = reader.hymn
                val info = reader.hymnal?.info
                if (hymn != null && info != null) services.player.start(hymn, info)
            }
            if (DebugOptions.external == "verse") {
                services.church.start(com.mDev.AdventPraise.analytics.ChurchModeSource.Tray)
                services.church.show(1)
            }
            if (DebugOptions.external == "blank") services.church.toggleBlank()
            tourStep(a.string("uiDebugTour"))?.let { step -> debugTour(step, services) }
        }
    }

    /** `uiDebugTour step-N`: the tour at step N, with the reader set up as that step's screenshot wants it. */
    private suspend fun debugTour(step: TourStep, services: AppServices) {
        val reader = services.reader
        delay(800)
        services.tour.start(TourSource.Debug, at = step)
        delay(400)
        when (step) {
            TourStep.Memorise -> reader.openLectern(LecternState.Hymn)
            TourStep.Church -> {
                reader.openLectern(LecternState.Hymn); delay(500); reader.closeLectern()
                services.navigator.openChurchMode("tray")
            }
            TourStep.Pro -> {
                reader.openLectern(LecternState.Hymn); delay(500); reader.closeLectern()
                services.navigator.openMore()
            }
            else -> Unit
        }
    }

    private fun tourStep(raw: String?): TourStep? {
        val digits = raw?.filter(Char::isDigit)?.toIntOrNull() ?: return null
        return TourStep.entries.firstOrNull { it.number == digits }
    }

    private fun paywallFeature(raw: String?): ProFeature? = when (raw?.lowercase()) {
        "yes", "1", "true", "player" -> ProFeature.Player
        "airplay" -> ProFeature.AirPlay
        "mirroring" -> ProFeature.Mirroring
        "support" -> ProFeature.Support
        "sheetmusic" -> ProFeature.SheetMusic
        else -> null
    }

    /** More's path to a page (DebugLaunch.morePages): the page, then the collection or plan asked for. */
    private fun morePage(sheet: String, a: Args, services: AppServices): List<Destination>? = when (sheet) {
        "scripture" -> listOf(Destination.ScriptureIndex)
        "collections" -> listOf(Destination.Collections) + listOfNotNull(
            a.string("uiDebugCollection")?.let { id ->
                services.catalogs.collections.all.firstOrNull { it.id == id }?.let { Destination.Collection(it.id, it.title) }
            },
        )
        "pitch" -> listOf(Destination.PitchPipe())
        "planner" -> listOf(Destination.ServicePlanner) + listOfNotNull(
            a.string("uiDebugPlan")?.let { name ->
                services.planner.plans.firstOrNull { it.name == name }?.let { Destination.ServicePlan(it.id) }
            },
        )
        "aboutApp" -> listOf(Destination.AboutApp)
        "privacy" -> listOf(Destination.Privacy)
        "terms" -> listOf(Destination.Terms)
        else -> null
    }

    /** The plain stored keys iOS reads from UserDefaults. */
    private val STORED = setOf("tourSeen", "whatsNew.lastSeenVersion", "reader.hymnal", "sheetMusic.viewMode")

    /** Reads an extra however it was passed (`--es`, `--ez`, `--ei`, `--ef`). */
    private class Args(private val extras: Bundle) {
        @Suppress("DEPRECATION")
        private fun raw(key: String): Any? = extras.get(key)

        fun string(key: String): String? = raw(key)?.toString()
        fun bool(key: String): Boolean = when (val v = raw(key)) {
            is Boolean -> v
            is Number -> v.toInt() != 0
            is String -> v.lowercase() in setOf("yes", "true", "1")
            else -> false
        }
        fun int(key: String): Int? = when (val v = raw(key)) {
            is Number -> v.toInt()
            is String -> v.toIntOrNull()
            else -> null
        }
        fun float(key: String): Float? = when (val v = raw(key)) {
            is Number -> v.toFloat()
            is String -> v.toFloatOrNull()
            else -> null
        }
    }
}
