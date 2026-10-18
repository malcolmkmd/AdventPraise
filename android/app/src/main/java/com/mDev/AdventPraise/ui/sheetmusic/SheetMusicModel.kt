// OWNER: music
package com.mDev.AdventPraise.ui.sheetmusic

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.mDev.AdventPraise.audio.AccompanimentPass
import com.mDev.AdventPraise.audio.AccompanimentState
import com.mDev.AdventPraise.audio.PassClock
import com.mDev.AdventPraise.data.SheetMusicHighlight
import com.mDev.AdventPraise.data.SheetMusicLayout
import com.mDev.AdventPraise.data.SheetMusicTiming
import com.mDev.AdventPraise.data.SheetMusicViewMode
import com.mDev.AdventPraise.extras.SheetMusicAccess
import kotlin.math.roundToLong

/**
 * The sheet music viewer's state and decisions (SheetMusicView's logic on
 * iOS), apart from drawing: what shows (the whole page or a preview), Page
 * or System, which system is up, what the accompaniment marks, and what a
 * tap on the music does. It reads the accompaniment only as an
 * [AccompanimentState], so it follows whichever transport plays.
 *
 * @param hymnKey "<hymnal>#<number>" of the hymn shown.
 * @param passes the hymn's passes (one per verse), for the verse being sung.
 * @param playerUnlocked Pro or MIDI Piano: playing from here and following need it, like the Lectern's play.
 * @param canPlay the hymn has accompaniment and audio works here.
 */
class SheetMusicModel(
    val hymnKey: String,
    access: SheetMusicAccess,
    private val passes: List<AccompanimentPass>,
    playerUnlocked: Boolean,
    canPlay: Boolean,
    viewMode: SheetMusicViewMode = SheetMusicViewMode.Page,
) {
    /** Pro, Hymn of the Day or a preview; Pro bought over the screen shows the whole page without leaving. */
    var access by mutableStateOf(access)
    var playerUnlocked by mutableStateOf(playerUnlocked)
    var canPlay by mutableStateOf(canPlay)
    /** Hymn `number`'s timing and geometry, once read (null: none ships, or not yet). */
    var timing by mutableStateOf<SheetMusicTiming?>(null)
    var viewMode by mutableStateOf(viewMode)
    /** A tap on the music hides the controls for the music alone; another brings them back. */
    var controlsVisible by mutableStateOf(true)
    /** System by system: a measure in the system on screen (kept across rotations). */
    var systemMeasure by mutableIntStateOf(0)

    /** The controls stay up for a preview (its Pro button) and with a screen reader. */
    fun showsControls(screenReader: Boolean): Boolean = controlsVisible || !access.showsWholePage || screenReader

    /** Playing from here and following along. */
    val canFollow: Boolean get() = access.showsWholePage && playerUnlocked && canPlay && timing != null

    /** The accompaniment is on this hymn, playing or paused part-way. */
    fun following(status: AccompanimentState): Boolean = canFollow && status.isActive && status.hymnKey == hymnKey

    private fun passOffset(status: AccompanimentState): Double? =
        SheetMusicTiming.passOffset(status.elapsedSeconds, status.durationSeconds, status.passes)

    /** The verse being sung (null for a chorus-only hymn's pass or nothing loaded). */
    private fun verse(status: AccompanimentState): Int? =
        PassClock.position(passes, status.elapsedSeconds, status.passSeconds)?.verse

    /** What's sounding, while following. */
    fun cue(status: AccompanimentState): SheetMusicTiming.Cue? {
        val timing = timing ?: return null
        if (!following(status)) return null
        val offset = passOffset(status) ?: return null
        return timing.cue(offset, verse(status))
    }

    /** The marks on a page drawn with `layout`. */
    fun highlight(layout: SheetMusicLayout, status: AccompanimentState): SheetMusicHighlight {
        val cue = cue(status) ?: return SheetMusicHighlight.none
        val geometry = timing?.geometry?.get(layout) ?: return SheetMusicHighlight.none
        return SheetMusicHighlight.of(cue, geometry)
    }

    /** The measure the accompaniment is in, while it's on this hymn. */
    fun cueMeasure(status: AccompanimentState): Int? = cue(status)?.measure

    /** System by system, when chosen and the page's systems are known. */
    val systemMode: Boolean
        get() = viewMode == SheetMusicViewMode.System && timing?.geometry?.get(SheetMusicLayout.Phone)?.systems?.isNotEmpty() == true

    /** The pages to show: system by system draws from pages with short lines, so one fills the width large. */
    fun pageLayout(width: Double): SheetMusicLayout =
        if (systemMode) SheetMusicLayout.forSystems(width) else SheetMusicLayout.forWidth(width)

    fun systemCount(layout: SheetMusicLayout): Int = timing?.geometry?.get(layout)?.systems?.size ?: 0

    fun systemIndex(layout: SheetMusicLayout): Int {
        val geometry = timing?.geometry?.get(layout) ?: return 0
        return minOf(geometry.system(systemMeasure), maxOf(geometry.systems.size - 1, 0))
    }

    /** To system `index` (its first measure); nothing past either end. */
    fun goToSystem(index: Int, layout: SheetMusicLayout): Boolean {
        val geometry = timing?.geometry?.get(layout) ?: return false
        val first = geometry.firstMeasure(index) ?: return false
        systemMeasure = first
        return true
    }

    /** System by system follows the accompaniment from line to line. */
    fun follow(status: AccompanimentState) {
        cueMeasure(status)?.let { systemMeasure = it }
    }

    /** What a tap on the music does. */
    sealed interface Tap {
        /** Play from there: performance milliseconds for the transport. */
        data class Seek(val ms: Long) : Tap
        data object ToggleControls : Tap
    }

    /**
     * A tap at `point` (SVG units; null off the page): on a measure while the
     * accompaniment is on this hymn, play from there, in the verse being
     * played; anywhere else, hide or show the controls.
     */
    fun tapped(point: Pair<Double, Double>?, layout: SheetMusicLayout, status: AccompanimentState): Tap {
        val timing = timing
        val offset = passOffset(status)
        if (following(status) && point != null && timing != null && offset != null) {
            val measure = timing.measure(point.first, point.second, layout)
            val target = measure?.let { timing.seekOffset(it, offset) }
            if (target != null) {
                val pass = SheetMusicTiming.passIndex(status.elapsedSeconds, status.durationSeconds, status.passes)
                val seconds = pass * status.durationSeconds / maxOf(status.passes, 1) + target
                return Tap.Seek((seconds * 1000).roundToLong())
            }
        }
        controlsVisible = !controlsVisible
        return Tap.ToggleControls
    }
}
