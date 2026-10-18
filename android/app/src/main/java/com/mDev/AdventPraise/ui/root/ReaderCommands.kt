package com.mDev.AdventPraise.ui.root

import android.view.KeyEvent
import android.view.KeyboardShortcutGroup
import android.view.KeyboardShortcutInfo
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.ui.design.HapticEvent
import com.mDev.AdventPraise.ui.design.Haptics

/**
 * Hardware-keyboard shortcuts for the reader (ReaderCommands.swift), listed in
 * Android's keyboard shortcuts helper (Meta + /). Ctrl stands in for ⌘. They act
 * on the same ReaderModel the Lectern drives, and only while nothing is presented
 * over the reader.
 */
object ReaderCommands {
    private const val CTRL = KeyEvent.META_CTRL_ON
    private const val CTRL_ALT = KeyEvent.META_CTRL_ON or KeyEvent.META_ALT_ON

    /** True when [event] was one of the reader's commands and was handled. */
    fun handle(event: KeyEvent, services: AppServices): Boolean {
        if (event.action != KeyEvent.ACTION_DOWN || event.repeatCount > 0) return false
        val navigator = services.navigator
        if (navigator.stack.isNotEmpty()) return false
        val reader = services.reader
        val ctrl = event.isCtrlPressed && !event.isShiftPressed && !event.isMetaPressed
        return when {
            ctrl && !event.isAltPressed && event.keyCode == KeyEvent.KEYCODE_RIGHT_BRACKET -> {
                if (reader.goToNext("keyboard") != null) Haptics.play(HapticEvent.PageTurn) else Haptics.play(HapticEvent.Limit)
                true
            }
            ctrl && !event.isAltPressed && event.keyCode == KeyEvent.KEYCODE_LEFT_BRACKET -> {
                if (reader.goToPrevious("keyboard") != null) Haptics.play(HapticEvent.PageTurn) else Haptics.play(HapticEvent.Limit)
                true
            }
            ctrl && !event.isAltPressed && event.keyCode == KeyEvent.KEYCODE_D -> { reader.toggleFavourite(); true }
            // ⌥⌘P on iOS ("play slideshow" in Keynote): Ctrl+Alt+P here.
            ctrl && event.isAltPressed && event.keyCode == KeyEvent.KEYCODE_P -> { navigator.openChurchMode("keyboard"); true }
            else -> false
        }
    }

    /** The "Hymn" group for the keyboard shortcuts helper. */
    fun shortcutGroup(): KeyboardShortcutGroup = KeyboardShortcutGroup(
        "Hymn",
        listOf(
            KeyboardShortcutInfo("Next Hymn", KeyEvent.KEYCODE_RIGHT_BRACKET, CTRL),
            KeyboardShortcutInfo("Previous Hymn", KeyEvent.KEYCODE_LEFT_BRACKET, CTRL),
            KeyboardShortcutInfo("Add or Remove Favourite", KeyEvent.KEYCODE_D, CTRL),
            KeyboardShortcutInfo("Church Mode", KeyEvent.KEYCODE_P, CTRL_ALT),
        ),
    )
}
