package com.mDev.AdventPraise.ui.root

import kotlinx.serialization.Serializable

/**
 * The feature area that owns a screen. Areas call each other only through
 * [AppNavigator]; each owns the packages named here.
 */
enum class Area(val packages: String) {
    /** ui/library, ui/reader: hymn list, search, number pad, reader, globe menu panels, About this hymn. */
    Reader("ui/library, ui/reader"),
    /** ui/sheetmusic, ui/player, ui/pitchpipe. */
    Music("ui/sheetmusic, ui/player, ui/pitchpipe"),
    /** ui/church, ui/playlists: church mode, presenter sheets, queue, playlist editor and preview. */
    Church("ui/church, ui/playlists"),
    /** ui/extras: collections, Memorise and its word-chip game, scripture links, drawer pages, hymn stories, service planner. */
    Extras("ui/extras"),
    /** ui/more, ui/paywall, ui/support, ui/legal, ui/tour, ui/whatsnew, ui/about, ui/root. */
    Shell("ui/more, ui/paywall, ui/support, ui/legal, ui/tour, ui/whatsnew, ui/about"),
}

/**
 * How a screen is presented, as iOS presents it (RootView, MoreSheet, Extras,
 * AdventDrawer). The root host draws each kind; areas draw only the content.
 */
enum class Presentation {
    /** The reader itself, under everything. */
    Root,
    /** A full-height sheet with its own bar and Done (`.sheet`): More, Memorise, Support, the playlist editor. */
    Sheet,
    /** Covers the screen (`.fullScreenCover`): church mode, sheet music. */
    FullScreen,
    /** The floating glass card (AdventDrawer): What's New, About this hymn. */
    Drawer,
    /** A page pushed inside More's sheet, under its bar with Back and Done (MorePage). */
    MorePage,
    /** A page pushed inside the About this hymn drawer (AboutHymnPage). */
    AboutHymnPage,
    /** A page pushed inside church mode's own sheets. */
    ChurchSheet,
    /** A small alert or prompt over everything. */
    Dialog,
    /** Drawn over the reader without taking it away (the tour's spotlight). */
    Overlay,
}

/**
 * Every screen in the iOS app, as a route. Pushed onto [AppNavigator]'s stack;
 * Back pops the top one (predictive back on the containers). Serializable so the
 * stack survives process death.
 */
@Serializable
sealed interface Destination {
    val area: Area
    val presentation: Presentation
    /** The bar title iOS shows, where it has one. */
    val title: String? get() = null

    // MARK: Reader

    /** The reader: hymn, Lectern (number pad, search, library, tray) and the reader menu (globe). */
    @Serializable data object Reader : Destination {
        override val area get() = Area.Reader
        override val presentation get() = Presentation.Root
    }

    /** The full hymn list with search (the first milestone's library; iPad's sidebar on iOS). */
    @Serializable data object HymnList : Destination {
        override val area get() = Area.Reader
        override val presentation get() = Presentation.FullScreen
        override val title get() = "Hymns"
    }

    /** All hymnals with purchase state (HymnalStorePicker; iPad sidebar's Hymnals sheet). */
    @Serializable data object Hymnals : Destination {
        override val area get() = Area.Reader
        override val presentation get() = Presentation.Sheet
        override val title get() = "Hymnals"
    }

    /** About this hymn: its drawer, whose pages are [AboutHymnPage]s (extras). */
    @Serializable data class AboutHymn(val source: String = "reader_menu") : Destination {
        override val area get() = Area.Reader
        override val presentation get() = Presentation.Drawer
        override val title get() = "About this hymn"
    }

    // MARK: Pages inside About this hymn (extras, except the pitch pipe)

    @Serializable data object HymnStory : Destination {
        override val area get() = Area.Extras
        override val presentation get() = Presentation.AboutHymnPage
        override val title get() = "Story"
    }

    @Serializable data object HymnCredits : Destination {
        override val area get() = Area.Extras
        override val presentation get() = Presentation.AboutHymnPage
        override val title get() = "Words and music"
    }

    @Serializable data object HymnSources : Destination {
        override val area get() = Area.Extras
        override val presentation get() = Presentation.AboutHymnPage
        override val title get() = "Sources"
    }

    /** The passages this hymn cites. */
    @Serializable data object HymnScripture : Destination {
        override val area get() = Area.Extras
        override val presentation get() = Presentation.AboutHymnPage
        override val title get() = "Scripture"
    }

    /** Hymns citing a passage, inside the drawer ([passageId] is Passage.id). */
    @Serializable data class HymnPassage(val passageId: String, val reference: String) : Destination {
        override val area get() = Area.Extras
        override val presentation get() = Presentation.AboutHymnPage
        override val title get() = reference
    }

    /** A collection the hymn is in, inside the drawer. */
    @Serializable data class HymnCollectionPage(val collectionId: String, val collectionTitle: String) : Destination {
        override val area get() = Area.Extras
        override val presentation get() = Presentation.AboutHymnPage
        override val title get() = collectionTitle
    }

    /** The pitch pipe for the open hymn, inside the drawer. */
    @Serializable data object HymnPitch : Destination {
        override val area get() = Area.Music
        override val presentation get() = Presentation.AboutHymnPage
        override val title get() = "Pitch pipe"
    }

    // MARK: Music

    /** The open hymn's sheet music, on the whole screen (SheetMusicView). */
    @Serializable data class SheetMusic(val source: String = "tray") : Destination {
        override val area get() = Area.Music
        override val presentation get() = Presentation.FullScreen
        override val title get() = "Sheet music"
    }

    /** The pitch pipe, as a More page; [hymnNumber] null = the open hymn (planPitch otherwise). */
    @Serializable data class PitchPipe(val hymnNumber: Int? = null) : Destination {
        override val area get() = Area.Music
        override val presentation get() = Presentation.MorePage
        override val title get() = "Pitch pipe"
    }

    // MARK: Church

    /** Church mode: one verse at a time, the worship display, the queue (ChurchModeView). */
    @Serializable data class ChurchMode(val source: String) : Destination {
        override val area get() = Area.Church
        override val presentation get() = Presentation.FullScreen
        override val title get() = "Church mode"
    }

    /** A notice on the worship display (ChurchAnnouncementSheet), over church mode. */
    @Serializable data object ChurchAnnouncement : Destination {
        override val area get() = Area.Church
        override val presentation get() = Presentation.ChurchSheet
        override val title get() = "Announcement"
    }

    /** A picture on the worship display (ChurchImageSheet), over church mode. */
    @Serializable data object ChurchImage : Destination {
        override val area get() = Area.Church
        override val presentation get() = Presentation.ChurchSheet
        override val title get() = "Image"
    }

    /** How to put the words on a TV (ScreenMirroringHelpSheet; Cast and second displays on Android). */
    @Serializable data object ScreenMirroringHelp : Destination {
        override val area get() = Area.Church
        override val presentation get() = Presentation.ChurchSheet
        override val title get() = "Show on a TV"
    }

    /** A playlist's editor (PlaylistEditorView); [playlistId] is Playlist.id. */
    @Serializable data class PlaylistEditor(val playlistId: String) : Destination {
        override val area get() = Area.Church
        override val presentation get() = Presentation.Sheet
        override val title get() = "Playlist"
    }

    /** New Playlist / Rename Playlist: the name prompt. [playlistId] null = a new one. */
    @Serializable data class PlaylistName(val playlistId: String? = null) : Destination {
        override val area get() = Area.Church
        override val presentation get() = Presentation.Dialog
        override val title get() = if (playlistId == null) "New Playlist" else "Rename Playlist"
    }

    /** Delete “name”? The hymns stay in the hymnal. */
    @Serializable data class PlaylistDelete(val playlistId: String) : Destination {
        override val area get() = Area.Church
        override val presentation get() = Presentation.Dialog
    }

    // MARK: Extras

    /** Memorise a verse and its word-chip game (MemoryGameView). */
    @Serializable data class Memorise(val source: String = "tray") : Destination {
        override val area get() = Area.Extras
        override val presentation get() = Presentation.Sheet
        override val title get() = "Memorise a verse"
    }

    @Serializable data object ScriptureIndex : Destination {
        override val area get() = Area.Extras
        override val presentation get() = Presentation.MorePage
        override val title get() = "Scripture index"
    }

    /** Hymns citing a passage, as a More page. */
    @Serializable data class Passage(val passageId: String, val reference: String) : Destination {
        override val area get() = Area.Extras
        override val presentation get() = Presentation.MorePage
        override val title get() = reference
    }

    @Serializable data object Collections : Destination {
        override val area get() = Area.Extras
        override val presentation get() = Presentation.MorePage
        override val title get() = "Collections"
    }

    @Serializable data class Collection(val collectionId: String, val collectionTitle: String) : Destination {
        override val area get() = Area.Extras
        override val presentation get() = Presentation.MorePage
        override val title get() = collectionTitle
    }

    @Serializable data object ServicePlanner : Destination {
        override val area get() = Area.Extras
        override val presentation get() = Presentation.MorePage
        override val title get() = "Service planner"
    }

    /** One service plan; [planId] is ServicePlan.id. */
    @Serializable data class ServicePlan(val planId: String) : Destination {
        override val area get() = Area.Extras
        override val presentation get() = Presentation.MorePage
        override val title get() = "Service plan"
    }

    // MARK: Shell

    /** More: Pro card, reading switches, tools, support and about, with its own pages. */
    @Serializable data object More : Destination {
        override val area get() = Area.Shell
        override val presentation get() = Presentation.Sheet
        override val title get() = "More"
    }

    /** The Pro paywall leading with [feature] (billing.ProFeature's analytics name). */
    @Serializable data class Paywall(val feature: String, val context: String = "reader") : Destination {
        override val area get() = Area.Shell
        override val presentation get() = Presentation.Sheet
    }

    /** Support Advent Praise: the tips (SupportView), in the paywall's chrome. */
    @Serializable data object Support : Destination {
        override val area get() = Area.Shell
        override val presentation get() = Presentation.Sheet
        override val title get() = "Support Advent Praise"
    }

    /** Thanks for a tip (TipThankYouSheet), over Support. */
    @Serializable data class TipThanks(val tipId: String) : Destination {
        override val area get() = Area.Shell
        override val presentation get() = Presentation.Sheet
    }

    @Serializable data object AboutApp : Destination {
        override val area get() = Area.Shell
        override val presentation get() = Presentation.MorePage
        override val title get() = "About"
    }

    @Serializable data object Privacy : Destination {
        override val area get() = Area.Shell
        override val presentation get() = Presentation.MorePage
        override val title get() = "Privacy"
    }

    @Serializable data object Terms : Destination {
        override val area get() = Area.Shell
        override val presentation get() = Presentation.MorePage
        override val title get() = "Terms"
    }

    /** Vote on features (FeatureBoard), over More; only when the board is configured. */
    @Serializable data object FeatureBoard : Destination {
        override val area get() = Area.Shell
        override val presentation get() = Presentation.Sheet
        override val title get() = "Vote on features"
    }

    /** What's New, once per major version, in the drawer on the Stage. */
    @Serializable data class WhatsNew(val version: String = "7.0") : Destination {
        override val area get() = Area.Shell
        override val presentation get() = Presentation.Drawer
        override val title get() = "What's New"
    }

    /** The onboarding tour's spotlight over the reader. */
    @Serializable data class Tour(val source: String) : Destination {
        override val area get() = Area.Shell
        override val presentation get() = Presentation.Overlay
    }

    companion object {
        /** One of each, for the route registry test and the area briefs. */
        val all: List<Destination> = listOf(
            Reader, HymnList, Hymnals, AboutHymn(), HymnStory, HymnCredits, HymnSources, HymnScripture,
            HymnPassage("", ""), HymnCollectionPage("", ""), HymnPitch,
            SheetMusic(), PitchPipe(),
            ChurchMode("more"), ChurchAnnouncement, ChurchImage, ScreenMirroringHelp,
            PlaylistEditor(""), PlaylistName(), PlaylistDelete(""),
            Memorise(), ScriptureIndex, Passage("", ""), Collections, Collection("", ""), ServicePlanner, ServicePlan(""),
            More, Paywall("support"), Support, TipThanks(""), AboutApp, Privacy, Terms, FeatureBoard, WhatsNew(), Tour("more"),
        )
    }
}
