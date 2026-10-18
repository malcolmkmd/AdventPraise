package com.mDev.AdventPraise.cast

import com.mDev.AdventPraise.audio.AccompanimentPlayer
import com.mDev.AdventPraise.audio.AccompanimentState
import com.mDev.AdventPraise.audio.AccompanimentTransport
import com.mDev.AdventPraise.audio.PlaybackState
import com.mDev.AdventPraise.church.ChurchHost
import com.mDev.AdventPraise.church.ChurchSession
import com.mDev.AdventPraise.analytics.ChurchModeSource
import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.data.Block
import com.mDev.AdventPraise.data.Hymn
import com.mDev.AdventPraise.data.HymnalInfo
import com.mDev.AdventPraise.settings.PlaybackTempo
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The TV as the clock: what the phone sends, how it follows the TV's
 * status (seq order, extrapolation, stale statuses after a command), and the
 * swap in and out keeping the place.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class CastTransportTest {
    private val english = HymnalInfo("english", "Christ In Song", "English", 300, 300)
    /** Two verses and a chorus, one pass a minute. */
    private val hymn = Hymn(1, "Watchman Blow The Gospel Trumpet", emptyList(),
        listOf(Block.Verse(1, listOf("a", "b")), Block.Chorus(listOf("c")), Block.Verse(2, listOf("d", "e"))), "hymn-001.mid")
    private val other = Hymn(2, "Another", emptyList(), listOf(Block.Verse(1, listOf("x"))), "hymn-002.mid")
    private val passMs = 60_000L

    private class Channel : CastChannel {
        val sent = mutableListOf<SenderMessage>()
        override fun send(message: SenderMessage): Boolean { sent += message; return true }
        inline fun <reified T : SenderMessage> of(): List<T> = sent.filterIsInstance<T>()
        fun audio() = sent.filter { it !is SenderMessage.Ping && it !is SenderMessage.GetStatus }
    }

    private fun TestScope.transport() = CastTransport(
        scope = backgroundScope,
        now = { testScheduler.currentTime },
        passLengthMs = { passMs },
        wordsFor = { h, info -> CastWords(h, info.id, info.name, "Chorus") },
    )

    private var seq = 0L
    private fun status(state: String, position: Long, key: String? = "english-1", rate: Float = 1f) =
        ReceiverMessage.toJson(ReceiverMessage.Status(state, position, passMs * 2, passMs, 1, 2, rate, 0, key, 0, false,
            if (key == "english-1") "hymn-001.mid" else null, ++seq))

    @Test fun playWaitsForTheTvThenFollowsItsClockAt30Hz() = runTest {
        val cast = transport()
        val channel = Channel()
        cast.attach(channel)
        assertTrue(cast.load(hymn, english))
        runCurrent()
        val load = channel.of<SenderMessage.Load>().single()
        assertEquals("hymn-001.mid", load.midi); assertEquals(2, load.passes); assertEquals(-1, load.pageIndex)
        assertEquals(AccompanimentState.key("english", 1), cast.state.value.hymnKey)
        assertEquals(120_000, cast.state.value.durationMs)

        cast.receive(status("paused", 0))
        cast.play()
        assertEquals(PlaybackState.Loading, cast.state.value.state)
        assertEquals(SenderMessage.Play(0), channel.sent.last())
        // A status sent before the TV saw play doesn't undo it.
        cast.receive(status("paused", 0))
        assertEquals(PlaybackState.Loading, cast.state.value.state)

        cast.receive(status("playing", 1_000))
        assertEquals(PlaybackState.Playing, cast.state.value.state)
        val updates = mutableListOf<Long>()
        val watching = backgroundScope.launch { cast.state.collect { updates += it.positionMs } }
        advanceTimeBy(1_000); runCurrent()
        watching.cancel()
        assertEquals(2_000, cast.state.value.positionMs, 40.0)
        // About 30 updates a second.
        assertTrue("${updates.size} updates", updates.size in 25..35)
        assertEquals(1, cast.state.value.pass)
    }

    @Test fun olderStatusesAreDroppedAndAnotherHymnsAreIgnored() = runTest {
        val cast = transport()
        cast.attach(Channel())
        cast.load(hymn, english); runCurrent()
        cast.receive(status("paused", 30_000))
        val newest = seq
        assertEquals(30_000, cast.state.value.positionMs)
        // An older one arriving late.
        cast.receive(ReceiverMessage.toJson(ReceiverMessage.Status("paused", 5_000, 120_000, passMs, 1, 2, 1f, 0,
            "english-1", 0, false, "hymn-001.mid", newest - 1)))
        assertEquals(30_000, cast.state.value.positionMs)
        // The TV on another hymn says nothing about this one.
        cast.receive(status("playing", 90_000, key = "english-2"))
        assertEquals(30_000, cast.state.value.positionMs)
        assertEquals(PlaybackState.Paused, cast.state.value.state)
    }

    @Test fun pauseAndSeekAnswerAtOnceAndStaleStatusesWait() = runTest {
        val cast = transport()
        val channel = Channel()
        cast.attach(channel)
        cast.load(hymn, english); runCurrent()
        cast.receive(status("playing", 10_000))
        advanceTimeBy(500)
        cast.pause()
        assertEquals(PlaybackState.Paused, cast.state.value.state)
        assertEquals(10_500, cast.state.value.positionMs)
        assertEquals(SenderMessage.Pause, channel.sent.last())
        cast.receive(status("playing", 10_400))   // sent before the pause landed
        assertEquals(PlaybackState.Paused, cast.state.value.state)
        cast.receive(status("paused", 10_520))
        assertEquals(10_520, cast.state.value.positionMs)

        cast.seek(70_000)
        assertEquals(SenderMessage.Seek(70_000), channel.sent.last())
        assertEquals(70_000, cast.state.value.positionMs)
        assertEquals(2, cast.state.value.pass)
        cast.receive(status("paused", 10_520))    // stale
        assertEquals(70_000, cast.state.value.positionMs)
        cast.receive(status("paused", 70_000))
        assertEquals(70_000, cast.state.value.positionMs)
        // After the grace, the TV is the truth even when it disagrees.
        advanceTimeBy(CastTransport.COMMAND_GRACE_MS + 1)
        cast.seek(5_000)
        advanceTimeBy(CastTransport.COMMAND_GRACE_MS + 1)
        cast.receive(status("paused", 6_000))
        assertEquals(6_000, cast.state.value.positionMs)
    }

    @Test fun theLastVerseEndingIsEndedAtTheTop() = runTest {
        val cast = transport()
        cast.attach(Channel())
        cast.load(hymn, english); runCurrent()
        cast.receive(status("playing", 119_000))
        cast.receive(status("ended", 0))
        assertEquals(PlaybackState.Ended, cast.state.value.state)
        assertEquals(0, cast.state.value.positionMs)
    }

    @Test fun tempoGoesToTheTvAndScalesTheClock() = runTest {
        val cast = transport()
        val channel = Channel()
        cast.attach(channel)
        cast.load(hymn, english); runCurrent()
        cast.setTempo(1.2f)
        assertEquals(SenderMessage.Tempo(1.2f), channel.sent.last())
        cast.receive(status("playing", 0, rate = 1.2f))
        advanceTimeBy(1_000)
        assertEquals(1_200, cast.positionNow())
        assertEquals(1.2f, cast.state.value.rate)
    }

    @Test fun aReceiverErrorLetsAWaitingPlayGo() = runTest {
        val cast = transport()
        cast.attach(Channel())
        cast.load(hymn, english); runCurrent()
        cast.play()
        cast.receive(ReceiverMessage.toJson(ReceiverMessage.Error("midi_not_found", "midi/hymn-001.mid: 404", "load")))
        assertEquals(PlaybackState.Idle, cast.state.value.state)
        cast.receive(ReceiverMessage.toJson(ReceiverMessage.Error("soundfont_failed", "", null)))
        assertFalse(cast.state.value.isAvailable)
    }

    @Test fun aPlayTheTvNeverAnswersGivesUp() = runTest {
        val cast = transport()
        cast.attach(Channel())
        cast.load(hymn, english); runCurrent()
        cast.seek(30_000)
        cast.play()
        advanceTimeBy(CastTransport.LOADING_TIMEOUT_MS + 1); runCurrent()
        assertEquals(PlaybackState.Paused, cast.state.value.state)
        assertEquals(30_000, cast.state.value.positionMs)
    }

    // MARK: Church mode on the TV

    private fun church(): ChurchSession {
        val session = ChurchSession(object : ChurchHost {
            override fun goToNextHymn() = false
            override fun showPaywall(feature: ProFeature) = Unit
        }, clock = { 0 })
        session.follow(hymn, "english", "Christ In Song", "Chorus", false)
        session.setPro(true)
        return session
    }

    @Test fun theMirrorSendsOnlyWhatChanged() = runTest {
        val cast = transport()
        val channel = Channel()
        val pictures = CastPictures(send = { cast.sendScreen(it) }, load = { ByteArray(10) }, launch = { block -> backgroundScope.launch { block() } })
        val mirror = CastChurchMirror(cast, pictures)
        cast.screen = { mirror.current!!.screen }
        cast.attach(channel)
        val session = church()
        val scene = { CastScene.of(session.current, 42f, false) }

        mirror.apply(scene()); runCurrent()
        assertEquals(-1, channel.of<SenderMessage.Load>().single().pageIndex)   // closed: the title card

        session.start(ChurchModeSource.Tray)
        mirror.apply(scene()); runCurrent()
        assertEquals(listOf(SenderMessage.Page(0)), channel.audio().drop(1))
        channel.sent.clear()

        session.next(); mirror.apply(scene())
        session.toggleBlank(); mirror.apply(scene())
        assertEquals(listOf(SenderMessage.Page(1), SenderMessage.Blank(true)), channel.sent)
        channel.sent.clear()

        session.showAnnouncement("Fellowship lunch after the service"); mirror.apply(scene())
        assertEquals(listOf(SenderMessage.Special("Fellowship lunch after the service", null)), channel.sent)
        channel.sent.clear()

        session.clearSpecial(); session.showImage("PICTURE-1"); mirror.apply(scene()); runCurrent()
        val id = CastPictures.imageId("PICTURE-1")
        assertEquals(listOf(SenderMessage.ImageChunk(id, 0, 1, "image/jpeg", "AAAAAAAAAAAAAA=="), SenderMessage.Special(null, id)), channel.sent)
        channel.sent.clear()

        // Another hymn: one load, on its first verse, the words back.
        session.follow(other, "english", "Christ In Song", "Chorus", false); session.clearSpecial(); mirror.apply(scene()); runCurrent()
        val load = channel.of<SenderMessage.Load>().single()
        assertEquals(2, load.number); assertEquals(0, load.pageIndex); assertFalse(load.blank)
        assertTrue(SenderMessage.Special(null, null) in channel.sent)
    }

    // MARK: Swapping in and out

    private class Local(private val passMs: Long) : AccompanimentTransport {
        val flow = MutableStateFlow(AccompanimentState())
        override val state: StateFlow<AccompanimentState> = flow
        val calls = mutableListOf<String>()
        override fun load(hymn: Hymn, hymnal: HymnalInfo): Boolean {
            calls += "load"
            val key = AccompanimentState.key(hymnal.id, hymn.number)
            if (flow.value.hymnKey != key) flow.value = AccompanimentState(key, PlaybackState.Idle, 0, passMs * 2, 1, 2)
            return true
        }
        override fun play(fromMs: Long?) { calls += "play"; flow.value = flow.value.copy(state = PlaybackState.Playing) }
        override fun pause() { calls += "pause"; flow.value = flow.value.copy(state = PlaybackState.Paused) }
        override fun stop() { calls += "stop"; flow.value = flow.value.copy(state = PlaybackState.Idle, positionMs = 0) }
        override fun seek(ms: Long) { calls += "seek $ms"; flow.value = flow.value.copy(positionMs = ms) }
        override fun setTempo(rate: Float) { flow.value = flow.value.copy(rate = rate) }
        override fun unload() { flow.value = AccompanimentState() }
    }

    @Test fun castingStartsWhereThePhoneWasAndEndsPausedThere() = runTest {
        val local = Local(passMs)
        val player = AccompanimentPlayer(local, backgroundScope, object : AccompanimentPlayer.TempoStore {
            override val tempo = PlaybackTempo.Medium
            override fun updateTempo(value: PlaybackTempo) = Unit
        })
        val cast = transport()
        val session = church()
        session.start(ChurchModeSource.Tray)
        val mirror = CastChurchMirror(cast, CastPictures({ cast.sendScreen(it) }, { null }, { }))
        cast.screen = { mirror.current?.screen ?: CastScreen.TitleCard }
        val engagement = CastEngagement(player, local, cast, mirror) { CastScene.of(session.current, 42f, false) }
        engagement.proChanged(true)

        // The phone plays verse 2, 5 s in.
        assertTrue(player.start(hymn, english))
        local.seek(65_000)
        runCurrent()
        assertTrue(player.isPlaying)

        val channel = Channel()
        engagement.connected(channel)
        runCurrent()
        assertTrue(engagement.isEngaged)
        assertTrue(player.transport === cast)
        assertEquals(PlaybackState.Idle, local.state.value.state)   // the phone is silent
        // One load: the words on church mode's verse, the audio from the phone's place, playing.
        val load = channel.of<SenderMessage.Load>().single()
        assertEquals(65_000, load.startMs)
        assertTrue(load.autoplay)
        assertEquals(0, load.pageIndex)
        assertEquals(1f, load.tempo)
        assertEquals(PlaybackState.Loading, cast.state.value.state)
        assertEquals(65_000, cast.state.value.positionMs)

        cast.receive(status("loading", 0))
        cast.receive(status("playing", 65_000))
        advanceTimeBy(10_000); runCurrent()
        assertTrue(player.isPlaying)
        assertEquals(75.0, player.elapsed, 0.05)
        assertEquals(2, player.position?.pass)

        // The session ends: the phone takes over, paused at the TV's place, silent.
        local.calls.clear()
        engagement.disconnected()
        runCurrent()
        assertFalse(engagement.isEngaged)
        assertTrue(player.transport === local)
        assertFalse(player.isPlaying)
        assertEquals(75_000, local.state.value.positionMs, 50.0)
        assertFalse("play" in local.calls)
        assertNull(local.calls.firstOrNull { it == "play" })
    }

    @Test fun withoutProTheTvTakesNothingOver() = runTest {
        val local = Local(passMs)
        val player = AccompanimentPlayer(local, backgroundScope, object : AccompanimentPlayer.TempoStore {
            override val tempo = PlaybackTempo.Medium
            override fun updateTempo(value: PlaybackTempo) = Unit
        })
        val cast = transport()
        val session = church()
        val mirror = CastChurchMirror(cast, CastPictures({ cast.sendScreen(it) }, { null }, { }))
        val engagement = CastEngagement(player, local, cast, mirror) { CastScene.of(session.current, 42f, false) }
        val channel = Channel()
        engagement.connected(channel)
        runCurrent()
        assertFalse(engagement.isEngaged)
        assertTrue(player.transport === local)
        assertTrue(channel.sent.isEmpty())
        // Buying Pro with the TV connected puts it up at once; losing it takes it down.
        engagement.proChanged(true); runCurrent()
        assertTrue(engagement.isEngaged)
        engagement.proChanged(false); runCurrent()
        assertTrue(player.transport === local)
        assertEquals(SenderMessage.Blank(true), channel.sent.last())
    }

    private fun assertEquals(expected: Long, actual: Long, delta: Double) =
        org.junit.Assert.assertEquals(expected.toDouble(), actual.toDouble(), delta)
}
