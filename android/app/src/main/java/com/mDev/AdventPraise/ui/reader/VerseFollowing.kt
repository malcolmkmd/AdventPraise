// OWNER: reader
package com.mDev.AdventPraise.ui.reader

import androidx.compose.runtime.Immutable
import com.mDev.AdventPraise.audio.PlaybackPosition
import com.mDev.AdventPraise.data.Block
import com.mDev.AdventPraise.ui.design.BlockState

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
        fun state(item: ReaderBlock, position: PlaybackPosition?, repeatChorus: Boolean): BlockState {
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
