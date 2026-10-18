package com.mDev.AdventPraise.reader

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.analytics.ErrorDomain
import com.mDev.AdventPraise.analytics.HymnSource
import com.mDev.AdventPraise.analytics.HymnalSource
import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.data.Catalogs
import com.mDev.AdventPraise.data.CrossReference
import com.mDev.AdventPraise.data.Hymn
import com.mDev.AdventPraise.data.HymnQueue
import com.mDev.AdventPraise.data.Hymnal
import com.mDev.AdventPraise.data.HymnalInfo
import com.mDev.AdventPraise.data.Playlist
import com.mDev.AdventPraise.data.PlaylistBook
import com.mDev.AdventPraise.data.RunningQueue
import com.mDev.AdventPraise.data.SearchHit
import com.mDev.AdventPraise.settings.ReaderHistory
import com.mDev.AdventPraise.settings.SharedPreferencesStore
import com.mDev.AdventPraise.ui.design.HapticEvent
import com.mDev.AdventPraise.ui.design.Haptics
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** What the Lectern shows above its row (LecternState on iOS). */
enum class LecternState { Collapsed, Hymn, Pad, Search, Library }

/** The reader menu's panels, which unfold below its bar (ReaderMenuPanel on iOS). */
enum class ReaderMenuPanel(val key: String, val label: String) {
    Translation("translation", "Translation"),
    Theme("theme", "Theme"),
    Text("text", "Text"),
    About("about", "About"),
}

/** The library panel's two lists (LibraryTab on iOS). */
enum class LibraryTab(val label: String) { Favourites("Favourites"), Playlists("Playlists") }

/** The first milestone's screen beside the reader that the shell still draws from here (More). */
enum class Screen { Reader, More }

/** The Terms of Use and the Privacy Policy, shown over whatever is open (the paywall too). */
enum class LegalDocument { Terms, Privacy }

/**
 * The reader's state, as iOS's ReaderModel: which hymnal is open, which hymn,
 * the Lectern, the reader menu and the library (favourites, recents and the
 * playlist being followed). Built on the domain: [ReaderHistory] keeps what is
 * remembered between launches, [HymnQueue] follows a playlist or service plan,
 * [Catalogs] reads the bundled files. Hymnals decode off the main thread
 * ([loader]); until the first one lands [hymnal] and [hymn] are null.
 *
 * Shared by the reader, the hymn list, church mode, the deep links and the
 * keyboard commands. Haptics are played here as iOS plays them in its model.
 */
class ReaderModel(
    val catalogs: Catalogs,
    val history: ReaderHistory,
    val queue: HymnQueue,
    val playlistBook: PlaylistBook,
    private val scope: CoroutineScope,
    private val loader: CoroutineDispatcher = Dispatchers.Default,
) {
    /** A model with its own domain objects, on the app's files (tests and previews). */
    constructor(context: Context, scope: CoroutineScope) :
        this(context, PlaylistBook(SharedPreferencesStore(context, ReaderHistory.PREFS_NAME)), scope)

    private constructor(context: Context, book: PlaylistBook, scope: CoroutineScope) :
        this(Catalogs(context.assets), ReaderHistory(context), HymnQueue(book), book, scope)

    /** Every hymnal the app ships, in hymnals.json order. */
    val catalogue: List<HymnalInfo> get() = catalogs.hymnals

    var hymnal by mutableStateOf<Hymnal?>(null)
        private set
    var hymn by mutableStateOf<Hymn?>(null)
        private set
    /** Christ In Song ↔ SDA Hymnal, built from the English hymns once they load. */
    var crossReference by mutableStateOf<CrossReference?>(null)
        private set
    /** The last three hymns opened, kept per numbering. */
    var recents by mutableStateOf<List<Int>>(emptyList())
        private set

    var isFocused by mutableStateOf(false)
    /** Written only through [openLectern] / [closeLectern] (and [show], which collapses it). */
    var lectern by mutableStateOf(LecternState.Collapsed)
        private set
    /** The reader menu at the top: open, and which panel shows under its bar (null: the bar alone). */
    var isMenuOpen by mutableStateOf(false)
        private set
    var menuPanel by mutableStateOf<ReaderMenuPanel?>(null)
        private set
    var digits by mutableStateOf("")
    var query by mutableStateOf("")
    var searchLyrics by mutableStateOf(true)
    var libraryTab by mutableStateOf(LibraryTab.Favourites)
    /** Wide windows: the hymn list beside the reader is showing (iPad's sidebar). */
    var isSidebarVisible by mutableStateOf(true)

    // The shell's first-milestone layers (More, the paywall, the legal documents).
    var screen by mutableStateOf(Screen.Reader)
    /** The paywall, leading with this feature; null when closed. */
    var paywall by mutableStateOf<ProFeature?>(null)
    var paywallContext by mutableStateOf("reader")
    /** The Terms or the Privacy Policy, over everything; null when closed. */
    var document by mutableStateOf<LegalDocument?>(null)

    /** Playlist Play: AppServices starts the accompaniment for the first hymn. */
    var onPlaylistStarted: ((Hymn) -> Unit)? = null

    /** The hymnal being loaded by a switch, so a second tap waits. */
    private var switching: String? = null
    /** A hymn asked for (a deep link) before the first hymnal had loaded. */
    private var pendingOpen: Pair<Int, String?>? = null
    /** Set when the first playlist is made; [playlistEditorClosed] reads it once. */
    private var revealsPlaylistsAfterEditor = false

    fun start() {
        val info = catalogs.hymnal(history.hymnalId) ?: catalogs.defaultHymnal
        scope.launch {
            val loaded = withContext(loader) { catalogs.load(info) ?: catalogs.load(catalogs.defaultHymnal) }
            if (loaded == null) {
                Analytics.error(ErrorDomain.HymnalLoad, info.id)
                return@launch
            }
            if (loaded.id != info.id) Analytics.error(ErrorDomain.HymnalLoad, info.id)
            hymnal = loaded
            recents = history.recents(loaded.info.numbering)
            hymn = history.lastHymn(loaded.info.numbering)?.let(loaded::hymn) ?: loaded.hymns.firstOrNull()
            Analytics.setHymnal(loaded.id)
            pendingOpen?.let { (number, hymnalId) -> pendingOpen = null; openLink(number, hymnalId) }
            if (crossReference == null) {
                val english = if (loaded.id == HymnalInfo.DEFAULT_ID) loaded else withContext(loader) { catalogs.load(catalogs.defaultHymnal) }
                crossReference = crossReference ?: english?.let { withContext(loader) { catalogs.crossReference(it) } }
            }
            // Read the sheet music manifest now, not on the first frame that asks.
            withContext(loader) { catalogs.sheetMusic.hymnal }
        }
    }

    // MARK: Derived

    val hymnalInfo: HymnalInfo? get() = hymnal?.info

    /**
     * The hymn on screen has sheet music in this hymnal (an SDA Hymnal hymn
     * through its public domain Christ In Song tune): the reader's top bar
     * shows the sheet music button beside the globe only then.
     */
    val hasSheetMusic: Boolean
        get() {
            val h = hymnal ?: return false
            val number = hymn?.number ?: return false
            return catalogs.hasSheetMusic(h.id, number)
        }

    val isFavourite: Boolean get() = hymn?.let { isFavouriteNumber(it.number) } ?: false

    fun isFavouriteNumber(number: Int): Boolean = hymnal?.let { history.isFavourite(it.id, number) } ?: false

    /** The open hymnal's favourites, by number. */
    val favouriteNumbers: List<Int> get() = hymnal?.let { history.favouriteNumbers(it.id) }.orEmpty()

    val favouriteHymns: List<Hymn> get() = hymnal?.let { h -> favouriteNumbers.mapNotNull(h::hymn) }.orEmpty()

    val previewHymn: Hymn? get() = digits.toIntOrNull()?.let { hymnal?.hymn(it) }

    /** Two letters, or any number, before searching (as iOS). */
    fun searchHits(text: String = query, inLyrics: Boolean = searchLyrics): List<SearchHit> {
        val h = hymnal ?: return emptyList()
        return if (text.trim().length >= 2 || text.toIntOrNull() != null) h.search(text, inLyrics) else emptyList()
    }

    /** The next number, or the next entry of a running service plan. */
    val nextHymn: Hymn? get() = withHymn { h, hy -> queue.nextHymn(h, hy) }
    val previousHymn: Hymn? get() = withHymn { h, hy -> queue.previousHymn(h, hy) }
    /** Where "next" goes: the next playlist entry while a playlist runs, else the next number. */
    val upcomingHymn: Hymn? get() = withHymn { h, hy -> queue.upcomingHymn(h, hy) }
    /** Where "previous" goes: back through the running playlist, else the previous number. */
    val precedingHymn: Hymn? get() = withHymn { h, hy -> queue.precedingHymn(h, hy) }

    private inline fun <T> withHymn(body: (Hymnal, Hymn) -> T?): T? {
        val h = hymnal ?: return null
        val hy = hymn ?: return null
        return body(h, hy)
    }

    /** Where the open hymn is in `info`: its number there, or null if it isn't there. */
    fun numberIn(info: HymnalInfo): Int? {
        val from = hymnal?.info ?: return null
        val number = hymn?.number ?: return null
        if (from.numbering == info.numbering) return number.takeIf { it <= info.maxNumber }
        return crossReference?.number(number, from, info)
    }

    // MARK: Focus, Lectern and menu

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
        // One piece of chrome open at a time.
        isMenuOpen = false
        menuPanel = null
        lectern = state
        Haptics.play(HapticEvent.SoftImpact)
    }

    /** Idempotent: a second call (one swipe seen by two gestures) does nothing. */
    fun closeLectern() {
        if (lectern == LecternState.Collapsed) return
        lectern = LecternState.Collapsed
        Haptics.play(HapticEvent.SoftImpact)
    }

    /** The globe: grows into the menu bar with `panel` open under it. */
    fun openMenu(panel: ReaderMenuPanel? = ReaderMenuPanel.Translation) {
        if (isMenuOpen) return
        isFocused = false
        lectern = LecternState.Collapsed
        isMenuOpen = true
        menuPanel = panel
        Haptics.play(HapticEvent.SoftImpact)
        Analytics.track(AnalyticsEvent.ReaderMenuOpened(panel?.key))
    }

    /** A tab in the bar: shows its panel, or folds it away if it's showing. */
    fun toggleMenuPanel(panel: ReaderMenuPanel) {
        if (!isMenuOpen) return openMenu(panel)
        val next = if (menuPanel == panel) null else panel
        menuPanel = next
        Haptics.play(HapticEvent.Selection)
        if (next != null) Analytics.track(AnalyticsEvent.ReaderMenuPanelOpened(next.key))
    }

    /** Idempotent, like [closeLectern]: the backdrop and the close button may both report one tap. */
    fun closeMenu() {
        if (!isMenuOpen) return
        isMenuOpen = false
        menuPanel = null
        Haptics.play(HapticEvent.SoftImpact)
    }

    // MARK: Number pad

    /** A key on the pad. Refuses a fifth digit or a number past the end of the hymnal. */
    fun push(digit: Char): Boolean {
        if (digits.length >= 4) { Haptics.play(HapticEvent.Limit); return false }
        val next = if (digits == "0") digit.toString() else digits + digit
        if (!accepts(next)) { Haptics.play(HapticEvent.Limit); return false }
        digits = next
        Haptics.play(HapticEvent.KeyPress)
        return true
    }

    /**
     * The pad writes through this (LecternView's guarded binding): shorter is
     * always taken; longer only while it stays within the hymnal.
     */
    fun proposeDigits(proposed: String): Boolean {
        if (proposed.length <= digits.length) { digits = proposed; return true }
        if (!accepts(proposed)) { Haptics.play(HapticEvent.Limit); return false }
        digits = proposed
        return true
    }

    private fun accepts(text: String): Boolean {
        val value = text.toIntOrNull() ?: return false
        // Like the legacy pad: never accept a number past the end of the hymnal.
        return value <= maxOf(hymnal?.info?.maxNumber ?: 1, 1)
    }

    fun backspace() { digits = digits.dropLast(1) }
    fun clearDigits() { digits = "" }

    fun openPreview(): Boolean {
        val target = previewHymn ?: return false
        show(target, source = HymnSource.Numpad)
        return true
    }

    // MARK: Opening hymns

    /**
     * Shows [target]. `feedback` is felt when the hymn actually changes;
     * callers pass null for changes the user didn't make by touch (playlist
     * advance, a link). `source` is sent with `hymn_opened`; null sends nothing
     * (a hymnal switch showing the same number).
     */
    fun show(target: Hymn, feedback: HapticEvent? = HapticEvent.PageTurn, source: HymnSource?) {
        val h = hymnal ?: return
        if (target != hymn && feedback != null) Haptics.play(feedback)
        hymn = target
        lectern = LecternState.Collapsed
        recents = history.recordOpened(h.info.numbering, target.number)
        if (source != null) Analytics.track(AnalyticsEvent.HymnOpened(h.id, target.number, source))
    }

    /** [show] with iOS's HymnSource raw value (`"playlist"`, `"church_mode"`…). */
    fun show(target: Hymn, source: String) = show(target, source = hymnSource(source))

    /** Opens hymn [number] in the current hymnal, leaving any playlist; false if it doesn't exist. */
    fun open(number: Int, source: HymnSource, feedback: HapticEvent? = HapticEvent.PageTurn): Boolean {
        val target = hymnal?.hymn(number) ?: return false
        queue.stop()
        show(target, feedback, source)
        return true
    }

    /** The navigator's string sources (`"numpad"`, `"search"`…), as iOS's HymnSource raw values. */
    fun open(number: Int, source: String): Boolean = open(number, hymnSource(source))

    /** Next hymn: the next playlist entry when a playlist is running, else the next number. */
    fun goToNext(source: HymnSource, feedback: HapticEvent? = HapticEvent.PageTurn): Hymn? {
        val h = hymnal ?: return null
        val current = hymn ?: return null
        return queue.goToNext(h, current)?.also { show(it, feedback, source) }
    }

    fun goToPrevious(source: HymnSource, feedback: HapticEvent? = HapticEvent.PageTurn): Hymn? {
        val h = hymnal ?: return null
        val current = hymn ?: return null
        return queue.goToPrevious(h, current)?.also { show(it, feedback, source) }
    }

    fun goToNext(source: String = "swipe"): Hymn? = goToNext(hymnSource(source))
    fun goToPrevious(source: String = "swipe"): Hymn? = goToPrevious(hymnSource(source))

    /**
     * Switches hymnal, keeping the same hymn: the same number among Christ In
     * Song and its translations; across to or from the SDA Hymnal, the
     * cross-referenced hymn, else the last hymn read there (else the first).
     * One firmer tap for the switch, not a page turn on top of it. [then] runs
     * once the new hymnal is showing.
     */
    fun switchHymnal(
        info: HymnalInfo,
        source: HymnalSource = HymnalSource.Translation,
        feedback: HapticEvent? = HapticEvent.MediumImpact,
        then: () -> Unit = {},
    ) {
        val current = hymnal ?: return
        if (info.id == current.id) { closeLectern(); then(); return }
        if (switching != null) return
        switching = info.id
        val number = hymn?.number
        scope.launch {
            val loaded = withContext(loader) { catalogs.load(info) }
            if (loaded == null) {
                switching = null
                Analytics.error(ErrorDomain.HymnalLoad, info.id)
                return@launch
            }
            val crossesNumbering = current.info.numbering != info.numbering
            val cross = if (!crossesNumbering) null else crossReference ?: withContext(loader) {
                catalogs.load(catalogs.defaultHymnal)?.let(catalogs::crossReference)
            }?.also { crossReference = it }
            val same = number?.let { n ->
                if (crossesNumbering) cross?.number(n, current.info, info) else n.takeIf { it <= info.maxNumber }
            }?.let(loaded::hymn)
            switching = null
            hymnal = loaded
            queue.stop()
            history.setHymnal(info.id)
            Analytics.setHymnal(info.id)
            if (crossesNumbering) recents = history.recents(info.numbering)
            val lastThere = if (crossesNumbering) history.lastHymn(info.numbering)?.let(loaded::hymn) else null
            (same ?: lastThere ?: loaded.hymns.firstOrNull())?.let { show(it, feedback = null, source = null) }
            Analytics.track(AnalyticsEvent.HymnalSwitched(current.id, info.id, source))
            if (feedback != null) Haptics.play(feedback)
            then()
        }
    }

    /** The navigator's and church mode's string sources. */
    fun switchHymnal(info: HymnalInfo, source: String) =
        switchHymnal(info, HymnalSource.entries.firstOrNull { it.key == source } ?: HymnalSource.Translation)

    /**
     * `adventpraise://hymn/<number>?hymnal=<id>` (the Hymn of the Day widget,
     * shortcuts): the number in its own hymnal, switching first when another
     * is open. Waits for the first hymnal if the app is still loading.
     */
    fun openLink(number: Int, hymnalId: String?) {
        val current = hymnal ?: run { pendingOpen = number to hymnalId; return }
        val info = hymnalId?.let(catalogs::hymnal)
        if (info != null && info.id != current.id) {
            switchHymnal(info, HymnalSource.Lectern, feedback = null) { open(number, HymnSource.Numpad) }
        } else {
            open(number, HymnSource.Numpad)
        }
    }

    // MARK: Favourites

    fun toggleFavourite() {
        val h = hymnal ?: return
        val target = hymn ?: return
        val now = history.toggleFavourite(h.id, target.number)
        Haptics.play(HapticEvent.toggle(now))
    }

    /**
     * Stars hymn [number] of the open hymnal (the library's Add hymn). False if
     * the hymnal has no such hymn; one already starred stays so.
     */
    fun addFavourite(number: Int): Boolean {
        val h = hymnal ?: return false
        if (h.hymn(number) == null) return false
        if (history.isFavourite(h.id, number)) return true
        history.addFavourite(h.id, number)
        Haptics.play(HapticEvent.ToggleOn)
        return true
    }

    // MARK: Playlists

    /** The open hymnal's playlists. */
    val playlists: List<Playlist> get() = hymnal?.let { playlistBook.playlists(it.id) }.orEmpty()

    fun playlist(id: String): Playlist? = playlists.firstOrNull { it.id == id }

    val nextPlaylistName: String get() = hymnal?.let { playlistBook.nextName(it.id) } ?: "Playlist 1"

    val activePlaylistId: String? get() = queue.activePlaylistId

    /** New Playlist: the library shows Playlists; the caller asks for a name (navigator.newPlaylist). */
    fun newPlaylist() {
        libraryTab = LibraryTab.Playlists
        closeLectern()
    }

    /** Creates a playlist holding the open hymn; the caller opens it in the editor. */
    fun createPlaylist(name: String): Playlist? {
        val h = hymnal ?: return null
        val first = hymn ?: return null
        val created = playlistBook.create(h.id, name, first.number)
        if (created.isFirstEver) revealsPlaylistsAfterEditor = true
        libraryTab = LibraryTab.Playlists
        closeLectern()
        return created.playlist
    }

    /**
     * The editor closed. True once, after the very first playlist: the caller
     * then opens the library on Playlists, so the reader sees where it lives.
     */
    fun playlistEditorClosed(): Boolean {
        if (!revealsPlaylistsAfterEditor) return false
        revealsPlaylistsAfterEditor = false
        libraryTab = LibraryTab.Playlists
        return true
    }

    fun addCurrentHymn(to: Playlist) {
        val h = hymnal ?: return
        val number = hymn?.number ?: return
        if (playlistBook.add(h.id, to.id, number)) Haptics.play(HapticEvent.ToggleOn)
    }

    fun rename(playlist: Playlist, to: String) {
        val h = hymnal ?: return
        playlistBook.rename(h.id, playlist.id, to)
    }

    /** Always after a confirmation, so one firm tap marks it done. */
    fun delete(playlist: Playlist) {
        val h = hymnal ?: return
        queue.onDeleted(playlist.id)
        playlistBook.delete(h.id, playlist.id)
        Haptics.play(HapticEvent.MediumImpact)
    }

    /** Play can start: at least one entry is in the open hymnal. */
    fun canPlay(playlist: Playlist): Boolean = hymnal?.let { queue.canPlay(playlist, it) } ?: false

    /**
     * Opens the playlist's hymn at [start], follows the playlist from there
     * and starts the accompaniment ([onPlaylistStarted]). Entries this
     * hymnal lacks are skipped, as Next skips them.
     */
    fun play(playlist: Playlist, start: Int = 0): Boolean {
        val h = hymnal ?: return false
        val target = queue.play(playlist, h, start) ?: return false
        show(target, source = HymnSource.Playlist)
        onPlaylistStarted?.invoke(target)
        return true
    }

    /** Runs [numbers] in order like a playlist without saving it. False if none exist. */
    fun play(numbers: List<Int>, name: String, source: HymnSource): Boolean {
        val h = hymnal ?: return false
        val target = queue.play(numbers, name, source, h) ?: return false
        show(target, source = source)
        return true
    }

    /** The playlist or service plan being followed, for church mode's number pad. */
    val runningQueue: RunningQueue? get() = withHymn { h, hy -> queue.runningQueue(h, hy) }

    /** "Sabbath · 2 of 5" while a playlist is running. */
    val playlistProgress: String? get() = withHymn { h, hy -> queue.progress(h, hy) }

    /** Opens entry [index] of the running playlist or queue and follows it from there. */
    fun jumpInQueue(index: Int): Boolean {
        val h = hymnal ?: return false
        val current = hymn ?: return false
        val (target, source) = queue.jump(index, h, current) ?: return false
        show(target, source = source)
        return true
    }

    /** Moves on within the playlist (also the player's end of hymn, which stays quiet). */
    fun advancePlaylist(feedback: HapticEvent? = null, source: HymnSource = HymnSource.PlaylistAdvance): Hymn? {
        val h = hymnal ?: return null
        val current = hymn ?: return null
        return queue.advance(h, current)?.also { show(it, feedback, source) }
    }

    // MARK: Paywall (the shell's legacy layer)

    fun showPaywall(feature: ProFeature, context: String = "reader") {
        paywallContext = context
        paywall = feature
    }

    companion object {
        /** iOS's HymnSource raw value; unknown strings count as the number pad. */
        fun hymnSource(key: String): HymnSource = HymnSource.entries.firstOrNull { it.key == key } ?: HymnSource.Numpad
    }
}
