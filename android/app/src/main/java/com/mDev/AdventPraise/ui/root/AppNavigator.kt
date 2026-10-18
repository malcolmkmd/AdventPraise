package com.mDev.AdventPraise.ui.root

import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.staticCompositionLocalOf
import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.reader.LegalDocument
import com.mDev.AdventPraise.reader.ReaderModel
import com.mDev.AdventPraise.reader.Screen
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json

/**
 * How the areas open each other's screens without importing each other's
 * internals. Read it with `LocalAppNavigator.current` (or take it as a
 * parameter). Sources and contexts are the iOS analytics names (`"tray"`,
 * `"more"`, `"reader_menu"`, `"church_mode"`…), sent on by whoever opens.
 */
interface AppNavigator {
    /** The presented screens over the reader, bottom first. */
    val stack: List<Destination>
    val top: Destination? get() = stack.lastOrNull()
    fun isShowing(destination: Destination): Boolean = destination in stack

    /** Presents [destination] the way iOS does (see [Presentation]). */
    fun navigate(destination: Destination)
    /** Closes the top screen. False when nothing was open (the reader handles Back then). */
    fun back(): Boolean
    /** Closes [destination] and everything over it. */
    fun dismiss(destination: Destination)
    /** Closes everything over the reader. */
    fun dismissAll()
    /** Closes More (and its pages), then runs [then] once it has gone (`model.leaveMore`). */
    fun leaveMore(then: () -> Unit = {})

    // MARK: Reader
    /** Opens hymn [number] in the reader and closes the sheets it was chosen in (Extras.open). */
    fun openHymn(number: Int, source: String)
    fun openHymnList() = navigate(Destination.HymnList)
    fun openHymnals() = navigate(Destination.Hymnals)
    fun openAboutHymn(source: String = "reader_menu") = navigate(Destination.AboutHymn(source))

    // MARK: Music
    fun openSheetMusic(source: String = "tray") = navigate(Destination.SheetMusic(source))
    /** The pitch pipe for [hymnNumber], or the open hymn. */
    fun openPitchPipe(hymnNumber: Int? = null) = navigate(Destination.PitchPipe(hymnNumber))

    // MARK: Church
    /** Church mode; closes any sheet first, as iOS does before its full-screen cover. */
    fun openChurchMode(source: String)
    fun openPlaylist(playlistId: String) = navigate(Destination.PlaylistEditor(playlistId))
    fun newPlaylist() = navigate(Destination.PlaylistName(null))
    fun renamePlaylist(playlistId: String) = navigate(Destination.PlaylistName(playlistId))
    fun deletePlaylist(playlistId: String) = navigate(Destination.PlaylistDelete(playlistId))

    // MARK: Extras
    fun openCollections() = navigate(Destination.Collections)
    fun openCollection(id: String, title: String) = navigate(Destination.Collection(id, title))
    fun openMemorise(source: String = "tray") = navigate(Destination.Memorise(source))
    fun openScriptureIndex() = navigate(Destination.ScriptureIndex)
    fun openPassage(id: String, reference: String) = navigate(Destination.Passage(id, reference))
    fun openServicePlanner() = navigate(Destination.ServicePlanner)
    fun openServicePlan(planId: String) = navigate(Destination.ServicePlan(planId))
    fun openHymnStory() = navigate(Destination.HymnStory)

    // MARK: Shell
    fun openMore() = navigate(Destination.More)
    /** The Pro paywall leading with [feature]; [context] is `reader`, `church_mode` or `sheet_music`. */
    fun openPaywall(feature: ProFeature, context: String = "reader")
    fun openSupport() = navigate(Destination.Support)
    fun openTerms() = navigate(Destination.Terms)
    fun openPrivacy() = navigate(Destination.Privacy)
    fun openAboutApp() = navigate(Destination.AboutApp)
    fun openTour(source: String) = navigate(Destination.Tour(source))
    fun openWhatsNew(version: String = "7.0") = navigate(Destination.WhatsNew(version))
    fun openFeatureBoard() = navigate(Destination.FeatureBoard)
}

/** The navigator for the composition (provided by the root). */
val LocalAppNavigator = staticCompositionLocalOf<AppNavigator> { error("No AppNavigator: compose inside AdventPraiseRoot") }

/**
 * The app's navigator: a stack of presented [Destination]s over the reader.
 *
 * The first milestone's screens (More, the paywall and the legal
 * documents) still draw from ReaderModel's own fields; until their areas move
 * them into the stack, their routes are handed to those fields here, so callers
 * already use the final API. Flip the `*IsLegacy` switches as each moves.
 */
class RootNavigator(private val reader: ReaderModel) : AppNavigator {
    private val entries = mutableStateListOf<Destination>()
    override val stack: List<Destination> get() = entries

    // The first milestone's layers (see the class comment).
    var moreIsLegacy = true
    var paywallIsLegacy = true
    var legalIsLegacy = true

    override fun navigate(destination: Destination) {
        when (destination) {
            Destination.Reader -> { dismissAll(); reader.screen = Screen.Reader; return }
            Destination.More -> if (moreIsLegacy) { reader.screen = Screen.More; return }
            is Destination.Paywall -> if (paywallIsLegacy) {
                val feature = ProFeature.entries.firstOrNull { it.analyticsName == destination.feature } ?: ProFeature.Support
                reader.showPaywall(feature, destination.context)
                return
            }
            Destination.Terms -> if (legalIsLegacy) { reader.document = LegalDocument.Terms; return }
            Destination.Privacy -> if (legalIsLegacy) { reader.document = LegalDocument.Privacy; return }
            else -> Unit
        }
        if (entries.lastOrNull() == destination) return
        when (destination.presentation) {
            // A page needs its container: More's sheet, or About this hymn's drawer.
            Presentation.MorePage -> if (!moreIsLegacy && Destination.More !in entries) entries += Destination.More
            Presentation.AboutHymnPage -> if (entries.none { it is Destination.AboutHymn }) entries += Destination.AboutHymn()
            else -> Unit
        }
        entries += destination
    }

    override fun back(): Boolean {
        if (entries.isEmpty()) return false
        entries.removeAt(entries.lastIndex)
        return true
    }

    override fun dismiss(destination: Destination) {
        val index = entries.indexOf(destination)
        if (index >= 0) entries.removeRange(index, entries.size)
    }

    override fun dismissAll() = entries.clear()

    override fun leaveMore(then: () -> Unit) {
        if (moreIsLegacy && reader.screen == Screen.More) reader.screen = Screen.Reader
        entries.removeAll { it == Destination.More || it.presentation == Presentation.MorePage }
        then()
    }

    override fun openHymn(number: Int, source: String) {
        if (!reader.open(number, source)) return
        reader.screen = Screen.Reader
        // Close what it was chosen in; church mode stays up (its queue opens hymns too).
        val church = entries.indexOfLast { it is Destination.ChurchMode }
        if (church >= 0) entries.removeRange(church + 1, entries.size) else entries.clear()
    }

    override fun openChurchMode(source: String) {
        leaveMore()
        entries.removeAll { it.presentation != Presentation.Root && it !is Destination.ChurchMode }
        if (entries.none { it is Destination.ChurchMode }) entries += Destination.ChurchMode(source)
    }

    override fun openPaywall(feature: ProFeature, context: String) =
        navigate(Destination.Paywall(feature.analyticsName, context))

    // MARK: Saving (process death)

    fun save(): String = json.encodeToString(serializer, entries.toList())

    fun restore(saved: String?) {
        if (saved == null) return
        runCatching { json.decodeFromString(serializer, saved) }.getOrNull()?.let {
            entries.clear(); entries += it
        }
    }

    private companion object {
        val json = Json { ignoreUnknownKeys = true }
        val serializer = ListSerializer(Destination.serializer())
    }
}
