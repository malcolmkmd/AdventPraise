package com.mDev.AdventPraise.settings

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.data.SheetMusicViewMode

/** The accompaniment's speed (PlaybackTempo on iOS); `rate` scales the written tempo. */
enum class PlaybackTempo(val key: String, val label: String, val rate: Float) {
    Slow("slow", "Slow", 0.8f),
    Medium("medium", "Medium", 1f),
    Fast("fast", "Fast", 1.2f);

    companion object {
        fun of(key: String?): PlaybackTempo? = entries.firstOrNull { it.key == key }
    }
}

/**
 * The rest of what iOS keeps in UserDefaults, under the same keys: the
 * onboarding tour and What's New seen, the sheet music viewer's Page |
 * System mode, the player's tempo, church mode's recent announcements and
 * the feature board's first-open notice. "Share anonymous usage" lives in
 * [Analytics.isEnabled]; reading choices and haptics in [ReadingSettings].
 */
class AppSettings(private val store: KeyValueStore) {
    constructor(context: Context) : this(SharedPreferencesStore(context, ReadingSettings.PREFS_NAME))

    /** The onboarding tour was finished or skipped ("tourSeen"; 7.0.1's "tour.completed" honoured). */
    var tourSeen by mutableStateOf(store.getBoolean(TOUR_SEEN) == true || store.getBoolean(TOUR_LEGACY) == true)
        private set

    /** The What's New version last shown ("whatsNew.lastSeenVersion"); "" before any. */
    var whatsNewLastSeen by mutableStateOf(store.getString(WHATS_NEW) ?: "")
        private set

    /** The full-screen sheet music viewer: the whole page or system by system. */
    var sheetMusicViewMode by mutableStateOf(SheetMusicViewMode.of(store.getString(SHEET_MUSIC_MODE)) ?: SheetMusicViewMode.Page)
        private set

    var tempo by mutableStateOf(PlaybackTempo.of(store.getString(TEMPO)) ?: PlaybackTempo.Medium)
        private set

    /** Church mode's last six announcements, newest first. */
    var announcementRecents by mutableStateOf(decodeList(store.getString(ANNOUNCEMENTS)))
        private set

    /** The feature board's notice was accepted (epoch millis), or null. */
    val featureBoardDisclosedAt: Long? get() = store.getLong(FEATURE_BOARD_DISCLOSED)

    /** "Share anonymous usage" (More → About). */
    var sharesUsage: Boolean
        get() = Analytics.isEnabled
        set(value) { Analytics.isEnabled = value }

    fun markTourSeen() {
        tourSeen = true
        store.putBoolean(TOUR_SEEN, true)
    }

    /** What's New shows once per major version: true when `version` hasn't been seen. */
    fun shouldShowWhatsNew(version: String): Boolean = whatsNewLastSeen != version

    fun markWhatsNewSeen(version: String) {
        whatsNewLastSeen = version
        store.putString(WHATS_NEW, version)
    }

    fun updateSheetMusicViewMode(mode: SheetMusicViewMode) {
        sheetMusicViewMode = mode
        store.putString(SHEET_MUSIC_MODE, mode.key)
    }

    fun updateTempo(value: PlaybackTempo) {
        tempo = value
        store.putString(TEMPO, value.key)
    }

    /** Adds `message` to the top of the recent announcements (six kept, no repeats). */
    fun addAnnouncement(message: String): List<String> {
        val list = (listOf(message) + announcementRecents.filter { it != message }).take(6)
        announcementRecents = list
        store.putString(ANNOUNCEMENTS, com.mDev.AdventPraise.data.Json.write(list))
        return list
    }

    /** Swipe to delete in the announcement sheet's Recent list. */
    fun removeAnnouncement(message: String) {
        announcementRecents = announcementRecents.filter { it != message }
        store.putString(ANNOUNCEMENTS, com.mDev.AdventPraise.data.Json.write(announcementRecents))
    }

    fun markFeatureBoardDisclosed(atMillis: Long = System.currentTimeMillis()) = store.putLong(FEATURE_BOARD_DISCLOSED, atMillis)

    private fun decodeList(text: String?): List<String> =
        (text?.let(com.mDev.AdventPraise.data.Json::parseOrNull) as? List<*>).orEmpty().filterIsInstance<String>()

    companion object {
        const val TOUR_SEEN = "tourSeen"
        const val TOUR_LEGACY = "tour.completed"
        const val WHATS_NEW = "whatsNew.lastSeenVersion"
        const val SHEET_MUSIC_MODE = "sheetMusic.viewMode"
        const val TEMPO = "player.tempo"
        const val ANNOUNCEMENTS = "church.announcements.recent"
        const val FEATURE_BOARD_DISCLOSED = "featureBoard.disclosedAt"
    }
}
