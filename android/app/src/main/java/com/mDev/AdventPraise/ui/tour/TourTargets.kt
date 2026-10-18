// OWNER: shell
package com.mDev.AdventPraise.ui.tour

import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned

/**
 * Where the tour's targets are on screen (`.tourAnchor` / TourAnchorKey on
 * iOS), in window (root) coordinates. Every area marks its real controls
 * with [tourTarget]; the one overlay over the window reads them. A target
 * leaves when its composable does.
 */
object TourTargets {
    private val bounds = mutableStateMapOf<TourTarget, Rect>()
    private val owners = mutableMapOf<TourTarget, Any>()

    operator fun get(target: TourTarget): Rect? = bounds[target]

    internal fun report(target: TourTarget, owner: Any, rect: Rect) {
        owners[target] = owner
        if (bounds[target] != rect) bounds[target] = rect
    }

    internal fun remove(target: TourTarget, owner: Any) {
        if (owners[target] !== owner) return
        owners.remove(target)
        bounds.remove(target)
    }

    /** Tests and previews: put a target where it would be. */
    fun place(target: TourTarget, rect: Rect) = report(target, this, rect)

    fun clear() {
        owners.clear()
        bounds.clear()
    }
}

/** Marks a real control the tour can point at (`.tourAnchor(_:)` on iOS). */
fun Modifier.tourTarget(target: TourTarget): Modifier = composed {
    val owner = remember { Any() }
    DisposableEffect(target) { onDispose { TourTargets.remove(target, owner) } }
    onGloballyPositioned { TourTargets.report(target, owner, it.boundsInRoot()) }
}
