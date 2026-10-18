package com.mDev.AdventPraise.ui

import android.app.Application
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.github.takahirom.roborazzi.captureRoboImage
import com.mDev.AdventPraise.audio.AccompanimentPass
import com.mDev.AdventPraise.audio.AccompanimentState
import com.mDev.AdventPraise.audio.PlaybackState
import com.mDev.AdventPraise.data.DirectoryAssets
import com.mDev.AdventPraise.data.SdahTunes
import com.mDev.AdventPraise.data.SheetMusicCatalog
import com.mDev.AdventPraise.data.SheetMusicViewMode
import com.mDev.AdventPraise.extras.SheetMusicAccess
import com.mDev.AdventPraise.extras.StartingNote
import com.mDev.AdventPraise.settings.PlaybackTempo
import com.mDev.AdventPraise.settings.ReadingSurface
import com.mDev.AdventPraise.ui.design.GlassCard
import com.mDev.AdventPraise.ui.pitchpipe.PitchPipeContent
import com.mDev.AdventPraise.ui.player.LecternPlayButtonFace
import com.mDev.AdventPraise.ui.player.LecternPlayerStrip
import com.mDev.AdventPraise.ui.sheetmusic.SheetMusicArt
import com.mDev.AdventPraise.ui.sheetmusic.SheetMusicContent
import com.mDev.AdventPraise.ui.sheetmusic.SheetMusicModel
import com.mDev.AdventPraise.ui.sheetmusic.sheetMusicInk
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import com.mDev.AdventPraise.ui.theme.SurfaceGround
import com.mDev.AdventPraise.ui.theme.VesperTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import kotlin.math.roundToLong

/**
 * JVM screenshots of the music area, light (Paper) and dark (Black): the
 * sheet music by page and by system with the accompaniment's marks at a
 * fixed place, the free preview with its Pro button, the Lectern player's
 * states and the pitch pipe. `./gradlew recordRoborazziDebug --tests '*MusicScreenshotTest'`.
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w411dp-h891dp-xxhdpi", application = Application::class)
class MusicScreenshotTest {
    @get:Rule val compose = createComposeRule()

    private val assets = DirectoryAssets.iosResources()
    private val catalog = SheetMusicCatalog(assets, SdahTunes(assets))
    private val hymn = 1
    private val timing = catalog.timing("english", hymn)!!

    private fun shot(name: String, surface: ReadingSurface, content: @Composable () -> Unit) {
        compose.setContent {
            VesperTheme(surface) { SurfaceGround(Modifier.fillMaxSize()) { content() } }
        }
        compose.onRoot().captureRoboImage("src/test/screenshots/music_$name.png")
    }

    // MARK: Sheet music

    private fun sheet(name: String, surface: ReadingSurface, access: SheetMusicAccess, mode: SheetMusicViewMode) {
        val model = SheetMusicModel(AccompanimentState.key("english", hymn), access,
            List(3) { AccompanimentPass(it + 1, 4, 0) }, playerUnlocked = true, canPlay = true, viewMode = mode)
        model.timing = timing
        val layout = model.pageLayout(411.0)
        val art = SheetMusicArt.render(catalog.page("english", hymn, layout)!!, surface.sheetMusicInk())!!
        // Verse 2, a fixed moment in: the measure, note and syllable marked.
        val status = AccompanimentState(
            hymnKey = model.hymnKey, state = PlaybackState.Playing,
            positionMs = ((timing.passLength + 9.0) * 1000).roundToLong(),
            durationMs = (timing.passLength * 3 * 1000).roundToLong(), pass = 2, passes = 3,
        )
        model.follow(status)
        shot(name, surface) {
            SheetMusicContent(
                model = model, status = status, surface = surface, hymnNumber = hymn, hymnTitle = "Watch, Ye Saints",
                proCount = 189, isPlayingHere = true, screenReader = false,
                art = { if (it == layout) art else null }, isUnreadable = { false }, onNeedPage = {},
                onClose = {}, onMode = {}, onTogglePlay = {}, onSeek = {}, onPro = {},
            )
        }
    }

    @Test fun sheetPageLight() = sheet("sheet_page_light", ReadingSurface.Paper, SheetMusicAccess.Pro, SheetMusicViewMode.Page)
    @Test fun sheetPageDark() = sheet("sheet_page_dark", ReadingSurface.Black, SheetMusicAccess.Pro, SheetMusicViewMode.Page)
    @Test fun sheetSystemLight() = sheet("sheet_system_light", ReadingSurface.Paper, SheetMusicAccess.Pro, SheetMusicViewMode.System)
    @Test fun sheetSystemDark() = sheet("sheet_system_dark", ReadingSurface.Black, SheetMusicAccess.Pro, SheetMusicViewMode.System)
    @Test fun sheetPreviewLight() = sheet("sheet_preview_light", ReadingSurface.Paper, SheetMusicAccess.Preview, SheetMusicViewMode.Page)
    @Test fun sheetPreviewDark() = sheet("sheet_preview_dark", ReadingSurface.Black, SheetMusicAccess.Preview, SheetMusicViewMode.Page)

    // MARK: Lectern player

    private fun lectern(name: String, surface: ReadingSurface) = shot(name, surface) {
        val p = LocalSurface.current
        Column(Modifier.fillMaxWidth().padding(DS.Space.l), verticalArrangement = Arrangement.spacedBy(DS.Space.l)) {
            Text("Transport, verse 2 of 4, Medium", style = DS.Type.caption, color = p.secondary)
            GlassCard {
                LecternPlayerStrip(elapsed = 47.0, duration = 33.3 * 4, rate = 1.0, verseLabel = "Verse 2 of 4",
                    tempo = PlaybackTempo.Medium, onSeek = {}, onRestart = {}, onTempo = {})
            }
            Text("Slow, a chorus-only hymn", style = DS.Type.caption, color = p.secondary)
            GlassCard {
                LecternPlayerStrip(elapsed = 10.0, duration = 40.0, rate = 0.8, verseLabel = "Chorus",
                    tempo = PlaybackTempo.Slow, onSeek = {}, onRestart = {}, onTempo = {})
            }
            Text("Play: ready, playing, locked (free plays used), no accompaniment", style = DS.Type.caption, color = p.secondary)
            Row(horizontalArrangement = Arrangement.spacedBy(DS.Space.l)) {
                LecternPlayButtonFace(isPlaying = false, isLocked = false, hasAccompaniment = true, onClick = {})
                LecternPlayButtonFace(isPlaying = true, isLocked = false, hasAccompaniment = true, onClick = {})
                LecternPlayButtonFace(isPlaying = false, isLocked = true, hasAccompaniment = true, onClick = {})
                LecternPlayButtonFace(isPlaying = false, isLocked = false, hasAccompaniment = false, onClick = {})
            }
        }
    }

    @Test fun lecternPlayerLight() = lectern("lectern_player_light", ReadingSurface.Paper)
    @Test fun lecternPlayerDark() = lectern("lectern_player_dark", ReadingSurface.Black)

    // MARK: Pitch pipe

    private fun pitch(name: String, surface: ReadingSurface, published: StartingNote?, chosen: Int?) = shot(name, surface) {
        PitchPipeContent(hymnNumber = 12, title = "Lift Up the Trumpet", published = published, chosen = chosen,
            sounding = null, octave = 4, onOctave = {}, onSound = {}, onKey = {}, onUseHymnalNote = {})
    }

    @Test fun pitchPipeLight() = pitch("pitch_pipe_light", ReadingSurface.Paper, StartingNote("F major", "C4"), null)
    @Test fun pitchPipeDark() = pitch("pitch_pipe_dark", ReadingSurface.Black, StartingNote("F major", "C4"), 65)
    @Test fun pitchPipeNoNoteLight() = pitch("pitch_pipe_no_note_light", ReadingSurface.Paper, null, null)

}
