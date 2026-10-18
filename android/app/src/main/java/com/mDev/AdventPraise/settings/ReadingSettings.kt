package com.mDev.AdventPraise.settings

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/** The ground the lyrics sit on (DSSurface on iOS). `key` is what analytics sends. */
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

/**
 * How the reader looks, kept between launches. The same choices as iOS
 * (ReadingSettings / DSReadingStyle): surface, size step, large print,
 * font, line spacing, alignment and "Chorus after every verse".
 */
class ReadingSettings(context: Context) {
    private val prefs = context.getSharedPreferences("reading.settings.v1", Context.MODE_PRIVATE)

    var surface by mutableStateOf(enumValue(prefs.getString("surface", null), ReadingSurface.Paper))
        private set
    var font by mutableStateOf(enumValue(prefs.getString("font", null), ReadingFont.Serif))
        private set
    var lineSpacing by mutableStateOf(enumValue(prefs.getString("lineSpacing", null), LineSpacing.Normal))
        private set
    var centered by mutableStateOf(prefs.getBoolean("centered", false))
        private set
    var largePrint by mutableStateOf(prefs.getBoolean("largePrint", false))
        private set
    /** 0…4, into `steps`. */
    var step by mutableStateOf(prefs.getInt("step", DEFAULT_STEP).coerceIn(0, 4))
        private set
    var repeatChorus by mutableStateOf(prefs.getBoolean("repeatChorus", false))
        private set
    var haptics by mutableStateOf(prefs.getBoolean("haptics", true))
        private set

    /** Point sizes at the default font scale, as on iOS. */
    val steps: List<Float> get() = if (largePrint) LARGE_PRINT_STEPS else STANDARD_STEPS
    val pointSize: Float get() = steps[step.coerceIn(steps.indices)]
    /** Big type needs proportionally less leading. */
    val leadingScale: Float get() = if (largePrint) 0.8f else 1f
    val isDefaultSize: Boolean get() = step == DEFAULT_STEP

    fun updateSurface(value: ReadingSurface) { surface = value; save() }
    fun updateFont(value: ReadingFont) { font = value; save() }
    fun updateLineSpacing(value: LineSpacing) { lineSpacing = value; save() }
    fun updateCentered(value: Boolean) { centered = value; save() }
    fun updateLargePrint(value: Boolean) { largePrint = value; save() }
    fun updateStep(value: Int) { step = value.coerceIn(0, 4); save() }
    fun updateRepeatChorus(value: Boolean) { repeatChorus = value; save() }
    fun updateHaptics(value: Boolean) { haptics = value; save() }

    private fun save() {
        prefs.edit()
            .putString("surface", surface.name)
            .putString("font", font.name)
            .putString("lineSpacing", lineSpacing.name)
            .putBoolean("centered", centered)
            .putBoolean("largePrint", largePrint)
            .putInt("step", step)
            .putBoolean("repeatChorus", repeatChorus)
            .putBoolean("haptics", haptics)
            .apply()
    }

    companion object {
        const val DEFAULT_STEP = 2
        val STANDARD_STEPS = listOf(16f, 18f, 19f, 21f, 24f)
        val LARGE_PRINT_STEPS = listOf(26f, 28f, 32f, 36f, 40f)

        private inline fun <reified T : Enum<T>> enumValue(name: String?, fallback: T): T =
            enumValues<T>().firstOrNull { it.name == name } ?: fallback
    }
}
