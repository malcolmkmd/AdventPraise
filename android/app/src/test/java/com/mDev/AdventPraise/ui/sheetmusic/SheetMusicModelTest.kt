package com.mDev.AdventPraise.ui.sheetmusic

import com.mDev.AdventPraise.audio.AccompanimentPass
import com.mDev.AdventPraise.audio.AccompanimentState
import com.mDev.AdventPraise.audio.PlaybackState
import com.mDev.AdventPraise.data.DirectoryAssets
import com.mDev.AdventPraise.data.SdahTunes
import com.mDev.AdventPraise.data.SheetMusicCatalog
import com.mDev.AdventPraise.data.SheetMusicHighlight
import com.mDev.AdventPraise.data.SheetMusicLayout
import com.mDev.AdventPraise.data.SheetMusicTiming
import com.mDev.AdventPraise.data.SheetMusicViewMode
import com.mDev.AdventPraise.extras.SheetMusicAccess
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.roundToLong

/** The sheet music viewer's decisions: access, Page | System, following the transport, tap to seek. */
class SheetMusicModelTest {
    private val assets = DirectoryAssets.iosResources()
    private val catalog = SheetMusicCatalog(assets, SdahTunes(assets))
    private val timing: SheetMusicTiming = catalog.timing("english", 1)!!
    private val passes = listOf(AccompanimentPass(1, 4, 0), AccompanimentPass(2, 4, 0), AccompanimentPass(3, 4, 0))
    private val key = AccompanimentState.key("english", 1)

    private fun model(access: SheetMusicAccess = SheetMusicAccess.Pro, unlocked: Boolean = true, mode: SheetMusicViewMode = SheetMusicViewMode.Page) =
        SheetMusicModel(key, access, passes, unlocked, canPlay = true, viewMode = mode).also { it.timing = timing }

    /** Playing hymn 1, `seconds` into the performance, three verses. */
    private fun playing(seconds: Double, hymnKey: String = key, state: PlaybackState = PlaybackState.Playing) = AccompanimentState(
        hymnKey = hymnKey, state = state,
        positionMs = (seconds * 1000).roundToLong(),
        durationMs = (timing.passLength * 3 * 1000).roundToLong(),
        pass = 0, passes = 3,
    )

    @Test fun accessDecidesWhatFollows() {
        assertTrue(model().canFollow)
        // A preview neither follows nor plays, and keeps its controls (the Pro button).
        val preview = model(SheetMusicAccess.Preview)
        assertFalse(preview.canFollow)
        preview.controlsVisible = false
        assertTrue(preview.showsControls(screenReader = false))
        // Hymn of the Day shows the whole page, but following needs the player unlocked.
        assertFalse(model(SheetMusicAccess.HymnOfTheDay, unlocked = false).canFollow)
        assertTrue(model(SheetMusicAccess.HymnOfTheDay, unlocked = true).canFollow)
        // Pro bought over the screen: the whole page without leaving.
        preview.access = SheetMusicAccess.Pro
        assertTrue(preview.canFollow)
        // A screen reader keeps the controls.
        val pro = model()
        pro.controlsVisible = false
        assertFalse(pro.showsControls(false))
        assertTrue(pro.showsControls(true))
    }

    @Test fun pageOrSystemAndTheirWidths() {
        val m = model()
        assertFalse(m.systemMode)
        assertEquals(SheetMusicLayout.Phone, m.pageLayout(411.0))
        assertEquals(SheetMusicLayout.Pad, m.pageLayout(900.0))
        m.viewMode = SheetMusicViewMode.System
        assertTrue(m.systemMode)
        // System by system draws from the shortest lines on an upright phone.
        assertEquals(SheetMusicLayout.Line, m.pageLayout(411.0))
        assertEquals(SheetMusicLayout.Phone, m.pageLayout(700.0))
        // Without known systems, System falls back to the page.
        m.timing = null
        assertFalse(m.systemMode)
    }

    @Test fun systemIndexFollowsThePosition() {
        val m = model(mode = SheetMusicViewMode.System)
        val layout = SheetMusicLayout.Line
        val geometry = timing.geometry.getValue(layout)
        assertTrue(geometry.systems.size > 2)
        assertEquals(0, m.systemIndex(layout))
        // Half way through verse 2: the system of the measure being played.
        val status = playing(timing.passLength * 1.5)
        m.follow(status)
        val measure = m.cueMeasure(status)!!
        assertEquals(geometry.system(measure), m.systemIndex(layout))
        assertTrue(m.systemIndex(layout) > 0)
        // Near the end of a pass: the last system.
        m.follow(playing(timing.passLength * 2 - 0.3))
        assertEquals(geometry.systems.size - 1, m.systemIndex(layout))
        // Another hymn playing, or paused part-way on this one.
        assertNull(m.cueMeasure(playing(10.0, hymnKey = "english#2")))
        assertEquals(m.cueMeasure(playing(10.0)), m.cueMeasure(playing(10.0, state = PlaybackState.Paused)))
        assertNull(m.cueMeasure(playing(10.0, state = PlaybackState.Idle)))
    }

    @Test fun arrowsAndSwipesStopAtTheEnds() {
        val m = model(mode = SheetMusicViewMode.System)
        val layout = SheetMusicLayout.Line
        val count = m.systemCount(layout)
        assertTrue(m.goToSystem(1, layout))
        assertEquals(1, m.systemIndex(layout))
        assertFalse(m.goToSystem(count, layout))
        assertEquals(1, m.systemIndex(layout))
        assertTrue(m.goToSystem(count - 1, layout))
        assertEquals(count - 1, m.systemIndex(layout))
        assertFalse(m.goToSystem(-1, layout))
    }

    @Test fun tapOnAMeasurePlaysFromThereInTheVerseBeingPlayed() {
        val m = model()
        val layout = SheetMusicLayout.Phone
        val boxes = timing.geometry.getValue(layout).measures
        val target = 3
        val box = boxes[target]
        val point = (box.x + box.width / 2) to (box.y + box.height / 2)
        // In verse 2 (pass index 1), 5 s in.
        val status = playing(timing.passLength + 5.0)
        val tap = m.tapped(point, layout, status)
        val offset = timing.seekOffset(target, 5.0)!!
        assertEquals(SheetMusicModel.Tap.Seek(((timing.passLength + offset) * 1000).roundToLong()), tap)
        assertTrue(m.controlsVisible)
        // Off the music: the controls hide, then show.
        assertEquals(SheetMusicModel.Tap.ToggleControls, m.tapped(-50.0 to -50.0, layout, status))
        assertFalse(m.controlsVisible)
        assertEquals(SheetMusicModel.Tap.ToggleControls, m.tapped(null, layout, status))
        assertTrue(m.controlsVisible)
        // Not following (another hymn up): a tap on a measure only toggles the controls.
        assertEquals(SheetMusicModel.Tap.ToggleControls, m.tapped(point, layout, playing(5.0, hymnKey = "english#2")))
        // A preview never seeks.
        assertEquals(SheetMusicModel.Tap.ToggleControls, model(SheetMusicAccess.Preview).tapped(point, layout, status))
    }

    @Test fun highlightMarksTheMeasureNoteAndSyllable() {
        val m = model()
        val status = playing(timing.passLength + 8.0)
        val highlight = m.highlight(SheetMusicLayout.Phone, status)
        assertNotEquals(SheetMusicHighlight.none, highlight)
        assertTrue(highlight.measure != null)
        assertEquals(SheetMusicHighlight.none, m.highlight(SheetMusicLayout.Phone, playing(8.0, hymnKey = "english#2")))
        assertEquals(SheetMusicHighlight.none, model(SheetMusicAccess.Preview).highlight(SheetMusicLayout.Phone, status))
    }
}
