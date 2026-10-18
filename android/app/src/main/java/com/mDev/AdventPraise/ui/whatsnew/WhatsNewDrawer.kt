// OWNER: shell
package com.mDev.AdventPraise.ui.whatsnew

import androidx.compose.runtime.Composable
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.ui.design.AdventDrawerStyle
import com.mDev.AdventPraise.ui.design.DrawerDetent
import com.mDev.AdventPraise.ui.design.HapticEvent
import com.mDev.AdventPraise.ui.design.Haptics
import com.mDev.AdventPraise.ui.design.WhatsNewActions
import com.mDev.AdventPraise.ui.design.WhatsNewPage
import com.mDev.AdventPraise.ui.design.stageBackground
import com.mDev.AdventPraise.settings.ReadingSurface
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.root.AppNavigator

/*
 * What's New in the drawer (WhatsNewSheet.swift's WhatsNewPresenter). Still to do
 * here (shell): show once per version after the splash (LocalSplashPhase, then a
 * 1.75 s pause), `whats_new_viewed` / `whats_new_dismissed`, and offering the tour
 * when it closes.
 */

/** Always the Stage: dark whatever the reading surface, fitted then large. */
val WhatsNewDrawerStyle = AdventDrawerStyle(
    detents = listOf(DrawerDetent.Fitted, DrawerDetent.Large),
    dimming = 0.5f,
    surface = ReadingSurface.Black,
    background = { stageBackground(0.92f) },
    actionScrim = DS.Palette.stage,
)

/** The scrolling page. */
@Composable
fun WhatsNewContent(services: AppServices, navigator: AppNavigator) {
    WhatsNewPage()
}

/** The pinned buttons: Try Worship Mode (church mode, felt) and Continue. */
@Composable
fun WhatsNewDrawerActions(services: AppServices, navigator: AppNavigator, onClose: () -> Unit) {
    WhatsNewActions(
        onPrimary = {
            Haptics.play(HapticEvent.MediumImpact)
            onClose()
            navigator.openChurchMode("whats_new")
        },
        onContinue = onClose,
    )
}
