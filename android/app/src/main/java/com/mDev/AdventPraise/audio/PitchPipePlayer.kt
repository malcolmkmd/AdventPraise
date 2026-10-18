// OWNER: music
package com.mDev.AdventPraise.audio

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Process
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.mDev.AdventPraise.extras.Pitch
import com.mDev.AdventPraise.extras.PitchTone
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Sounds a hymn's starting note (PitchPipe on iOS): the soft reedy tone of
 * [PitchTone] on its own [AudioTrack], apart from the accompaniment. It
 * mixes with other audio (no focus taken), sounds for [PitchTone.DURATION_SECONDS]
 * and fades out.
 */
class PitchPipePlayer(private val scope: CoroutineScope) {
    /** The MIDI note sounding, or null. */
    var sounding by mutableStateOf<Int?>(null)
        private set

    private val lock = Any()
    private var tone: PitchTone? = null
    private var track: AudioTrack? = null
    private var thread: Thread? = null
    @Volatile private var running = false
    private var stopper: Job? = null

    fun play(midi: Int) {
        val ok = runCatching { ensureRunning() }.isSuccess
        if (!ok) return
        synchronized(lock) { tone?.start(Pitch.frequency(midi)) }
        sounding = midi
        stopper?.cancel()
        stopper = scope.launch {
            delay((PitchTone.DURATION_SECONDS * 1000).toLong())
            stop()
        }
    }

    fun stop() {
        stopper?.cancel()
        synchronized(lock) { tone?.release() }
        sounding = null
        stopper = scope.launch {
            delay(300)   // let the fade finish
            if (sounding == null) shutdown()
        }
    }

    /** Lets the track go (leaving the screen). */
    fun shutdown() {
        stopper?.cancel()
        running = false
        thread?.join(200)
        thread = null
        track?.let { runCatching { it.stop() }; it.release() }
        track = null
        synchronized(lock) { tone = null }
        sounding = null
    }

    private fun ensureRunning() {
        if (running && track != null) return
        val rate = AudioTrack.getNativeOutputSampleRate(AudioManager.STREAM_MUSIC).takeIf { it in 8000..192000 } ?: 44100
        val min = AudioTrack.getMinBufferSize(rate, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_FLOAT)
        val t = AudioTrack.Builder()
            .setAudioAttributes(AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build())
            .setAudioFormat(AudioFormat.Builder()
                .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                .setSampleRate(rate)
                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                .build())
            .setBufferSizeInBytes(maxOf(min, 1024 * 4))
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()
        check(t.state == AudioTrack.STATE_INITIALIZED)
        synchronized(lock) { tone = PitchTone(rate.toDouble()) }
        track = t
        running = true
        t.play()
        thread = Thread({
            Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO)
            val buffer = FloatArray(512)
            while (running) {
                synchronized(lock) { tone?.render(buffer) ?: buffer.fill(0f) }
                if (t.write(buffer, 0, buffer.size, AudioTrack.WRITE_BLOCKING) < 0) break
            }
        }, "pitch-pipe").also { it.start() }
    }
}
