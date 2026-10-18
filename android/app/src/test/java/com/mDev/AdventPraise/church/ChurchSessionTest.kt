package com.mDev.AdventPraise.church

import com.mDev.AdventPraise.analytics.ChurchModeSource
import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.data.Block
import com.mDev.AdventPraise.data.Hymn
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Church mode's moves, the remote's buttons and what every screen shows (ChurchModeView, ChurchLiveActivity, ChurchWidgetSync). */
class ChurchSessionTest {
    /** Two verses and a chorus: sung as v1, c, v2, c. */
    private fun hymn(n: Int) = Hymn(n, "Hymn $n", emptyList(),
        listOf(Block.Verse(1, listOf("one")), Block.Chorus(listOf("refrain")), Block.Verse(2, listOf("two"))), null)

    private class Reader(var number: Int, val last: Int) : ChurchHost {
        var paywall: ProFeature? = null
        var session: ChurchSession? = null
        override fun goToNextHymn(): Boolean {
            if (number >= last) return false
            number += 1
            session?.follow(Hymn(number, "Hymn $number", emptyList(),
                listOf(Block.Verse(1, listOf("one")), Block.Chorus(listOf("refrain")), Block.Verse(2, listOf("two"))), null),
                "english", "Christ In Song", "Chorus", number < last)
            return true
        }
        override fun showPaywall(feature: ProFeature) { paywall = feature }
    }

    private fun session(number: Int = 1, last: Int = 2, isPro: Boolean = true): Pair<ChurchSession, Reader> {
        val reader = Reader(number, last)
        val session = ChurchSession(reader, clock = { 0L })
        reader.session = session
        session.follow(hymn(number), "english", "Christ In Song", "Chorus", number < last)
        session.setPro(isPro)
        return session to reader
    }

    @Test fun thePresenterWalksTheSungSequenceThenTheNextHymn() {
        val (s, _) = session()
        s.start(ChurchModeSource.Tray)
        assertEquals("Verse 1 of 2", s.current.position)
        assertEquals(ChurchMove.Limit, s.previous())
        assertEquals(ChurchMove.Moved, s.advance())
        assertEquals("Chorus", s.current.position)
        s.advance()
        assertEquals("Verse 2 of 2", s.current.position)
        s.advance()
        assertTrue(s.current.isLast)
        assertEquals(ChurchMove.NextHymn, s.advance())
        assertEquals(2, s.current.hymn?.number)
        assertEquals(0, s.current.index)
        repeat(3) { s.advance() }
        assertEquals("past the last verse of the last hymn", ChurchMove.End, s.advance())
    }

    @Test fun blankHidesTheWordsUntilAVerseTurns() {
        val (s, _) = session()
        s.start(ChurchModeSource.Tray)
        assertTrue(s.toggleBlank())
        assertEquals("TV blank", s.current.tvStatus)
        assertEquals("Screen blank", s.current.remotePosition)
        s.advance()
        assertFalse(s.current.isBlanked)
        s.toggleBlank()
        s.previous()
        assertFalse(s.current.isBlanked)
    }

    @Test fun announcementsAndImagesComeBeforeTheWords() {
        val (s, _) = session()
        s.start(ChurchModeSource.Tray)
        s.showAnnouncement("Potluck after the service")
        assertTrue(s.current.isShowingSpecial)
        assertEquals("Announcement on TV", s.current.tvStatus)
        s.showImage("content://image/1")
        assertEquals("Image", s.current.remotePosition)
        s.clearSpecial()
        assertNull(s.current.tvStatus)
        s.showAnnouncement("   ")
        assertNull(s.current.announcement)
    }

    @Test fun aTranslationKeepsTheVerseAndANewHymnStartsAtTheTop() {
        val (s, _) = session(number = 5, last = 10)
        s.start(ChurchModeSource.Tray)
        s.advance(); s.advance()
        s.follow(hymn(5), "shona", "Kristu MuNzwiyo", "Chorus", true)
        assertEquals(2, s.current.index)
        s.toggleBlank()
        s.follow(hymn(6), "shona", "Kristu MuNzwiyo", "Chorus", true)
        assertEquals(0, s.current.index)
        assertFalse(s.current.isBlanked)
        // A shorter hymn in another hymnal clamps to its last block.
        s.advance(); s.advance(); s.advance()
        s.follow(Hymn(6, "Short", emptyList(), listOf(Block.Verse(1, listOf("x"))), null), "english", "Christ In Song", "Chorus", true)
        assertEquals(0, s.current.index)
    }

    @Test fun theRemoteNeedsProAndAnOpenChurchMode() {
        val (free, reader) = session(isPro = false)
        free.perform(ChurchRemoteAction.Next)
        assertEquals(ProFeature.AirPlay, reader.paywall)

        val (s, r) = session(number = 1, last = 3)
        s.perform(ChurchRemoteAction.Next)
        assertEquals("verse buttons only act while presenting", 0, s.current.index)
        s.perform(ChurchRemoteAction.NextHymn)
        assertEquals("Next hymn works any time", 2, r.number)
        s.start(ChurchModeSource.Tray)
        s.perform(ChurchRemoteAction.Next)
        assertEquals(1, s.current.index)
        s.perform(ChurchRemoteAction.Blank)
        assertTrue(s.current.isBlanked)
        s.perform(ChurchRemoteAction.Previous)
        assertEquals(0, s.current.index)
        assertFalse(s.current.isBlanked)
        repeat(4) { s.perform(ChurchRemoteAction.Next) }
        assertEquals("past the last verse: the next hymn", 3, r.number)
        assertEquals(0, s.current.index)
        s.perform(ChurchRemoteAction.End)
        assertTrue(s.current.endRequested)
        s.acknowledgeEnd()
        s.stop()
        assertFalse(s.current.isActive)
    }

    @Test fun theWidgetAndNotificationShowWhatIsPresented() {
        val (s, _) = session()
        assertEquals("", s.current.widgetState.position)
        assertFalse(s.current.widgetState.isPresenting)
        assertNull(s.current.activityState)
        s.start(ChurchModeSource.Tray)
        s.setExternalScreen(true)
        s.advance()
        val widget = s.current.widgetState
        assertEquals("Chorus", widget.position)
        assertTrue(widget.isPresenting && widget.isOnTV && widget.canGoBack && widget.hasNextHymn && widget.isPro)
        assertEquals("Christ In Song", widget.hymnal)
        assertEquals(widget, ChurchWidgetState.fromJson(widget.toJson()))
        val activity = s.current.activityState!!
        assertEquals(2, activity.step)
        assertEquals(4, activity.stepCount)
        assertTrue(activity.isOnTV && activity.canGoBack)
        assertTrue(s.current.isOnExternalScreen)
        s.setPro(false)
        assertFalse("without Pro a TV mirrors the phone", s.current.isOnExternalScreen)
    }

    @Test fun deepLinks() {
        assertEquals(AppLink.OpenHymn(123, "sdah"), AppLink.parse("adventpraise://hymn/123?hymnal=sdah"))
        assertEquals(AppLink.OpenHymn(7, null), AppLink.parse("adventpraise://hymn/7"))
        assertEquals(AppLink.Widget(WidgetLink.HymnOfTheDay), AppLink.parse(WidgetLink.HymnOfTheDay.url))
        assertEquals("adventpraise://number-pad", WidgetLink.NumberPad.url)
        assertNull(AppLink.parse("https://example.com"))
        assertEquals(ChurchRemoteAction.NextHymn, ChurchRemoteAction.of("nextHymn"))
    }
}
