package com.mDev.AdventPraise.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.data.Hymn

/** The free-play counter moved to billing (iOS Store/FreePlays.swift). */
typealias FreePlays = com.mDev.AdventPraise.billing.FreePlays

/**
 * The MIDI accompaniment: the iOS app's Cyber Hymnal files, played with
 * Android's own MIDI synthesizer through MediaPlayer. Play and pause only
 * for now (iOS also follows the verses, scrubs, loops and changes tempo).
 */
class AccompanimentPlayer(private val context: Context) {
    /** "<hymnal>#<number>" of the hymn loaded, playing or paused. */
    var loadedKey by mutableStateOf<String?>(null)
        private set
    var isPlaying by mutableStateOf(false)
        private set

    private var player: MediaPlayer? = null
    private var loadedHymn: Hymn? = null

    fun isPlayingHymn(hymnal: String, hymn: Hymn): Boolean = isPlaying && loadedKey == key(hymnal, hymn)
    fun isLoaded(hymnal: String, hymn: Hymn): Boolean = loadedKey == key(hymnal, hymn)

    /** Starts `hymn` from the top. False if its file couldn't be opened. */
    fun start(hymnal: String, hymn: Hymn): Boolean {
        val asset = hymn.midiAsset ?: return false
        stop()
        return try {
            val mp = MediaPlayer()
            context.assets.openFd(asset).use { fd -> mp.setDataSource(fd.fileDescriptor, fd.startOffset, fd.length) }
            mp.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build(),
            )
            mp.setOnCompletionListener {
                isPlaying = false
                Analytics.track(AnalyticsEvent.AccompanimentCompleted(hymn.number, hymn.verseCount))
                stop()
            }
            mp.prepare()
            mp.start()
            player = mp
            loadedHymn = hymn
            loadedKey = key(hymnal, hymn)
            isPlaying = true
            Analytics.track(AnalyticsEvent.AccompanimentPlayed(hymn.number, resumed = false))
            true
        } catch (e: Exception) {
            Analytics.error("audio", e.javaClass.simpleName)
            stop()
            false
        }
    }

    fun resume() {
        val mp = player ?: return
        val hymn = loadedHymn ?: return
        mp.start()
        isPlaying = true
        Analytics.track(AnalyticsEvent.AccompanimentPlayed(hymn.number, resumed = true))
    }

    fun pause() {
        val mp = player ?: return
        val hymn = loadedHymn ?: return
        if (!mp.isPlaying) return
        mp.pause()
        isPlaying = false
        val progress = if (mp.duration > 0) (mp.currentPosition * 100 / mp.duration) else 0
        Analytics.track(AnalyticsEvent.AccompanimentPaused(hymn.number, progress))
    }

    fun stop() {
        runCatching { player?.stop() }
        player?.release()
        player = null
        loadedHymn = null
        loadedKey = null
        isPlaying = false
    }

    private fun key(hymnal: String, hymn: Hymn) = "$hymnal#${hymn.number}"
}
