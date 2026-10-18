// OWNER: shell
package com.mDev.AdventPraise.ui.tour

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.analytics.TourSource
import com.mDev.AdventPraise.reader.LecternState
import com.mDev.AdventPraise.settings.AppSettings
import com.mDev.AdventPraise.ui.design.HapticEvent
import com.mDev.AdventPraise.ui.design.Haptics

/*
 * The onboarding tour (TourModel.swift): eight coach marks over the real app.
 * It runs once, right after What's New is dismissed, and again from More's
 * Replay tour. Each step dims the screen around a real control (TourOverlay.kt
 * draws the cut-out and the card) and waits for the person to use it: open the
 * number pad and go to a hymn, swipe, open the tray, the globe, Play,
 * Memorise, church mode and its actions, then where Pro and Support live. A
 * step's later stages explain what opened and offer Next; Skip tour is on
 * every card.
 *
 * The model is a small state machine. It never reaches into the reader: the
 * host reports what happened (`observe`) and runs the few side effects a Next
 * needs (`perform`). While it runs, nothing played counts toward the free
 * plays (`FreePlays.isTourActive`, wired in AppServices).
 */

/** The eight stops, in order. [number] is the step shown. */
enum class TourStep(val number: Int) {
    NumberPad(1), Swipe(2), Tray(3), Globe(4), Player(5), Memorise(6), Church(7), Pro(8);

    val next: TourStep? get() = entries.getOrNull(ordinal + 1)
}

/**
 * Which part of the app a stage's card belongs to: the reader, church mode's
 * cover, or More's sheet. Android draws one overlay over the whole window, so
 * the area says when the card may show (its hierarchy is on top).
 */
enum class TourArea { Root, Church, More }

/**
 * A real control the tour points at. Composables mark themselves with
 * `Modifier.tourTarget(TourTarget.X)`; the overlay finds the bounds.
 */
enum class TourTarget {
    /** The Lectern's keypad button, number pad, title, hymn tray, Play and transport. */
    Jump, NumberPad, Title, Tray, Play, Transport,
    /** The globe in the top bar, and the menu bar it grows into. */
    Globe, MenuBar,
    /** Tiles in the hymn tray. */
    MemoriseTile, ChurchTile, MoreTile,
    /** Church mode's presenter actions (the slider) and its Leave button. */
    ChurchActions, ChurchLeave,
    /** More's Pro card and Support row. */
    ProCard, SupportRow,
    /** A tablet sidebar's two rows, lit together (iPad; unused on Android phones). */
    SidebarPro, SidebarSupport,
}

/** What the reader is like right now, which shapes a few stages. */
data class TourContext(
    /** The open hymn has a piano, so Play is on the bar. */
    val hasAccompaniment: Boolean = true,
    /** A tablet sidebar is out, so step 8 can point at its rows too. */
    val sidebarVisible: Boolean = false,
    /** The keypad opens a popover the tour can't see into. */
    val isRegularWidth: Boolean = false,
)

/** One card: where it is drawn, what it points at, what it says, and whether it offers Next or waits. */
data class TourStage(
    val area: TourArea,
    /** The controls lit together; empty for a card alone. */
    val targets: List<TourTarget>,
    val title: String,
    val body: String,
    /** Explains rather than asks: the card offers Next (Done on the last). */
    val showsNext: Boolean = false,
    /** Under a sheet the person is exploring: no card at all until it closes. */
    val isHidden: Boolean = false,
    /** Taps outside the cut-out are swallowed. Off for the swipe step. */
    val blocksTouches: Boolean = true,
) {
    val target: TourTarget? get() = targets.firstOrNull()
}

/** What the host tells the tour. */
sealed interface TourSignal {
    data class Lectern(val state: LecternState) : TourSignal
    data object HymnChanged : TourSignal
    data class MenuOpen(val open: Boolean) : TourSignal
    data class Playing(val playing: Boolean) : TourSignal
    data class MemoriseOpen(val open: Boolean) : TourSignal
    data class ChurchOpen(val open: Boolean) : TourSignal
    /** Church mode's presenter actions (text size, Blank, Announcement, Image) opened or closed. Church reports this. */
    data class ChurchActionsOpen(val open: Boolean) : TourSignal
    data class MoreOpen(val open: Boolean) : TourSignal
}

/** What a Next may need done to the reader. */
enum class TourAction {
    /** Before step 1: the tray and the menu closed. */
    ResetChrome, CloseLectern, CloseMenu, StopPlayer, LeaveChurchMode, CloseMore,
}

/** Where the tour is. */
sealed interface TourPhase {
    data object Idle : TourPhase
    data class Running(val step: TourStep, val stage: Int) : TourPhase
    /** "You're all set", after step 8. */
    data object Finale : TourPhase
}

/**
 * The tour's state machine. Compose state: the overlay reads [stage] and
 * [cardId]. [track] and [haptic] are injectable for the tests.
 */
class TourModel(
    private val settings: AppSettings,
    private val track: (AnalyticsEvent) -> Unit = Analytics::track,
    private val haptic: (HapticEvent) -> Unit = Haptics::play,
) {
    var phase: TourPhase by mutableStateOf(TourPhase.Idle)
        private set
    var isActive by mutableStateOf(false)
        private set
    /** What the reader is like; the host keeps it current. */
    var context by mutableStateOf(TourContext())
    /**
     * A start asked for while something else was up (What's New's Try
     * Worship Mode opens church mode first). The host starts it once the
     * screen is clear.
     */
    var pending: TourSource? by mutableStateOf(null)
        private set
    /** The host runs these for the model. */
    var perform: ((TourAction) -> Unit)? = null
    /** FreePlays follows this (AppServices). */
    var onActiveChanged: ((Boolean) -> Unit)? = null
    private var furthestStep = TourStep.NumberPad

    val hasCompleted: Boolean get() = settings.tourSeen

    val step: TourStep? get() = (phase as? TourPhase.Running)?.step
    val stageIndex: Int get() = (phase as? TourPhase.Running)?.stage ?: 0

    /** The card to draw now, if any. */
    val stage: TourStage?
        get() = when (val p = phase) {
            TourPhase.Idle -> null
            is TourPhase.Running -> stages(p.step).getOrNull(p.stage)
            TourPhase.Finale -> TourStage(TourArea.Root, emptyList(), "You’re all set",
                "That’s the tour. Replay it any time from More. Happy singing.", showsNext = true)
        }

    /** One value per card, for the card's transitions. */
    val cardId: String
        get() = when (val p = phase) {
            TourPhase.Idle -> "idle"
            is TourPhase.Running -> "${p.step.number}.${p.stage}"
            TourPhase.Finale -> "finale"
        }

    // Starting and ending

    /** What's New has just closed: the tour follows, once, unless it has been taken. */
    fun offerAfterWhatsNew() {
        if (hasCompleted || isActive || pending != null) return
        pending = TourSource.WhatsNew
    }

    /** Launch with What's New already dismissed (an existing user): the tour runs once, when the reader is clear. */
    fun offerOnLaunch() = offerAfterWhatsNew()

    /** The screen is clear (no church mode, More or sheet): a pending start goes ahead. */
    fun startPending() {
        val source = pending ?: return
        pending = null
        start(source)
    }

    fun start(source: TourSource, at: TourStep = TourStep.NumberPad, stage: Int = 0) {
        furthestStep = at
        pending = null
        perform?.invoke(TourAction.ResetChrome)
        track(AnalyticsEvent.TourStarted(source))
        set(TourPhase.Running(at, stage))
        haptic(HapticEvent.SoftImpact)
        onActiveChanged?.invoke(true)
    }

    /** Skip tour: ends it here. It won't come back after What's New. */
    fun skip() {
        if (!isActive) return
        finish(completed = false)
    }

    /** Next, or Done on the last card. */
    fun advance() {
        when (val p = phase) {
            TourPhase.Idle -> Unit
            TourPhase.Finale -> finish(completed = true)
            is TourPhase.Running -> {
                leave(p.step, p.stage)
                moveOn(p.step, p.stage)
            }
        }
    }

    private fun finish(completed: Boolean) {
        settings.markTourSeen()
        track(AnalyticsEvent.TourFinished(completed, furthestStep.number))
        set(TourPhase.Idle)
        haptic(if (completed) HapticEvent.Success else HapticEvent.SoftImpact)
        onActiveChanged?.invoke(false)
    }

    // Observing

    /** Something happened in the reader. The current stage decides whether it was the thing asked for. */
    fun observe(signal: TourSignal) {
        val p = phase as? TourPhase.Running ?: return
        val step = p.step
        val index = p.stage
        when (step) {
            // 1 · Number pad: open it, type, Go.
            TourStep.NumberPad -> when {
                index == 0 && signal == TourSignal.Lectern(LecternState.Pad) -> go(step, 1)
                index == 1 && (signal == TourSignal.Lectern(LecternState.Collapsed) || signal == TourSignal.Lectern(LecternState.Search)) -> go(step, 0)
                signal == TourSignal.HymnChanged -> complete(step)
            }
            // 2 · Swipe.
            TourStep.Swipe -> if (signal == TourSignal.HymnChanged) complete(step)
            // 3 · The tray.
            TourStep.Tray -> when {
                index == 0 && signal == TourSignal.Lectern(LecternState.Hymn) -> go(step, 1)
                index == 1 && signal == TourSignal.Lectern(LecternState.Collapsed) -> complete(step)
            }
            // 4 · The globe.
            TourStep.Globe -> when {
                index == 0 && signal == TourSignal.MenuOpen(true) -> go(step, 1)
                index == 1 && signal == TourSignal.MenuOpen(false) -> complete(step)
            }
            // 5 · The piano.
            TourStep.Player -> if (index == 0 && signal == TourSignal.Playing(true) && context.hasAccompaniment) go(step, 1)
            // 6 · Memorise, in the tray; the sheet is explored, then the tour goes on.
            TourStep.Memorise -> when {
                index == 0 && signal == TourSignal.Lectern(LecternState.Hymn) -> go(step, 1)
                index == 1 && signal == TourSignal.Lectern(LecternState.Collapsed) -> go(step, 0)
                signal == TourSignal.MemoriseOpen(true) -> go(step, 2)
                index == 2 && signal == TourSignal.MemoriseOpen(false) -> complete(step)
            }
            // 7 · Church mode and its actions.
            TourStep.Church -> when {
                index == 0 && signal == TourSignal.Lectern(LecternState.Hymn) -> go(step, 1)
                index == 1 && signal == TourSignal.Lectern(LecternState.Collapsed) -> go(step, 0)
                index <= 1 && signal == TourSignal.ChurchOpen(true) -> go(step, 2)
                index == 2 && signal == TourSignal.ChurchActionsOpen(true) -> go(step, 3)
                index == 3 && signal == TourSignal.ChurchActionsOpen(false) -> go(step, 4)
                index in 2..4 && signal == TourSignal.ChurchOpen(false) -> complete(step)
            }
            // 8 · Pro and Support, in More (and a tablet sidebar).
            TourStep.Pro -> when {
                index == 0 && signal == TourSignal.Lectern(LecternState.Hymn) -> go(step, 1)
                index == 1 && signal == TourSignal.Lectern(LecternState.Collapsed) -> go(step, 0)
                index <= 1 && signal == TourSignal.MoreOpen(true) -> go(step, 2)
                index in 2..3 && signal == TourSignal.MoreOpen(false) ->
                    if (context.sidebarVisible) go(step, 4) else complete(step)
            }
        }
    }

    // Stages

    /** The cards of a step, in order. */
    fun stages(step: TourStep): List<TourStage> = when (step) {
        TourStep.NumberPad -> listOf(
            TourStage(TourArea.Root, listOf(TourTarget.Jump), "Find a hymn by number",
                "Tap the keypad to open the number pad."),
            TourStage(TourArea.Root, listOf(TourTarget.NumberPad), "Type a number, then tap Go",
                "The title appears as you type, so you know you have the right hymn.",
                isHidden = context.isRegularWidth),
        )
        TourStep.Swipe -> listOf(
            TourStage(TourArea.Root, emptyList(), "Turn the page",
                "Swipe left for the next hymn and right for the one before. The arrow at the edge fills up when you have gone far enough to let go.",
                showsNext = true, blocksTouches = false),
        )
        TourStep.Tray -> listOf(
            TourStage(TourArea.Root, listOf(TourTarget.Title), "Everything for this hymn",
                "Tap the number or title on the bar to open the hymn tray."),
            TourStage(TourArea.Root, listOf(TourTarget.Tray), "The hymn tray",
                "Church mode, Memorise, playlists and Save are all one tap away. More, at the end, holds the tools and settings.",
                showsNext = true),
        )
        TourStep.Globe -> listOf(
            TourStage(TourArea.Root, listOf(TourTarget.Globe), "Translations, theme and text",
                "Tap the globe at the top."),
            TourStage(TourArea.Root, listOf(TourTarget.MenuBar), "Read it your way",
                "Switch hymnals and keep your hymn number, pick a reading surface, or set the text size and font. About tells the hymn’s story.",
                showsNext = true),
        )
        TourStep.Player -> if (!context.hasAccompaniment) listOf(
            TourStage(TourArea.Root, emptyList(), "Hear the piano",
                "Hymns with a piano show Play at the left of the bar, and the verse being sung lights up as it goes. This hymn has no piano yet.",
                showsNext = true),
        ) else listOf(
            TourStage(TourArea.Root, listOf(TourTarget.Play), "Hear the piano",
                "Tap Play. Nothing you play on the tour counts toward your free plays."),
            TourStage(TourArea.Root, listOf(TourTarget.Transport), "Sing along",
                "The verse being sung lights up as it goes. Restart, scrub, or change the tempo here, and pause whenever you like.",
                showsNext = true),
        )
        TourStep.Memorise -> listOf(
            TourStage(TourArea.Root, listOf(TourTarget.Title), "Learn a verse by heart",
                "Open the hymn tray again."),
            TourStage(TourArea.Root, listOf(TourTarget.MemoriseTile), "Learn a verse by heart",
                "Tap Memorise and fill in the missing words. Tap Done there to come back to the tour."),
            TourStage(TourArea.Root, emptyList(), "", "", isHidden = true),
        )
        TourStep.Church -> listOf(
            TourStage(TourArea.Root, listOf(TourTarget.Title), "Sing together",
                "Open the hymn tray."),
            TourStage(TourArea.Root, listOf(TourTarget.ChurchTile), "Sing together",
                "Tap Church for one verse at a time, big and bright."),
            TourStage(TourArea.Church, listOf(TourTarget.ChurchActions), "Church mode",
                "Tap the slider for text size, Blank, Announcement and Image."),
            TourStage(TourArea.Church, emptyList(), "", "", isHidden = true),
            // iOS says AirPlay; on Android the words reach a TV through Cast (or a second display).
            TourStage(TourArea.Church, listOf(TourTarget.ChurchLeave), "Leading the singing",
                "Tap the right side of the screen for the next verse, the left to go back. With Pro, Cast puts the words on a TV. Tap X when you are done.",
                showsNext = true),
        )
        TourStep.Pro -> buildList {
            add(TourStage(TourArea.Root, listOf(TourTarget.Title), "Pro and support",
                "Open the hymn tray one last time."))
            add(TourStage(TourArea.Root, listOf(TourTarget.MoreTile), "Pro and support",
                "Tap More."))
            add(TourStage(TourArea.More, listOf(TourTarget.ProCard), "Advent Praise Pro",
                "Unlimited piano, sheet music, the worship display on a TV and more, as a yearly subscription with a free trial to start. Tap this card any time to see what Pro opens.",
                showsNext = true))
            add(TourStage(TourArea.More, listOf(TourTarget.SupportRow), "Support Advent Praise",
                "A one-time tip to keep the hymns ringing. It unlocks nothing and is never required.",
                showsNext = true))
            if (context.sidebarVisible) {
                add(TourStage(TourArea.Root, listOf(TourTarget.SidebarPro, TourTarget.SidebarSupport), "Also in the sidebar",
                    "On a tablet, Pro and Support are one tap away here too.", showsNext = true))
            }
        }
    }

    // Private

    private fun go(step: TourStep, stage: Int) {
        set(TourPhase.Running(step, stage))
        haptic(HapticEvent.Selection)
    }

    /** The step is done: on to the next, or the finale. */
    private fun complete(step: TourStep) {
        track(AnalyticsEvent.TourStepCompleted(step.number))
        val next = step.next
        if (next != null) {
            furthestStep = next
            set(TourPhase.Running(next, 0))
        } else {
            set(TourPhase.Finale)
        }
        haptic(HapticEvent.SoftImpact)
    }

    /** Next on an explaining stage: what to put back before moving on. */
    private fun leave(step: TourStep, stage: Int) {
        when {
            step == TourStep.Tray && stage == 1 -> perform?.invoke(TourAction.CloseLectern)
            step == TourStep.Globe && stage == 1 -> perform?.invoke(TourAction.CloseMenu)
            step == TourStep.Player && stage == 1 -> perform?.invoke(TourAction.StopPlayer)
            step == TourStep.Church && stage == 4 -> perform?.invoke(TourAction.LeaveChurchMode)
            step == TourStep.Pro && stage == 3 -> perform?.invoke(TourAction.CloseMore)
        }
    }

    /** Where Next goes from each stage. */
    private fun moveOn(step: TourStep, stage: Int) {
        when {
            // Leaving church mode reports ChurchOpen(false), which completes the step.
            step == TourStep.Church && stage == 4 -> Unit
            // Closing More reports MoreOpen(false): the sidebar stage or the finale follows.
            step == TourStep.Pro && stage == 3 -> Unit
            step == TourStep.Pro && stage == 4 -> complete(step)
            else -> {
                val all = stages(step)
                if (stage + 1 < all.size && !all[stage + 1].isHidden) go(step, stage + 1) else complete(step)
            }
        }
    }

    private fun set(next: TourPhase) {
        if (phase == next) return
        phase = next
        val active = next != TourPhase.Idle
        if (isActive != active) isActive = active
    }
}
