// OWNER: cast
package com.mDev.AdventPraise.cast

import com.mDev.AdventPraise.audio.AccompanimentPlayer
import com.mDev.AdventPraise.audio.AccompanimentTransport

/**
 * When the TV takes over (a Cast session is up and there is Pro, as iOS's
 * AirPlay button is Pro): the TV gets church mode's scene and becomes the
 * accompaniment's clock (the player swaps to [cast], resuming where the
 * phone was); when the session ends or Pro goes, the phone takes the
 * accompaniment back, paused at the same place.
 */
class CastEngagement(
    private val player: AccompanimentPlayer,
    private val local: AccompanimentTransport,
    private val cast: CastTransport,
    private val mirror: CastChurchMirror,
    /** Church mode's scene now. */
    private val scene: () -> CastScene,
) {
    private var channel: CastChannel? = null
    private var isPro = false

    /** The TV is showing church mode and keeping the time. */
    var isEngaged = false
        private set

    /** A session is up, or back after a drop. */
    fun connected(channel: CastChannel) {
        this.channel = channel
        if (isEngaged) {
            // Resumed: the same TV, talk to it again.
            cast.attach(channel)
            mirror.reset()
            mirror.apply(scene())
        } else settle()
    }

    /** The session ended. */
    fun disconnected() {
        channel = null
        settle()
    }

    fun proChanged(value: Boolean) {
        if (value == isPro) return
        isPro = value
        settle()
    }

    /** Church mode changed: mirror it while engaged. */
    fun sceneChanged(next: CastScene) {
        if (isEngaged) mirror.apply(next)
    }

    private fun settle() {
        val c = channel
        val want = c != null && isPro
        if (want == isEngaged) return
        if (want) {
            isEngaged = true
            cast.attach(c!!)
            mirror.reset()
            mirror.apply(scene())
            player.use(cast, resumePlaying = true)
        } else {
            isEngaged = false
            if (c != null) {
                // Pro went with the TV still connected: silence it and take the words down.
                c.send(SenderMessage.Stop)
                c.send(SenderMessage.Blank(true))
            }
            cast.detach()
            player.use(local, resumePlaying = false)
        }
    }
}
