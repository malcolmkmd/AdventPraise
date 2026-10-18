// OWNER: shell
package com.mDev.AdventPraise.ui.paywall

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.LineBreak
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.billing.PurchaseStore
import com.mDev.AdventPraise.ui.design.Eyebrow
import com.mDev.AdventPraise.ui.design.GlassButton
import com.mDev.AdventPraise.ui.design.GlassButtonKind
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import com.mDev.AdventPraise.ui.theme.rememberReduceMotion
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/*
 * The paywall's frame (PaywallChrome in ProPaywall.swift), shared by the Pro
 * paywall and Support Advent Praise: the light and the hands behind a page
 * that scrolls, Close at the top and the call to action floating at the
 * bottom. It runs the opening (`opened`: the hands lift, the page and the
 * action rise); pieces of the page rise after it with `paywallRise`.
 */

/** Height of a front-row hand behind the paywall. */
val PaywallHandHeight = 184.dp
/** How far the words fade out above the pinned button. */
private val FadeHeight = 44.dp

/** Whether the paywall's words run past the fold, and whether they've been scrolled (PaywallScrollState). */
data class PaywallScrollState(val moreBelow: Boolean = false, val scrolled: Boolean = false) {
    /** The hint shows while there's more below, until the first scroll. */
    val showsHint: Boolean get() = moreBelow && !scrolled

    companion object {
        /**
         * [remaining] is how far the words run below what's on screen, without the
         * empty room under them. More below means a line or two hidden (72 dp), not
         * the last few points; scrolled is past 12 dp.
         */
        fun from(offset: Float, remaining: Float, density: Float, scrolled: Boolean): PaywallScrollState =
            PaywallScrollState(moreBelow = remaining > 72f * density, scrolled = scrolled || offset > 12f * density)
    }
}

/**
 * The opening: a beat after the sheet lands, so the lift is seen. Starts
 * open when still (screenshots) so nothing waits.
 */
@Composable
fun rememberPaywallOpening(): Boolean {
    val still = rememberStillMotion()
    var opened by rememberSaveable { mutableStateOf(still) }
    LaunchedEffect(Unit) {
        if (!opened) { delay(150); opened = true }
    }
    return opened
}

/**
 * The paywall's frame. [page] scrolls; [actions] float at the bottom (empty
 * when there is nothing to buy). [moreHint] ("See everything in Pro") shows
 * over the fade while there is more below, until the first scroll.
 */
@Composable
fun PaywallChrome(
    opened: Boolean,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
    moreHint: String? = null,
    scroll: ScrollState = rememberScrollState(),
    page: @Composable ColumnScope.() -> Unit,
    actions: @Composable ColumnScope.() -> Unit,
) {
    val p = LocalSurface.current
    val palette = PaywallPalette(p)
    val density = LocalDensity.current
    val scope = rememberCoroutineScope()
    var scrolledOnce by remember { mutableStateOf(false) }
    val trailing = with(density) { (PaywallHandHeight * 0.55f).toPx() }
    val state = PaywallScrollState.from(
        offset = scroll.value.toFloat(),
        remaining = (scroll.maxValue - scroll.value).toFloat() - trailing,
        density = density.density,
        scrolled = scrolledOnce,
    )
    if (state.scrolled && !scrolledOnce) scrolledOnce = true

    PaywallBackdrop(palette, lifted = opened, modifier = modifier, handHeight = PaywallHandHeight) {
        Column(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.navigationBars)) {
            Box(Modifier.weight(1f).fillMaxWidth()) {
                Column(
                    Modifier
                        .fillMaxSize()
                        // The words fade out just above the button, so it's plain there's more.
                        .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
                        .drawWithContent {
                            drawContent()
                            val fade = FadeHeight.toPx()
                            drawRect(
                                Brush.verticalGradient(listOf(Color.Black, Color.Transparent), startY = size.height - fade, endY = size.height),
                                topLeft = Offset(0f, size.height - fade), size = Size(size.width, fade), blendMode = BlendMode.DstIn,
                            )
                        }
                        .verticalScroll(scroll),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Column(
                        Modifier
                            .widthIn(max = 560.dp)
                            .fillMaxWidth()
                            .padding(horizontal = DS.Space.l + DS.Space.xxs)
                            .padding(top = DS.Space.l, bottom = PaywallHandHeight * 0.55f)
                            .paywallRise(opened),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        content = page,
                    )
                }
                // "See everything in Pro ⌄": scrolls to the end. Just above the button, over the fade.
                if (moreHint != null) {
                    MoreHintOverlay(state.showsHint, moreHint, palette, Modifier.align(Alignment.BottomCenter).offset(y = -DS.Space.xxs)) {
                        scope.launch { scroll.animateScrollTo(scroll.maxValue) }
                    }
                }
            }
            Column(
                Modifier
                    .align(Alignment.CenterHorizontally)
                    .widthIn(max = 560.dp)
                    .fillMaxWidth()
                    .padding(horizontal = DS.Space.l + DS.Space.xxs)
                    .padding(top = DS.Space.s, bottom = DS.Space.m)
                    .paywallRise(opened, delayMs = 450),
                content = actions,
            )
        }
        GlassButton(
            "Close", onClick = onClose, kind = GlassButtonKind.Icon, icon = Icons.Rounded.Close,
            modifier = Modifier.align(Alignment.TopEnd).padding(top = DS.Space.m, end = DS.Space.m),
        )
    }
}

@Composable
private fun MoreHintOverlay(visible: Boolean, title: String, palette: PaywallPalette, modifier: Modifier, onClick: () -> Unit) {
    AnimatedVisibility(visible = visible, enter = fadeIn(tween(250)), exit = fadeOut(tween(250)), modifier = modifier) {
        MoreHint(title, palette, onClick)
    }
}

@Composable
private fun MoreHint(title: String, palette: PaywallPalette, onClick: () -> Unit) {
    val p = LocalSurface.current
    Box(
        Modifier
            .heightIn(min = DS.Size.hitTarget)
            .clip(RoundedCornerShape(50))
            .clickable(onClick = onClick)
            .semantics { role = Role.Button },
        contentAlignment = Alignment.Center,
    ) {
        Row(
            Modifier
                .background(p.background.copy(alpha = 0.9f), RoundedCornerShape(50))
                .padding(horizontal = DS.Space.m, vertical = DS.Space.xs),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(DS.Space.xxs),
        ) {
            Text(title, style = DS.Type.caption.copy(fontWeight = FontWeight.SemiBold), color = palette.brass)
            Icon(Icons.Rounded.KeyboardArrowDown, null, tint = palette.brass, modifier = Modifier.size(14.dp))
        }
    }
}

/**
 * Fades up a little as the paywall opens (fade only with animations off), after
 * [delayMs] (PaywallRise). Shared with Support and the tip thank-you.
 */
fun Modifier.paywallRise(opened: Boolean, delayMs: Long = 100): Modifier = composed {
    val still = rememberStillMotion()
    val reduce = rememberReduceMotion()
    val progress = remember { Animatable(if (opened && still) 1f else 0f) }
    LaunchedEffect(opened) {
        if (still) { progress.snapTo(if (opened) 1f else 0f); return@LaunchedEffect }
        if (opened) delay(delayMs)
        progress.animateTo(if (opened) 1f else 0f,
            if (reduce) tween(450, easing = DS.Motion.easeInOut) else DS.Motion.criticalSpring(0.8f))
    }
    val rise = with(LocalDensity.current) { 14.dp.toPx() }
    graphicsLayer {
        alpha = progress.value
        translationY = if (reduce) 0f else (1f - progress.value) * rise
    }
}

/** The paywall's header: the church logo, a brass eyebrow, the title and a line or two under it. */
@Composable
fun PaywallHeader(eyebrow: String, title: String, lead: String) {
    val p = LocalSurface.current
    val palette = PaywallPalette(p)
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(DS.Space.m)) {
        PaywallLogo(palette, Modifier.padding(top = DS.Space.l))
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(DS.Space.s)) {
            Eyebrow(eyebrow, palette.brass, tracking = 1.6f)
            Text(title, style = DS.Type.display.copy(lineBreak = LineBreak.Heading), color = p.foreground,
                textAlign = TextAlign.Center, modifier = Modifier.semantics { heading() })
            Text(lead, style = DS.Type.rowBody, color = p.secondary, textAlign = TextAlign.Center)
        }
    }
}

/** One line of what Pro opens: a brass symbol in a soft disc, and the words. */
@Composable
fun FeatureLine(icon: ImageVector, text: String, modifier: Modifier = Modifier) {
    val p = LocalSurface.current
    val palette = PaywallPalette(p)
    Row(
        modifier.fillMaxWidth().semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Space.m),
    ) {
        Box(
            Modifier.size(30.dp).background(palette.gold.copy(alpha = if (palette.isDark) 0.16f else 0.2f), CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = palette.brass, modifier = Modifier.size(16.dp))
        }
        Text(text, style = DS.Type.rowTitle, color = p.foreground, modifier = Modifier.weight(1f))
    }
}

/**
 * Restore purchases, Terms of Use and the Privacy Policy, under the offer:
 * quiet text links, each its own 44 dp target. [restoreHint] says what
 * Restore opens here, for TalkBack.
 */
@Composable
fun PaywallLegal(store: PurchaseStore, restoreHint: String, onRestore: () -> Unit, onTerms: () -> Unit, onPrivacy: () -> Unit) {
    val p = LocalSurface.current
    Row(
        Modifier.fillMaxWidth().padding(top = DS.Space.s),
        horizontalArrangement = Arrangement.spacedBy(DS.Space.xs, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (store.isRestoring) {
            Box(Modifier.heightIn(min = DS.Size.hitTarget).padding(horizontal = DS.Space.xxs), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp, color = p.secondary)
            }
        } else {
            LegalLink("Restore purchases", enabled = !store.purchasing, hint = restoreHint, onClick = onRestore)
        }
        Dot()
        LegalLink("Terms of Use", onClick = onTerms)
        Dot()
        LegalLink("Privacy Policy", onClick = onPrivacy)
    }
}

@Composable
private fun Dot() {
    Text("·", style = DS.Type.caption.copy(fontWeight = FontWeight.Medium), color = LocalSurface.current.secondary,
        modifier = Modifier.clearAndSetSemantics {})
}

@Composable
private fun LegalLink(text: String, enabled: Boolean = true, hint: String? = null, onClick: () -> Unit) {
    val p = LocalSurface.current
    Box(
        Modifier
            .heightIn(min = DS.Size.hitTarget)
            .clip(RoundedCornerShape(DS.Radius.chip))
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .semantics { if (hint != null) contentDescription = "$text. $hint" }
            .padding(horizontal = DS.Space.xxs),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = DS.Type.caption.copy(fontWeight = FontWeight.Medium),
            color = p.secondary.copy(alpha = if (enabled) p.secondary.alpha else p.secondary.alpha * DS.Fill.disabled))
    }
}

/**
 * In place of the offer while a price loads, or when it couldn't be: [failure]
 * and Try again (PaywallPriceStatus).
 */
@Composable
fun PaywallPriceStatus(store: PurchaseStore, failure: String, onRetry: () -> Unit) {
    val p = LocalSurface.current
    if (store.isLoadingOptions) {
        Row(
            Modifier.fillMaxWidth().heightIn(min = DS.Size.row).semantics(mergeDescendants = true) {},
            horizontalArrangement = Arrangement.spacedBy(DS.Space.s, Alignment.CenterHorizontally),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp, color = p.secondary)
            Text("Getting prices from Google Play…", style = DS.Type.detail, color = p.secondary)
        }
    } else {
        Column(
            Modifier
                .fillMaxWidth()
                .background(p.primary(DS.Fill.row), RoundedCornerShape(DS.Radius.card))
                .padding(DS.Space.m),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(DS.Space.xs),
        ) {
            Text(failure, style = DS.Type.detail, color = p.secondary, textAlign = TextAlign.Center)
            Box(
                Modifier
                    .heightIn(min = DS.Size.hitTarget)
                    .clip(RoundedCornerShape(DS.Radius.chip))
                    .clickable(role = Role.Button, onClick = onRetry)
                    .padding(horizontal = DS.Space.m),
                contentAlignment = Alignment.Center,
            ) { Text("Try again", style = DS.Type.button, color = p.tint) }
        }
    }
}

/** Width of the paywall's column. */
val PaywallMaxWidth: Dp = 560.dp
