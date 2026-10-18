package com.mDev.AdventPraise.ui.playlists

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.data.Hymn
import com.mDev.AdventPraise.data.HymnQueue
import com.mDev.AdventPraise.data.Hymnal
import com.mDev.AdventPraise.data.Playlist
import com.mDev.AdventPraise.data.PlaylistBook
import com.mDev.AdventPraise.ui.design.HapticEvent
import com.mDev.AdventPraise.ui.design.Haptics

/**
 * One playlist's editor (PlaylistEditorView and ReaderModel's playlist
 * section): reorder by dragging or by one step, remove by swipe or Edit,
 * add or remove from the picker, rename, delete, play. Mutations go
 * through [PlaylistBook] (which saves and sends the analytics); haptics are
 * iOS's: a hymn added is a toggle on, removed a toggle off, a reorder a
 * selection tick, a delete one firm tap.
 */
class PlaylistEditorModel(
    private val book: PlaylistBook,
    private val queue: HymnQueue,
    /** The open hymnal's id: playlists live per hymnal. */
    private val hymnalId: () -> String?,
    val playlistId: String,
    private val haptic: (HapticEvent) -> Unit = Haptics::play,
) {
    val playlist: Playlist? get() = hymnalId()?.let { book.playlist(it, playlistId) }

    /** "1 hymn", "3 hymns". */
    val countText: String get() = countText(playlist?.hymnNumbers?.size ?: 0)

    /**
     * A drag dropped: the hymn at [from] now sits at [to] (both positions in
     * the list as it was). SwiftUI's `move(fromOffsets:toOffset:)` counts the
     * destination before removal, so a move down lands one further.
     */
    fun move(from: Int, to: Int) {
        val hymnal = hymnalId() ?: return
        if (from == to) return
        val offset = if (to > from) to + 1 else to
        if (book.move(hymnal, playlistId, setOf(from), offset)) haptic(HapticEvent.Selection)
    }

    /** Moves one hymn up (-1) or down (+1): TalkBack's Move up / Move down. */
    fun moveHymn(number: Int, by: Int) {
        val hymnal = hymnalId() ?: return
        if (book.moveHymn(hymnal, playlistId, number, by)) haptic(HapticEvent.Selection)
    }

    /** A swipe left, or Edit's delete. */
    fun removeAt(index: Int) {
        val hymnal = hymnalId() ?: return
        if (book.removeAt(hymnal, playlistId, setOf(index))) haptic(HapticEvent.ToggleOff)
    }

    fun remove(number: Int) {
        val hymnal = hymnalId() ?: return
        if (book.remove(hymnal, playlistId, number)) haptic(HapticEvent.ToggleOff)
    }

    /** Adds a hymn at the end; a playlist holds each hymn once. */
    fun add(number: Int) {
        val hymnal = hymnalId() ?: return
        if (book.add(hymnal, playlistId, number)) haptic(HapticEvent.ToggleOn)
    }

    /** The picker's row: in the playlist → out; out → added at the end. */
    fun toggle(number: Int) {
        if (playlist?.hymnNumbers?.contains(number) == true) remove(number) else add(number)
    }

    /** An empty name keeps the old one. */
    fun rename(name: String) {
        val hymnal = hymnalId() ?: return
        book.rename(hymnal, playlistId, name)
    }

    /** Always after a confirmation; stops following it if it was running. */
    fun delete() {
        val hymnal = hymnalId() ?: return
        if (book.playlist(hymnal, playlistId) == null) return
        queue.onDeleted(playlistId)
        book.delete(hymnal, playlistId)
        haptic(HapticEvent.MediumImpact)
    }

    /** Play can start: at least one entry is in this hymnal. */
    fun canPlay(hymnal: Hymnal?): Boolean = hymnal != null && playlist?.let { queue.canPlay(it, hymnal) } == true

    /** Starts following the playlist from entry [start]: the hymn to open, or null. */
    fun play(hymnal: Hymnal, start: Int = 0): Hymn? = playlist?.let { queue.play(it, hymnal, start) }

    companion object {
        fun countText(count: Int): String = if (count == 1) "1 hymn" else "$count hymns"
    }
}

/**
 * What the playlist screens do to the reader, in one place: play a list
 * (the reader shows its hymn and Next follows the list), add the open hymn,
 * start a new one. iOS's ReaderModel does these; here the queue and the
 * reader are separate, so they meet here.
 */
object PlaylistActions {
    /** Plays [playlist] from entry [start]: the reader opens it (`source = playlist`), the Lectern closes. */
    fun play(services: AppServices, playlist: Playlist, start: Int = 0): Boolean =
        // The reader turns the page and starts the accompaniment (onPlaylistStarted), as iOS's play(_:from:).
        services.reader.play(playlist, start)

    /** Adds the open hymn to [playlist] (the touch-and-hold menu, the tray's Playlist tile). */
    fun addCurrentHymn(services: AppServices, playlist: Playlist) {
        val hymnal = services.reader.hymnal ?: return
        val number = services.reader.hymn?.number ?: return
        if (services.playlists.add(hymnal.id, playlist.id, number)) Haptics.play(HapticEvent.ToggleOn)
    }
}

/**
 * Set once, when the very first playlist's editor closes: the library then
 * opens on its Playlists tab, so the reader sees where playlists live
 * (iOS's revealFirstPlaylist). The reader's library reads and clears it.
 */
object PlaylistReveal {
    var opensPlaylistsTab by mutableStateOf(false)
    /** The first playlist was just made; its editor's close shows the library. */
    internal var pending = false
}
