// OWNER: cast
package com.mDev.AdventPraise.cast

import com.mDev.AdventPraise.church.ChurchState
import java.security.MessageDigest
import java.util.Base64

/** Everything church mode puts on the TV at one moment. */
data class CastScene(
    /** The hymn whose words are up (church mode's hymn, the reader's). */
    val words: CastWords?,
    val screen: CastScreen,
    val announcement: String?,
    /** A picture's id in ChurchImages. */
    val image: String?,
) {
    companion object {
        /**
         * Church mode open: its block, Blank and specials. Closed: the title
         * card of the hymn up (iOS shows it between hymns). The worship display
         * is always dark; the text size and large print are the phone's.
         */
        fun of(state: ChurchState, worshipPointSize: Float, largePrint: Boolean): CastScene {
            val hymn = state.hymn
            val words = hymn?.let { CastWords(it, state.hymnalId, state.hymnalName, state.chorusLabel) }
            val theme = CastTheme(CastTheme.DARK, worshipPointSize, largePrint)
            if (!state.isActive) return CastScene(words, CastScreen(-1, false, theme), null, null)
            val last = maxOf(state.sequence.size - 1, 0)
            return CastScene(words, CastScreen(state.index.coerceIn(0, last), state.isBlanked, theme), state.announcement, state.image)
        }
    }
}

/**
 * Mirrors church mode onto the TV: the hymn (through [CastTransport.showHymn],
 * which carries the page, Blank and theme), then only what changed: `page`,
 * `blank` (after the page, as iOS ends Blank on a verse turn), `theme` and
 * `special` with its picture. [reset] makes the next scene go up whole (a new
 * session).
 */
class CastChurchMirror(
    private val transport: CastTransport,
    private val pictures: CastPictures,
) {
    private var last: CastScene? = null

    /** The scene now, for loads the player starts. */
    var current: CastScene? = null
        private set

    fun reset() {
        last = null
        pictures.reset()
    }

    fun apply(scene: CastScene) {
        val old = last
        last = scene
        current = scene
        val loaded = scene.words?.let(transport::showHymn) ?: false
        if (!loaded) {
            if (old == null || old.screen.pageIndex != scene.screen.pageIndex || old.words != scene.words) {
                transport.sendScreen(SenderMessage.Page(scene.screen.pageIndex))
            }
            if (old == null || old.screen.blank != scene.screen.blank) transport.sendScreen(SenderMessage.Blank(scene.screen.blank))
            if (old == null || old.screen.theme != scene.screen.theme) transport.sendScreen(SenderMessage.Theme(scene.screen.theme))
        }
        if ((old == null && (scene.announcement != null || scene.image != null)) ||
            (old != null && (old.announcement != scene.announcement || old.image != scene.image))) {
            pictures.show(scene.announcement, scene.image)
        }
    }
}

/**
 * Pictures for the TV (PROTOCOL.md `imageChunk`): fitted to 1920 × 1080,
 * JPEG, base64 in chunks of at most 48,000 characters, then `special`.
 * The receiver keeps the last four, so one sent this session goes up again
 * by id alone.
 */
class CastPictures(
    private val send: (SenderMessage) -> Unit,
    /** The fitted JPEG for a ChurchImages id, read off the main thread; null when it can't be. */
    private val load: suspend (String) -> ByteArray?,
    private val launch: (suspend () -> Unit) -> Unit,
) {
    private val sent = LinkedHashSet<String>()
    private var wanted: Pair<String?, String?>? = null

    fun reset() {
        sent.clear()
        wanted = null
    }

    fun show(announcement: String?, image: String?) {
        wanted = announcement to image
        if (image == null) { send(SenderMessage.Special(announcement, null)); return }
        val tvId = imageId(image)
        if (tvId in sent) { send(SenderMessage.Special(announcement, tvId)); return }
        launch {
            val bytes = load(image)
            if (wanted != (announcement to image)) return@launch
            if (bytes == null) { send(SenderMessage.Special(announcement, null)); return@launch }
            chunks(tvId, bytes).forEach(send)
            sent += tvId
            while (sent.size > RECEIVER_KEEPS) sent.remove(sent.first())
            send(SenderMessage.Special(announcement, tvId))
        }
    }

    companion object {
        const val RECEIVER_KEEPS = 4

        /** A short id for the TV, stable for a picture. */
        fun imageId(image: String): String =
            MessageDigest.getInstance("SHA-1").digest(image.toByteArray()).take(6).joinToString("") { "%02x".format(it) }

        fun chunks(imageId: String, jpeg: ByteArray, size: Int = CastProtocol.IMAGE_CHUNK_CHARS): List<SenderMessage.ImageChunk> {
            val data = Base64.getEncoder().encodeToString(jpeg)
            val pieces = data.chunked(size).ifEmpty { listOf("") }
            return pieces.mapIndexed { i, piece -> SenderMessage.ImageChunk(imageId, i, pieces.size, "image/jpeg", piece) }
        }
    }
}
