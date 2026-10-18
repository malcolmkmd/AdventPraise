package com.mDev.AdventPraise.data

import com.mDev.AdventPraise.extras.SheetMusicAccess
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs

/** The sheet music that ships and its timing against the MIDI (SheetMusicTests, SheetMusicSyncTests). */
class SheetMusicTest {
    private val assets = DirectoryAssets.iosResources()
    private val catalog = SheetMusicCatalog(assets, SdahTunes(assets))
    private val withMusic = (1..300).filter { catalog.has("english", it) }

    @Test fun everyListedHymnOpensInEveryWidth() {
        assertEquals(189, catalog.count("english"))
        assertEquals(189, withMusic.size)
        for (number in withMusic) for (layout in SheetMusicLayout.entries) {
            val page = catalog.page("english", number, layout)
            assertNotNull("hymn $number $layout", page)
            assertTrue(page!!.svg.startsWith("<svg"))
            assertTrue(page.svg.contains("currentColor"))
            assertFalse("hymn $number has hard-coded black", page.svg.contains("#000"))
            assertTrue(page.width > 0 && page.height > 0)
        }
    }

    @Test fun heldHymnsDontShip() {
        val held = listOf(5, 11, 87, 101, 125, 161, 170, 173, 182, 216, 260, 281, 85, 29, 164, 266,
            31, 41, 53, 59, 60, 66, 81, 82, 84, 89, 90, 95, 140, 143, 146, 172, 174, 176, 188, 223, 229, 243, 257, 282, 287, 299)
        for (n in held) assertFalse("hymn $n", catalog.has("english", n))
    }

    @Test fun onlyEnglishAndSameTuneSDAHymnsHaveSheetMusic() {
        assertFalse(catalog.has("ndebele", 100))
        assertNull(catalog.page("ndebele", 100, SheetMusicLayout.Phone))
        assertTrue(catalog.has("sdah", 368))       // CIS 1's public domain tune
        assertFalse(catalog.has("sdah", 489))      // another tune than CIS 59
        assertFalse(catalog.has("sdah", 1))        // not in Christ In Song
        val tunes = SdahTunes(assets)
        for (n in 1..695) if (catalog.has("sdah", n)) assertNotNull("SDAH $n", tunes.cisScore(n))
        assertTrue(catalog.count("sdah") > 0)
        assertTrue(catalog.has("english", 1))
        assertFalse(catalog.has("english", 4))
    }

    @Test fun layoutsByWidth() {
        assertEquals(SheetMusicLayout.Phone, SheetMusicLayout.forWidth(402.0))
        assertEquals(SheetMusicLayout.Phone, SheetMusicLayout.forWidth(699.0))
        assertEquals(SheetMusicLayout.Pad, SheetMusicLayout.forWidth(700.0))
        assertEquals(SheetMusicLayout.Line, SheetMusicLayout.forSystems(402.0))
        assertEquals(SheetMusicLayout.Line, SheetMusicLayout.forSystems(599.0))
        assertEquals(SheetMusicLayout.Phone, SheetMusicLayout.forSystems(734.0))
        assertEquals(SheetMusicViewMode.System, SheetMusicViewMode.of("system"))
    }

    @Test fun everyShippedHymnHasTimingThatFitsItsPages() {
        var notes = 0
        for (number in withMusic) {
            val timing = catalog.timing("english", number)
            assertNotNull("hymn $number", timing)
            timing!!
            assertTrue(timing.passLength > 0)
            assertTrue("hymn $number matched ${timing.match}", timing.match >= 0.85)
            assertEquals(timing.measureTimes.sorted(), timing.measureTimes)
            assertEquals(0.0, timing.measureTimes.first(), 0.0)
            assertTrue(timing.measureTimes.last() < timing.passLength)
            assertEquals(timing.noteTimes.sorted(), timing.noteTimes)
            for (layout in SheetMusicLayout.entries) {
                val g = timing.geometry[layout]
                assertNotNull("hymn $number $layout", g)
                g!!
                assertTrue(g.staffSpace > 0)
                assertTrue(timing.measureOrder.all { it in g.measures.indices })
                val page = catalog.page("english", number, layout)!!
                assertTrue(g.measures.all { it.x >= 0 && it.x + it.width <= page.width + 1 && it.y + it.height <= page.height + 1 })
                if (timing.followsNotes) assertEquals(timing.noteVoices.size, g.notes.size)
                // Systems run top to bottom without gaps, each holding its measures.
                assertTrue(g.systems.isNotEmpty())
                assertEquals(g.measures.size, g.measureSystems.size)
                assertEquals(g.measureSystems.sorted(), g.measureSystems)
                assertEquals(g.systems.indices.toSet(), g.measureSystems.toSet())
                assertEquals(0.0, g.systems.first().y, 0.0)
                g.systems.zipWithNext().forEach { (a, b) -> assertTrue(abs(a.y + a.height - b.y) < 0.2) }
                g.measures.zip(g.measureSystems).forEach { (box, s) ->
                    val band = g.systems[s]
                    assertTrue(box.y >= band.y && box.y + box.height <= band.y + band.height + 0.1)
                }
                assertTrue(g.systemExtent.second > 0)
            }
            if (timing.followsNotes) notes++
        }
        assertTrue(notes >= 185)
    }

    @Test fun theClockRepeatsForEachVerse() {
        assertEquals(10.0, SheetMusicTiming.passOffset(50.0, 120.0, 3)!!, 1e-9)
        assertEquals(1, SheetMusicTiming.passIndex(50.0, 120.0, 3))
        assertEquals(40.0, SheetMusicTiming.passOffset(120.0, 120.0, 3)!!, 1e-9)
        assertEquals(2, SheetMusicTiming.passIndex(120.0, 120.0, 3))
        assertNull(SheetMusicTiming.passOffset(5.0, 0.0, 0))
    }

    @Test fun followsWhatAFriendByMeasureNoteAndSyllable() {
        val timing = catalog.timing("english", 100)!!
        assertEquals(listOf(1, 2, 3), timing.verseNumbers)
        assertEquals(2, timing.lyricLine(2))
        assertEquals(1, timing.lyricLine(null))
        val cue = timing.cue(13.0, 2)
        assertEquals(5, cue.measure)
        assertNotNull(cue.note)
        assertEquals(2, cue.syllableLine)
        val g = timing.geometry[SheetMusicLayout.Phone]!!
        val highlight = SheetMusicHighlight.of(cue, g)
        assertTrue(highlight.measure != null && highlight.note != null && highlight.syllable != null)
        assertTrue(highlight.script.startsWith("{\"m\":{"))
        assertEquals(0, timing.cue(0.0, 1).measure)
        val box = g.measures[5]
        assertEquals(5, timing.measure(box.x + box.width / 2, box.y + box.height / 2, SheetMusicLayout.Phone))
        assertNull(timing.measure(-50.0, -50.0, SheetMusicLayout.Phone))
        assertEquals(12.24, timing.seekOffset(5, 0.0)!!, 0.05)
        // System by system.
        assertEquals(5, g.systems.size)
        assertEquals(0, g.system(0))
        assertEquals(2, g.system(5))
        assertNull(g.firstMeasure(g.systems.size))
        assertEquals(0, g.system(999))
        val line = timing.geometry[SheetMusicLayout.Line]!!
        assertTrue(line.systems.size > g.systems.size)
        assertTrue((402.0 / line.systemExtent.second) / (402.0 / g.systemExtent.second) > 1.35)
    }

    @Test fun repeatsSeekToTheRightPass() {
        val timing = catalog.timing("english", 33)!!
        assertEquals(2, timing.measureOrder.count { it == 9 })
        val first = timing.seekOffset(9, 5.0)!!
        val again = timing.seekOffset(9, 20.0)!!
        val back = timing.seekOffset(9, 30.0)!!
        assertTrue(first < again)
        assertEquals(again, back, 0.0)
        assertEquals(9, timing.cue(again + 0.1, 1).measure)
    }

    @Test fun timingParsesItsJSON() {
        val json = """
            {"len": 10, "match": 1, "m": [[0, 0], [5, 1]], "e": [[0, 0], [5, 1]], "l": [0, 0], "nm": [0, 1], "v": [1, 2],
             "geo": {"phone": {"ss": 9, "m": [[0, 0, 100, 50], [100, 0, 100, 50]],
                               "n": [[10, 20, [[1, 8, 60, 20, 12], [2, 8, 75, 20, 12]]], [110, 20, [[1, 108, 60, 20, 12]]]]}}}
        """.trimIndent()
        val timing = SheetMusicTiming.parse(json)!!
        assertEquals(SheetMusicTiming.Cue(1, 1, 1, 1), timing.cue(6.0, 2))
        assertEquals(SheetMusicTiming.Cue(0, 0, 0, 2), timing.cue(1.0, 2))
        assertNull(timing.geometry[SheetMusicLayout.Pad])
        assertNull(SheetMusicTiming.parse("{}"))
    }

    @Test fun aSystemFillsTheWidthAndTapsMapBack() {
        val band = SheetMusicTiming.Box(0.0, 360.0, 798.0, 370.0)
        val f = SheetMusicSystemFrame.fit(band, 0.0, 798.0, 798.0, 1665.0, 48.0, 120.0, 306.0, 600.0)!!
        assertEquals(306.0 / 798, f.scale, 1e-9)
        assertEquals(306.0, f.width, 1e-9)
        assertEquals(48.0, f.x, 1e-9)
        assertEquals(120 + (600 - 370 * f.scale) / 2, f.y + band.y * f.scale, 1e-9)
        assertEquals(360 * f.scale, f.clipTop, 1e-9)
        assertEquals((1665 - 730) * f.scale, f.clipBottom, 1e-9)
        val (px, py) = f.pagePoint(f.x + 399 * f.scale, f.y + 545 * f.scale)
        assertEquals(399.0, px, 1e-6)
        assertEquals(545.0, py, 1e-6)
        assertTrue(f.script.startsWith("{\"w\":306.00"))
        val wide = SheetMusicSystemFrame.fit(band, 0.0, 798.0, 798.0, 1665.0, 0.0, 0.0, 800.0, 250.0)!!
        assertEquals(250.0 / 370, wide.scale, 1e-9)
        assertEquals((800 - 798 * wide.scale) / 2, wide.x, 1e-9)
        assertNull(SheetMusicSystemFrame.fit(band, 0.0, 0.0, 798.0, 1665.0, 48.0, 120.0, 306.0, 600.0))
    }

    @Test fun proSeesEverythingHymnOfTheDayIsFreeOthersPreview() {
        assertEquals(SheetMusicAccess.Pro, SheetMusicAccess.resolve(isPro = true, isHymnOfTheDay = false))
        assertEquals(SheetMusicAccess.HymnOfTheDay, SheetMusicAccess.resolve(isPro = false, isHymnOfTheDay = true))
        assertEquals(SheetMusicAccess.Preview, SheetMusicAccess.resolve(isPro = false, isHymnOfTheDay = false))
        assertTrue(SheetMusicAccess.HymnOfTheDay.showsWholePage)
        assertFalse(SheetMusicAccess.Preview.showsWholePage)
    }
}
