package com.mDev.AdventPraise.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

/** Hymn of the Day: one pure rule, a full cycle with no repeats, and the same pick as iOS. */
class HymnOfTheDayTest {
    @Test fun everyHymnOncePerCycle() {
        for (count in listOf(1, 2, 3, 7, 12, 100, 695, 1000)) {
            for (cycle in listOf(-1, 0, 1, 2, 57)) {
                val picks = (0 until count).map { HymnOfTheDayPicker.index(cycle * count + it, count) }
                assertEquals("cycle $cycle of $count repeats", count, picks.toSet().size)
                assertTrue(picks.all { it in 0 until count })
            }
        }
    }

    @Test fun deterministicPerLocalDay() {
        assertEquals(1017, HymnOfTheDayPicker.dayIndex(LocalDate.of(2026, 10, 14)))
        assertEquals(0, HymnOfTheDayPicker.dayIndex(LocalDate.of(2024, 1, 1)))
        assertEquals(-1, HymnOfTheDayPicker.dayIndex(LocalDate.of(2023, 12, 31)))
    }

    @Test fun neighbouringDaysAreScattered() {
        val picks = (0 until 30).map { HymnOfTheDayPicker.index(1000 + it, 695) }
        assertTrue(picks.zipWithNext().none { (a, b) -> kotlin.math.abs(a - b) == 1 })
    }

    /** Computed by iOS's HymnOfTheDayPicker (Swift) for these day indices and hymnal sizes. */
    @Test fun picksTheSameHymnAsIOS() {
        val ios = "300:-800:162,300:-1:28,300:0:255,300:1:194,300:299:16,300:300:158,300:1017:284,300:1018:141,300:2000:101," +
            "300:5000:141,350:-800:12,350:-1:330,350:0:205,350:1:342,350:299:218,350:300:5,350:1017:273,350:1018:334," +
            "350:2000:69,350:5000:230,352:-800:342,352:-1:118,352:0:15,352:1:126,352:299:116,352:300:227,352:1017:331," +
            "352:1018:250,352:2000:165,352:5000:28,306:-800:180,306:-1:86,306:0:117,306:1:214,306:299:50,306:300:147," +
            "306:1017:158,306:1018:79,306:2000:145,306:5000:185,695:-800:28,695:-1:41,695:0:270,695:1:256,695:299:254," +
            "695:300:240,695:1017:345,695:1018:146,695:2000:136,695:5000:226"
        for (entry in ios.split(',')) {
            val (n, day, pick) = entry.split(':').map(String::toInt)
            assertEquals("day $day of $n", pick, HymnOfTheDayPicker.index(day, n))
        }
    }

    @Test fun theFeedAndItsLinkNameTheSameHymn() {
        val assets = DirectoryAssets.iosResources()
        val english = Hymnal.load(assets, HymnalInfo.fallback)
        assertNotNull(english)
        val start = LocalDate.of(2026, 10, 18)
        val feed = HymnOfTheDayFeed.days(english!!, start, 30)
        assertEquals(30, feed.size)
        feed.forEachIndexed { offset, day ->
            assertEquals(HymnOfTheDayFeed.hymn(start.plusDays(offset.toLong()), english)?.number, day.number)
            assertEquals(english.hymn(day.number)?.title, day.title)
            assertEquals("adventpraise://hymn/${day.number}?hymnal=english", day.url)
            assertTrue(day.lines.isNotEmpty())
        }
        assertEquals(feed, HymnOfTheDay.decodeAll(HymnOfTheDay.encodeAll(feed)))
        assertTrue(HymnOfTheDayFeed.isToday(english.hymn(feed[0].number)!!, english, start))
    }
}
