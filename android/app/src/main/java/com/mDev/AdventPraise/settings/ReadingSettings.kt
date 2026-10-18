package com.mDev.AdventPraise.settings

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.mDev.AdventPraise.data.Json
import com.mDev.AdventPraise.data.jsonDouble
import com.mDev.AdventPraise.data.jsonInt
import com.mDev.AdventPraise.data.jsonObject
import com.mDev.AdventPraise.data.jsonString

/** The ground the lyrics sit on (DSSurface on iOS). `key` is its raw value, as analytics and the snapshot send it. */
enum class ReadingSurface(val key: String, val label: String, val isDark: Boolean) {
    Paper("paper", "Paper", false),
    Parchment("parchment", "Parchment", false),
    Sepia("sepia", "Sepia", false),
    Muted("muted", "Muted", true),
    Black("black", "Black", true),
}

enum class ReadingFont(val key: String, val label: String, val detail: String) {
    Serif("serif", "Serif", "For the hymnal"),
    Sans("sans", "Sans", "Clean and plain"),
}

enum class LineSpacing(val key: String, val label: String, val leading: Float) {
    Compact("compact", "Compact", 0.18f),
    Normal("normal", "Normal", 0.34f),
    Relaxed("relaxed", "Relaxed", 0.55f),
}

/** The lyric size ladders (DS.LyricScale on iOS), in points at the default font scale. */
enum class LyricScale(
    val key: String,
    val steps: List<Float>,
    /** Upper bound on the font-scale multiplier: big type uncapped wraps one word per line. */
    val fontScaleCap: Float,
    /** Big type needs proportionally less leading. */
    val leadingScale: Float,
    /** How far pinch-to-zoom may take the base size. */
    val pinchRange: ClosedFloatingPointRange<Float>,
) {
    Standard("standard", listOf(16f, 18f, 19f, 21f, 24f), 2.2f, 1f, 14f..32f),
    LargePrint("largePrint", listOf(26f, 28f, 32f, 36f, 40f), 1.5f, 0.8f, 24f..48f),
    Worship("worship", listOf(36f, 42f, 48f, 56f, 64f), 1.2f, 0.6f, 30f..80f);

    val defaultStep: Int get() = 2
}

/**
 * How the reader looks, kept between launches: iOS's ReadingSettings and
 * DSReadingStyle. Surface, size step (or a pinched size), large print,
 * font, line spacing, alignment, "Chorus after every verse" and church
 * mode's size, saved as iOS saves them: one JSON snapshot under
 * "reading.settings.v1". Haptics is its own switch ("haptics.enabled").
 */
class ReadingSettings(private val store: KeyValueStore) {
    constructor(context: Context) : this(SharedPreferencesStore(context, PREFS_NAME))

    var surface by mutableStateOf(ReadingSurface.Paper)
        private set
    var font by mutableStateOf(ReadingFont.Serif)
        private set
    var lineSpacing by mutableStateOf(LineSpacing.Normal)
        private set
    var centered by mutableStateOf(false)
        private set
    var largePrint by mutableStateOf(false)
        private set
    /** 0…4, into [steps]. */
    var step by mutableStateOf(DEFAULT_STEP)
        private set
    /** A size between the steps, set by pinch-to-zoom. Null means "use [step]". */
    var pinchedPointSize by mutableStateOf<Float?>(null)
        private set
    /** Print a hymn's single chorus after every verse, as it is sung. */
    var repeatChorus by mutableStateOf(false)
        private set
    /** Church mode's base lyric size, before font scale and large print. */
    var worshipPointSize by mutableStateOf(DEFAULT_WORSHIP_POINT_SIZE)
        private set
    var haptics by mutableStateOf(true)
        private set

    init {
        load()
    }

    val scale: LyricScale get() = if (largePrint) LyricScale.LargePrint else LyricScale.Standard
    /** Point sizes at the default font scale, as on iOS. */
    val steps: List<Float> get() = scale.steps
    /** The reader's base size: the pinched size, else the step. */
    val pointSize: Float
        get() = pinchedPointSize?.coerceIn(scale.pinchRange) ?: steps[step.coerceIn(steps.indices)]
    /** Big type needs proportionally less leading. */
    val leadingScale: Float get() = scale.leadingScale
    val isDefaultSize: Boolean get() = pinchedPointSize == null && step == DEFAULT_STEP
    val isDefaultWorshipSize: Boolean get() = worshipPointSize == DEFAULT_WORSHIP_POINT_SIZE

    fun updateSurface(value: ReadingSurface) { surface = value; save() }
    fun updateFont(value: ReadingFont) { font = value; save() }
    fun updateLineSpacing(value: LineSpacing) { lineSpacing = value; save() }
    fun updateCentered(value: Boolean) { centered = value; save() }
    fun updateRepeatChorus(value: Boolean) { repeatChorus = value; save() }

    /** Changing the scale keeps the step where it fits and drops any pinched size. */
    fun updateLargePrint(value: Boolean) {
        if (value == largePrint) return
        largePrint = value
        step = step.coerceAtMost(scale.steps.size - 1)
        pinchedPointSize = null
        save()
    }

    /** The slider or its − / + buttons. Drops any pinched size. */
    fun updateStep(value: Int) {
        step = value.coerceIn(0, 4)
        pinchedPointSize = null
        save()
    }

    /** Keeps a pinched size; the slider shows the nearest step. */
    fun pinch(size: Float) {
        val clamped = size.coerceIn(scale.pinchRange)
        step = scale.steps.indices.minByOrNull { kotlin.math.abs(scale.steps[it] - clamped) } ?: DEFAULT_STEP
        pinchedPointSize = clamped
        save()
    }

    /** Double-tap: back to the default step. */
    fun resetSize() = updateStep(scale.defaultStep)

    fun updateHaptics(value: Boolean) {
        haptics = value
        store.putBoolean(HAPTICS_KEY, value)
    }

    // Church mode's size

    /** The worship step the text size buttons would move to from wherever a pinch left it; null at either end. */
    fun worshipStepTarget(delta: Int): Float? {
        val steps = LyricScale.Worship.steps
        return if (delta > 0) steps.firstOrNull { it > worshipPointSize + 0.5f } else steps.lastOrNull { it < worshipPointSize - 0.5f }
    }

    /** Church mode's A− / A+: one step smaller or larger. False at a limit. */
    fun stepWorshipText(delta: Int): Boolean {
        val target = worshipStepTarget(delta) ?: return false
        worshipPointSize = target
        save()
        return true
    }

    /** Church mode's pinch, anywhere in the worship pinch range. */
    fun updateWorshipPointSize(size: Float) {
        worshipPointSize = size.coerceIn(LyricScale.Worship.pinchRange)
        save()
    }

    fun resetWorshipSize() = updateWorshipPointSize(DEFAULT_WORSHIP_POINT_SIZE)

    private fun load() {
        haptics = store.getBoolean(HAPTICS_KEY) ?: true
        val saved = store.getString(KEY)?.let(Json::parseOrNull).jsonObject() ?: return
        largePrint = saved["largePrint"] as? Boolean ?: false
        step = (saved["sizeIndex"].jsonInt() ?: DEFAULT_STEP).coerceIn(0, 4)
        font = ReadingFont.entries.firstOrNull { it.key == saved["font"].jsonString() } ?: ReadingFont.Serif
        lineSpacing = LineSpacing.entries.firstOrNull { it.key == saved["lineSpacing"].jsonString() } ?: LineSpacing.Normal
        centered = saved["centered"] as? Boolean ?: false
        surface = ReadingSurface.entries.firstOrNull { it.key == saved["environment"].jsonString() } ?: ReadingSurface.Paper
        repeatChorus = saved["repeatChorus"] as? Boolean ?: false
        pinchedPointSize = saved["pointSize"].jsonDouble()?.toFloat()
        worshipPointSize = (saved["worshipPointSize"].jsonDouble()?.toFloat() ?: DEFAULT_WORSHIP_POINT_SIZE)
            .coerceIn(LyricScale.Worship.pinchRange)
    }

    /** The iOS snapshot: the same keys and raw values. */
    private fun save() {
        val snapshot = linkedMapOf<String, Any?>(
            "sizeIndex" to step, "lineSpacing" to lineSpacing.key, "centered" to centered, "font" to font.key,
            "environment" to surface.key, "largePrint" to largePrint, "repeatChorus" to repeatChorus,
            "pointSize" to pinchedPointSize?.toDouble(), "worshipPointSize" to worshipPointSize.toDouble(),
        ).filterValues { it != null }
        store.putString(KEY, Json.write(snapshot))
    }

    companion object {
        const val PREFS_NAME = "settings"
        const val KEY = "reading.settings.v1"
        const val HAPTICS_KEY = "haptics.enabled"
        const val DEFAULT_STEP = 2
        val STANDARD_STEPS = LyricScale.Standard.steps
        val LARGE_PRINT_STEPS = LyricScale.LargePrint.steps
        /** 42 pt: a typical four-line verse fits a phone without scrolling. */
        val DEFAULT_WORSHIP_POINT_SIZE = LyricScale.Worship.steps[1]
    }
}
