package com.mDev.AdventPraise.extras

import com.mDev.AdventPraise.data.AssetSource
import com.mDev.AdventPraise.data.Json
import com.mDev.AdventPraise.data.jsonInt
import com.mDev.AdventPraise.data.jsonObject
import com.mDev.AdventPraise.data.jsonString
import com.mDev.AdventPraise.settings.KeyValueStore
import kotlin.math.pow

/** A hymn's published starting note (StartingNote on iOS). */
data class StartingNote(
    /** The hymn's key as printed, e.g. "F major". */
    val key: String? = null,
    /** Scientific pitch name of the first sung note, e.g. "C4", "F#4", "Bb3". */
    val note: String? = null,
) {
    /** The note as a MIDI number, when it parses. */
    val midi: Int? get() = note?.let(Pitch::midi)
}

/** Note names, MIDI numbers and frequencies (Pitch on iOS). */
object Pitch {
    val names = listOf("C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B")

    private val letters = mapOf('C' to 0, 'D' to 2, 'E' to 4, 'F' to 5, 'G' to 7, 'A' to 9, 'B' to 11)

    /** "C4" → 60, "F#4"/"F♯4" → 66, "Bb3"/"B♭3" → 58. */
    fun midi(name: String): Int? {
        var rest = name.trim()
        val letter = rest.firstOrNull()?.uppercaseChar()?.let(letters::get) ?: return null
        rest = rest.drop(1)
        var semitone = letter
        while (rest.isNotEmpty() && rest[0] in "#♯b♭") {
            semitone += if (rest[0] == '#' || rest[0] == '♯') 1 else -1
            rest = rest.drop(1)
        }
        val octave = rest.toIntOrNull() ?: return null
        return (octave + 1) * 12 + semitone
    }

    /** 60 → "C4". */
    fun name(midi: Int): String = names[((midi % 12) + 12) % 12] + (midi / 12 - 1)

    /** Equal temperament, A4 = 440 Hz. */
    fun frequency(midi: Int): Double = 440.0 * 2.0.pow((midi - 69) / 12.0)

    /** The keyboard's octave stepper range, as on iOS. */
    val OCTAVES = 2..5

    /** One octave of keys, C to B (the keyboard shows twelve, four across). */
    fun octave(octave: Int = 4): List<Int> = (0 until 12).map { (octave + 1) * 12 + it }
}

/**
 * Starting notes (PitchNotes on iOS): published ones from
 * Resources/Extras/pitch_notes.json, and the singer's own choice per hymn,
 * kept on this device ("pitch.custom.v1", `{"english#12": 60}`). The
 * singer's choice wins over the published note.
 */
class PitchNotes(assets: AssetSource, private val store: KeyValueStore) {
    private val file = PerHymnFile.load(assets, "pitch_notes.json") { raw ->
        raw.jsonObject()?.let { StartingNote(it["key"].jsonString(), it["note"].jsonString()) }
    }

    fun published(hymnal: String, number: Int): StartingNote? = file.entry(hymnal, number)

    /** The singer's own choice for this hymn, if any. */
    fun custom(hymnal: String, number: Int): Int? = all()["$hymnal#$number"]

    fun setCustom(midi: Int?, hymnal: String, number: Int) {
        val next = all().toMutableMap()
        if (midi == null) next.remove("$hymnal#$number") else next["$hymnal#$number"] = midi
        store.putString(KEY, Json.write(next))
    }

    /** The note to sound: the singer's choice, else the published note. */
    fun note(hymnal: String, number: Int): Int? = custom(hymnal, number) ?: published(hymnal, number)?.midi

    private fun all(): Map<String, Int> =
        store.getString(KEY)?.let(Json::parseOrNull).jsonObject().orEmpty().mapNotNull { (k, v) -> v.jsonInt()?.let { k to it } }.toMap()

    companion object {
        const val KEY = "pitch.custom.v1"
    }
}

/**
 * The pitch pipe's tone, as iOS renders it: a soft sine with a touch of the
 * octave and twelfth, 40 ms in and 250 ms out. The audio side (AudioTrack)
 * renders samples with this; nothing here plays sound.
 */
class PitchTone(private val sampleRate: Double) {
    var frequency = 440.0
    private var target = 0.0
    private var level = 0.0
    private var phase = 0.0

    fun start(frequency: Double) {
        this.frequency = frequency
        target = PEAK
    }

    fun release() { target = 0.0 }

    val isSilent: Boolean get() = target == 0.0 && level == 0.0

    /** Fills `out` with the next samples (mono, -1…1). */
    fun render(out: FloatArray, count: Int = out.size) {
        val step = 2 * Math.PI * frequency / sampleRate
        val attack = 1 / (0.04 * sampleRate)
        val decay = 1 / (0.25 * sampleRate)
        for (i in 0 until count) {
            if (level < target) level = minOf(target, level + attack) else if (level > target) level = maxOf(target, level - decay)
            out[i] = (level * (kotlin.math.sin(phase) + 0.18 * kotlin.math.sin(2 * phase) + 0.08 * kotlin.math.sin(3 * phase)) / 1.26).toFloat()
            phase += step
            if (phase > 2 * Math.PI) phase -= 2 * Math.PI
        }
    }

    companion object {
        const val PEAK = 0.28
        /** Seconds a tap sounds for before fading. */
        const val DURATION_SECONDS = 2.5
    }
}
