package com.mDev.AdventPraise.ui.root

import androidx.test.core.app.ApplicationProvider
import android.app.Application
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.reader.LegalDocument
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
        assertEquals(2, navigator.stack.size)
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

    @Test fun firstMilestoneScreensGoToTheirOwnLayers() {
        navigator.openMore()
        assertEquals(Screen.More, reader.screen)
        navigator.openHymnList()
        assertEquals(Screen.More, reader.screen)
        assertEquals(listOf(Destination.HymnList), navigator.stack)
        navigator.back()
        navigator.openPaywall(ProFeature.Player, "church_mode")
        assertEquals(ProFeature.Player, reader.paywall)
        assertEquals("church_mode", reader.paywallContext)
        navigator.openTerms()
        assertEquals(LegalDocument.Terms, reader.document)
        assertTrue(navigator.stack.isEmpty())
        navigator.openMore()
        navigator.leaveMore()
        assertEquals(Screen.Reader, reader.screen)
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
