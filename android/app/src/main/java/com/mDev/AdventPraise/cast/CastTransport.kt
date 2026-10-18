// OWNER: cast
package com.mDev.AdventPraise.cast

import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.ErrorDomain
import com.mDev.AdventPraise.audio.AccompanimentState
import com.mDev.AdventPraise.audio.AccompanimentTransport
import com.mDev.AdventPraise.audio.PlaybackState
import com.mDev.AdventPraise.audio.accompanimentPasses
import com.mDev.AdventPraise.data.Hymn
import com.mDev.AdventPraise.data.HymnalInfo
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.math.abs
import kotlin.math.roundToLong

/** The open Cast session's message channel (our namespace). */
fun interface CastChannel {
    /** Sends one message; false when nothing is connected. */
    fun send(message: SenderMessage): Boolean
}

/**
 * The accompaniment on a Cast TV: the TV plays the hymn's MIDI on the
 * shared piano and is the clock; the phone stays silent and follows the
 * position the TV reports (PROTOCOL.md), extrapolated on the phone's clock
 * and published about 30 times a second while playing.
 *
 * The TV shows one hymn at a time, words and audio together, so this is also
 * the only thing that sends `load`: the church mirror asks for words with
 * [showHymn], the player for audio with [load]. Requests made in one turn of
 * the main loop go out as one `load` (so the player's load, seek and play when
 * casting starts arrive as a single load with `startMs` and `autoplay`).
 *
 * Commands answer at once on the phone (pause holds the place, seek jumps);
 * a status the TV sent before it saw the command is ignored for a moment
 * rather than snapping the phone back. Play waits in Loading for the TV.
 */
class CastTransport(
    private val scope: CoroutineScope,
    /** The phone's monotonic clock, ms. */
    private val now: () -> Long,
    /** One pass of a MIDI asset in ms, measured on the phone (as the TV measures it); null when unreadable. */
    private val passLengthMs: (String) -> Long?,
    /** The words for the player's hymn: its hymnal's name and chorus label. */
    private val wordsFor: (Hymn, HymnalInfo) -> CastWords,
) : AccompanimentTransport {
    private val mutable = MutableStateFlow(AccompanimentState())
    override val state: StateFlow<AccompanimentState> = mutable.asStateFlow()

    /** What the TV should show of the words right now (the church mirror's page, Blank and theme). */
    var screen: () -> CastScreen = { CastScreen.TitleCard }

    private var channel: CastChannel? = null
    val isAttached: Boolean get() = channel != null
    val clock = CastStatusClock()

    // The player's hymn.
    private var words: CastWords? = null
    private var key: String? = null
    private var passes = 0
    private var localPassMs = 0L
    private var tvPassMs = 0L
    private var available = true

    // The phone's view of the TV's transport.
    private var phase = PlaybackState.Idle
    private var anchorMs = 0L
    private var anchorAt = 0L
    private var rate = 1f
    private var tvRate = 1f
    private var expectation: Expectation? = null
    private var commandAt = 0L
    private var lastStatusAt = Long.MIN_VALUE

    // What the TV has: the words sent, and a load waiting for the end of this turn.
    private var shown: CastWords? = null
    private var pending: Pending? = null
    private var flushing: Job? = null
    private var ticker: Job? = null
    private var timeout: Job? = null
    private var pinging: Job? = null
    private var pingId = 0
    private val pings = HashMap<Int, Long>()

    private data class Pending(val words: CastWords, val startMs: Long?, val autoplay: Boolean)
    private class Expectation(val until: Long, val accepts: (ReceiverMessage.Status, Long) -> Boolean)

    // MARK: The session

    /** A session is up (or back): talk to it. The TV is asked for its status and the words are (re)sent. */
    fun attach(channel: CastChannel) {
        this.channel = channel
        clock.reset()
        clock.oneWayMs = 0
        lastStatusAt = Long.MIN_VALUE
        send(SenderMessage.GetStatus)
        ping()
        pinging?.cancel()
        pinging = scope.launch {
            while (isActive) { delay(PING_EVERY_MS); ping() }
        }
        val again = pending ?: shown?.let { Pending(it, null, false) }
        shown = null
        if (again != null) request(again.words, again.startMs, again.autoplay)
    }

    /** The session is gone: the place is held where the TV was last known to be. */
    fun detach() {
        if (phase == PlaybackState.Playing || phase == PlaybackState.Loading) {
            anchorMs = positionNow(); anchorAt = now()
            phase = if (anchorMs > 0) PlaybackState.Paused else PlaybackState.Idle
        }
        channel = null
        expectation = null
        pinging?.cancel(); timeout?.cancel(); ticker?.cancel()
        // Whatever the TV showed goes up again on the next session.
        if (pending == null) shown?.let { pending = Pending(it, null, false) }
        shown = null
        publish()
    }

    /** A message from the TV (JSON text). */
    fun receive(text: String, arrivedAt: Long = now()) {
        when (val message = ReceiverMessage.parse(text) ?: return) {
            is ReceiverMessage.Status -> {
                if (clock.accept(message, arrivedAt)) adopt(message, clock.receivedAt)
            }
            is ReceiverMessage.Pong -> {
                val sent = message.id?.let(pings::remove) ?: return
                clock.oneWayMs = ((arrivedAt - sent) / 2).coerceIn(0, 2_000)
            }
            is ReceiverMessage.Error -> failed(message)
        }
    }

    // MARK: Words (the church mirror)

    /**
     * Puts [words] on the TV (the hymn church mode is on). Another hymn stops
     * what the TV was playing. False when the TV already has (or is about to
     * get) them, so the caller sends page, Blank and theme itself.
     */
    fun showHymn(words: CastWords): Boolean {
        val target = pending?.words ?: shown
        if (target == words) return false
        if (this.words != null && this.words != words && (phase == PlaybackState.Playing || phase == PlaybackState.Loading || phase == PlaybackState.Paused)) {
            // The TV loads the new hymn, so the player's hymn there stops.
            phase = PlaybackState.Idle; anchorMs = 0; anchorAt = now(); expectation = null
            stopTicking()
            publish()
        }
        request(words, null, false)
        return true
    }

    /** Page, Blank, theme, special and picture messages. Page and Blank wait for a pending load, which carries them. */
    fun sendScreen(message: SenderMessage) {
        if ((message is SenderMessage.Page || message is SenderMessage.Blank) && (pending != null || shown == null)) return
        send(message)
    }

    // MARK: AccompanimentTransport

    override fun load(hymn: Hymn, hymnal: HymnalInfo): Boolean {
        val asset = hymn.midiAsset ?: return false
        val k = AccompanimentState.key(hymnal.id, hymn.number)
        if (k == key && words != null) return true
        val pass = passLengthMs(asset)?.takeIf { it > 0 } ?: return false
        val w = wordsFor(hymn, hymnal)
        key = k
        words = w
        passes = hymn.accompanimentPasses.size
        localPassMs = pass
        tvPassMs = 0
        phase = PlaybackState.Idle
        anchorMs = 0; anchorAt = now()
        expectation = null
        stopTicking()
        // The words up stay up until this hymn plays (church mode may be on another).
        if (shown == null && pending == null) request(w, null, false)
        // The TV may already have it (church mode put it up): follow what it says.
        clock.status?.let { adopt(it, clock.receivedAt) }
        publish()
        return true
    }

    override fun unload() {
        if (words != null && pending?.words == words) pending = pending?.copy(autoplay = false, startMs = null)
        if (phase != PlaybackState.Idle && phase != PlaybackState.Ended && pending == null && shown == words) send(SenderMessage.Stop)
        words = null; key = null; passes = 0; localPassMs = 0; tvPassMs = 0
        phase = PlaybackState.Idle; anchorMs = 0; expectation = null
        stopTicking(); timeout?.cancel()
        publish()
    }

    override fun play(fromMs: Long?) {
        val w = words ?: return
        if (!available) return
        if (fromMs != null) anchor(clampMs(fromMs))
        if (phase == PlaybackState.Playing || phase == PlaybackState.Loading) return
        val from = when {
            fromMs != null -> anchorMs
            phase == PlaybackState.Ended -> 0
            else -> positionNow()
        }
        val wasEnded = phase == PlaybackState.Ended
        anchor(from)
        phase = PlaybackState.Loading
        val p = pending
        when {
            p != null && p.words == w -> pending = p.copy(startMs = from, autoplay = true)
            shown != w -> request(w, from, true)
            else -> send(SenderMessage.Play(if (fromMs != null || !wasEnded) from else null))
        }
        expect(PLAY_GRACE_MS) { s, _ -> s.state == CastStatusClock.STATE_PLAYING || s.state == CastStatusClock.STATE_LOADING }
        watchLoading()
        publish()
    }

    override fun pause() {
        when (phase) {
            PlaybackState.Loading -> {
                phase = if (anchorMs > 0) PlaybackState.Paused else PlaybackState.Idle
                timeout?.cancel()
            }
            PlaybackState.Playing -> {
                anchor(positionNow())
                phase = PlaybackState.Paused
                stopTicking()
            }
            else -> return
        }
        val p = pending
        if (p != null && p.words == words) pending = p.copy(autoplay = false)
        else if (shown == words) send(SenderMessage.Pause)
        expect(COMMAND_GRACE_MS) { s, _ -> s.state != CastStatusClock.STATE_PLAYING }
        publish()
    }

    override fun stop() {
        timeout?.cancel()
        stopTicking()
        val wasActive = phase != PlaybackState.Idle || anchorMs != 0L
        phase = PlaybackState.Idle
        anchor(0)
        val p = pending
        if (p != null && p.words == words) pending = p.copy(startMs = 0, autoplay = false)
        else if (words != null && wasActive && shown == words) send(SenderMessage.Stop)
        if (words != null) expect(COMMAND_GRACE_MS) { s, _ -> s.state == CastStatusClock.STATE_IDLE || s.state == CastStatusClock.STATE_ENDED }
        publish()
    }

    override fun seek(ms: Long) {
        if (words == null || passes <= 0) return
        val target = clampMs(ms)
        val playing = phase == PlaybackState.Playing
        anchor(target)
        if (phase == PlaybackState.Ended || phase == PlaybackState.Idle) phase = PlaybackState.Paused
        val p = pending
        if (p != null && p.words == words) pending = p.copy(startMs = target)
        else if (shown == words) send(SenderMessage.Seek(target))
        // Otherwise the place goes with the load when it plays.
        val sentAt = now()
        val r = rate
        expect(COMMAND_GRACE_MS) { s, at ->
            val expected = target + if (playing) ((at - sentAt).coerceAtLeast(0) * r).roundToLong() else 0
            abs(s.positionMs - expected) <= SEEK_TOLERANCE_MS
        }
        publish()
    }

    override fun setTempo(rate: Float) {
        if (rate == this.rate) return
        anchor(positionNow())
        this.rate = rate
        tvRate = rate
        send(SenderMessage.Tempo(rate))
        publish()
    }

    // MARK: Following the TV

    private fun adopt(status: ReceiverMessage.Status, at: Long) {
        lastStatusAt = at
        val w = words ?: return
        if (status.hymnKey != w.tvKey || pending != null || shown != w) return
        val e = expectation
        if (e != null) {
            if (now() < e.until && !e.accepts(status, at)) return
            expectation = null
        }
        if (status.passDurationMs > 0) tvPassMs = status.passDurationMs
        tvRate = status.rate
        phase = when (status.state) {
            CastStatusClock.STATE_PLAYING -> PlaybackState.Playing
            CastStatusClock.STATE_PAUSED -> PlaybackState.Paused
            CastStatusClock.STATE_LOADING -> PlaybackState.Loading
            CastStatusClock.STATE_ENDED -> PlaybackState.Ended
            else -> PlaybackState.Idle
        }
        // While the TV loads, its position means nothing yet: the place asked for stands.
        if (phase != PlaybackState.Loading) {
            anchorMs = if (phase == PlaybackState.Ended) 0 else status.positionMs
            anchorAt = at
        }
        if (phase == PlaybackState.Playing) startTicking() else stopTicking()
        if (phase != PlaybackState.Loading) timeout?.cancel()
        publish()
    }

    private fun failed(error: ReceiverMessage.Error) {
        when (error.code) {
            "soundfont_failed", "audio_failed" -> {
                available = false
                settleFromLoading()
                Analytics.error(ErrorDomain.Audio, "cast_${error.code}")
            }
            "no_accompaniment", "midi_not_found", "midi_load_failed" -> {
                settleFromLoading()
                Analytics.error(ErrorDomain.Audio, "cast_${error.code}")
            }
            "no_hymn" -> {
                // The TV lost the hymn (a new receiver): put it back.
                val again = shown ?: words
                shown = null
                if (again != null) request(again, null, false)
            }
            else -> Analytics.error(ErrorDomain.Audio, "cast_${error.code}")
        }
        publish()
    }

    private fun settleFromLoading() {
        if (phase == PlaybackState.Loading) phase = if (anchorMs > 0) PlaybackState.Paused else PlaybackState.Idle
        expectation = null
        timeout?.cancel()
    }

    /** A play the TV never answered (no status at all) gives up, holding the place. */
    private fun watchLoading() {
        timeout?.cancel()
        commandAt = now()
        timeout = scope.launch {
            delay(LOADING_TIMEOUT_MS)
            if (phase == PlaybackState.Loading && lastStatusAt < commandAt) {
                settleFromLoading()
                publish()
            }
        }
    }

    private fun startTicking() {
        if (ticker?.isActive == true) return
        ticker = scope.launch {
            while (isActive && phase == PlaybackState.Playing) {
                delay(TICK_MS)
                publish()
            }
        }
    }

    private fun stopTicking() {
        ticker?.cancel()
        ticker = null
    }

    // MARK: Sending

    private fun request(words: CastWords, startMs: Long?, autoplay: Boolean) {
        pending = Pending(words, startMs, autoplay)
        if (flushing?.isActive == true) return
        flushing = scope.launch { flush() }
    }

    private fun flush() {
        val p = pending ?: return
        val channel = channel ?: return
        pending = null
        val start = p.startMs
        val tv = clock.status
        val sameAudio = tv != null && tv.hymnKey == p.words.tvKey && tv.midi == p.words.hymn.midiAsset &&
            tv.passes == p.words.hymn.accompanimentPasses.size &&
            (tv.passDurationMs > 0 || tv.state == CastStatusClock.STATE_LOADING)
        val tempo = if (p.words == words) rate else null
        if (!sameAudio) {
            channel.send(CastLoads.load(p.words, screen(), tempo, p.autoplay, start ?: 0))
        } else {
            channel.send(CastLoads.load(p.words, screen(), tempo, autoplay = false))
            if (p.autoplay) channel.send(SenderMessage.Play(start))
            else if (start != null) channel.send(SenderMessage.Seek(start))
        }
        shown = p.words
        // The TV's last word on this hymn may be the newest there is.
        clock.status?.let { adopt(it, clock.receivedAt) }
        if (p.autoplay && phase == PlaybackState.Loading) watchLoading()
    }

    private fun send(message: SenderMessage): Boolean = channel?.send(message) ?: false

    private fun ping() {
        val id = ++pingId
        pings[id] = now()
        if (pings.size > 8) pings.keys.minOrNull()?.let(pings::remove)
        send(SenderMessage.Ping(id))
    }

    private fun expect(graceMs: Long, accepts: (ReceiverMessage.Status, Long) -> Boolean) {
        expectation = Expectation(now() + graceMs, accepts)
    }

    // MARK: Arithmetic

    private val passMs: Long get() = if (tvPassMs > 0) tvPassMs else localPassMs
    private val durationMs: Long get() = passMs * passes

    private fun clampMs(ms: Long): Long = ms.coerceIn(0, durationMs.coerceAtLeast(0))

    private fun anchor(ms: Long) {
        anchorMs = ms
        anchorAt = now()
    }

    /** The performance position now: held, or moving at the TV's rate since the anchor. */
    fun positionNow(): Long =
        CastStatusClock.extrapolate(anchorMs, durationMs, anchorAt, now(), tvRate, phase == PlaybackState.Playing)

    private fun publish() {
        val k = key
        if (k == null || words == null) {
            mutable.value = AccompanimentState(rate = rate, isAvailable = available)
            return
        }
        val position = positionNow()
        val pass = if (passMs > 0 && passes > 0) minOf((position / passMs).toInt(), passes - 1) + 1 else 0
        mutable.value = AccompanimentState(
            hymnKey = k,
            state = phase,
            positionMs = position,
            durationMs = durationMs,
            pass = pass,
            passes = passes,
            rate = rate,
            isAvailable = available,
        )
    }

    companion object {
        /** About 30 Hz while playing. */
        const val TICK_MS = 33L
        const val COMMAND_GRACE_MS = 1_500L
        const val PLAY_GRACE_MS = 2_000L
        const val SEEK_TOLERANCE_MS = 1_000L
        const val LOADING_TIMEOUT_MS = 15_000L
        const val PING_EVERY_MS = 30_000L
    }
}
