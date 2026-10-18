// OWNER: shell
package com.mDev.AdventPraise.ui.support

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.RadioButtonUnchecked
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.style.LineBreak
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsScreen
import com.mDev.AdventPraise.billing.PurchaseStore
import com.mDev.AdventPraise.billing.TipIcon
import com.mDev.AdventPraise.billing.TipOption
import com.mDev.AdventPraise.ui.design.GlassButton
import com.mDev.AdventPraise.ui.design.HapticEvent
import com.mDev.AdventPraise.ui.design.Haptics
import com.mDev.AdventPraise.ui.design.dsPress
import com.mDev.AdventPraise.ui.design.findActivity
import com.mDev.AdventPraise.ui.paywall.PaywallBackdrop
import com.mDev.AdventPraise.ui.paywall.PaywallChrome
import com.mDev.AdventPraise.ui.paywall.PaywallHeader
import com.mDev.AdventPraise.ui.paywall.PaywallLogo
import com.mDev.AdventPraise.ui.paywall.PaywallPalette
import com.mDev.AdventPraise.ui.paywall.PaywallPriceStatus
import com.mDev.AdventPraise.ui.paywall.paywallRise
import com.mDev.AdventPraise.ui.paywall.rememberPaywallOpening
import com.mDev.AdventPraise.ui.paywall.rememberStillMotion
import com.mDev.AdventPraise.ui.root.AppNavigator
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import com.mDev.AdventPraise.ui.theme.rememberReduceMotion
import kotlinx.coroutines.launch

/*
 * Support Advent Praise (SupportView.swift): the three one-off tips (Amen,
 * Hallelujah, Hosanna), open to free and Pro users alike, with Google Play's
 * prices. It opens from More exactly like the Pro paywall (PaywallChrome): the
 * light and the crowd of hands, Close at the top, the header, and one floating
 * button that gives the tip chosen above it. It opens over More, which stays
 * open under it. Tips are consumables that unlock nothing; the screen says so.
 * A tip that goes through opens the thank-you: "Praise the Lord!" over the
 * light and the hands.
 */

/** Support Advent Praise (Destination.Support). */
@Composable
fun SupportScreen(services: AppServices, navigator: AppNavigator, onClose: () -> Unit) {
    val store = services.store
    val activity = LocalContext.current.findActivity()
    val scope = rememberCoroutineScope()
    SupportContent(store, onClose) { tip -> scope.launch { store.tip(activity, tip) } }
}

/** The tips' symbols: iOS's heart.fill, music.note and sparkles. */
private val TipIcon.vector: ImageVector
    get() = when (this) {
        TipIcon.Heart -> Icons.Rounded.Favorite
        TipIcon.MusicNote -> Icons.Rounded.MusicNote
        TipIcon.Sparkles -> Icons.Rounded.AutoAwesome
    }

/** The tip the button gives: the one chosen, else the middle one (Hallelujah). */
fun chosenTip(tips: List<TipOption>, chosenId: String?): TipOption? =
    tips.firstOrNull { it.id == chosenId } ?: tips.drop(tips.size / 2).firstOrNull()

@Composable
fun SupportContent(store: PurchaseStore, onClose: () -> Unit, onTip: (TipOption) -> Unit) {
    val p = LocalSurface.current
    val palette = PaywallPalette(p)
    val scope = rememberCoroutineScope()
    val opened = rememberPaywallOpening()
    var chosenId by rememberSaveable { mutableStateOf<String?>(null) }
    val chosen = chosenTip(store.tips, chosenId)
    LaunchedEffect(Unit) {
        Analytics.screen(AnalyticsScreen.Support)
        if (store.tips.isEmpty()) store.loadStorefront()
    }

    Box(Modifier.fillMaxSize()) {
        PaywallChrome(
            opened = opened,
            onClose = onClose,
            page = {
                Column(
                    Modifier.fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(DS.Space.l + DS.Space.xxs),
                ) {
                    PaywallHeader(
                        eyebrow = "SUPPORT THE MINISTRY",
                        title = "A Note from Malcolm",
                        lead = "Hi, I’m Malcolm. I built Advent Praise in my spare time to keep sacred hymns accessible and uplift hearts in worship. If this music has been a blessing to your devotional life or home, a one-time tip helps cover ongoing costs and sustains this independent ministry.",
                    )
                    when {
                        store.tips.isNotEmpty() -> Column(
                            Modifier.fillMaxWidth().semantics { contentDescription = "Tips" },
                            verticalArrangement = Arrangement.spacedBy(DS.Space.s),
                        ) {
                            store.tips.forEachIndexed { index, tip ->
                                TipRow(
                                    tip, isChosen = tip == chosen, enabled = store.tipping == null,
                                    modifier = Modifier.paywallRise(opened, delayMs = 250L + index * 50L),
                                ) {
                                    Haptics.play(HapticEvent.Selection)
                                    chosenId = tip.id
                                }
                            }
                        }
                        // While loading: the spinner; failed: iOS's no-tips state with Try again.
                        else -> PaywallPriceStatus(
                            store, "Couldn’t reach Google Play for the tips. Check your connection and try again.",
                        ) { scope.launch { store.loadStorefront() } }
                    }
                    Text(
                        "Tips are a one-time gift to support the app; they do not recur or unlock digital features. Advent Praise Pro is separate.",
                        style = DS.Type.caption, color = p.secondary, textAlign = TextAlign.Center,
                        modifier = Modifier.padding(horizontal = DS.Space.m),
                    )
                }
            },
            actions = {
                // The one button: the chosen tip, with Google Play's price on it.
                if (chosen != null) {
                    GlassButton(
                        "Support the Ministry · ${chosen.price}",
                        onClick = { onTip(chosen) },
                        tint = palette.brass,
                        isLoading = store.tipping != null,
                        fullWidth = true,
                        enabled = store.tipping == null,
                    )
                }
            },
        )
        // After a tip: the thank-you, over Support.
        TipThankYouOverlay(store.thankYouForTip) { store.thankYouForTip = null }
    }
}

/**
 * One tip: its name and a line, with Google Play's price. Tapping chooses it
 * for the button below. Content on the surface, so a fill and outline, no
 * glass; the chosen one is brass.
 */
@Composable
private fun TipRow(tip: TipOption, isChosen: Boolean, enabled: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val p = LocalSurface.current
    val palette = PaywallPalette(p)
    val shape = RoundedCornerShape(DS.Radius.tile)
    val interaction = remember { MutableInteractionSource() }
    Row(
        modifier
            .fillMaxWidth()
            .heightIn(min = DS.Size.row + 8.dp)
            .dsPress(interaction, enabled)
            .background(if (isChosen) palette.gold.copy(alpha = if (palette.isDark) 0.14f else 0.18f) else p.primary(DS.Fill.row), shape)
            .border(if (isChosen) 1.5.dp else 1.dp, if (isChosen) palette.brass.copy(alpha = 0.7f) else p.controlBorder.copy(alpha = 0.3f), shape)
            .clickable(interaction, indication = null, enabled = enabled, role = Role.Button, onClick = onClick)
            .semantics(mergeDescendants = true) {
                contentDescription = "${tip.name} tip, ${tip.price}"
                stateDescription = tip.blurb
                selected = isChosen
            }
            .padding(DS.Space.m),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Space.m),
    ) {
        Icon(tip.icon.vector, null, tint = palette.brass, modifier = Modifier.width(30.dp).size(24.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(DS.Space.hair)) {
            Text(tip.name, style = DS.Type.rowTitle, color = p.foreground)
            Text(tip.blurb, style = DS.Type.caption, color = p.secondary)
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DS.Space.s)) {
            Text(tip.price, style = DS.Type.button.copy(fontFeatureSettings = "tnum"), color = if (isChosen) palette.brass else p.secondary)
            Icon(
                if (isChosen) Icons.Rounded.CheckCircle else Icons.Rounded.RadioButtonUnchecked, null,
                tint = if (isChosen) palette.brass else p.secondary.copy(alpha = p.secondary.alpha * 0.6f),
                modifier = Modifier.size(24.dp),
            )
        }
    }
}

/** The thank-you as a 420 dp sheet over Support (TipThankYouSheet's `.height(420)` detent). [tip] null: closed. */
@Composable
private fun TipThankYouOverlay(tip: TipOption?, onDone: () -> Unit) {
    var shown by remember { mutableStateOf(tip) }
    SideEffect { if (tip != null) shown = tip }
    val reduce = rememberReduceMotion() || rememberStillMotion()
    BackHandler(enabled = tip != null, onBack = onDone)
    Box(Modifier.fillMaxSize()) {
        AnimatedVisibility(tip != null, enter = fadeIn(), exit = fadeOut()) {
            Box(
                Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.36f))
                    .clickable(remember { MutableInteractionSource() }, null, onClick = onDone),
            )
        }
        AnimatedVisibility(
            tip != null,
            modifier = Modifier.align(Alignment.BottomCenter),
            enter = if (reduce) fadeIn(tween(200)) else slideInVertically { it } + fadeIn(),
            exit = if (reduce) fadeOut(tween(200)) else slideOutVertically { it } + fadeOut(),
        ) {
            val shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)
            Box(Modifier.fillMaxWidth().height(420.dp).clip(shape)) { TipThankYou(onDone) }
        }
    }
}

/** "Praise the Lord!" over the light and the crowd of hands, with Amen. */
@Composable
fun TipThankYou(onDone: () -> Unit, modifier: Modifier = Modifier) {
    val p = LocalSurface.current
    val palette = PaywallPalette(p)
    val opened = rememberPaywallOpening()
    PaywallBackdrop(palette, lifted = opened, modifier = modifier, handHeight = 150.dp, lightIntensity = 0.9f) {
        Column(
            Modifier
                .fillMaxSize()
                .padding(horizontal = DS.Space.l + DS.Space.xxs)
                .windowInsetsPadding(WindowInsets.navigationBars)
                .paywallRise(opened),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(DS.Space.m),
        ) {
            // The grabber.
            Box(Modifier.padding(top = DS.Space.xs).size(36.dp, 5.dp).background(p.primary(0.28f), RoundedCornerShape(50)))
            PaywallLogo(palette, Modifier.padding(top = DS.Space.l), width = 64.dp)
            Text("Praise the Lord!", style = DS.Type.display.copy(lineBreak = LineBreak.Heading), color = p.foreground,
                textAlign = TextAlign.Center, modifier = Modifier.semantics { heading() })
            Text("Thank you for supporting Advent Praise.", style = DS.Type.rowBody, color = p.secondary, textAlign = TextAlign.Center)
            Spacer(Modifier.weight(1f))
            GlassButton("Amen", onClick = onDone, tint = palette.brass, fullWidth = true,
                modifier = Modifier.widthIn(max = 400.dp).padding(bottom = DS.Space.l))
        }
    }
}

/** Thanks for a tip as its own sheet (Destination.TipThanks). */
@Composable
fun TipThanksSheet(services: AppServices, navigator: AppNavigator, tipId: String, onClose: () -> Unit) {
    TipThankYou(onDone = {
        if (services.store.thankYouForTip?.id == tipId) services.store.thankYouForTip = null
        onClose()
    })
}
