package com.mDev.AdventPraise.settings

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.data.Numbering

/**
 * What the reader remembers between launches (ReaderModel's UserDefaults on
 * iOS), under the iOS keys: the open hymnal, the last hymn and the last
 * three opened, kept per numbering (Christ In Song and its translations
 * share the plain keys, the SDA Hymnal has its own), and favourites per
 * hymnal ("english#12").
 */
class ReaderHistory(private val store: KeyValueStore) {
    constructor(context: Context) : this(SharedPreferencesStore(context, PREFS_NAME))

    /** Favourites across hymnals, "<hymnal>#<number>". */
    var favourites by mutableStateOf(store.getStringSet(KEY_FAVOURITES).orEmpty())
        private set

    /** The hymnal open at the last launch. */
    val hymnalId: String? get() = store.getString(KEY_HYMNAL)

    fun setHymnal(id: String) = store.putString(KEY_HYMNAL, id)

    /** The last hymn read in `numbering`, or null before any. */
    fun lastHymn(numbering: Numbering): Int? = store.getInt(lastHymnKey(numbering))

    /** The last three hymns opened in `numbering`, newest first. */
    fun recents(numbering: Numbering): List<Int> =
        store.getString(recentsKey(numbering)).orEmpty().split(',').mapNotNull { it.trim().toIntOrNull() }

    /** A hymn was shown: it becomes the last hymn and goes to the top of the recents. Returns the recents. */
    fun recordOpened(numbering: Numbering, number: Int): List<Int> {
        val recents = (listOf(number) + recents(numbering).filter { it != number }).take(3)
        store.putInt(lastHymnKey(numbering), number)
        store.putString(recentsKey(numbering), recents.joinToString(","))
        return recents
    }

    fun isFavourite(hymnal: String, number: Int): Boolean = key(hymnal, number) in favourites

    /** The favourites of `hymnal`, by number. */
    fun favouriteNumbers(hymnal: String): List<Int> = favourites.mapNotNull { key ->
        val parts = key.split('#')
        if (parts.size == 2 && parts[0] == hymnal) parts[1].toIntOrNull() else null
    }.sorted()

    /** Stars or unstars a hymn; returns whether it is a favourite now. Sends `favourite_toggled`. */
    fun toggleFavourite(hymnal: String, number: Int): Boolean {
        val key = key(hymnal, number)
        val now = key !in favourites
        save(if (now) favourites + key else favourites - key)
        Analytics.track(AnalyticsEvent.FavouriteToggled(number, now))
        return now
    }

    /** The library's Add hymn: stars it (one already starred stays so). */
    fun addFavourite(hymnal: String, number: Int) {
        val key = key(hymnal, number)
        if (key in favourites) return
        save(favourites + key)
        Analytics.track(AnalyticsEvent.FavouriteToggled(number, true))
    }

    private fun save(next: Set<String>) {
        favourites = next
        store.putStringSet(KEY_FAVOURITES, next)
    }

    private fun key(hymnal: String, number: Int) = "$hymnal#$number"

    companion object {
        const val PREFS_NAME = "reader"
        const val KEY_HYMNAL = "reader.hymnal"
        const val KEY_LAST_HYMN = "reader.lastHymn"
        const val KEY_FAVOURITES = "reader.favourites.v2"
        const val KEY_RECENTS = "reader.recents"

        fun lastHymnKey(n: Numbering) = if (n == Numbering.Sdah) "$KEY_LAST_HYMN.sdah" else KEY_LAST_HYMN
        fun recentsKey(n: Numbering) = if (n == Numbering.Sdah) "$KEY_RECENTS.sdah" else KEY_RECENTS
    }
}
