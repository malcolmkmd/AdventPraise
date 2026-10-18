package com.mDev.AdventPraise.reader

import android.content.Context
import android.content.res.AssetManager
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.data.CrossReference
import com.mDev.AdventPraise.data.Hymn
import com.mDev.AdventPraise.data.Hymnal
import com.mDev.AdventPraise.data.HymnalInfo
import com.mDev.AdventPraise.data.MidiCatalog
import com.mDev.AdventPraise.data.Numbering
import com.mDev.AdventPraise.data.SdahTunes
import com.mDev.AdventPraise.data.SearchHit
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** What the Lectern shows above its row (LecternState on iOS). */
enum class LecternState { Collapsed, Hymn, Pad, Search, Library }

/** The reader menu's panels (ReaderMenuPanel on iOS; About comes later). */
enum class ReaderMenuPanel(val key: String, val label: String) {
    Translation("translation", "Translation"),
    Theme("theme", "Theme"),
    Text("text", "Text"),
}

/** The screens beside the reader. */
enum class Screen { Reader, Hymns, More }

/** The Terms of Use and the Privacy Policy, shown over whatever is open (the paywall too). */
enum class LegalDocument { Terms, Privacy }

/**
 * The reader's state, as iOS's ReaderModel: the open hymnal and hymn,
 * favourites (per hymnal, "english#12"), recents, the Lectern and the
 * reader menu. Hymnals are the iOS app's files, decoded off the main thread.
 */
class ReaderModel(context: Context, private val scope: CoroutineScope) {
    private val assets: AssetManager = context.assets
    private val prefs = context.getSharedPreferences("reader", Context.MODE_PRIVATE)
    private val midi by lazy { MidiCatalog(assets) }
    private val tunes by lazy { SdahTunes(assets) }
    /** Christ In Song ↔ SDA Hymnal, built from the English hymns once they load. */
    private var crossReference by mutableStateOf<CrossReference?>(null)

    val catalogue: List<HymnalInfo> = HymnalInfo.catalogue(assets)

    var hymnal by mutableStateOf<Hymnal?>(null)
        private set
    var hymn by mutableStateOf<Hymn?>(null)
        private set
    var favourites by mutableStateOf(prefs.getStringSet(KEY_FAVOURITES, emptySet())!!.toSet())
        private set
    /** The last three hymns opened, kept per numbering. */
    var recents by mutableStateOf<List<Int>>(emptyList())
        private set

    var screen by mutableStateOf(Screen.Reader)
    var isFocused by mutableStateOf(false)
    var lectern by mutableStateOf(LecternState.Collapsed)
        private set
    var isMenuOpen by mutableStateOf(false)
        private set
    var menuPanel by mutableStateOf<ReaderMenuPanel?>(null)
        private set
    var digits by mutableStateOf("")
        private set
    var query by mutableStateOf("")
    var searchLyrics by mutableStateOf(true)
    /** The paywall, leading with this feature; null when closed. */
    var paywall by mutableStateOf<ProFeature?>(null)
    var paywallContext by mutableStateOf("reader")
    /** The Terms or the Privacy Policy, over everything; null when closed. */
    var document by mutableStateOf<LegalDocument?>(null)

    /** The hymnal being loaded by a switch, so a second tap waits. */
    private var switching: String? = null

    fun start() {
        val info = catalogue.firstOrNull { it.id == prefs.getString(KEY_HYMNAL, null) }
            ?: catalogue.firstOrNull { it.id == HymnalInfo.fallback.id } ?: catalogue.first()
        scope.launch {
            val loaded = withContext(Dispatchers.Default) { Hymnal.load(assets, info, midi, tunes) }
                ?: withContext(Dispatchers.Default) { Hymnal.load(assets, HymnalInfo.fallback, midi, tunes) }
                ?: return@launch
            hymnal = loaded
            recents = loadRecents(loaded.info.numbering)
            hymn = loaded.hymn(lastHymn(loaded.info.numbering)) ?: loaded.hymns.firstOrNull()
            Analytics.setHymnal(loaded.id)
            val english = if (loaded.id == HymnalInfo.fallback.id) loaded
            else withContext(Dispatchers.Default) { Hymnal.load(assets, HymnalInfo.fallback, midi) }
            crossReference = english?.let { withContext(Dispatchers.Default) { CrossReference(it) } }
        }
    }

    /** Where the open hymn is in `info`: its number there, or null if it isn't there. */
    fun numberIn(info: HymnalInfo): Int? {
        val from = hymnal?.info ?: return null
        val number = hymn?.number ?: return null
        if (from.numbering == info.numbering) return number.takeIf { it <= info.maxNumber }
        return crossReference?.number(number, from, info)
    }

    // MARK: Derived

    val isFavourite: Boolean get() = hymn?.let { favouriteKey(it.number) in favourites } ?: false

    val favouriteHymns: List<Hymn>
        get() {
            val h = hymnal ?: return emptyList()
            return favourites.mapNotNull { key ->
                val parts = key.split('#')
                if (parts.size == 2 && parts[0] == h.id) parts[1].toIntOrNull() else null
            }.sorted().mapNotNull(h::hymn)
        }

    val previewHymn: Hymn? get() = digits.toIntOrNull()?.let { hymnal?.hymn(it) }

    fun searchHits(text: String = query): List<SearchHit> {
        val h = hymnal ?: return emptyList()
        val trimmed = text.trim()
        return if (trimmed.length >= 2 || trimmed.toIntOrNull() != null) h.search(trimmed, searchLyrics) else emptyList()
    }

    val nextHymn: Hymn? get() = hymn?.let { hymnal?.hymnAfter(it.number, 1) }
    val previousHymn: Hymn? get() = hymn?.let { hymnal?.hymnAfter(it.number, -1) }

    // MARK: Lectern and menu

    fun toggleFocus() {
        when {
            isMenuOpen -> closeMenu()
            lectern != LecternState.Collapsed -> closeLectern()
            else -> isFocused = !isFocused
        }
    }

    fun openLectern(state: LecternState) {
        isFocused = false
        if (state == LecternState.Pad) digits = ""
        isMenuOpen = false
        menuPanel = null
        lectern = state
        Analytics.screen(
            when (state) {
                LecternState.Pad -> "number_pad"
                LecternState.Search -> "search"
                LecternState.Library -> "library"
                else -> "reader"
            },
        )
    }

    fun closeLectern() {
        lectern = LecternState.Collapsed
    }

    fun openMenu(panel: ReaderMenuPanel? = ReaderMenuPanel.Translation) {
        if (isMenuOpen) return
        isFocused = false
        lectern = LecternState.Collapsed
        isMenuOpen = true
        menuPanel = panel
        Analytics.track(AnalyticsEvent.ReaderMenuOpened(panel?.key))
    }

    fun toggleMenuPanel(panel: ReaderMenuPanel) {
        if (!isMenuOpen) return openMenu(panel)
        val next = if (menuPanel == panel) null else panel
        menuPanel = next
        if (next != null) Analytics.track(AnalyticsEvent.ReaderMenuPanelOpened(next.key))
    }

    fun closeMenu() {
        isMenuOpen = false
        menuPanel = null
    }

    // MARK: Number pad

    fun push(digit: Char): Boolean {
        if (digits.length >= 4) return false
        val next = if (digits == "0") digit.toString() else digits + digit
        val value = next.toIntOrNull() ?: return false
        // Like the legacy pad: never accept a number past the end of the hymnal.
        if (value > maxOf(hymnal?.info?.maxNumber ?: 1, 1)) return false
        digits = next
        return true
    }

    fun backspace() { digits = digits.dropLast(1) }

    fun openPreview(): Boolean {
        val target = previewHymn ?: return false
        show(target, "numpad")
        return true
    }

    // MARK: Opening hymns

    /** `source` is sent with hymn_opened; null sends nothing (a translation switch). */
    fun show(target: Hymn, source: String?) {
        val h = hymnal ?: return
        hymn = target
        lectern = LecternState.Collapsed
        val numbering = h.info.numbering
        recents = (listOf(target.number) + recents.filter { it != target.number }).take(3)
        prefs.edit()
            .putInt(lastHymnKey(numbering), target.number)
            .putString(recentsKey(numbering), recents.joinToString(","))
            .apply()
        if (source != null) Analytics.track(AnalyticsEvent.HymnOpened(h.id, target.number, source))
    }

    fun open(number: Int, source: String): Boolean {
        val target = hymnal?.hymn(number) ?: return false
        show(target, source)
        return true
    }

    fun goToNext(source: String = "swipe"): Hymn? = nextHymn?.also { show(it, source) }
    fun goToPrevious(source: String = "swipe"): Hymn? = previousHymn?.also { show(it, source) }

    /**
     * Switches hymnal, keeping the same hymn: the same number within a
     * numbering, the cross-referenced number between Christ In Song and the
     * SDA Hymnal, else the last hymn read in that numbering.
     */
    fun switchHymnal(info: HymnalInfo, source: String = "translation") {
        val current = hymnal ?: return
        if (info.id == current.id || switching != null) return
        switching = info.id
        val number = numberIn(info)
        scope.launch {
            val loaded = withContext(Dispatchers.Default) { Hymnal.load(assets, info, midi, tunes) }
            switching = null
            if (loaded == null) {
                Analytics.error("hymnal_load", info.id)
                return@launch
            }
            hymnal = loaded
            prefs.edit().putString(KEY_HYMNAL, info.id).apply()
            Analytics.setHymnal(info.id)
            if (info.numbering != current.info.numbering) recents = loadRecents(info.numbering)
            val target = number?.let(loaded::hymn)
                ?: loaded.hymn(lastHymn(info.numbering))
                ?: loaded.hymns.firstOrNull()
            if (target != null) show(target, null)
            Analytics.track(AnalyticsEvent.HymnalSwitched(current.id, info.id, source))
        }
    }

    // MARK: Favourites

    fun toggleFavourite() {
        val target = hymn ?: return
        val key = favouriteKey(target.number)
        val now = key !in favourites
        favourites = if (now) favourites + key else favourites - key
        prefs.edit().putStringSet(KEY_FAVOURITES, favourites).apply()
        Analytics.track(AnalyticsEvent.FavouriteToggled(target.number, now))
    }

    fun isFavouriteNumber(number: Int): Boolean = favouriteKey(number) in favourites

    // MARK: Paywall

    fun showPaywall(feature: ProFeature, context: String = "reader") {
        paywallContext = context
        paywall = feature
    }

    private fun favouriteKey(number: Int) = "${hymnal?.id}#$number"

    // Last hymn and recents are kept per numbering, as on iOS.
    private fun lastHymnKey(n: Numbering) = if (n == Numbering.ChristInSong) KEY_LAST_HYMN else "$KEY_LAST_HYMN.${n.key}"
    private fun recentsKey(n: Numbering) = if (n == Numbering.ChristInSong) KEY_RECENTS else "$KEY_RECENTS.${n.key}"
    private fun lastHymn(n: Numbering) = prefs.getInt(lastHymnKey(n), 1)
    private fun loadRecents(n: Numbering) =
        prefs.getString(recentsKey(n), "").orEmpty().split(',').mapNotNull { it.toIntOrNull() }

    companion object {
        private const val KEY_HYMNAL = "reader.hymnal"
        private const val KEY_LAST_HYMN = "reader.lastHymn"
        private const val KEY_FAVOURITES = "reader.favourites.v2"
        private const val KEY_RECENTS = "reader.recents"
    }
}
