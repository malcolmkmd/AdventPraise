package com.mDev.AdventPraise.data

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.analytics.HymnSource
import com.mDev.AdventPraise.analytics.PlaylistEdit
import com.mDev.AdventPraise.settings.KeyValueStore
import java.util.UUID

/** A saved, ordered list of hymn numbers in one hymnal (Playlist on iOS). Each hymn appears once. */
data class Playlist(val id: String, val name: String, val hymnNumbers: List<Int>) {
    fun toJson(): Map<String, Any?> = linkedMapOf("id" to id, "name" to name, "hymnNumbers" to hymnNumbers)

    companion object {
        /** iOS writes UUIDs upper-case; so does Android, so the two read alike. */
        fun newId(): String = UUID.randomUUID().toString().uppercase()

        fun fromJson(value: Any?): Playlist? = runCatching {
            val o = value.jsonObject()!!
            Playlist(o["id"].jsonString()!!, o["name"].jsonString()!!, o["hymnNumbers"].jsonArray()!!.map { it.jsonInt()!! })
        }.getOrNull()
    }
}

/**
 * A playlist or service plan in progress: its hymns in order, the open one
 * and the one Next goes to (both null when off the list or at its end).
 */
data class RunningQueue(val name: String, val numbers: List<Int>, val current: Int?, val next: Int?) {
    /** Where `number` is on the list: the first time after the open hymn, else the first time at all. */
    fun index(of: Int): Int? {
        val after = (current ?: -1) + 1
        return (after until numbers.size).firstOrNull { numbers[it] == of } ?: numbers.indexOf(of).takeIf { it >= 0 }
    }
}

/**
 * Every playlist, per hymnal id (hymn numbers mean different hymns in each
 * hymnal), saved as iOS saves them: JSON `{hymnal id: [Playlist]}` under
 * "reader.playlists.v2". The mutations and their analytics are iOS's
 * (ReaderModel's playlist section); haptics are the caller's.
 */
class PlaylistBook(private val store: KeyValueStore) {
    var byHymnal: Map<String, List<Playlist>> by mutableStateOf(load())
        private set

    /** The open hymnal's playlists, in the order made. */
    fun playlists(hymnal: String): List<Playlist> = byHymnal[hymnal].orEmpty()

    fun playlist(hymnal: String, id: String): Playlist? = playlists(hymnal).firstOrNull { it.id == id }

    /** "Playlist N", skipping names already in use. */
    fun nextName(hymnal: String): String {
        val lists = playlists(hymnal)
        val names = lists.map { it.name }.toSet()
        var n = lists.size + 1
        while ("Playlist $n" in names) n++
        return "Playlist $n"
    }

    /**
     * Creates a playlist holding `firstHymn` (the open hymn). An empty name
     * takes [nextName]. `isFirstEver` is true once, for the very first
     * playlist: the library then opens on Playlists after the editor closes.
     */
    fun create(hymnal: String, name: String, firstHymn: Int): Created {
        val trimmed = name.trim()
        val list = Playlist(Playlist.newId(), trimmed.ifEmpty { nextName(hymnal) }, listOf(firstHymn))
        val isFirstEver = playlists(hymnal).isEmpty() && store.getBoolean(KEY_FIRST_REVEALED) != true
        if (isFirstEver) store.putBoolean(KEY_FIRST_REVEALED, true)
        set(hymnal, playlists(hymnal) + list)
        Analytics.track(AnalyticsEvent.PlaylistCreated(list.hymnNumbers.size))
        return Created(list, isFirstEver)
    }

    data class Created(val playlist: Playlist, val isFirstEver: Boolean)

    /** An empty name keeps the old one. */
    fun rename(hymnal: String, id: String, name: String) {
        val trimmed = name.trim()
        if (trimmed.isEmpty()) return
        update(hymnal, id, PlaylistEdit.Renamed) { if (it.name == trimmed) null else it.copy(name = trimmed) }
    }

    /** Adds a hymn at the end; a playlist holds each hymn once. False when nothing changed. */
    fun add(hymnal: String, id: String, number: Int): Boolean =
        update(hymnal, id, PlaylistEdit.HymnAdded) { if (number in it.hymnNumbers) null else it.copy(hymnNumbers = it.hymnNumbers + number) }

    fun remove(hymnal: String, id: String, number: Int): Boolean =
        update(hymnal, id, PlaylistEdit.HymnRemoved) { if (number !in it.hymnNumbers) null else it.copy(hymnNumbers = it.hymnNumbers - number) }

    /** Removes the entries at `offsets` (a swipe or Edit's delete). */
    fun removeAt(hymnal: String, id: String, offsets: Set<Int>): Boolean =
        update(hymnal, id, PlaylistEdit.HymnRemoved) { list ->
            list.copy(hymnNumbers = list.hymnNumbers.filterIndexed { i, _ -> i !in offsets })
        }

    /** The drop of a drag reorder: SwiftUI's `move(fromOffsets:toOffset:)`. */
    fun move(hymnal: String, id: String, from: Set<Int>, to: Int): Boolean =
        update(hymnal, id, PlaylistEdit.Reordered) { it.copy(hymnNumbers = moved(it.hymnNumbers, from, to)) }

    /** Moves one hymn up (-1) or down (+1): the accessibility alternative to dragging. */
    fun moveHymn(hymnal: String, id: String, number: Int, by: Int): Boolean =
        update(hymnal, id, PlaylistEdit.Reordered) { list ->
            val from = list.hymnNumbers.indexOf(number)
            val to = from + by
            if (from < 0 || to !in list.hymnNumbers.indices) return@update null
            val numbers = list.hymnNumbers.toMutableList()
            numbers[from] = numbers[to].also { numbers[to] = numbers[from] }
            list.copy(hymnNumbers = numbers)
        }

    /** Always after a confirmation. */
    fun delete(hymnal: String, id: String) {
        val list = playlist(hymnal, id) ?: return
        set(hymnal, playlists(hymnal).filterNot { it.id == id })
        Analytics.track(AnalyticsEvent.PlaylistDeleted(list.hymnNumbers.size))
    }

    private fun update(hymnal: String, id: String, edit: PlaylistEdit, change: (Playlist) -> Playlist?): Boolean {
        val lists = playlists(hymnal)
        val i = lists.indexOfFirst { it.id == id }
        if (i < 0) return false
        val next = change(lists[i]) ?: return false
        set(hymnal, lists.toMutableList().also { it[i] = next })
        Analytics.track(AnalyticsEvent.PlaylistEdited(edit, next.hymnNumbers.size))
        return true
    }

    private fun set(hymnal: String, lists: List<Playlist>) {
        byHymnal = if (lists.isEmpty()) byHymnal - hymnal else byHymnal + (hymnal to lists)
        store.putString(KEY_PLAYLISTS, Json.write(byHymnal.mapValues { (_, v) -> v.map { it.toJson() } }))
    }

    private fun load(): Map<String, List<Playlist>> {
        val text = store.getString(KEY_PLAYLISTS) ?: return emptyMap()
        return Json.parseOrNull(text).jsonObject().orEmpty()
            .mapValues { (_, v) -> v.jsonArray().orEmpty().mapNotNull(Playlist::fromJson) }
            .filterValues { it.isNotEmpty() }
    }

    companion object {
        const val KEY_PLAYLISTS = "reader.playlists.v2"
        /** Set once the library has opened on Playlists after the first playlist. */
        const val KEY_FIRST_REVEALED = "reader.firstPlaylistRevealed"

        /** SwiftUI's `Array.move(fromOffsets:toOffset:)`. */
        fun <T> moved(list: List<T>, from: Set<Int>, to: Int): List<T> {
            val picked = from.filter { it in list.indices }.sorted()
            val moving = picked.map { list[it] }
            val rest = list.filterIndexed { i, _ -> i !in picked }
            val insertAt = (to - picked.count { it < to }).coerceIn(0, rest.size)
            return rest.subList(0, insertAt) + moving + rest.subList(insertAt, rest.size)
        }
    }
}

/**
 * Following a playlist, service plan or collection through the hymnal (the
 * queue half of iOS's ReaderModel): what Next and Previous open, the
 * running queue for church mode's number pad, "Sabbath · 2 of 5".
 *
 * Every method takes the open hymnal and hymn and returns the hymn to show;
 * the reader shows it (recents, last hymn, `hymn_opened`). Opening a hymn
 * any other way, or switching hymnal, calls [stop].
 */
class HymnQueue(private val book: PlaylistBook) {
    private data class ActivePlaylist(val id: String, val index: Int)
    private data class ActiveQueue(val numbers: List<Int>, val index: Int, val name: String, val source: HymnSource)

    private var activePlaylist: ActivePlaylist? by mutableStateOf(null)
    private var activeQueue: ActiveQueue? by mutableStateOf(null)

    val activePlaylistId: String? get() = activePlaylist?.id
    val isRunning: Boolean get() = activePlaylist != null || activeQueue != null

    /** Off the list: a hymn opened by number, search or swipe back, or another hymnal. */
    fun stop() {
        activePlaylist = null
        activeQueue = null
    }

    /** A playlist was deleted: stop following it. */
    fun onDeleted(id: String) {
        if (activePlaylist?.id == id) activePlaylist = null
    }

    /** The next number, or the next queue entry this hymnal has while a queue runs. */
    fun nextHymn(hymnal: Hymnal, hymn: Hymn): Hymn? {
        activeQueue?.let { q -> return q.numbers.drop(q.index + 1).firstNotNullOfOrNull(hymnal::hymn) }
        return hymnal.hymnAfter(hymn.number, 1)
    }

    fun previousHymn(hymnal: Hymnal, hymn: Hymn): Hymn? = hymnal.hymnAfter(hymn.number, -1)

    /** Where "next" goes: the next playlist entry while a playlist runs, else [nextHymn]. */
    fun upcomingHymn(hymnal: Hymnal, hymn: Hymn): Hymn? = playlistEntry(hymnal, hymn, 1)?.first ?: nextHymn(hymnal, hymn)

    /** Where "previous" goes: back through the running playlist, else the previous number. */
    fun precedingHymn(hymnal: Hymnal, hymn: Hymn): Hymn? = playlistEntry(hymnal, hymn, -1)?.first ?: previousHymn(hymnal, hymn)

    /**
     * Next hymn (goToNextHymn): the next playlist or queue entry, else the
     * next number. A finished queue ends there (null); a finished playlist
     * carries on by number.
     */
    fun goToNext(hymnal: Hymnal, hymn: Hymn): Hymn? {
        val wasQueued = activeQueue != null
        advance(hymnal, hymn)?.let { return it }
        if (wasQueued) return null
        return nextHymn(hymnal, hymn)
    }

    /** Previous hymn: back through the playlist, else the previous number (leaving the list). */
    fun goToPrevious(hymnal: Hymnal, hymn: Hymn): Hymn? {
        val id = activePlaylist?.id
        val entry = playlistEntry(hymnal, hymn, -1)
        if (entry != null && id != null) {
            activePlaylist = ActivePlaylist(id, entry.second)
            return entry.first
        }
        val previous = previousHymn(hymnal, hymn) ?: return null
        stop()
        return previous
    }

    /**
     * Moves on within the running playlist or queue (also the player's
     * end of hymn, which sends `playlist_advance`). Null, and the queue
     * stops, at its end.
     */
    fun advance(hymnal: Hymnal, hymn: Hymn): Hymn? {
        activeQueue?.let { q ->
            val index = (q.index + 1 until q.numbers.size).firstOrNull { hymnal.hymn(q.numbers[it]) != null }
            if (index == null) {
                activeQueue = null
                return null
            }
            activeQueue = q.copy(index = index)
            return hymnal.hymn(q.numbers[index])
        }
        val id = activePlaylist?.id
        val entry = playlistEntry(hymnal, hymn, 1)
        if (id == null || entry == null) {
            activePlaylist = null
            return null
        }
        activePlaylist = ActivePlaylist(id, entry.second)
        return entry.first
    }

    /**
     * Plays `playlist` from entry `start` (skipping numbers this hymnal
     * lacks): the hymn to open, sent as `source = playlist`, and the player
     * starts its accompaniment. Null when none of its hymns are here.
     */
    fun play(playlist: Playlist, hymnal: Hymnal, start: Int = 0): Hymn? {
        val index = (maxOf(start, 0) until playlist.hymnNumbers.size)
            .firstOrNull { hymnal.hymn(playlist.hymnNumbers[it]) != null } ?: return null
        val target = hymnal.hymn(playlist.hymnNumbers[index]) ?: return null
        Analytics.track(AnalyticsEvent.PlaylistPlayed(playlist.hymnNumbers.size, index))
        activePlaylist = ActivePlaylist(playlist.id, index)
        activeQueue = null
        return target
    }

    /**
     * Runs `numbers` in order like a playlist without saving it (a service
     * plan or collection). Numbers missing from the hymnal are skipped. Null if none exist.
     */
    fun play(numbers: List<Int>, name: String, source: HymnSource, hymnal: Hymnal): Hymn? {
        val start = numbers.indexOfFirst { hymnal.hymn(it) != null }.takeIf { it >= 0 } ?: return null
        activePlaylist = null
        activeQueue = ActiveQueue(numbers, start, name, source)
        return hymnal.hymn(numbers[start])
    }

    /** Play can start: at least one entry is in the hymnal. */
    fun canPlay(playlist: Playlist, hymnal: Hymnal): Boolean = playlist.hymnNumbers.any { hymnal.hymn(it) != null }

    /** The playlist or service plan being followed, for church mode's number pad. */
    fun runningQueue(hymnal: Hymnal, hymn: Hymn): RunningQueue? {
        activeQueue?.let { q ->
            val current = if (q.index in q.numbers.indices && q.numbers[q.index] == hymn.number) q.index else null
            val next = (q.index + 1 until q.numbers.size).firstOrNull { hymnal.hymn(q.numbers[it]) != null }
            return RunningQueue(q.name, q.numbers, current, next)
        }
        val (list, index) = activePosition(hymnal, hymn) ?: return null
        val current = if (index in list.hymnNumbers.indices && list.hymnNumbers[index] == hymn.number) index else null
        return RunningQueue(list.name, list.hymnNumbers, current, playlistEntry(hymnal, hymn, 1)?.second)
    }

    /**
     * Opens entry `index` of the running playlist or queue and follows it
     * from there: the hymn and the source to send. Null if nothing runs or
     * the hymnal lacks that hymn.
     */
    fun jump(index: Int, hymnal: Hymnal, hymn: Hymn): Pair<Hymn, HymnSource>? {
        activeQueue?.let { q ->
            val target = q.numbers.getOrNull(index)?.let(hymnal::hymn) ?: return null
            activeQueue = q.copy(index = index)
            return target to q.source
        }
        val (list, _) = activePosition(hymnal, hymn) ?: return null
        val target = list.hymnNumbers.getOrNull(index)?.let(hymnal::hymn) ?: return null
        activePlaylist = ActivePlaylist(list.id, index)
        return target to HymnSource.Playlist
    }

    /** "Sabbath · 2 of 5" while a playlist is running and its hymn is open. */
    fun progress(hymnal: Hymnal, hymn: Hymn): String? {
        val (list, index) = activePosition(hymnal, hymn) ?: return null
        if (list.hymnNumbers.getOrNull(index) != hymn.number) return null
        return "${list.name} · ${index + 1} of ${list.hymnNumbers.size}"
    }

    /**
     * Where the open hymn sits in the running playlist. Follows the hymn
     * rather than the stored index, so editing a running playlist doesn't
     * derail it; if the open hymn was removed, carries on from where it was.
     */
    private fun activePosition(hymnal: Hymnal, hymn: Hymn): Pair<Playlist, Int>? {
        val active = activePlaylist ?: return null
        val list = book.playlist(hymnal.id, active.id) ?: return null
        val found = list.hymnNumbers.indexOf(hymn.number)
        if (found >= 0) return list to found
        return list to (minOf(active.index, list.hymnNumbers.size) - 1)
    }

    /** The entry `step` places from the open hymn that this hymnal has, skipping numbers it lacks. */
    private fun playlistEntry(hymnal: Hymnal, hymn: Hymn, step: Int): Pair<Hymn, Int>? {
        val (list, index) = activePosition(hymnal, hymn) ?: return null
        // When the open hymn was removed, `index` is the entry before the gap.
        val onHymn = list.hymnNumbers.getOrNull(index) == hymn.number
        var i = if (step < 0 && !onHymn) index else index + step
        while (i in list.hymnNumbers.indices) {
            hymnal.hymn(list.hymnNumbers[i])?.let { return it to i }
            i += step
        }
        return null
    }
}
