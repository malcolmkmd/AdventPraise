// OWNER: music
package com.mDev.AdventPraise.audio

import com.mDev.AdventPraise.data.Hymn
import com.mDev.AdventPraise.data.HymnalInfo
import kotlinx.coroutines.flow.StateFlow

/** Where the transport is in its life. */
enum class PlaybackState {
    /** Nothing playing: a hymn may be loaded (cued), at the top or at a sought place. */
    Idle,
    /** Play was asked for and audio is starting (the piano loading, a receiver connecting). */
    Loading,
    Playing,
    /** Started and paused part-way: the place is kept. */
    Paused,
    /** The last verse finished; the position is back at the top. */
    Ended,
}

/**
 * Everything anyone reads about the accompaniment. Times are in the
 * performance's own clock: milliseconds into the whole performance (every
 * verse) at the file's written tempo, as iOS's `elapsed` and the sheet
 * music's timings are. Wall-clock time is that ÷ [rate].
 */
data class AccompanimentState(
    /** "<hymnal id>#<number>" of the hymn loaded, or null. */
    val hymnKey: String? = null,
    val state: PlaybackState = PlaybackState.Idle,
    /** Performance position, sample-accurate to what is being heard. */
    val positionMs: Long = 0,
    /** The whole performance: one pass × [passes]. */
    val durationMs: Long = 0,
    /** 1-based pass (verse) at [positionMs]; 0 with nothing loaded. */
    val pass: Int = 0,
    val passes: Int = 0,
    /** Tempo: 0.8, 1 or 1.2 (PlaybackTempo). */
    val rate: Float = 1f,
    /** False once audio couldn't start on this device: the play controls hide. */
    val isAvailable: Boolean = true,
) {
    val isPlaying: Boolean get() = state == PlaybackState.Playing
    /** Started and not yet stopped or finished (iOS `isActive`). */
    val isActive: Boolean get() = state == PlaybackState.Playing || state == PlaybackState.Paused || state == PlaybackState.Loading
    val elapsedSeconds: Double get() = positionMs / 1000.0
    val durationSeconds: Double get() = durationMs / 1000.0
    /** One pass through the tune, in seconds at the written tempo. */
    val passSeconds: Double get() = if (passes > 0) durationSeconds / passes else 0.0
    /** Wall-clock seconds, as people see them. */
    val displayElapsedSeconds: Double get() = elapsedSeconds / rate
    val displayDurationSeconds: Double get() = durationSeconds / rate

    companion object {
        fun key(hymnal: String, number: Int) = "$hymnal#$number"
    }
}

/**
 * The accompaniment's clock and sound, local or remote. The phone's own
 * piano ([LocalAccompaniment]) is the default; a Cast receiver can stand in
 * for it (the TV is then the clock). Everything that follows the music (the
 * Lectern player, verse following, sheet music, church mode) reads the
 * position only from [state].
 *
 * Semantics (HymnMIDIEngine on iOS): the MIDI file is played once per verse
 * (`passes`), straight through to its End of Track each time; no loop at the
 * end. The free-play gate, analytics and Now Playing live above this, in
 * [AccompanimentPlayer].
 */
interface AccompanimentTransport {
    val state: StateFlow<AccompanimentState>

    /**
     * Picks the hymn: parses its file, touches no audio hardware. Loading the
     * hymn already loaded does nothing, so playback carries on. Another hymn
     * stops the one playing. False when it has no readable accompaniment.
     */
    fun load(hymn: Hymn, hymnal: HymnalInfo): Boolean

    /** Plays the loaded hymn from where it is, or from [fromMs] (performance ms). */
    fun play(fromMs: Long? = null)

    /** Holds the place. */
    fun pause()

    /** Ends the performance: back to the top, audio released. The hymn stays loaded. */
    fun stop()

    /** Jumps to [ms] (performance ms, clamped), playing or not. */
    fun seek(ms: Long)

    /** 0.8, 1 or 1.2; takes effect at once, keeping the place. */
    fun setTempo(rate: Float)

    /** Forgets the hymn and lets everything go. */
    fun unload()
}
