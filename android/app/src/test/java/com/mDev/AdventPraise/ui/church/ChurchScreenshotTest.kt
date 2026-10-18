package com.mDev.AdventPraise.ui.church

import android.app.Application
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.github.takahirom.roborazzi.captureRoboImage
import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.church.ChurchHost
import com.mDev.AdventPraise.church.ChurchSession
import com.mDev.AdventPraise.church.ChurchState
import com.mDev.AdventPraise.church.display.TvOutputState
import com.mDev.AdventPraise.church.display.TvRoute
import com.mDev.AdventPraise.church.display.TvRouteKind
import com.mDev.AdventPraise.church.display.WorshipDisplay
import com.mDev.AdventPraise.data.Block
import com.mDev.AdventPraise.data.Hymn
import com.mDev.AdventPraise.data.Hymnal
import com.mDev.AdventPraise.data.HymnalInfo
import com.mDev.AdventPraise.data.Playlist
import com.mDev.AdventPraise.settings.MemoryStore
import com.mDev.AdventPraise.settings.ReadingSettings
import com.mDev.AdventPraise.settings.ReadingSurface
import com.mDev.AdventPraise.ui.design.DSPreview
import com.mDev.AdventPraise.ui.design.DSHymnBlock
import com.mDev.AdventPraise.ui.playlists.PlaylistContextPreview
import com.mDev.AdventPraise.ui.playlists.PlaylistEditorContent
import com.mDev.AdventPraise.ui.playlists.PlaylistMenuItem
import com.mDev.AdventPraise.ui.playlists.PlaylistRowStyle
import com.mDev.AdventPraise.ui.playlists.PlaylistSummaryRowContent
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.SurfaceGround
import com.mDev.AdventPraise.ui.theme.VesperTheme
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.DriveFileRenameOutline
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.PlayArrow
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * JVM screenshots of the church area: church mode (with and without Pro, on
 * a light and a dark phone: church mode itself is always black), its sheets,
 * the playlist preview and editor, and the worship display at 1920 × 1080.
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w411dp-h891dp-xxhdpi", application = Application::class)
class ChurchScreenshotTest {
    @get:Rule val compose = createComposeRule()

    private val blessedAssurance = Hymn(30, "Blessed Assurance", emptyList(), DSPreview.blocks.map {
        when (it) {
            is DSHymnBlock.Verse -> Block.Verse(it.number, it.lines)
            is DSHymnBlock.Chorus -> Block.Chorus(it.lines)
        }
    }, null)

    private val hymnal = Hymnal(HymnalInfo("english", "Christ In Song", "English", 300, 300), "Chorus",
        DSPreview.hymns.map { Hymn(it.number, it.title, emptyList(), listOf(Block.Verse(1, listOf(it.firstLine.orEmpty()))), null) })

    private fun state(isPro: Boolean, onTV: Boolean, index: Int = 0, active: Boolean = true, blanked: Boolean = false,
                      announcement: String? = null) = ChurchState(
        isActive = active, index = index, isExternalScreenConnected = onTV, isBlanked = blanked, announcement = announcement,
        hymn = blessedAssurance, hymnalId = "english", hymnalName = "Christ In Song", hasNextHymn = true, isPro = isPro,
    )

    private fun presenter() = ChurchPresenter(
        ChurchSession(object : ChurchHost {
            override fun goToNextHymn() = false
            override fun showPaywall(feature: ProFeature) = Unit
        }),
        ReadingSettings(MemoryStore()), null, {}, {},
    )

    @Composable
    private fun Church(state: ChurchState, popover: WorshipPopover? = null) {
        ChurchModeContent(
            state = state, worshipPointSize = 42f, largePrint = false, isDefaultSize = true, canShrinkText = true,
            canEnlargeText = true, language = "English", hasUpcomingHymn = true, presenter = presenter(),
            popover = popover, onPopover = {}, onExit = {}, onTv = {}, onAnnouncement = {}, onImage = {},
            banner = { m -> if (!state.isPro && state.isExternalScreenConnected) Box(m) { MirroringBanner {} } },
            numberPad = {}, translations = {}, tourActive = true,
        )
    }

    private fun shoot(name: String, surface: ReadingSurface = ReadingSurface.Paper, content: @Composable () -> Unit) {
        compose.setContent { VesperTheme(surface) { SurfaceGround(Modifier.fillMaxSize()) { content() } } }
        compose.onRoot().captureRoboImage("src/test/screenshots/$name.png")
    }

    // Church mode

    @Test fun churchModeProLight() = shoot("church_mode_pro_light") { Church(state(isPro = true, onTV = true, index = 1)) }
    @Test fun churchModeProDark() = shoot("church_mode_pro_dark", ReadingSurface.Black) { Church(state(isPro = true, onTV = true, index = 1)) }
    @Test fun churchModeFreeLight() = shoot("church_mode_free_light") { Church(state(isPro = false, onTV = true)) }
    @Test fun churchModeFreeDark() = shoot("church_mode_free_dark", ReadingSurface.Black) { Church(state(isPro = false, onTV = false, index = 2)) }
    @Test fun churchModeActions() = shoot("church_mode_actions_dark", ReadingSurface.Black) {
        Church(state(isPro = true, onTV = true, blanked = true), popover = WorshipPopover.Actions)
    }

    @Test fun announcementSheet() = shoot("church_announcement_sheet", ReadingSurface.Paper) {
        ChurchSheetPreview { AnnouncementContent("Welcome! Please silence your phones.", listOf("Potluck after the service", "Choir practice at 4"), {}, {}, {}, {}, focusesField = false) }
    }

    @Test fun showOnTvSheet() = shoot("church_show_on_tv_sheet", ReadingSurface.Paper) {
        val hdmi = TvRoute("2", "HDMI", TvRouteKind.SecondDisplay)
        ChurchSheetPreview { ShowOnTvContent(TvOutputState(listOf(hdmi), hdmi, true), {}, {}, {}) }
    }

    @Composable
    private fun ChurchSheetPreview(content: @Composable () -> Unit) {
        ChurchSheetContainer(visible = true, onDismissRequest = {}, onGone = {}) { content() }
    }

    // Playlists

    private val sabbath = Playlist("A", "Sabbath", listOf(30, 1, 254, 999))
    private val menu = listOf(
        PlaylistMenuItem("Play", Icons.Rounded.PlayArrow) {}, PlaylistMenuItem("Edit Playlist", Icons.Rounded.Edit) {},
        PlaylistMenuItem("Add Hymn 18", Icons.Rounded.Add) {}, PlaylistMenuItem("Rename", Icons.Rounded.DriveFileRenameOutline) {},
        PlaylistMenuItem("Delete Playlist", Icons.Rounded.Delete, destructive = true) {},
    )

    @Composable
    private fun Preview() {
        Box(Modifier.fillMaxSize()) {
            Column(Modifier.padding(start = 20.dp, end = 20.dp, top = 120.dp), verticalArrangement = Arrangement.spacedBy(DS.Space.xs)) {
                PlaylistSummaryRowContent(sabbath, isActive = true, style = PlaylistRowStyle.Inset, menu = menu, onPlay = {}, onEdit = {})
                PlaylistSummaryRowContent(Playlist("B", "Choir practice", listOf(18, 1)), false, PlaylistRowStyle.Inset, menu, {}, {})
                PlaylistSummaryRowContent(Playlist("C", "Vespers", emptyList()), false, PlaylistRowStyle.Inset, menu, {}, {})
            }
            // The second row, touched and held: 20 dp in, under the first (xxhdpi: 3 px a dp).
            PlaylistContextPreview(Rect(60f, 3f * 178f, 3f * 391f, 3f * 230f), row = {
                PlaylistSummaryRowContent(Playlist("B", "Choir practice", listOf(18, 1)), false, PlaylistRowStyle.Inset, menu, {}, {})
            }, items = menu, onDismiss = {})
        }
    }

    @Test fun playlistPreviewLight() = shoot("playlist_preview_light") { Preview() }
    @Test fun playlistPreviewDark() = shoot("playlist_preview_dark", ReadingSurface.Black) { Preview() }

    @Composable
    private fun Editor(picking: Boolean = false) {
        PlaylistEditorContent(sabbath, hymnal, openNumber = 1, canPlay = true, onDone = {}, onPlay = {}, onRename = {},
            onDelete = {}, onMove = { _, _ -> }, onMoveHymn = { _, _ -> }, onRemoveAt = {}, onToggle = {}, initialPicking = picking)
    }

    @Test fun playlistEditorLight() = shoot("playlist_editor_light") { Editor() }
    @Test fun playlistEditorDark() = shoot("playlist_editor_dark", ReadingSurface.Black) { Editor() }
    @Test fun playlistPickerLight() = shoot("playlist_picker_light") { Editor(picking = true) }

    // The worship display, as a 1080p TV draws it

    @Composable
    private fun Tv(state: ChurchState) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { WorshipDisplay(state, 42f, false) }
    }

    @Test @Config(qualifiers = "w1920dp-h1080dp-mdpi")
    fun worshipDisplayVerse() = shoot("worship_display_verse") { Tv(state(isPro = true, onTV = true)) }

    @Test @Config(qualifiers = "w1920dp-h1080dp-mdpi")
    fun worshipDisplayChorus() = shoot("worship_display_chorus") { Tv(state(isPro = true, onTV = true, index = 1)) }

    @Test @Config(qualifiers = "w1920dp-h1080dp-mdpi")
    fun worshipDisplayTitle() = shoot("worship_display_title") { Tv(state(isPro = true, onTV = true, active = false)) }

    @Test @Config(qualifiers = "w1920dp-h1080dp-mdpi")
    fun worshipDisplayBlank() = shoot("worship_display_blank") { Tv(state(isPro = true, onTV = true, blanked = true)) }

    @Test @Config(qualifiers = "w1920dp-h1080dp-mdpi")
    fun worshipDisplayAnnouncement() = shoot("worship_display_announcement") {
        Tv(state(isPro = true, onTV = true, announcement = "Welcome! Please silence your phones."))
    }
}
