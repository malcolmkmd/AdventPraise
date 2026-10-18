package com.mDev.AdventPraise.church

import androidx.compose.runtime.snapshotFlow
import com.mDev.AdventPraise.data.Hymn
import com.mDev.AdventPraise.data.HymnQueue
import com.mDev.AdventPraise.data.Hymnal
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach

/**
 * Keeps [ChurchSession] on the reader's hymn (iOS's ChurchPresentation reads
 * `model.hymn` directly): the open hymn and hymnal, the hymnal's word for
 * the chorus, and whether Next hymn has somewhere to go (the running
 * playlist or service plan, else the next number). Following twice is
 * harmless: the same hymn changes nothing.
 */
object ChurchReaderLink {
    private data class Snapshot(val hymnal: Hymnal, val hymn: Hymn, val hasNext: Boolean)

    fun start(
        session: ChurchSession,
        scope: CoroutineScope,
        hymnal: () -> Hymnal?,
        hymn: () -> Hymn?,
        queue: HymnQueue,
    ) {
        snapshotFlow {
            val h = hymnal() ?: return@snapshotFlow null
            val current = hymn() ?: return@snapshotFlow null
            Snapshot(h, current, queue.upcomingHymn(h, current) != null)
        }
            .filterNotNull()
            .distinctUntilChanged()
            .onEach { (h, current, hasNext) ->
                session.follow(current, h.id, h.name, h.chorusLabel, hasNext)
            }
            .launchIn(scope)
    }
}
