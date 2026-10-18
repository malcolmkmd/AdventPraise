package com.mDev.AdventPraise.ui.design

import com.mDev.AdventPraise.settings.LyricScale
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.ReadingStyle
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** Lyric sizing as DSReadingStyle does it: steps, scales, pinching and the font-scale cap. */
class ReadingStyleTest {
    @Test fun stepsAndScales() {
        assertEquals(19f, ReadingStyle().basePointSize)
        assertEquals(32f, ReadingStyle().withScale(LyricScale.LargePrint).basePointSize)
        assertEquals(48f, ReadingStyle.Worship.basePointSize)
    }

    @Test fun pinchingKeepsTheSizeAndShowsTheNearestStep() {
        val pinched = ReadingStyle().pinched(22.4f)
        assertEquals(22.4f, pinched.basePointSize)
        assertEquals(3, pinched.step)
        assertEquals(32f, ReadingStyle().pinched(90f).basePointSize)
        assertNull(pinched.withStep(1).pinchedPointSize)
    }

    @Test fun theFontScaleIsCappedPerScale() {
        assertEquals(19f * 2f, ReadingStyle().lyricPoints(2f))
        assertEquals(32f * 1.5f, ReadingStyle().withScale(LyricScale.LargePrint).lyricPoints(3f))
    }

    @Test fun theVerseBadgeGrowsWithTheText() {
        assertEquals(26f, ReadingStyle().withStep(0).verseBadge(1f).value)
        assertEquals(19f * 1.35f * 2f, ReadingStyle().verseBadge(2f).value, 0.001f)
    }
}
