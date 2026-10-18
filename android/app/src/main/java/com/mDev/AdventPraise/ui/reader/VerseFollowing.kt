// OWNER: reader
package com.mDev.AdventPraise.ui.reader

import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import com.mDev.AdventPraise.data.Block
import com.mDev.AdventPraise.data.Hymn
import com.mDev.AdventPraise.ui.design.BlockState

/**
 * Where the accompaniment is in the hymn on screen (HymnMIDIEngine.position on
 * iOS): the verse it is on (0 before the first), whether it is in that pass's
 * chorus, and the line being sung.
 */
@Immutable
data class PlayerPosition(val verse: Int, val isChorus: Boolean, val line: Int?)

/**
 * The seam the reader follows the accompaniment through. The music area
 * provides one at the root, reading its AccompanimentTransport (the TV is the
 * clock while casting); until then nothing is followed. [position] is null
 * unless this hymn is up in the player; [isPlaying] keeps the verse in view.
 */
interface VerseFollowing {
    @Composable fun position(hymnalId: String, hymn: Hymn): PlayerPosition?
    @Composable fun isPlaying(hymnalId: String, hymn: Hymn): Boolean

    companion object {
        val None = object : VerseFollowing {
            @Composable override fun position(hymnalId: String, hymn: Hymn): PlayerPosition? = null
            @Composable override fun isPlaying(hymnalId: String, hymn: Hymn): Boolean = false
        }
    }
}

val LocalVerseFollowing = staticCompositionLocalOf { VerseFollowing.None }

/**
 * A lyric block with an identity that survives "Chorus after every verse"
 * being toggled: the nth verse is always "v n", the nth chorus "c n"
 * (ReaderBlock). A chorus remembers the verse just above it.
 */
@Immutable
data class ReaderBlock(val id: String, val block: Block, val precedingVerse: Int? = null) {
    companion object {
        fun list(blocks: List<Block>): List<ReaderBlock> {
            var verses = 0
            var choruses = 0
            var lastVerse: Int? = null
            return blocks.map { block ->
                when (block) {
                    is Block.Verse -> {
                        verses += 1
                        lastVerse = block.number
                        ReaderBlock("v$verses", block)
                    }
                    is Block.Chorus -> {
                        choruses += 1
                        ReaderBlock("c$choruses", block, lastVerse)
                    }
                }
            }
        }

        /**
         * While the accompaniment plays, the verse it is on is current and the
         * rest dim. The chorus is current during the chorus part of each pass;
         * with "chorus after every verse" on, only the copy after that verse.
         */
        fun state(item: ReaderBlock, position: PlayerPosition?, repeatChorus: Boolean): BlockState {
            position ?: return BlockState.Normal
            return when (val block = item.block) {
                is Block.Verse -> if (!position.isChorus && block.number == position.verse) BlockState.Current else BlockState.Dimmed
                is Block.Chorus -> when {
                    !position.isChorus -> BlockState.Dimmed
                    // Shown once, or a hymn with no verses: the one chorus is current.
                    !repeatChorus || position.verse == 0 -> BlockState.Current
                    item.precedingVerse == position.verse -> BlockState.Current
                    else -> BlockState.Dimmed
                }
            }
        }
    }
}
