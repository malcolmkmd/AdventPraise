// OWNER: music
package com.mDev.AdventPraise.audio

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.data.Hymn
import com.mDev.AdventPraise.data.HymnalInfo
import com.mDev.AdventPraise.settings.PlaybackTempo
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlin.math.roundToInt
import kotlin.math.roundToLong

/** The free-play counter moved to billing (iOS Store/FreePlays.swift). */
typealias FreePlays = com.mDev.AdventPraise.billing.FreePlays

/**
 * The hymn accompaniment as the app uses it (HymnMIDIEngine on iOS): which
 * hymn is up, play / pause / restart / seek / tempo, the verse being played,
 * the free-play gate, analytics and the lock-screen controls, over an
 * [AccompanimentTransport] that makes the sound and keeps the clock (the
 * phone's piano by default; [use] swaps in another, such as a Cast receiver).
 *
 * The free-play gate: a new play is a hymn starting while the player isn't
 * active (first play, or after it stopped or finished); resuming, scrubbing
 * and restarting an active hymn are not. While [isLocked] returns true a new
 * play calls [onLocked] (the paywall) instead, from any source.
 *
 * Every property is Compose state.
 */
class AccompanimentPlayer(
    transport: AccompanimentTransport,
    private val scope: CoroutineScope,
    private val tempoStore: TempoStore,
) {
    /** Where the chosen tempo is kept (AppSettings, "player.tempo"). */
    interface TempoStore {
        val tempo: PlaybackTempo
        fun updateTempo(value: PlaybackTempo)
    }

    var transport: AccompanimentTransport = transport
        private set

    /** The transport's latest state (Compose-observable mirror). */
    var status by mutableStateOf(transport.state.value)
        private set

    var hymn by mutableStateOf<Hymn?>(null)
        private set
    var hymnal by mutableStateOf<HymnalInfo?>(null)
        private set

    private var chosenTempo by mutableStateOf(tempoStore.tempo)

    /** Slow, Medium or Fast: kept ("player.tempo"), applied at once, keeping the place. */
    var tempo: PlaybackTempo
        get() = chosenTempo
        set(value) {
            if (value == chosenTempo) return
            chosenTempo = value
            tempoStore.updateTempo(value)
            transport.setTempo(value.rate)
            Analytics.track(AnalyticsEvent.AccompanimentTempoChanged(value))
            onChange?.invoke()
        }

    /** Fires when the last verse ends: playlists use it to advance. */
    var onFinish: (() -> Unit)? = null
    /** Lock screen / headphones "next track". */
    var onNextTrack: (() -> Unit)? = null
    var isLocked: () -> Boolean = { false }
    var onLocked: (() -> Unit)? = null
    /** A new play has started (once audio is running), so it can be counted. */
    var onNewPlay: (() -> Unit)? = null
    /** Called on every state change (Now Playing listens). */
    internal var onChange: (() -> Unit)? = null

    private var watching: Job? = null
    private var pendingStart: PendingStart? = null
    private class PendingStart(val isNewPlay: Boolean, val resumed: Boolean, val counts: Boolean)

    init {
        transport.setTempo(tempo.rate)
        watch()
    }

    // MARK: Reading

    val isPlaying: Boolean get() = status.isPlaying
    /** Started and not yet stopped or finished: the reader follows and the Lectern shows the transport. */
    val isActive: Boolean get() = status.isActive
    val isAvailable: Boolean get() = status.isAvailable
    /** Seconds into the whole performance, at the written tempo. */
    val elapsed: Double get() = status.elapsedSeconds
    val duration: Double get() = status.durationSeconds
    val displayElapsed: Double get() = elapsed / tempo.rate
    val displayDuration: Double get() = duration / tempo.rate
    val passCount: Int get() = status.passes

    /** The verse and line being played, while active. */
    val position: PlaybackPosition?
        get() {
            val h = hymn ?: return null
            if (!isActive) return null
            return PassClock.position(h.accompanimentPasses, elapsed, status.passSeconds)
        }

    /** This hymn (in this hymnal) is the one up. */
    fun isHymn(hymnalId: String, hymn: Hymn): Boolean = status.hymnKey == AccompanimentState.key(hymnalId, hymn.number)

    // MARK: Loading

    /** Picks `hymn` without playing it; the hymn already up carries on. False without a readable file. */
    fun load(hymn: Hymn, hymnal: HymnalInfo): Boolean {
        if (!hymn.hasAccompaniment) return false
        if (!transport.load(hymn, hymnal)) {
            this.hymn = null; this.hymnal = null
            return false
        }
        this.hymn = hymn
        this.hymnal = hymnal
        return true
    }

    /** Follows the reader: keeps the hymn up if it's the one on screen, else loads the new one (or nothing). */
    fun cue(hymn: Hymn, hymnal: HymnalInfo) {
        if (!hymn.hasAccompaniment) {
            if (!isHymn(hymnal.id, hymn)) unload()
            return
        }
        load(hymn, hymnal)
    }

    /** Loads and plays `hymn` from the top; false if it has no accompaniment or the play is locked. */
    fun start(hymn: Hymn, hymnal: HymnalInfo): Boolean {
        if (!load(hymn, hymnal)) return false
        transport.seek(0)
        play()
        return transport.state.value.isActive
    }

    fun unload() {
        pendingStart = null
        transport.unload()
        hymn = null
        hymnal = null
    }

    // MARK: Transport

    fun play() = begin(gated = true)

    private fun begin(gated: Boolean) {
        val now = transport.state.value
        if (!now.isAvailable || now.isPlaying || now.state == PlaybackState.Loading || hymn == null) return
        val isNewPlay = !now.isActive
        if (gated && isNewPlay && isLocked()) { onLocked?.invoke(); return }
        pendingStart = PendingStart(isNewPlay, resumed = now.positionMs > 0, counts = gated)
        transport.play()
    }

    /** Holds the place; the transport stays up and the lock screen keeps the hymn. */
    fun pause() {
        val now = transport.state.value
        if (now.state == PlaybackState.Loading) { pendingStart = null; transport.pause(); return }
        if (!now.isPlaying) return
        transport.pause()
        val h = hymn ?: return
        val progress = if (now.durationMs > 0) (now.positionMs * 100.0 / now.durationMs).roundToInt() else 0
        Analytics.track(AnalyticsEvent.AccompanimentPaused(h.number, progress))
    }

    fun toggle() = if (transport.state.value.isPlaying) pause() else play()

    /** Back to the start of verse 1, and playing. */
    fun restart() {
        seek(0.0)
        if (!transport.state.value.isPlaying) play()
    }

    /** `time` is performance seconds (0…duration), as the scrub bar uses. */
    fun seek(time: Double) {
        val now = transport.state.value
        if (now.passes <= 0) return
        transport.seek((PassClock.clamp(time, now.durationSeconds) * 1000).roundToLong())
    }

    /** Ends the performance: rewinds and lets the audio go. */
    fun stop() {
        pendingStart = null
        transport.stop()
    }

    /** Slow → Medium → Fast → Slow (the Lectern's tempo pill), or back with -1. */
    fun stepTempo(offset: Int = 1) {
        val all = PlaybackTempo.entries
        tempo = all[(all.indexOf(tempo) + offset + all.size) % all.size]
    }

    // MARK: Swapping the transport (Cast)

    /**
     * Hands the accompaniment to `next` (a Cast receiver, or back to the
     * phone). The hymn and place carry over; it plays on there when
     * [resumePlaying] and it was playing. The old transport is stopped.
     */
    fun use(next: AccompanimentTransport, resumePlaying: Boolean = false) {
        if (next === transport) return
        val was = transport.state.value
        val h = hymn
        val info = hymnal
        transport.stop()
        transport = next
        next.setTempo(tempo.rate)
        if (h != null && info != null && next.load(h, info)) {
            if (was.positionMs > 0) next.seek(was.positionMs)
            if (resumePlaying && was.isPlaying) next.play()
        }
        watch()
    }

    // MARK: Following the transport

    private fun watch() {
        watching?.cancel()
        val source = transport
        status = source.state.value
        watching = scope.launch {
            source.state.collect { next -> apply(next) }
        }
    }

    private fun apply(next: AccompanimentState) {
        val previous = status
        status = next
        val h = hymn
        if (next.isPlaying && !previous.isPlaying) {
            pendingStart?.let { start ->
                pendingStart = null
                if (start.isNewPlay && start.counts) onNewPlay?.invoke()
                if (h != null) Analytics.track(AnalyticsEvent.AccompanimentPlayed(h.number, tempo, start.resumed))
            }
        }
        if (!next.isActive) pendingStart = null
        if (next.state == PlaybackState.Ended && previous.state != PlaybackState.Ended && h != null) {
            Analytics.track(AnalyticsEvent.AccompanimentCompleted(h.number, tempo, maxOf(previous.passes, next.passes)))
            onFinish?.invoke()
        }
        onChange?.invoke()
    }

    // MARK: The first milestone's API (the reader's current Lectern), until it moves to the above.

    /** "<hymnal>#<number>" of the hymn playing or paused. */
    @Deprecated("Read status.hymnKey") val loadedKey: String? get() = status.hymnKey.takeIf { isActive }

    @Deprecated("Use isHymn and isPlaying")
    fun isPlayingHymn(hymnal: String, hymn: Hymn): Boolean = isPlaying && isHymn(hymnal, hymn)

    /** The hymn is up and active (playing or paused part-way). */
    @Deprecated("Use isHymn and isActive")
    fun isLoaded(hymnal: String, hymn: Hymn): Boolean = isActive && isHymn(hymnal, hymn)

    /** Starts `hymn` from the top with no gate: the caller counts the free play. */
    @Deprecated("Use start(hymn, hymnal), which applies the free-play gate")
    fun start(hymnal: String, hymn: Hymn): Boolean {
        val info = this.hymnal?.takeIf { it.id == hymnal } ?: HymnalInfo(hymnal, hymnal, "", 0, 0)
        if (!load(hymn, info)) return false
        transport.seek(0)
        begin(gated = false)
        return true
    }

    @Deprecated("Use play()") fun resume() = play()
}
