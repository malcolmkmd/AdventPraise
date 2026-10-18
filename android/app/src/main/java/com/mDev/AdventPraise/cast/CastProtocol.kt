// OWNER: cast
package com.mDev.AdventPraise.cast

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonObjectBuilder
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.longOrNull
import kotlinx.serialization.json.put

/**
 * Church mode on Cast, protocol v1 (android/cast-receiver/PROTOCOL.md): the
 * phone (sender) and our custom Web Receiver talk JSON over one namespace.
 * The phone owns what is on screen; the TV owns audio time.
 */
object CastProtocol {
    const val NAMESPACE = "urn:x-cast:com.mDev.AdventPraise.church"
    const val VERSION = 1
    /** Pictures travel base64 in pieces of at most this many characters (a Cast message is at most 64 KB). */
    const val IMAGE_CHUNK_CHARS = 48_000
    /** Pictures are downscaled to fit this before they are sent. */
    const val IMAGE_MAX_WIDTH = 1920
    const val IMAGE_MAX_HEIGHT = 1080

    internal val json = Json { ignoreUnknownKeys = true }
}

/** One page of the sung sequence. [kind] is `verse` or `chorus`. */
data class CastPage(val kind: String, val label: String, val lines: List<String>) {
    companion object {
        const val VERSE = "verse"
        const val CHORUS = "chorus"
    }
}

/** The worship display's look. Missing fields keep the receiver's current values. */
data class CastTheme(val appearance: String = DARK, val worshipPointSize: Float = 42f, val largePrint: Boolean = false) {
    companion object {
        /** iOS's worship display is always dark (the Stage ground). */
        const val DARK = "dark"
        const val LIGHT = "light"
    }
}

/** A message from the phone to the TV. */
sealed interface SenderMessage {
    val type: String

    data class Load(
        val hymnalKey: String,
        val hymnalName: String,
        val number: Int,
        val title: String,
        val pages: List<CastPage>,
        /** An index into [pages], or -1 for the title card. */
        val pageIndex: Int = 0,
        val blank: Boolean = false,
        val theme: CastTheme? = null,
        /** The file in the receiver's `midi/`, or null for words only. */
        val midi: String? = null,
        val passes: Int? = null,
        val tempo: Float? = null,
        val autoplay: Boolean = false,
        val startMs: Long = 0,
    ) : SenderMessage {
        override val type get() = "load"
        /** The receiver's `hymnKey` for this hymn. */
        val hymnKey: String get() = "$hymnalKey-$number"
    }

    data class Page(val pageIndex: Int) : SenderMessage { override val type get() = "page" }
    data class Blank(val on: Boolean) : SenderMessage { override val type get() = "blank" }
    data class Theme(val theme: CastTheme) : SenderMessage { override val type get() = "theme" }
    data class Special(val announcement: String?, val imageId: String?) : SenderMessage { override val type get() = "special" }
    data class ImageChunk(val imageId: String, val index: Int, val count: Int, val mime: String, val data: String) : SenderMessage {
        override val type get() = "imageChunk"
    }
    data class Play(val fromMs: Long? = null) : SenderMessage { override val type get() = "play" }
    data object Pause : SenderMessage { override val type get() = "pause" }
    data object Stop : SenderMessage { override val type get() = "stop" }
    data class Seek(val ms: Long) : SenderMessage { override val type get() = "seek" }
    data class Tempo(val rate: Float) : SenderMessage { override val type get() = "tempo" }
    data object GetStatus : SenderMessage { override val type get() = "getStatus" }
    data class Ping(val id: Int) : SenderMessage { override val type get() = "ping" }

    fun toJsonObject(): JsonObject = buildJsonObject {
        put("v", CastProtocol.VERSION)
        put("type", type)
        when (val m = this@SenderMessage) {
            is Load -> {
                put("hymnalKey", m.hymnalKey)
                put("hymnalName", m.hymnalName)
                put("number", m.number)
                put("title", m.title)
                put("pages", buildJsonArray {
                    for (page in m.pages) add(buildJsonObject {
                        put("kind", page.kind)
                        put("label", page.label)
                        put("lines", JsonArray(page.lines.map(::JsonPrimitive)))
                    })
                })
                put("pageIndex", m.pageIndex)
                put("blank", m.blank)
                m.theme?.let { put("theme", buildJsonObject { theme(it) }) }
                put("midi", m.midi)
                m.passes?.let { put("passes", it) }
                m.tempo?.let { put("tempo", number(it)) }
                put("autoplay", m.autoplay)
                put("startMs", m.startMs)
            }
            is Page -> put("pageIndex", m.pageIndex)
            is Blank -> put("on", m.on)
            is Theme -> theme(m.theme)
            is Special -> { put("announcement", m.announcement); put("imageId", m.imageId) }
            is ImageChunk -> {
                put("imageId", m.imageId); put("index", m.index); put("count", m.count)
                put("mime", m.mime); put("data", m.data)
            }
            is Play -> m.fromMs?.let { put("fromMs", it) }
            is Seek -> put("ms", m.ms)
            is Tempo -> put("rate", number(m.rate))
            is Ping -> put("id", m.id)
            Pause, Stop, GetStatus -> Unit
        }
    }

    fun toJson(): String = toJsonObject().toString()

    companion object {
        private fun JsonObjectBuilder.theme(theme: CastTheme) {
            put("appearance", theme.appearance)
            put("worshipPointSize", number(theme.worshipPointSize))
            put("largePrint", theme.largePrint)
        }

        /** 1 rather than 1.0, 0.8 rather than 0.800000011920929. */
        internal fun number(value: Float): JsonPrimitive {
            val whole = value.toLong()
            return if (whole.toFloat() == value) JsonPrimitive(whole) else JsonPrimitive(value.toString().toDouble())
        }

        /** Reads a sender message (the fake receiver in tests; a receiver would). Null when it isn't one. */
        fun parse(text: String): SenderMessage? = runCatching {
            val o = CastProtocol.json.parseToJsonElement(text) as JsonObject
            when (o.string("type")) {
                "load" -> Load(
                    hymnalKey = o.string("hymnalKey")!!,
                    hymnalName = o.string("hymnalName") ?: "",
                    number = o.int("number")!!,
                    title = o.string("title")!!,
                    pages = (o["pages"] as JsonArray).map { p ->
                        val page = p as JsonObject
                        CastPage(page.string("kind") ?: CastPage.VERSE, page.string("label") ?: "",
                            (page["lines"] as? JsonArray).orEmpty().map { it.jsonPrimitive.content })
                    },
                    pageIndex = o.int("pageIndex") ?: 0,
                    blank = o.bool("blank") ?: false,
                    theme = (o["theme"] as? JsonObject)?.let(::theme),
                    midi = o.string("midi"),
                    passes = o.int("passes"),
                    tempo = o.double("tempo")?.toFloat(),
                    autoplay = o.bool("autoplay") ?: false,
                    startMs = o.long("startMs") ?: 0,
                )
                "page" -> Page(o.int("pageIndex")!!)
                "blank" -> Blank(o.bool("on")!!)
                "theme" -> Theme(theme(o))
                "special" -> Special(o.string("announcement"), o.string("imageId"))
                "imageChunk" -> ImageChunk(o.string("imageId")!!, o.int("index")!!, o.int("count")!!,
                    o.string("mime") ?: "image/jpeg", o.string("data")!!)
                "play" -> Play(o.long("fromMs"))
                "pause" -> Pause
                "stop" -> Stop
                "seek" -> Seek(o.long("ms")!!)
                "tempo" -> Tempo(o.double("rate")!!.toFloat())
                "getStatus" -> GetStatus
                "ping" -> Ping(o.int("id") ?: 0)
                else -> null
            }
        }.getOrNull()

        private fun theme(o: JsonObject) = CastTheme(
            appearance = o.string("appearance") ?: CastTheme.DARK,
            worshipPointSize = o.double("worshipPointSize")?.toFloat() ?: 42f,
            largePrint = o.bool("largePrint") ?: false,
        )
    }
}

/** A message from the TV to the phone. */
sealed interface ReceiverMessage {
    data class Status(
        /** idle, loading, playing, paused or ended. */
        val state: String,
        val positionMs: Long,
        val durationMs: Long,
        val passDurationMs: Long,
        val pass: Int,
        val passes: Int,
        val rate: Float,
        val sentAtEpochMs: Long,
        /** "<hymnalKey>-<number>", null before a load. */
        val hymnKey: String?,
        val pageIndex: Int?,
        val blank: Boolean,
        val midi: String?,
        val seq: Long,
    ) : ReceiverMessage

    data class Pong(val id: Int?, val receivedAtEpochMs: Long) : ReceiverMessage

    data class Error(val code: String, val message: String, val request: String?) : ReceiverMessage

    companion object {
        /** Null for anything that isn't a v1 message we know (the receiver may add types). */
        fun parse(text: String): ReceiverMessage? = runCatching {
            val o = CastProtocol.json.parseToJsonElement(text) as JsonObject
            when (o.string("type")) {
                "status" -> Status(
                    state = o.string("state") ?: "idle",
                    positionMs = o.long("positionMs") ?: 0,
                    durationMs = o.long("durationMs") ?: 0,
                    passDurationMs = o.long("passDurationMs") ?: 0,
                    pass = o.int("pass") ?: 0,
                    passes = o.int("passes") ?: 0,
                    rate = o.double("rate")?.toFloat() ?: 1f,
                    sentAtEpochMs = o.long("sentAtEpochMs") ?: 0,
                    hymnKey = o.string("hymnKey"),
                    pageIndex = o.int("pageIndex"),
                    blank = o.bool("blank") ?: false,
                    midi = o.string("midi"),
                    seq = o.long("seq") ?: 0,
                )
                "pong" -> Pong(o.int("id"), o.long("receivedAtEpochMs") ?: 0)
                "error" -> Error(o.string("code") ?: "unknown", o.string("message") ?: "", o.string("request"))
                else -> null
            }
        }.getOrNull()

        /** The receiver's side, for the fake receiver in tests. */
        fun toJson(message: ReceiverMessage): String = buildJsonObject {
            put("v", CastProtocol.VERSION)
            when (message) {
                is Status -> {
                    put("type", "status"); put("state", message.state)
                    put("positionMs", message.positionMs); put("durationMs", message.durationMs)
                    put("passDurationMs", message.passDurationMs); put("pass", message.pass); put("passes", message.passes)
                    put("rate", SenderMessage.number(message.rate)); put("sentAtEpochMs", message.sentAtEpochMs)
                    put("hymnKey", message.hymnKey); put("pageIndex", message.pageIndex); put("blank", message.blank)
                    put("midi", message.midi); put("seq", message.seq)
                }
                is Pong -> { put("type", "pong"); put("id", message.id); put("receivedAtEpochMs", message.receivedAtEpochMs) }
                is Error -> { put("type", "error"); put("code", message.code); put("message", message.message); message.request?.let { put("request", it) } }
            }
        }.toString()
    }
}

private fun JsonObject.primitive(key: String): JsonPrimitive? = (this[key] as? JsonPrimitive)?.takeUnless { it is JsonNull }
private fun JsonObject.string(key: String): String? = primitive(key)?.contentOrNull
private fun JsonObject.int(key: String): Int? = primitive(key)?.let { it.intOrNull ?: it.doubleOrNull?.toInt() }
private fun JsonObject.long(key: String): Long? = primitive(key)?.let { it.longOrNull ?: it.doubleOrNull?.toLong() }
private fun JsonObject.double(key: String): Double? = primitive(key)?.doubleOrNull
private fun JsonObject.bool(key: String): Boolean? = primitive(key)?.booleanOrNull
