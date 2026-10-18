package com.mDev.AdventPraise.extras

import com.mDev.AdventPraise.analytics.ServicePlanEdit
import com.mDev.AdventPraise.data.DirectoryAssets
import com.mDev.AdventPraise.data.SdahTunes
import com.mDev.AdventPraise.settings.MemoryStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class ScriptureTest {
    private val links = ScriptureLinks(DirectoryAssets.iosResources())

    @Test fun passagesParseAndPrintAsOnIOS() {
        assertEquals(Passage("Psalms", 23, 1), Passage.parse("Psalms 23:1"))
        assertEquals("John 3:16–17", Passage.parse("John 3:16-17")?.reference)
        assertEquals("John 3:16–17", Passage.parse("John 3:16–17")?.reference)
        assertEquals("1 Corinthians 13", Passage.parse("1 Corinthians 13")?.reference)
        assertNull(Passage.parse("Hezekiah 1:1"))
        assertNull(Passage.parse("John 0:1"))
        assertNull(Passage.parse("John"))
    }

    @Test fun youVersionLinks() {
        assertEquals("https://www.bible.com/bible/1/PSA.23.1", Passage.parse("Psalms 23:1")?.bibleUrl)
        assertEquals("https://www.bible.com/bible/1/JHN.3.16-17", Passage.parse("John 3:16-17")?.bibleUrl)
        assertEquals("https://www.bible.com/bible/1/1CO.13", Passage.parse("1 Corinthians 13")?.bibleUrl)
        assertEquals("https://www.bible.com/bible/1/REV.22.20", Passage("Revelation", 22, 20, 20).bibleUrl)
    }

    @Test fun canonicalOrderAndOverlap() {
        val sorted = listOf("John 3:16", "Genesis 1:1", "John 1", "Psalms 23:1").map { Passage.parse(it)!! }.sorted()
        assertEquals(listOf("Genesis 1:1", "Psalms 23:1", "John 1", "John 3:16"), sorted.map { it.reference })
        assertTrue(Passage.parse("John 3")!!.overlaps(Passage.parse("John 3:16")!!))
        assertTrue(Passage.parse("John 3:14-16")!!.overlaps(Passage.parse("John 3:16-18")!!))
        assertFalse(Passage.parse("John 3:1-2")!!.overlaps(Passage.parse("John 3:16")!!))
    }

    @Test fun theShippedLinksAndIndex() {
        val first = links.links("english", 1)
        assertTrue(first.isNotEmpty())
        assertEquals(first.map { it.passage }.sorted(), first.map { it.passage })
        assertEquals(ScriptureSource.Lyric, first.first().source)
        val index = links.index("english")
        assertTrue(index.isNotEmpty())
        assertEquals(index.map { it.passage }.sorted(), index.map { it.passage })
        val citing = links.hymns(first.first().passage, "english", excluding = 1)
        assertFalse(1 in citing)
    }
}

class StoriesPitchAndPlannerTest {
    private val assets = DirectoryAssets.iosResources()

    @Test fun storiesFallBackFromTheSDAHymnalToTheSameTune() {
        val stories = HymnStories(assets, SdahTunes(assets))
        assertEquals("H. L. Gilmour", stories.story("english", 1)?.words)
        assertEquals(stories.story("english", 1), stories.story("sdah", 368))
        assertNull(stories.story("ndebele", 1))
    }

    @Test fun pitchNamesMidiAndFrequency() {
        assertEquals(60, Pitch.midi("C4"))
        assertEquals(66, Pitch.midi("F#4"))
        assertEquals(66, Pitch.midi("F♯4"))
        assertEquals(58, Pitch.midi("Bb3"))
        assertEquals(58, Pitch.midi("B♭3"))
        assertNull(Pitch.midi("H4"))
        assertEquals("C4", Pitch.name(60))
        assertEquals("B♭3", Pitch.name(58))
        assertEquals(440.0, Pitch.frequency(69), 1e-9)
        assertEquals(261.6256, Pitch.frequency(60), 1e-3)
        assertEquals(listOf(60, 71), Pitch.octave(4).let { listOf(it.first(), it.last()) })
    }

    @Test fun theSingersNoteWinsAndIsKept() {
        val store = MemoryStore()
        val notes = PitchNotes(assets, store)
        assertNull(notes.note("english", 12))
        notes.setCustom(65, "english", 12)
        assertEquals(65, PitchNotes(assets, store).custom("english", 12))
        assertEquals(65, notes.note("english", 12))
        notes.setCustom(null, "english", 12)
        assertNull(notes.custom("english", 12))
        assertEquals(60, StartingNote("C major", "C4").midi)
    }

    @Test fun theToneFadesInAndOut() {
        val tone = PitchTone(44_100.0)
        val buffer = FloatArray(44_100)
        assertTrue(tone.isSilent)
        tone.start(440.0)
        tone.render(buffer)
        assertTrue(buffer.maxOrNull()!! > 0.2f && buffer.maxOrNull()!! <= PitchTone.PEAK.toFloat())
        tone.release()
        tone.render(buffer)
        assertTrue(tone.isSilent)
    }

    @Test fun plansForTheComingSabbath() {
        assertEquals(LocalDate.of(2026, 10, 24), ServicePlanner.nextSabbath(LocalDate.of(2026, 10, 18)))
        assertEquals(LocalDate.of(2026, 10, 24), ServicePlanner.nextSabbath(LocalDate.of(2026, 10, 24)))
        val store = MemoryStore()
        val planner = ServicePlanner(store, today = { LocalDate.of(2026, 10, 18) }, nameForDate = { it.toString() })
        val plan = planner.newPlan("english", listOf(1, 12))
        assertEquals("2026-10-24", plan.name)
        assertEquals(listOf(1, 12), plan.numbers)
        planner.add(100, plan.id)
        assertEquals(listOf(1, 12, 100), planner.plan(plan.id)?.numbers)
        // Saved and read back.
        assertEquals(planner.plans, ServicePlanner(store).plans)
        planner.delete(planner.plan(plan.id)!!)
        assertTrue(planner.plans.isEmpty())
    }

    @Test fun plansSortNewestFirstAndEditsAreNamed() {
        val planner = ServicePlanner(MemoryStore(), today = { LocalDate.of(2026, 10, 18) }, nameForDate = { "Plan" })
        val a = planner.newPlan("english")
        planner.update(a.copy(name = "A", date = LocalDate.of(2026, 1, 1)))
        val b = planner.newPlan("english")
        planner.update(b.copy(name = "B"))
        planner.newPlan("shona")
        assertEquals(listOf("B", "A"), planner.plans("english").map { it.name })
        val item = ServicePlan.Item(number = 1)
        val base = ServicePlan(name = "P", hymnal = "english", items = listOf(item, ServicePlan.Item(number = 2)))
        assertEquals(ServicePlanEdit.HymnAdded, ServicePlanner.edit(base, base.copy(items = base.items + ServicePlan.Item(number = 3))))
        assertEquals(ServicePlanEdit.HymnRemoved, ServicePlanner.edit(base, base.copy(items = base.items.take(1))))
        assertEquals(ServicePlanEdit.Reordered, ServicePlanner.edit(base, base.copy(items = base.items.reversed())))
        assertEquals(ServicePlanEdit.RoleSet, ServicePlanner.edit(base, base.copy(items = listOf(item.copy(role = "Opening hymn"), base.items[1]))))
        assertNull(ServicePlanner.edit(base, base.copy(name = "Renamed")))
        assertNotNull(ServicePlanner.ROLES.firstOrNull { it == "Closing hymn" })
    }
}
