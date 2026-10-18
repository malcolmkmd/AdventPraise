package com.mDev.AdventPraise.ui.design

import android.animation.ValueAnimator
import android.content.Context
import android.os.Build
import android.os.SystemClock
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.HapticFeedbackConstants
import android.view.View
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ProcessLifecycleOwner
import java.lang.ref.WeakReference

/** What happened, never how it should feel (HapticEvent on iOS). */
enum class HapticEvent(
    /** The same event can't repeat faster than this. */
    val minimumIntervalMs: Long,
    /** Outcomes are never swallowed by a tap that happened just before them. */
    val isOutcome: Boolean = false,
) {
    /** A choice changed: a segment, chip, tempo, reorder. */
    Selection(50),
    LightImpact(70),
    MediumImpact(70),
    /** Panels and drawers opening, closing or settling on a detent. */
    SoftImpact(70),
    /** A drag passed the point where letting go commits (page swipe). */
    ThresholdCrossed(150),
    /** Hit an end: no further hymn, smallest / largest text, pinch range, pad full. */
    Limit(350),
    Success(400, isOutcome = true),
    Warning(400, isOutcome = true),
    Error(400, isOutcome = true),
    PurchaseComplete(1000, isOutcome = true),
    /** The hymn on screen changed. */
    PageTurn(250),
    /** A number pad key. */
    KeyPress(35),
    ToggleOn(70),
    ToggleOff(70);

    companion object {
        fun toggle(isOn: Boolean) = if (isOn) ToggleOn else ToggleOff
    }
}

/**
 * The one place the app makes haptics (Services/Haptics.swift). Call sites say what
 * happened (`Haptics.play(HapticEvent.PageTurn)`), so the feel is tuned here.
 *
 * - Events with a shape of their own (key press, page turn, threshold, limit,
 *   toggles, purchase complete) are vibrator primitives where the hardware has
 *   them, as iOS uses Core Haptics; everything else, and the fallback, is the
 *   nearest `HapticFeedbackConstants` on the attached view, which follows the
 *   system's touch-feedback switch.
 * - Each event has a minimum interval, and anything within 25 ms of the last
 *   haptic is dropped (outcomes excepted).
 * - Off when the person turns Haptics off in More ([isEnabled], wired to the
 *   reading settings) and while the app is in the background.
 * - Animations off (Android's Reduce Motion): the multi-pulse page turn and purchase
 *   flourish become single plain taps.
 */
object Haptics {
    /** The person's Haptics switch (More → Reading). AppServices wires it to the settings. */
    @Volatile var isEnabled: () -> Boolean = { true }

    private var view: WeakReference<View>? = null
    private var vibrator: Vibrator? = null
    private val lastPlayed = HashMap<HapticEvent, Long>()
    private var lastAny = 0L
    private const val GLOBAL_FLOOR_MS = 25L

    /** Call once from the activity with its decor view (feedback constants need a view). */
    fun attach(view: View) {
        this.view = WeakReference(view)
        vibrator = view.context.vibrator()
    }

    fun play(event: HapticEvent) {
        if (!isEnabled() || !isForeground() || !admit(event, SystemClock.uptimeMillis())) return
        val reduced = !ValueAnimator.areAnimatorsEnabled()
        if (playPrimitives(event, reduced)) return
        playConstant(event)
    }

    /** Rate limiting; records the event when it's let through. Internal for the tests. */
    internal fun admit(event: HapticEvent, now: Long): Boolean {
        lastPlayed[event]?.let { if (now - it < event.minimumIntervalMs) return false }
        if (!event.isOutcome && lastAny != 0L && now - lastAny < GLOBAL_FLOOR_MS) return false
        lastPlayed[event] = now
        lastAny = now
        return true
    }

    internal fun resetForTests() {
        lastPlayed.clear(); lastAny = 0L
    }

    private fun isForeground(): Boolean = runCatching {
        ProcessLifecycleOwner.get().lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)
    }.getOrDefault(true)

    // MARK: Constants (UIKit generators on iOS)

    private fun playConstant(event: HapticEvent) {
        val v = view?.get() ?: return
        v.performHapticFeedback(constant(event))
    }

    private fun constant(event: HapticEvent): Int {
        val api34 = Build.VERSION.SDK_INT >= 34
        val api30 = Build.VERSION.SDK_INT >= 30
        return when (event) {
            HapticEvent.Selection -> if (api34) HapticFeedbackConstants.SEGMENT_TICK else HapticFeedbackConstants.CLOCK_TICK
            HapticEvent.LightImpact -> HapticFeedbackConstants.CONTEXT_CLICK
            HapticEvent.MediumImpact -> HapticFeedbackConstants.VIRTUAL_KEY
            HapticEvent.SoftImpact, HapticEvent.PageTurn -> if (api30) HapticFeedbackConstants.GESTURE_END else HapticFeedbackConstants.CLOCK_TICK
            HapticEvent.ThresholdCrossed -> if (api34) HapticFeedbackConstants.GESTURE_THRESHOLD_ACTIVATE else HapticFeedbackConstants.CONTEXT_CLICK
            HapticEvent.Limit -> if (api30) HapticFeedbackConstants.REJECT else HapticFeedbackConstants.LONG_PRESS
            HapticEvent.Success, HapticEvent.PurchaseComplete -> if (api30) HapticFeedbackConstants.CONFIRM else HapticFeedbackConstants.VIRTUAL_KEY
            HapticEvent.Warning, HapticEvent.Error -> if (api30) HapticFeedbackConstants.REJECT else HapticFeedbackConstants.LONG_PRESS
            HapticEvent.KeyPress -> HapticFeedbackConstants.KEYBOARD_TAP
            HapticEvent.ToggleOn -> if (api34) HapticFeedbackConstants.TOGGLE_ON else HapticFeedbackConstants.CONTEXT_CLICK
            HapticEvent.ToggleOff -> if (api34) HapticFeedbackConstants.TOGGLE_OFF else HapticFeedbackConstants.CLOCK_TICK
        }
    }

    // MARK: Primitives (Core Haptics on iOS)

    private class Tap(val primitive: Int, val scale: Float, val delayMs: Int = 0)

    /** The shaped events, as primitive compositions. False to fall back to a constant. */
    private fun playPrimitives(event: HapticEvent, reduced: Boolean): Boolean {
        if (Build.VERSION.SDK_INT < 30) return false
        val vib = vibrator ?: return false
        val c = VibrationEffect.Composition.PRIMITIVE_CLICK
        val tick = VibrationEffect.Composition.PRIMITIVE_TICK
        val low = VibrationEffect.Composition.PRIMITIVE_LOW_TICK
        val taps: List<Tap> = when (event) {
            HapticEvent.KeyPress -> listOf(Tap(tick, 0.5f))
            HapticEvent.Limit -> listOf(Tap(c, 0.65f))
            HapticEvent.ThresholdCrossed -> listOf(Tap(c, 0.85f))
            HapticEvent.ToggleOn -> listOf(Tap(c, 0.7f))
            HapticEvent.ToggleOff -> listOf(Tap(tick, 0.45f))
            // A soft brush, then the page landing.
            HapticEvent.PageTurn -> if (reduced) listOf(Tap(c, 0.6f)) else listOf(Tap(low, 0.35f), Tap(c, 0.7f, 50))
            // Three rising taps and a short warm swell.
            HapticEvent.PurchaseComplete -> if (reduced) return false else listOf(
                Tap(tick, 0.45f), Tap(c, 0.65f, 90), Tap(c, 1f, 110),
                Tap(VibrationEffect.Composition.PRIMITIVE_SLOW_RISE, 0.3f),
            )
            else -> return false
        }
        val needed = taps.map { it.primitive }.distinct().toIntArray()
        if (!vib.areAllPrimitivesSupported(*needed)) return false
        val composition = VibrationEffect.startComposition()
        taps.forEach { composition.addPrimitive(it.primitive, it.scale, it.delayMs) }
        return runCatching {
            if (Build.VERSION.SDK_INT >= 33) {
                vib.vibrate(composition.compose(), VibrationAttributes.createForUsage(VibrationAttributes.USAGE_TOUCH))
            } else {
                @Suppress("DEPRECATION") vib.vibrate(composition.compose())
            }
            true
        }.getOrDefault(false)
    }

    private fun Context.vibrator(): Vibrator? =
        if (Build.VERSION.SDK_INT >= 31) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION") getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }?.takeIf { it.hasVibrator() }
}

/** Plays [event] whenever [trigger] changes (not on first composition), as `.haptic(_:trigger:)`. */
@Composable
fun <T> HapticOnChange(event: HapticEvent, trigger: T) {
    val first = remember { booleanArrayOf(true) }
    LaunchedEffect(trigger) {
        if (first[0]) first[0] = false else Haptics.play(event)
    }
}
