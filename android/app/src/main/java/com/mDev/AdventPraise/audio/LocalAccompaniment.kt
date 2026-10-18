// OWNER: music
package com.mDev.AdventPraise.audio

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Build
import android.os.Process
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.ErrorDomain
import com.mDev.AdventPraise.data.Hymn
import com.mDev.AdventPraise.data.HymnalInfo
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.max
import kotlin.math.roundToLong

/**
 * The phone's own piano: the hymn's MIDI file through [PianoSynth] (the
 * bundled `piano.sf2`) into an [AudioTrack], on an audio thread of its own.
 *
 * Nothing touches audio until the first play: the SoundFont loads then (off
 * the main thread, state Loading), the track is built, audio focus asked for.
 * Pausing or losing focus holds the place; headphones pulled out pause
 * (becoming noisy); a transient loss resumes when focus returns, as iOS
 * resumes after an interruption. Stopping and finishing let audio go.
 *
 * The position is what is being heard: frames rendered are mapped to
 * performance time as they are written, and the track's playback head says
 * which frame is sounding.
 */
class LocalAccompaniment(
    private val context: Context,
    private val scope: CoroutineScope,
) : AccompanimentTransport {
    private val _state = MutableStateFlow(AccompanimentState())
    override val state: StateFlow<AccompanimentState> = _state

    // Main-thread state.
    private var hymnKey: String? = null
    private var file: StandardMidiFile? = null
    private var passes = 0
    private var rate = 1.0
    /** The truth while not playing: performance seconds. */
    private var elapsed = 0.0
    private var phase = PlaybackState.Idle
    private var available = true
    private var starting: Job? = null
    private var ticker: Job? = null
    private var resumeOnFocusGain = false

    // Audio-side state, guarded by [lock].
    private val lock = Any()
    private var renderer: MidiRenderer? = null
    private var track: AudioTrack? = null
    private var generation = 0
    private var framesWritten = 0L
    private var headBase = 0L
    /** Frame index → performance seconds at a rate, from that frame on. */
    private val segments = ArrayDeque<Segment>()

    private class Segment(val frame: Long, val elapsed: Double, val rate: Double)

    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var focusRequest: AudioFocusRequest? = null
    private var noisyRegistered = false

    private val noisy = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            // Headphones pulled out: pause rather than play out loud.
            if (intent.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) scope.launch { pause() }
        }
    }

    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        scope.launch {
            when (change) {
                AudioManager.AUDIOFOCUS_LOSS -> { resumeOnFocusGain = false; pause() }
                AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> if (phase == PlaybackState.Playing) { pause(); resumeOnFocusGain = true }
                AudioManager.AUDIOFOCUS_GAIN -> if (resumeOnFocusGain) { resumeOnFocusGain = false; play() }
            }
        }
    }

    private val attributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_MEDIA)
        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
        .build()

    // MARK: Loading

    override fun load(hymn: Hymn, hymnal: HymnalInfo): Boolean {
        val key = AccompanimentState.key(hymnal.id, hymn.number)
        if (key == hymnKey && file != null) return true
        unload()
        val asset = hymn.midiAsset ?: return false
        val parsed = try {
            context.assets.open(asset).use { StandardMidiFile.parse(it.readBytes()) }.takeIf { it.lengthSeconds > 0 }
        } catch (e: Exception) {
            Analytics.error(ErrorDomain.Audio, "load_unreadable_file", e)
            null
        } ?: return false
        hymnKey = key
        file = parsed
        passes = hymn.accompanimentPasses.size
        elapsed = 0.0
        phase = PlaybackState.Idle
        publish()
        return true
    }

    override fun unload() {
        stop()
        hymnKey = null
        file = null
        passes = 0
        synchronized(lock) { renderer = null }
        publish()
    }

    private val duration: Double get() = (file?.lengthSeconds ?: 0.0) * passes

    // MARK: Transport

    override fun play(fromMs: Long?) {
        if (fromMs != null) seek(fromMs)
        val midi = file ?: return
        if (!available || phase == PlaybackState.Playing || phase == PlaybackState.Loading) return
        if (!requestFocus()) return
        val previous = phase
        phase = PlaybackState.Loading
        publish()
        starting = scope.launch {
            try {
                val synth = withContext(Dispatchers.IO) { piano(context) }
                if (file !== midi || phase != PlaybackState.Loading) return@launch
                startTrack(midi, synth)
            } catch (e: Throwable) {
                if (e is kotlinx.coroutines.CancellationException) throw e
                Analytics.error(ErrorDomain.Audio, "playback_${e.javaClass.simpleName}", e)
                teardownTrack()
                available = false
                phase = if (previous == PlaybackState.Paused) PlaybackState.Paused else PlaybackState.Idle
                abandonFocus()
                publish()
            }
        }
    }

    private fun startTrack(midi: StandardMidiFile, synth: PianoSynth) {
        val track = track ?: buildTrack(synth.outputRate).also { track = it }
        val gen: Int
        synchronized(lock) {
            val r = renderer?.takeIf { it.file === midi && it.synth === synth } ?: MidiRenderer(midi, synth, passes)
            renderer = r
            r.rate = rate
            r.seek(elapsed)
            segments.clear()
            framesWritten = 0
            segments.addLast(Segment(0, r.elapsed, rate))
            gen = ++generation
            headBase = track.playbackHeadPosition.toLong() and 0xFFFFFFFFL
        }
        track.play()
        Thread({ renderLoop(track, gen) }, "accompaniment").start()
        phase = PlaybackState.Playing
        registerNoisy()
        startTicker()
        publish()
    }

    override fun pause() {
        when (phase) {
            PlaybackState.Loading -> {
                starting?.cancel()
                phase = if (elapsed > 0) PlaybackState.Paused else PlaybackState.Idle
                publish()
                return
            }
            PlaybackState.Playing -> Unit
            else -> return
        }
        elapsed = audibleElapsed()
        haltTrack()
        ticker?.cancel()
        unregisterNoisy()
        phase = PlaybackState.Paused
        publish()
    }

    override fun stop() {
        starting?.cancel()
        if (phase == PlaybackState.Playing) haltTrack()
        ticker?.cancel()
        resumeOnFocusGain = false
        elapsed = 0.0
        if (file != null || phase != PlaybackState.Idle) phase = PlaybackState.Idle
        releaseAudio()
        publish()
    }

    override fun seek(ms: Long) {
        val midi = file ?: return
        if (passes <= 0 || midi.lengthSeconds <= 0) return
        val target = PassClock.clamp(ms / 1000.0, duration)
        elapsed = target
        if (phase == PlaybackState.Playing) {
            val track = track ?: return
            haltTrack()
            val gen: Int
            synchronized(lock) {
                val r = renderer ?: return
                r.seek(target)
                segments.clear()
                framesWritten = 0
                segments.addLast(Segment(0, r.elapsed, rate))
                gen = ++generation
                headBase = track.playbackHeadPosition.toLong() and 0xFFFFFFFFL
            }
            track.play()
            Thread({ renderLoop(track, gen) }, "accompaniment").start()
        } else if (phase == PlaybackState.Ended) {
            phase = PlaybackState.Idle
        }
        publish()
    }

    override fun setTempo(rate: Float) {
        val value = rate.toDouble().coerceIn(0.25, 4.0)
        if (value == this.rate) return
        this.rate = value
        synchronized(lock) {
            val r = renderer
            if (r != null) {
                r.rate = value
                if (phase == PlaybackState.Playing) {
                    segments.addLast(Segment(framesWritten, r.elapsed, value))
                    while (segments.size > 16) segments.removeFirst()
                }
            }
        }
        publish()
    }

    // MARK: Following

    private fun startTicker() {
        ticker?.cancel()
        ticker = scope.launch {
            while (isActive) {
                delay(TICK_MS)
                if (phase != PlaybackState.Playing) return@launch
                val now = audibleElapsed()
                val finished = synchronized(lock) { renderer?.isFinished == true }
                if (finished && now >= duration - 0.001) { finish(); return@launch }
                elapsed = now
                publish()
            }
        }
    }

    private fun finish() {
        haltTrack()
        unregisterNoisy()
        elapsed = 0.0
        phase = PlaybackState.Ended
        releaseAudio()
        publish()
    }

    /** Performance seconds being heard now. */
    private fun audibleElapsed(): Double = synchronized(lock) {
        val track = track ?: return elapsed
        val head = ((track.playbackHeadPosition.toLong() and 0xFFFFFFFFL) - headBase).coerceAtLeast(0)
        val segment = segments.lastOrNull { it.frame <= head } ?: segments.firstOrNull() ?: return elapsed
        val sampleRate = track.sampleRate.toDouble()
        PassClock.clamp(segment.elapsed + (head - segment.frame) / sampleRate * segment.rate, duration)
    }

    private fun publish() {
        val midi = file
        val total = duration
        val position = if (phase == PlaybackState.Playing) elapsed else elapsed
        _state.value = AccompanimentState(
            hymnKey = hymnKey,
            state = phase,
            positionMs = (position * 1000).roundToLong(),
            durationMs = (total * 1000).roundToLong(),
            pass = if (midi == null || passes == 0) 0 else PassClock.passIndex(position, midi.lengthSeconds, passes) + 1,
            passes = passes,
            rate = rate.toFloat(),
            isAvailable = available,
        )
    }

    // MARK: Audio thread

    private fun renderLoop(track: AudioTrack, gen: Int) {
        Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO)
        val buffer = FloatArray(BLOCK_FRAMES)
        while (true) {
            synchronized(lock) {
                if (gen != generation) return
                val r = renderer ?: return
                r.render(buffer, 0, BLOCK_FRAMES)
                framesWritten += BLOCK_FRAMES
            }
            var written = 0
            while (written < BLOCK_FRAMES) {
                if (gen != generation) return
                val n = track.write(buffer, written, BLOCK_FRAMES - written, AudioTrack.WRITE_NON_BLOCKING)
                if (n < 0) return
                written += n
                if (written < BLOCK_FRAMES) Thread.sleep(WRITE_RETRY_MS)
            }
        }
    }

    /** Stops the audio thread and drops what is queued. */
    private fun haltTrack() {
        synchronized(lock) { generation++ }
        track?.let { runCatching { it.pause(); it.flush() } }
    }

    private fun buildTrack(sampleRate: Int): AudioTrack {
        val min = AudioTrack.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_FLOAT)
        val bytes = max(min, BLOCK_FRAMES * 4 * 4)
        return AudioTrack.Builder()
            .setAudioAttributes(attributes)
            .setAudioFormat(AudioFormat.Builder()
                .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                .setSampleRate(sampleRate)
                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                .build())
            .setBufferSizeInBytes(bytes)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()
            .also { if (it.state != AudioTrack.STATE_INITIALIZED) { it.release(); error("track not initialised") } }
    }

    private fun teardownTrack() {
        synchronized(lock) { generation++ }
        track?.let { runCatching { it.pause(); it.flush() }; it.release() }
        track = null
    }

    /** Lets audio go: the track, focus and the headphones watch. */
    private fun releaseAudio() {
        teardownTrack()
        unregisterNoisy()
        abandonFocus()
    }

    // MARK: Focus and headphones

    private fun requestFocus(): Boolean {
        val request = focusRequest ?: AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
            .setAudioAttributes(attributes)
            .setOnAudioFocusChangeListener(focusListener)
            .setWillPauseWhenDucked(false)
            .build()
            .also { focusRequest = it }
        return audioManager.requestAudioFocus(request) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }

    private fun abandonFocus() {
        focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
    }

    private fun registerNoisy() {
        if (noisyRegistered) return
        noisyRegistered = true
        val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
        if (Build.VERSION.SDK_INT >= 33) context.registerReceiver(noisy, filter, Context.RECEIVER_NOT_EXPORTED)
        else context.registerReceiver(noisy, filter)
    }

    private fun unregisterNoisy() {
        if (!noisyRegistered) return
        noisyRegistered = false
        runCatching { context.unregisterReceiver(noisy) }
    }

    companion object {
        const val BLOCK_FRAMES = 512
        private const val TICK_MS = 50L
        private const val WRITE_RETRY_MS = 3L
        const val SOUNDFONT_ASSET = "piano.sf2"

        @Volatile private var font: SoundFont? = null

        /** The bundled piano, read once. */
        fun soundFont(context: Context): SoundFont =
            font ?: synchronized(this) {
                font ?: context.assets.open(SOUNDFONT_ASSET).use { SoundFont.parse(it.readBytes()) }.also { font = it }
            }

        private var synth: PianoSynth? = null

        /** One synth at the device's output rate. */
        @Synchronized
        fun piano(context: Context): PianoSynth = synth ?: PianoSynth(
            soundFont(context),
            AudioTrack.getNativeOutputSampleRate(AudioManager.STREAM_MUSIC).takeIf { it in 8000..192000 } ?: 48000,
        ).also { synth = it }
    }
}
