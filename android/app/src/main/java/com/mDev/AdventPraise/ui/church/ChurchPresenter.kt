package com.mDev.AdventPraise.ui.church

import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.audio.PlaybackPosition
import com.mDev.AdventPraise.data.Block
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.analytics.TextSizeContext
import com.mDev.AdventPraise.analytics.TextSizeMethod
import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.church.ChurchMove
import com.mDev.AdventPraise.church.ChurchSession
import com.mDev.AdventPraise.settings.AppSettings
import com.mDev.AdventPraise.settings.ReadingSettings
import com.mDev.AdventPraise.ui.design.HapticEvent
import com.mDev.AdventPraise.ui.design.Haptics

/**
 * Church mode's presenter on the phone (the actions half of ChurchModeView):
 * every tap, swipe, key and button becomes a move on [ChurchSession], with
 * iOS's haptic for how it went. Presenting on a TV is Pro: without it the
 * TV button and the presenter actions (Blank, Announcement, Show image)
 * open the paywall. Turning a verse always brings the words back.
 */
class ChurchPresenter(
    private val session: ChurchSession,
    private val settings: ReadingSettings,
    private val appSettings: AppSettings?,
    private val openPaywall: (ProFeature) -> Unit,
    /** Leaves church mode (past the last verse of the last hymn, or the remote's End). */
    private val close: () -> Unit,
    private val haptic: (HapticEvent) -> Unit = Haptics::play,
) {
    val isPro: Boolean get() = session.current.isPro

    /** A tap on the right, a swipe left, →, space: the next verse, then the next hymn; past the end, church mode closes. */
    fun advance() {
        when (session.advance()) {
            ChurchMove.Moved -> haptic(HapticEvent.LightImpact)
            // The new hymn is felt as its page turn.
            ChurchMove.NextHymn -> haptic(HapticEvent.PageTurn)
            ChurchMove.End -> close()
            ChurchMove.Limit -> haptic(HapticEvent.Limit)
        }
    }

    /** A tap on the left third, a swipe right, ←: the previous verse; the limit on the first. */
    fun previous() {
        when (session.previous()) {
            ChurchMove.Moved -> haptic(HapticEvent.LightImpact)
            else -> haptic(HapticEvent.Limit)
        }
    }

    /** The remote's Blank (the worship display is up): the TV shows only its ground, or the words again. */
    fun toggleBlank() {
        val blank = session.toggleBlank()
        haptic(HapticEvent.toggle(blank))
    }

    /** The remote's Next hymn. */
    fun nextHymnFromRemote() {
        when (session.nextHymn()) {
            ChurchMove.NextHymn -> haptic(HapticEvent.PageTurn)
            else -> haptic(HapticEvent.Limit)
        }
    }

    /** Presenter actions are Pro, like presenting itself: [action] runs with Pro, else the paywall. */
    fun presenterAction(action: () -> Unit) {
        if (!isPro) { openPaywall(ProFeature.AirPlay); return }
        action()
    }

    /** The TV button without Pro (iOS's locked AirPlay button). */
    fun tvLocked() = openPaywall(ProFeature.AirPlay)

    /** "Clear the TV": back to blank or the words. */
    fun clearSpecial() {
        session.clearSpecial()
        haptic(HapticEvent.ToggleOff)
    }

    // MARK: Announcement and picture (the presenter sheets)

    fun showAnnouncement(text: String) {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return
        session.showAnnouncement(trimmed)
        appSettings?.addAnnouncement(trimmed)
        haptic(HapticEvent.ToggleOn)
    }

    fun clearAnnouncement() {
        session.showAnnouncement("")
        haptic(HapticEvent.ToggleOff)
    }

    fun showImage(id: String) {
        session.showImage(id)
        haptic(HapticEvent.ToggleOn)
    }

    /** Clears the picture only; an announcement stays up. */
    fun clearImage() {
        val announcement = session.current.announcement
        session.clearSpecial()
        announcement?.let(session::showAnnouncement)
        haptic(HapticEvent.ToggleOff)
    }

    // MARK: Text size

    /** A− / A+: one worship step from wherever a pinch left it; the limit at either end. */
    fun changeTextSize(delta: Int): Boolean {
        val changed = settings.stepWorshipText(delta)
        haptic(if (changed) HapticEvent.Selection else HapticEvent.Limit)
        if (changed) track(TextSizeMethod.Buttons)
        return changed
    }

    /** Double-tap: back to the default size. */
    fun resetTextSize() {
        if (settings.isDefaultWorshipSize) return
        settings.resetWorshipSize()
        haptic(HapticEvent.SoftImpact)
        track(TextSizeMethod.Reset)
    }

    /** A pinch let go at [size]. */
    fun pinched(size: Float) {
        settings.updateWorshipPointSize(size)
        track(TextSizeMethod.Pinch)
    }

    private fun track(method: TextSizeMethod) =
        Analytics.track(AnalyticsEvent.TextSizeChanged(TextSizeContext.ChurchMode, method, settings.worshipPointSize.toInt()))
}

/**
 * Church mode follows the accompaniment's clock, never one of its own: the
 * block of the sung sequence for the verse (and chorus) being played, from
 * [com.mDev.AdventPraise.audio.AccompanimentPlayer.position]. Null when the
 * hymn has no such block.
 */
fun churchIndex(sequence: List<Block>, position: PlaybackPosition): Int? {
    val verse = sequence.indexOfFirst { it is Block.Verse && it.number == position.verse }
    if (verse < 0) return sequence.indexOfFirst { it is Block.Chorus }.takeIf { it >= 0 && position.verse == 0 }
    if (position.isChorus && sequence.getOrNull(verse + 1) is Block.Chorus) return verse + 1
    return verse
}
