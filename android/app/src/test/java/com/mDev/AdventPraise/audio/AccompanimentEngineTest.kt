package com.mDev.AdventPraise.audio

import com.mDev.AdventPraise.data.Block
import com.mDev.AdventPraise.data.DirectoryAssets
import com.mDev.AdventPraise.data.Hymn
import com.mDev.AdventPraise.data.SdahTunes
import com.mDev.AdventPraise.data.SheetMusicCatalog
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayOutputStream
import java.io.File
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * The accompaniment engine's arithmetic: the MIDI parser and tempo map
 * (against the pass lengths the sheet music sync was measured with on iOS),
 * the pass / seek / verse arithmetic, the SoundFont zone choice and the
 * renderer's passes, seeks and levels.
 */
class AccompanimentEngineTest {
    private val assets = DirectoryAssets.iosResources()
    private fun midi(number: Int) = StandardMidiFile.parse(assets.open("hymn-%03d.mid".format(number)).readBytes())
    private val font: SoundFont by lazy {
        val file = listOf("../shared-audio/piano.sf2", "shared-audio/piano.sf2").map(::File).first { it.isFile }
        SoundFont.parse(file.readBytes())
    }

    // MARK: MIDI file

    @Test fun passLengthIsEndOfTrackThroughTheTempoMap() {
        // The sync timings' `len` is one pass as iOS's AudioToolbox measures it.
        val catalog = SheetMusicCatalog(assets, SdahTunes(assets))
        var checked = 0
        for (number in 1..300) {
            if (!catalog.has("english", number)) continue
            val name = "hymn-%03d.mid".format(number)
            if (name !in assets.list()) continue
            val timing = catalog.timing("english", number) ?: continue
            assertEquals("hymn $number", timing.passLength, midi(number).lengthSeconds, 0.002)
            if (++checked == 40) break
        }
        assertTrue(checked >= 30)
    }

    @Test fun everyShippedFileParses() {
        val names = assets.list().filter { it.startsWith("hymn-") && it.endsWith(".mid") }
        assertTrue(names.size > 200)
        for (name in names) {
            val file = StandardMidiFile.parse(assets.open(name).readBytes())
            assertTrue(name, file.lengthSeconds > 5)
            assertTrue(name, file.size > 10)
            // Time-ordered.
            for (i in 1 until file.size) assertTrue(name, file.times[i] >= file.times[i - 1])
        }
    }

    @Test fun tempoMapRunningStatusAndEndOfTrack() {
        // Format 0, 96 ticks a quarter: 120 bpm, then 60 bpm from tick 192.
        val track = bytes(
            0x00, 0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20,       // 500 000 µs
            0x00, 0x90, 60, 100,                            // note on
            0x60, 60, 0,                                    // running status: note off at 96
            0x60, 0xFF, 0x51, 0x03, 0x0F, 0x42, 0x40,       // tick 192: 1 000 000 µs
            0x00, 0xC0, 52,                                 // program change (choir)
            0x81, 0x40, 0x90, 64, 90,                       // tick 384 (vlq 0x81 0x40 = 192)
            0x60, 0x80, 64, 0,                              // tick 480
            0x00, 0xFF, 0x2F, 0x00,
        )
        val file = StandardMidiFile.parse(smf(format = 0, division = 96, track))
        assertEquals(5, file.size)
        assertEquals(0.5, file.times[1], 1e-9)          // tick 96 at 120 bpm
        assertEquals(1.0, file.tempoMap.seconds(192), 1e-9)
        assertEquals(3.0, file.times[3], 1e-9)          // tick 384: 1 s + 192 ticks at 60 bpm
        assertEquals(4.0, file.lengthSeconds, 1e-9)     // End of Track at 480
        assertEquals(384.0, file.tempoMap.tick(3.0), 1e-6)
        assertEquals(0x90, file.status(3) and 0xF0)
        assertEquals(0xC0, file.status(2) and 0xF0)
        assertEquals(0, file.data2(1))                  // running-status note off
        assertEquals(3, file.firstIndex(1.5))
    }

    @Test fun formatOneMergesTracksInTimeOrder() {
        val tempo = bytes(0x00, 0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20, 0x00, 0xFF, 0x2F, 0x00)
        val a = bytes(0x00, 0x91, 60, 80, 0x60, 0x81, 60, 0, 0x00, 0xFF, 0x2F, 0x00)
        val b = bytes(0x30, 0x92, 67, 80, 0x60, 0x82, 67, 0, 0x00, 0xFF, 0x2F, 0x00)
        val file = StandardMidiFile.parse(smf(format = 1, division = 96, tempo, a, b))
        assertEquals(listOf(0L, 48L, 96L, 144L), file.ticks.toList())
        assertEquals(144.0 / 96 * 0.5, file.lengthSeconds, 1e-9)
    }

    // MARK: Passes, seeking, verses

    private fun hymn(vararg blocks: Block) = Hymn(1, "Test", emptyList(), blocks.toList(), "hymn-001.mid")

    @Test fun onePassPerVerseWithTheChorusInside() {
        val chorus = Block.Chorus(listOf("a", "b"))
        val h = hymn(Block.Verse(1, listOf("1", "2", "3", "4")), chorus, Block.Verse(2, listOf("1", "2", "3", "4")), Block.Verse(3, listOf("x")))
        assertEquals(listOf(AccompanimentPass(1, 4, 2), AccompanimentPass(2, 4, 2), AccompanimentPass(3, 1, 2)), h.accompanimentPasses)
        // Two different choruses: no chorus lines in the passes.
        val two = hymn(Block.Verse(1, listOf("1")), Block.Chorus(listOf("a")), Block.Chorus(listOf("b")))
        assertEquals(listOf(AccompanimentPass(1, 1, 0)), two.accompanimentPasses)
        // Chorus only: one pass, verse 0.
        assertEquals(listOf(AccompanimentPass(0, 0, 2)), hymn(chorus).accompanimentPasses)
    }

    @Test fun passAndOffsetFromElapsed() {
        assertEquals(0, PassClock.passIndex(0.0, 30.0, 4))
        assertEquals(1, PassClock.passIndex(30.0, 30.0, 4))
        assertEquals(3, PassClock.passIndex(120.0, 30.0, 4))   // the very end stays in the last pass
        assertEquals(30.0, PassClock.passOffset(120.0, 30.0, 4), 1e-9)
        assertEquals(15.0, PassClock.passOffset(45.0, 30.0, 4), 1e-9)
        assertEquals(0, PassClock.passIndex(10.0, 0.0, 4))
    }

    @Test fun seekLandsInThePassAndClamps() {
        assertEquals(2 to 5.0, PassClock.seekTarget(65.0, 30.0, 4))
        assertEquals(0 to 0.0, PassClock.seekTarget(-3.0, 30.0, 4))
        assertEquals(3 to 30.0, PassClock.seekTarget(500.0, 30.0, 4))
    }

    @Test fun verseAndLineFollowThePass() {
        val passes = listOf(AccompanimentPass(1, 4, 2), AccompanimentPass(2, 4, 2))
        assertEquals(PlaybackPosition(1, 1, false, 0), PassClock.position(passes, 0.0, 60.0))
        assertEquals(PlaybackPosition(1, 1, false, 3), PassClock.position(passes, 35.0, 60.0))
        assertEquals(PlaybackPosition(1, 1, true, 0), PassClock.position(passes, 40.0, 60.0))
        assertEquals(PlaybackPosition(2, 2, true, 1), PassClock.position(passes, 119.9, 60.0))
        assertEquals(PlaybackPosition(0, 1, false, null), PassClock.position(listOf(AccompanimentPass(0, 0, 0)), 3.0, 60.0))
        assertNull(PassClock.position(passes, 3.0, 0.0))
        assertEquals("1:05", PassClock.clock(65.4))
        assertEquals("0:00", PassClock.clock(-2.0))
    }

    // MARK: SoundFont

    @Test fun pianoZonesByKeyAndVelocity() {
        val preset = font.preset(0, 0)!!
        val middle = font.zones(preset, 60, 100).single()
        assertEquals("P200 Piano D5", middle.sample.name)
        assertEquals(62, middle.rootKey)
        assertEquals(1, middle.sampleModes)
        // Preset offsets add: attenuation 88 cB, and the 97–104 velocity layer's release −182 tc.
        assertEquals(88, middle[SoundFont.Gen.INITIAL_ATTENUATION])
        assertEquals(-182, middle[SoundFont.Gen.RELEASE_VOL_ENV])
        // Instrument global and local generators.
        assertEquals(12623, middle[SoundFont.Gen.INITIAL_FILTER_FC])
        assertEquals(-8359, middle[SoundFont.Gen.ATTACK_VOL_ENV])
        assertEquals(1000, middle[SoundFont.Gen.SUSTAIN_VOL_ENV])
        // The loudest layer has the longest release; the softest the shortest.
        assertEquals(316, font.zones(preset, 60, 127).single()[SoundFont.Gen.RELEASE_VOL_ENV])
        assertEquals(-1586, font.zones(preset, 60, 30).single()[SoundFont.Gen.RELEASE_VOL_ENV])
        // The ends of the keyboard.
        assertEquals("P200 Piano D2", font.zones(preset, 21, 90).single().sample.name)
        assertEquals("P200 Piano C10", font.zones(preset, 108, 90).single().sample.name)
    }

    @Test fun everyKeyHasOneZoneAndItsLoopIsInsideTheSample() {
        val preset = font.preset(0, 0)!!
        // The piano's zones reach the top of a grand (C8, key 108).
        assertTrue(font.zones(preset, 109, 90).isEmpty())
        for (key in 0..108) for (velocity in listOf(1, 64, 100, 127)) {
            val zone = font.zones(preset, key, velocity).single()
            assertTrue(zone.loopStart >= zone.start && zone.loopEnd <= zone.end && zone.loopStart < zone.loopEnd)
            assertTrue(zone.end <= font.samples.size)
        }
    }

    @Test fun programChangesStayOnThePiano() {
        val synth = PianoSynth(font, 48000)
        synth.send(0xC1, 91, 0)       // pad
        synth.send(0x91, 60, 100)
        assertEquals(1, synth.activeVoices)
        synth.send(0x81, 60, 0)
        // Released, still ringing out.
        assertEquals(1, synth.activeVoices)
        synth.render(FloatArray(48000 * 2), 0, 48000 * 2)
        assertEquals(0, synth.activeVoices)
    }

    // MARK: Rendering

    @Test fun renderPlaysEveryPassThenStops() {
        val file = midi(1)
        val synth = PianoSynth(font, 24000)
        val renderer = MidiRenderer(file, synth, passes = 2)
        val block = 512
        val buffer = FloatArray(block)
        var peak = 0f
        var sum = 0.0
        var frames = 0L
        var sawSecondPass = false
        while (!renderer.isFinished) {
            renderer.render(buffer, 0, block)
            for (x in buffer) { peak = maxOf(peak, abs(x)); sum += x * x }
            frames += block
            if (renderer.pass == 1) sawSecondPass = true
            assertTrue(frames < 24000L * 200)
        }
        assertTrue(sawSecondPass)
        // Both passes' worth of audio, to within a block.
        assertEquals(renderer.duration, frames / 24000.0, block / 24000.0 + 1e-6)
        assertEquals(renderer.duration, renderer.elapsed, 1e-6)
        val rms = sqrt(sum / frames)
        assertTrue("peak $peak", peak in 0.15f..1f)
        assertTrue("rms $rms", rms in 0.02..0.4)
    }

    @Test fun tempoScalesThePerformanceClock() {
        val file = midi(1)
        val renderer = MidiRenderer(file, PianoSynth(font, 24000), passes = 1)
        renderer.rate = 1.2
        renderer.render(FloatArray(24000), 0, 24000)     // one wall-clock second
        assertEquals(1.2, renderer.elapsed, 1e-3)
        renderer.rate = 0.8
        renderer.render(FloatArray(24000), 0, 24000)
        assertEquals(2.0, renderer.elapsed, 1e-3)
    }

    @Test fun seekLandsInThePassAndChasesControllers() {
        val file = midi(1)
        val renderer = MidiRenderer(file, PianoSynth(font, 24000), passes = 3)
        renderer.seek(file.lengthSeconds * 1.5)
        assertEquals(1, renderer.pass)
        assertEquals(file.lengthSeconds / 2, renderer.offset, 1e-9)
        renderer.seek(-4.0)
        assertEquals(0, renderer.pass)
        assertEquals(0.0, renderer.elapsed, 1e-9)
        renderer.seek(1e9)
        assertEquals(2, renderer.pass)
        assertEquals(file.lengthSeconds * 3, renderer.elapsed, 1e-9)
        assertFalse(renderer.isFinished)
        renderer.render(FloatArray(512), 0, 512)
        assertTrue(renderer.isFinished)
    }

    @Test fun eventsSoundOnTheirOwnFrame() {
        // One note at exactly 0.25 s: silence before its frame, sound from it.
        val track = bytes(0x00, 0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20, 0x30, 0x90, 60, 110, 0x60, 0x80, 60, 0, 0x00, 0xFF, 0x2F, 0x00)
        val file = StandardMidiFile.parse(smf(0, 96, track))
        val renderer = MidiRenderer(file, PianoSynth(font, 24000), 1)
        val out = FloatArray(12000)
        renderer.render(out, 0, out.size)
        val onset = 6000      // 0.25 s at 24 kHz
        for (i in 0 until onset) assertEquals(0f, out[i], 0f)
        assertTrue((onset until onset + 400).any { abs(out[it]) > 0.001f })
    }

    // MARK: Helpers

    private fun bytes(vararg values: Int) = ByteArray(values.size) { values[it].toByte() }

    private fun smf(format: Int, division: Int, vararg tracks: ByteArray): ByteArray {
        val out = ByteArrayOutputStream()
        fun u16(v: Int) { out.write(v shr 8 and 0xFF); out.write(v and 0xFF) }
        fun u32(v: Int) { u16(v ushr 16); u16(v and 0xFFFF) }
        out.write("MThd".toByteArray()); u32(6); u16(format); u16(tracks.size); u16(division)
        for (t in tracks) { out.write("MTrk".toByteArray()); u32(t.size); out.write(t) }
        return out.toByteArray()
    }
}
