package com.mDev.AdventPraise.church.display

import com.mDev.AdventPraise.church.ChurchSession
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach

/** What kind of TV a [TvRoute] is. */
enum class TvRouteKind {
    /** A second display: a cable, or a screen cast from Android's Cast settings (Miracast). */
    SecondDisplay,
    /** A Google Cast receiver (added by the Cast output). */
    Cast,
}

/** A TV the worship display can go to, as the chooser lists it. */
data class TvRoute(val id: String, val name: String, val kind: TvRouteKind)

/** What one [TvOutput] sees and does. */
data class TvOutputState(
    /** TVs this output can offer. A second display is in use from the moment it is seen. */
    val routes: List<TvRoute> = emptyList(),
    /** The TV in use, if any: church mode's "TV connected". */
    val connected: TvRoute? = null,
    /** The worship display is drawn on [connected] (Pro). Otherwise Android mirrors the phone there. */
    val showsWorshipDisplay: Boolean = false,
)

/**
 * Where church mode's words go on a TV: the seam between church mode and
 * the ways Android reaches a TV (ExternalDisplay.swift and the AirPlay
 * button on iOS). Church mode's TV button opens a chooser over
 * [TvOutputs.state]; picking a route calls [select].
 *
 * Implementations:
 * - [PresentationTvOutput]: a second display (cable or Miracast). Android
 *   connects it; with Pro the worship display goes up on it as a
 *   `Presentation`, without Pro nothing is drawn and Android mirrors the phone.
 * - Cast (a later agent): a Google Cast receiver, where the TV is the clock.
 *   Add it to [TvOutputs] in AppServices; nothing else changes.
 *
 * Every output reads Pro and what to show from [ChurchSession]; only
 * [TvOutputs] tells the session a TV is connected.
 */
interface TvOutput {
    val state: StateFlow<TvOutputState>
    /** Starts watching for TVs (at launch). */
    fun start()
    fun stop()
    /** The chooser picked [route]. A second display is already in use; Cast connects to it. */
    fun select(route: TvRoute)
    /** Stops using the TV in use (Cast ends its session; a second display can only be unplugged). */
    fun disconnect()
}

/**
 * Every [TvOutput], merged for the chooser, and the one place that tells
 * [ChurchSession] whether a TV is connected (`church_mode_cast_changed`,
 * the hymn card's TV mark, the remote's "On TV").
 */
class TvOutputs(
    private val session: ChurchSession,
    private val scope: CoroutineScope,
    val outputs: List<TvOutput>,
) : TvOutput {
    private val merged = MutableStateFlow(TvOutputState())
    override val state: StateFlow<TvOutputState> = merged.asStateFlow()
    private var started = false

    override fun start() {
        if (started) return
        started = true
        outputs.forEach { it.start() }
        val flows = outputs.map { it.state }
        if (flows.isEmpty()) return
        combine(flows) { states -> merge(states.toList()) }
            .onEach { next ->
                merged.value = next
                session.setExternalScreen(next.connected != null)
            }
            .launchIn(scope)
    }

    override fun stop() {
        outputs.forEach { it.stop() }
    }

    override fun select(route: TvRoute) {
        outputs.firstOrNull { o -> o.state.value.routes.any { it.id == route.id } }?.select(route)
    }

    override fun disconnect() {
        outputs.filter { it.state.value.connected != null }.forEach { it.disconnect() }
    }

    companion object {
        /** Routes in output order; the first connected TV wins (a cable before Cast). */
        fun merge(states: List<TvOutputState>): TvOutputState {
            val connected = states.firstOrNull { it.connected != null }
            return TvOutputState(
                routes = states.flatMap { it.routes },
                connected = connected?.connected,
                showsWorshipDisplay = connected?.showsWorshipDisplay ?: false,
            )
        }
    }
}
