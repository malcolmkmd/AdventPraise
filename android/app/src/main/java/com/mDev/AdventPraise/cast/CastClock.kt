// OWNER: cast
package com.mDev.AdventPraise.cast

import kotlin.math.roundToLong

/**
 * The TV's clock as the phone sees it (PROTOCOL.md, "Extrapolating"): the
 * newest `status` by `seq`, stamped with the phone's own clock when it
 * arrived (less half the measured round trip). While the TV is playing, the
 * position now is `positionMs + (now - receivedAt) * rate`.
 */
class CastStatusClock {
    var status: ReceiverMessage.Status? = null
        private set
    /** The phone's clock (ms) when [status] was sent, as best known. */
    var receivedAt: Long = 0
        private set
    /** Half the last measured round trip, taken off [receivedAt]. */
    var oneWayMs: Long = 0

    /** A new receiver (a new or resumed session): its `seq` starts again. */
    fun reset() {
        status = null
        receivedAt = 0
    }

    /** Keeps [next] unless an equal or newer `seq` has been seen; false when it is dropped. */
    fun accept(next: ReceiverMessage.Status, arrivedAt: Long): Boolean {
        val last = status
        if (last != null && next.seq <= last.seq) return false
        status = next
        receivedAt = arrivedAt - oneWayMs
        return true
    }

    /** The TV's position at [now] (phone clock), per the last status. */
    fun positionAt(now: Long): Long {
        val s = status ?: return 0
        return extrapolate(s.positionMs, s.durationMs, receivedAt, now, s.rate, s.state == STATE_PLAYING)
    }

    companion object {
        const val STATE_IDLE = "idle"
        const val STATE_LOADING = "loading"
        const val STATE_PLAYING = "playing"
        const val STATE_PAUSED = "paused"
        const val STATE_ENDED = "ended"

        /** `positionMs + (now - at) * rate` while playing, held otherwise; never past the end. */
        fun extrapolate(positionMs: Long, durationMs: Long, at: Long, now: Long, rate: Float, playing: Boolean): Long {
            if (!playing) return positionMs
            val moved = positionMs + ((now - at).coerceAtLeast(0) * rate.toDouble()).roundToLong()
            return if (durationMs > 0) moved.coerceIn(0, durationMs) else moved.coerceAtLeast(0)
        }
    }
}
