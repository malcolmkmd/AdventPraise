package com.mDev.AdventPraise.ui.design

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/** The rate limits that keep a fast slider or a held key from buzzing. */
class HapticsTest {
    @Before fun reset() = Haptics.resetForTests()

    @Test fun anEventCannotRepeatInsideItsInterval() {
        assertTrue(Haptics.admit(HapticEvent.PageTurn, 1_000))
        assertFalse(Haptics.admit(HapticEvent.PageTurn, 1_200))
        assertTrue(Haptics.admit(HapticEvent.PageTurn, 1_250))
    }

    @Test fun anythingWithin25msOfTheLastHapticIsDropped() {
        assertTrue(Haptics.admit(HapticEvent.KeyPress, 1_000))
        assertFalse(Haptics.admit(HapticEvent.Selection, 1_010))
        assertTrue(Haptics.admit(HapticEvent.Selection, 1_030))
    }

    @Test fun outcomesAreNeverSwallowedByATapJustBefore() {
        assertTrue(Haptics.admit(HapticEvent.KeyPress, 1_000))
        assertTrue(Haptics.admit(HapticEvent.Success, 1_005))
    }
}
