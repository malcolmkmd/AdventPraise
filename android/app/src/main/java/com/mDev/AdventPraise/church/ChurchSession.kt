package com.mDev.AdventPraise.church

import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.analytics.AnalyticsScreen
import com.mDev.AdventPraise.analytics.ChurchModeSource
import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.data.Block
import com.mDev.AdventPraise.data.Hymn
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * What church mode is showing, shared by everything that shows it: the
 * phone's presenter, the TV (a second display's Presentation or the Cast
 * receiver), the Church Remote widget and the ongoing notification
 * (ChurchPresentation, ChurchActivity and ChurchWidgetState on iOS).
 */
data class ChurchState(
    /** Church mode is open on the phone. */
    val isActive: Boolean = false,
    /** The block of [sequence] being sung. */
    val index: Int = 0,
    /** A TV is connected (a second display or Cast). With Pro it gets the worship display. */
    val isExternalScreenConnected: Boolean = false,
    /** The TV shows only its ground (between hymns, for a sermon). Turning a verse shows the words again. */
    val isBlanked: Boolean = false,
    /** A message on the big screen, over the blank ground. */
    val announcement: String? = null,
    /** A picture on the big screen (a content URI or an id the TV side resolves). */
    val image: String? = null,
    /** The notification's End button: the presenter closes when it sees this. */
    val endRequested: Boolean = false,
    /** The hymn being presented, and its hymnal. */
    val hymn: Hymn? = null,
    val hymnalId: String = "",
    val hymnalName: String = "",
    /** What this hymnal calls the chorus ("Refrain", "Coro"…). */
    val chorusLabel: String = "Chorus",
    /** Next hymn has somewhere to go (the running playlist, else the next number). */
    val hasNextHymn: Boolean = false,
    val isPro: Boolean = false,
) {
    /** The order a congregation sings it: every verse, a single chorus after each. */
    val sequence: List<Block> get() = hymn?.sungSequence.orEmpty()
    val block: Block? get() = sequence.getOrNull(index)
    val isLast: Boolean get() = index >= sequence.size - 1
    val canGoBack: Boolean get() = index > 0
    /** Something other than the hymn is up: Clear goes back to blank or the words. */
    val isShowingSpecial: Boolean get() = announcement != null || image != null
    /** The worship display is up on a TV (Pro); otherwise a connected screen mirrors the phone. */
    val isOnExternalScreen: Boolean get() = isExternalScreenConnected && isPro

    /** The hymn card's line: "Verse 2 of 4", the chorus label, or "". */
    val position: String
        get() = when (val b = block) {
            is Block.Verse -> "Verse ${b.number} of ${hymn?.verseCount ?: 0}"
            is Block.Chorus -> chorusLabel
            null -> ""
        }

    /** What the TV shows instead of the words, for the hymn card; null when it shows them. */
    val tvStatus: String?
        get() = when {
            image != null -> "Image on TV"
            announcement != null -> "Announcement on TV"
            isBlanked -> "TV blank"
            else -> null
        }

    /** The remote's line (notification, widget): "Image", "Announcement", "Screen blank", else [position]. */
    val remotePosition: String
        get() = when {
            image != null -> "Image"
            announcement != null -> "Announcement"
            isBlanked -> "Screen blank"
            else -> position
        }

    /** The ongoing notification's content while presenting; null when nothing is presented. */
    val activityState: ChurchActivityState?
        get() {
            val hymn = hymn ?: return null
            if (!isActive) return null
            val clamped = index.coerceIn(0, maxOf(sequence.size - 1, 0))
            return ChurchActivityState(hymnalName, hymn.number, hymn.title, remotePosition, clamped + 1, sequence.size,
                clamped > 0, isExternalScreenConnected)
        }

    /** The Church Remote widget's state. */
    val widgetState: ChurchWidgetState
        get() {
            val hymn = hymn ?: return ChurchWidgetState.placeholder.copy(isPro = isPro)
            val clamped = index.coerceIn(0, maxOf(sequence.size - 1, 0))
            return ChurchWidgetState(
                hymnNumber = hymn.number, title = hymn.title, hymnal = hymnalName,
                position = if (isActive) remotePosition else "",
                isPresenting = isActive, isOnTV = isActive && isExternalScreenConnected,
                isBlanked = isActive && isBlanked, isPro = isPro, hasNextHymn = hasNextHymn,
                canGoBack = isActive && clamped > 0,
            )
        }
}

/** How a move went, so the presenter can play its haptic (iOS: a light impact, or the limit). */
enum class ChurchMove {
    /** The verse moved. */
    Moved,
    /** On to the next hymn, from its first verse. */
    NextHymn,
    /** Nothing to move to (the first verse, or no next hymn). */
    Limit,
    /** Past the last verse of the last hymn: church mode closes. */
    End,
}

/** What church mode needs from the reader. */
interface ChurchHost {
    /** Next hymn: the running playlist's next entry, else the next number (iOS goToNextHymn(source: .churchMode)). False when there is none. */
    fun goToNextHymn(): Boolean
    /** The Pro paywall, leading with [feature] (church mode on a TV is `AirPlay`). */
    fun showPaywall(feature: ProFeature)
}

/**
 * Church mode's one state holder: the presenter's moves, the remote's
 * buttons and what every screen shows, as a [StateFlow]. The reader pushes
 * the open hymn with [follow]; purchases push [setPro]; the display and
 * Cast layers push [setExternalScreen].
 */
class ChurchSession(private val host: ChurchHost, private val clock: () -> Long = System::currentTimeMillis) {
    private val mutable = MutableStateFlow(ChurchState())
    val state: StateFlow<ChurchState> = mutable.asStateFlow()
    val current: ChurchState get() = mutable.value

    private var enteredAt = 0L
    private var versesShown = 1
    private var hymnsShown = 1

    // Inputs

    /**
     * The reader's open hymn and hymnal. A new hymn starts at its first
     * verse (the words come back); the same number in another translation
     * stays on the verse being sung.
     */
    fun follow(hymn: Hymn, hymnalId: String, hymnalName: String, chorusLabel: String, hasNextHymn: Boolean) {
        val old = current
        var next = old.copy(hymn = hymn, hymnalId = hymnalId, hymnalName = hymnalName, chorusLabel = chorusLabel,
            hasNextHymn = hasNextHymn)
        if (old.hymn != null && old.hymn.number != hymn.number) {
            next = next.copy(index = 0, isBlanked = false)
            if (old.isActive) {
                versesShown += 1
                hymnsShown += 1
            }
        } else if (old.hymnalId != hymnalId) {
            next = next.copy(index = minOf(old.index, maxOf(hymn.sungSequence.size - 1, 0)))
        }
        mutable.value = next
    }

    fun setPro(isPro: Boolean) = mutable.update { it.copy(isPro = isPro) }

    /** A TV connected or gone. While presenting, sends `church_mode_cast_changed`. */
    fun setExternalScreen(connected: Boolean) {
        val old = current
        if (old.isExternalScreenConnected == connected) return
        mutable.update { it.copy(isExternalScreenConnected = connected) }
        if (old.isActive) trackCast(connected)
    }

    // The presenter

    /** Church mode opened: the first verse, words showing. */
    fun start(source: ChurchModeSource) {
        enteredAt = clock()
        versesShown = 1
        hymnsShown = 1
        mutable.update { it.copy(isActive = true, index = 0, isBlanked = false, endRequested = false) }
        Analytics.track(AnalyticsEvent.ChurchModeEntered(source))
        Analytics.screen(AnalyticsScreen.ChurchMode)
        if (current.isExternalScreenConnected) trackCast(true)
    }

    /** Church mode closed. Sends `church_mode_exited`. */
    fun stop() {
        if (!current.isActive) return
        mutable.update { it.copy(isActive = false, isBlanked = false, endRequested = false) }
        val seconds = ((clock() - enteredAt) / 1000).toInt()
        Analytics.track(AnalyticsEvent.ChurchModeExited(seconds, versesShown, hymnsShown))
    }

    /** A tap forward: the next verse, or past the last one the next hymn; [ChurchMove.End] when there is none. */
    fun advance(): ChurchMove {
        mutable.update { it.copy(isBlanked = false) }
        if (!current.isLast) return next()
        return if (goToNextHymn()) ChurchMove.NextHymn else ChurchMove.End
    }

    /** The next verse of this hymn. */
    fun next(): ChurchMove {
        if (current.isLast) return ChurchMove.Limit
        mutable.update { it.copy(index = it.index + 1) }
        versesShown += 1
        return ChurchMove.Moved
    }

    /** The previous verse; the limit on the first verse of the hymn. Brings the words back. */
    fun previous(): ChurchMove {
        if (current.index <= 0) return ChurchMove.Limit
        mutable.update { it.copy(isBlanked = false, index = it.index - 1) }
        return ChurchMove.Moved
    }

    /** Blank shows only the TV's ground; returns whether it is blank now. */
    fun toggleBlank(): Boolean {
        mutable.update { it.copy(isBlanked = !it.isBlanked) }
        return current.isBlanked
    }

    /** The remote's Next hymn (the worship display is up). */
    fun nextHymn(): ChurchMove {
        mutable.update { it.copy(isBlanked = false) }
        return if (goToNextHymn()) ChurchMove.NextHymn else ChurchMove.Limit
    }

    /** Jumps to block `index` of the sung sequence (the presenter's verse list). */
    fun show(index: Int) {
        val count = current.sequence.size
        if (index !in 0 until count) return
        mutable.update { it.copy(index = index, isBlanked = false) }
    }

    fun showAnnouncement(message: String) = mutable.update { it.copy(announcement = message.trim().ifEmpty { null }) }
    fun showImage(image: String) = mutable.update { it.copy(image = image) }
    /** Clear: back to blank or the words. */
    fun clearSpecial() = mutable.update { it.copy(announcement = null, image = null) }

    /** The presenter has closed for an End request. */
    fun acknowledgeEnd() = mutable.update { it.copy(endRequested = false) }

    // The remote: the notification's and widget's buttons

    /**
     * The same moves as the presenter's arrows. Presenting is Pro (without
     * it, the paywall); verse buttons only act while church mode is up;
     * Next hymn works any time.
     */
    fun perform(action: ChurchRemoteAction) {
        val state = current
        if (!state.isPro) {
            host.showPaywall(ProFeature.AirPlay)
            return
        }
        if (action != ChurchRemoteAction.NextHymn && !state.isActive) return
        when (action) {
            ChurchRemoteAction.Blank -> toggleBlank()
            ChurchRemoteAction.NextHymn -> {
                mutable.update { it.copy(isBlanked = false) }
                goToNextHymn()
            }
            ChurchRemoteAction.Next -> {
                mutable.update { it.copy(isBlanked = false) }
                if (!current.isLast) mutable.update { it.copy(index = it.index + 1) } else goToNextHymn()
            }
            ChurchRemoteAction.Previous -> {
                mutable.update { it.copy(isBlanked = false) }
                if (current.index > 0) mutable.update { it.copy(index = it.index - 1) }
            }
            ChurchRemoteAction.End -> mutable.update { it.copy(endRequested = true) }
        }
    }

    private fun goToNextHymn(): Boolean {
        if (!host.goToNextHymn()) return false
        mutable.update { it.copy(index = 0) }
        return true
    }

    private fun trackCast(connected: Boolean) =
        Analytics.track(AnalyticsEvent.ChurchModeCastChanged(connected, connected && current.isPro))
}
