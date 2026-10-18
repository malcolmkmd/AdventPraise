package com.mDev.AdventPraise.cast

import com.mDev.AdventPraise.data.Catalogs
import com.mDev.AdventPraise.data.DirectoryAssets
import com.mDev.AdventPraise.data.HymnalInfo
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Base64

/** Protocol v1 against PROTOCOL.md's own examples, the TV clock, and `load` built from real hymns. */
class CastProtocolTest {
    private fun json(text: String) = Json.parseToJsonElement(text) as JsonObject

    // MARK: Sender → receiver, as PROTOCOL.md writes them

    private val loadExample = """
        {
          "v": 1, "type": "load",
          "hymnalKey": "english",
          "hymnalName": "Christ In Song",
          "number": 1,
          "title": "Watchman Blow The Gospel Trumpet",
          "pages": [
            { "kind": "verse",  "label": "Verse 1 of 4", "lines": ["Watchman, blow the gospel trumpet,", "…"] },
            { "kind": "chorus", "label": "Chorus",       "lines": ["Blow the trumpet, trusty watchman,", "…"] }
          ],
          "pageIndex": 0,
          "blank": false,
          "theme": { "appearance": "dark", "worshipPointSize": 42, "largePrint": false },
          "midi": "hymn-001.mid",
          "passes": 4,
          "tempo": 1,
          "autoplay": false,
          "startMs": 0
        }
    """

    private val loadMessage = SenderMessage.Load(
        hymnalKey = "english", hymnalName = "Christ In Song", number = 1, title = "Watchman Blow The Gospel Trumpet",
        pages = listOf(
            CastPage("verse", "Verse 1 of 4", listOf("Watchman, blow the gospel trumpet,", "…")),
            CastPage("chorus", "Chorus", listOf("Blow the trumpet, trusty watchman,", "…")),
        ),
        pageIndex = 0, blank = false, theme = CastTheme("dark", 42f, false), midi = "hymn-001.mid",
        passes = 4, tempo = 1f, autoplay = false, startMs = 0,
    )

    private val examples: List<Pair<String, SenderMessage>> = listOf(
        loadExample to loadMessage,
        """{ "v": 1, "type": "page", "pageIndex": 2 }""" to SenderMessage.Page(2),
        """{ "v": 1, "type": "blank", "on": true }""" to SenderMessage.Blank(true),
        """{ "v": 1, "type": "theme", "appearance": "dark", "worshipPointSize": 48, "largePrint": false }""" to
            SenderMessage.Theme(CastTheme("dark", 48f, false)),
        """{ "v": 1, "type": "special", "announcement": "Fellowship lunch after the service", "imageId": null }""" to
            SenderMessage.Special("Fellowship lunch after the service", null),
        """{ "v": 1, "type": "imageChunk", "imageId": "a1b2", "index": 0, "count": 6, "mime": "image/jpeg", "data": "/9j/4AAQ…" }""" to
            SenderMessage.ImageChunk("a1b2", 0, 6, "image/jpeg", "/9j/4AAQ…"),
        """{ "v": 1, "type": "play", "fromMs": 0 }""" to SenderMessage.Play(0),
        """{ "v": 1, "type": "pause" }""" to SenderMessage.Pause,
        """{ "v": 1, "type": "stop" }""" to SenderMessage.Stop,
        """{ "v": 1, "type": "seek", "ms": 61250 }""" to SenderMessage.Seek(61250),
        """{ "v": 1, "type": "tempo", "rate": 0.8 }""" to SenderMessage.Tempo(0.8f),
        """{ "v": 1, "type": "getStatus" }""" to SenderMessage.GetStatus,
        """{ "v": 1, "type": "ping", "id": 17 }""" to SenderMessage.Ping(17),
    )

    @Test fun everySenderExampleEncodesAsPrintedAndDecodesBack() {
        for ((text, message) in examples) {
            assertEquals(message.type, json(text), message.toJsonObject())
            assertEquals(message.type, message, SenderMessage.parse(text))
            assertEquals(message.type, message, SenderMessage.parse(message.toJson()))
        }
    }

    @Test fun playWithoutAPlaceLeavesFromMsOut() {
        assertEquals(json("""{ "v": 1, "type": "play" }"""), SenderMessage.Play().toJsonObject())
        assertEquals("""{"v":1,"type":"tempo","rate":1.2}""", SenderMessage.Tempo(1.2f).toJson())
    }

    // MARK: Receiver → sender

    private val statusExample = """
        {
          "v": 1, "type": "status",
          "state": "playing",
          "positionMs": 61250, "durationMs": 196000, "passDurationMs": 49000,
          "pass": 2, "passes": 4, "rate": 1,
          "sentAtEpochMs": 1760781600123,
          "hymnKey": "english-1", "pageIndex": 2, "blank": false,
          "midi": "hymn-001.mid", "seq": 812
        }
    """

    @Test fun receiverExamplesDecodeAndRoundTrip() {
        val status = ReceiverMessage.parse(statusExample) as ReceiverMessage.Status
        assertEquals(ReceiverMessage.Status("playing", 61250, 196000, 49000, 2, 4, 1f, 1760781600123,
            "english-1", 2, false, "hymn-001.mid", 812), status)
        assertEquals(json(statusExample), json(ReceiverMessage.toJson(status)))

        val pong = ReceiverMessage.parse("""{ "v": 1, "type": "pong", "id": 17, "receivedAtEpochMs": 1760781600120 }""")
        assertEquals(ReceiverMessage.Pong(17, 1760781600120), pong)
        assertEquals(pong, ReceiverMessage.parse(ReceiverMessage.toJson(pong!!)))

        val error = ReceiverMessage.parse("""{ "v": 1, "type": "error", "code": "midi_not_found", "message": "midi/hymn-999.mid: 404", "request": "load" }""")
        assertEquals(ReceiverMessage.Error("midi_not_found", "midi/hymn-999.mid: 404", "load"), error)
        assertEquals(error, ReceiverMessage.parse(ReceiverMessage.toJson(error!!)))

        // Before any load: no hymn, no page.
        val idle = ReceiverMessage.parse("""{"v":1,"type":"status","state":"idle","positionMs":0,"durationMs":0,"passDurationMs":0,"pass":0,"passes":0,"rate":1,"sentAtEpochMs":1,"hymnKey":null,"pageIndex":null,"blank":false,"midi":null,"seq":1}""")
            as ReceiverMessage.Status
        assertNull(idle.hymnKey); assertNull(idle.pageIndex); assertNull(idle.midi)
        // Unknown types and junk are ignored, not fatal.
        assertNull(ReceiverMessage.parse("""{"v":1,"type":"hello"}"""))
        assertNull(ReceiverMessage.parse("not json"))
    }

    // MARK: The TV's clock

    private fun status(seq: Long, state: String = "playing", position: Long = 10_000, rate: Float = 1f) =
        ReceiverMessage.Status(state, position, 196_000, 49_000, 1, 4, rate, 0, "english-1", 0, false, "hymn-001.mid", seq)

    @Test fun positionMovesAtTheRateWhilePlayingAndHoldsOtherwise() {
        val clock = CastStatusClock()
        clock.accept(status(1, position = 10_000), arrivedAt = 1_000)
        assertEquals(10_000, clock.positionAt(1_000))
        assertEquals(12_500, clock.positionAt(3_500))
        clock.accept(status(2, position = 20_000, rate = 1.2f), arrivedAt = 5_000)
        assertEquals(21_200, clock.positionAt(6_000))
        clock.accept(status(3, state = "paused", position = 30_000), arrivedAt = 7_000)
        assertEquals(30_000, clock.positionAt(60_000))
        // Never past the end.
        clock.accept(status(4, position = 195_000), arrivedAt = 8_000)
        assertEquals(196_000, clock.positionAt(20_000))
    }

    @Test fun anOlderOrRepeatedSeqIsDropped() {
        val clock = CastStatusClock()
        assertTrue(clock.accept(status(812, position = 61_250), 0))
        assertEquals(false, clock.accept(status(811, position = 1_000), 10))
        assertEquals(false, clock.accept(status(812, position = 1_000), 10))
        assertEquals(61_250L, clock.status!!.positionMs)
        assertTrue(clock.accept(status(813, position = 61_500), 20))
        // A new receiver counts from 1 again.
        clock.reset()
        assertTrue(clock.accept(status(1, position = 0), 30))
    }

    @Test fun halfTheRoundTripComesOffTheArrival() {
        val clock = CastStatusClock()
        clock.oneWayMs = 40
        clock.accept(status(1, position = 10_000), arrivedAt = 1_000)
        assertEquals(960, clock.receivedAt)
        assertEquals(10_040, clock.positionAt(1_000))
    }

    // MARK: load from real hymns

    private val catalogs = Catalogs(DirectoryAssets.iosResources())

    @Test fun christInSongHymnLoadsItsSungSequenceAndMidi() {
        val english = catalogs.hymnal("english")!!
        val hymnal = catalogs.load(english)!!
        val hymn = hymnal.hymn(1)!!
        val words = CastWords(hymn, english.id, english.name, hymnal.chorusLabel)
        val load = CastLoads.load(words, CastScreen(2, false, CastTheme(CastTheme.DARK, 48f, true)), tempo = 0.8f)
        assertEquals("english", load.hymnalKey)
        assertEquals("Christ In Song", load.hymnalName)
        assertEquals(1, load.number)
        assertEquals("Watchman Blow The Gospel Trumpet", load.title)
        assertEquals("hymn-001.mid", load.midi)
        assertEquals(4, load.passes)
        // Four verses, the one chorus after each.
        assertEquals(listOf("Verse 1 of 4", "Chorus", "Verse 2 of 4", "Chorus", "Verse 3 of 4", "Chorus", "Verse 4 of 4", "Chorus"),
            load.pages.map { it.label })
        assertEquals(listOf("verse", "chorus", "verse", "chorus", "verse", "chorus", "verse", "chorus"), load.pages.map { it.kind })
        assertEquals("Watchman, blow the gospel trumpet,", load.pages[0].lines[0])
        assertEquals(2, load.pageIndex)
        assertEquals(CastTheme("dark", 48f, true), load.theme)
        assertEquals(0.8f, load.tempo)
        assertEquals("english-1", load.hymnKey)
        // Through JSON and back.
        assertEquals(load, SenderMessage.parse(load.toJson()))
        // Every page fits in one Cast message.
        assertTrue(load.toJson().toByteArray().size < 64 * 1024)
    }

    @Test fun sdaHymnalHymnPlaysItsChristInSongTune() {
        val sdah = catalogs.hymnal(HymnalInfo.SDAH_ID)!!
        val hymnal = catalogs.load(sdah)!!
        val (hymn, tune) = hymnal.hymns.asSequence()
            .mapNotNull { h -> catalogs.tunes.cisTune(h.number)?.let { h to it } }
            .first { (h, _) -> h.midiAsset != null }
        val load = CastLoads.load(CastWords(hymn, sdah.id, sdah.name, hymnal.chorusLabel), CastScreen.TitleCard)
        assertEquals("sdah", load.hymnalKey)
        assertEquals(hymn.number, load.number)
        assertEquals("hymn-%03d.mid".format(tune), load.midi)
        assertEquals(maxOf(1, hymn.verseCount), load.passes)
        assertEquals(-1, load.pageIndex)
        // An SDA Hymnal hymn with no Christ In Song tune has words only.
        val wordsOnly = hymnal.hymns.first { catalogs.tunes.cisTune(it.number) == null }
        val silent = CastLoads.load(CastWords(wordsOnly, sdah.id, sdah.name, hymnal.chorusLabel), CastScreen.TitleCard, autoplay = true)
        assertNull(silent.midi)
        assertEquals(false, silent.autoplay)
    }

    // MARK: Pictures

    @Test fun picturesGoInChunksOfAtMost48000Characters() {
        val jpeg = ByteArray(100_000) { (it * 31).toByte() }
        val chunks = CastPictures.chunks("abc", jpeg)
        val base64 = Base64.getEncoder().encodeToString(jpeg)
        assertEquals((base64.length + 47_999) / 48_000, chunks.size)
        assertTrue(chunks.all { it.data.length <= 48_000 && it.count == chunks.size && it.imageId == "abc" && it.mime == "image/jpeg" })
        assertEquals((0 until chunks.size).toList(), chunks.map { it.index })
        assertTrue(Base64.getDecoder().decode(chunks.joinToString("") { it.data }).contentEquals(jpeg))
        // Each message stays under Cast's 64 KB.
        assertTrue(chunks.all { it.toJson().length < 64 * 1024 })
        val id = CastPictures.imageId("0F6C1E9A-4E1B-4C55-9D7B-0A6F0E0D2C11")
        assertEquals(12, id.length)
        assertEquals(id, CastPictures.imageId("0F6C1E9A-4E1B-4C55-9D7B-0A6F0E0D2C11"))
        assertNotNull(id)
    }
}
