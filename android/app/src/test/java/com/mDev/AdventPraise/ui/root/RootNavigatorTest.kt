package com.mDev.AdventPraise.ui.root

import androidx.test.core.app.ApplicationProvider
import android.app.Application
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.reader.ReaderModel
import com.mDev.AdventPraise.reader.Screen
import kotlinx.coroutines.test.TestScope
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/** The presentation stack: what opens over what, and what Back and the closers remove. */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [35], application = Application::class)
class RootNavigatorTest {
    private lateinit var reader: ReaderModel
    private lateinit var navigator: RootNavigator

    @Before fun setUp() {
        reader = ReaderModel(ApplicationProvider.getApplicationContext(), TestScope())
        navigator = RootNavigator(reader)
    }

    @Test fun backPopsOneAtATimeThenReportsNothingOpen() {
        navigator.openSheetMusic()
        assertEquals(listOf(Destination.SheetMusic()), navigator.stack)
        assertTrue(navigator.back())
        assertFalse(navigator.back())
    }

    @Test fun aDrawerPageBringsItsDrawer() {
        navigator.openHymnStory()
        assertEquals(listOf(Destination.AboutHymn(), Destination.HymnStory), navigator.stack)
        navigator.dismiss(Destination.AboutHymn())
        assertTrue(navigator.stack.isEmpty())
    }

    @Test fun morePagesStackAndLeaveMoreClearsThem() {
        navigator.openCollections()
        navigator.openCollection("worship", "Worship")
        assertEquals(listOf(Destination.More, Destination.Collections, Destination.Collection("worship", "Worship")), navigator.stack)
        var ran = false
        navigator.leaveMore { ran = true }
        assertTrue(navigator.stack.isEmpty())
        assertTrue(ran)
    }

    @Test fun moreInTheStackHostsItsPages() {
        navigator.moreIsLegacy = false
        navigator.openPitchPipe()
        assertEquals(listOf(Destination.More, Destination.PitchPipe()), navigator.stack)
    }

    @Test fun churchModeClosesTheSheetsUnderIt() {
        navigator.openMemorise()
        navigator.openScriptureIndex()
        navigator.openChurchMode("tray")
        assertEquals(listOf(Destination.ChurchMode("tray")), navigator.stack)
        navigator.navigate(Destination.ChurchAnnouncement)
        navigator.openChurchMode("keyboard")
        assertEquals(listOf(Destination.ChurchMode("tray")), navigator.stack)
    }

    @Test fun theSameDestinationTwiceIsShownOnce() {
        navigator.openMemorise()
        navigator.openMemorise()
        assertEquals(1, navigator.stack.size)
    }

    @Test fun theHymnListStillGoesToItsOwnLayer() {
        navigator.openHymnList()
        assertEquals(Screen.Hymns, reader.screen)
        assertTrue(navigator.stack.isEmpty())
    }

    @Test fun moreThePaywallAndTheLegalPagesAreStacked() {
        navigator.openMore()
        assertEquals(Screen.Reader, reader.screen)
        assertEquals(listOf(Destination.More), navigator.stack)
        navigator.openTerms()
        assertEquals(listOf(Destination.More, Destination.Terms), navigator.stack)
        assertNull(reader.document)
        navigator.leaveMore { navigator.openPaywall(ProFeature.Player, "church_mode") }
        assertEquals(listOf(Destination.Paywall("player", "church_mode")), navigator.stack)
        assertNull(reader.paywall)
        // From the reader, the policy brings More's sheet with it.
        navigator.dismissAll()
        navigator.openPrivacy()
        assertEquals(listOf(Destination.More, Destination.Privacy), navigator.stack)
    }

    @Test fun theStackSurvivesSaving() {
        navigator.openCollection("gospel", "Gospel")
        navigator.openPlaylist("A1")
        val saved = navigator.save()
        val restored = RootNavigator(reader).apply { restore(saved) }
        assertEquals(navigator.stack.toList(), restored.stack.toList())
        RootNavigator(reader).apply { restore("not json") }.also { assertNull(it.top) }
    }

    @Test fun everyDestinationSerializes() {
        val all = Destination.all
        val nav = RootNavigator(reader).apply { all.filter { it != Destination.Reader }.forEach { navigate(it) } }
        val back = RootNavigator(reader).apply { restore(nav.save()) }
        assertEquals(nav.stack.toList(), back.stack.toList())
    }
}
