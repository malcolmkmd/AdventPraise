// OWNER: shell
package com.mDev.AdventPraise.ui.more

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.Verified
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.min
import com.mDev.AdventPraise.billing.Entitlements
import com.mDev.AdventPraise.billing.FreePlayAllowance
import com.mDev.AdventPraise.ui.design.dsPress
import com.mDev.AdventPraise.ui.paywall.PaywallLight
import com.mDev.AdventPraise.ui.paywall.PaywallLogo
import com.mDev.AdventPraise.ui.paywall.PaywallPalette
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface

/** What the card says and does (ProMoreCard.swift). */
enum class ProCardState {
    /** Free: the paywall, with the free plays left. */
    Free,
    /** The annual subscription: Google Play's subscription page. */
    Subscriber,
    /** Pro bought once (iOS 7.0.x) or 7.0.1's MIDI Piano: a thank-you, nothing to open. */
    ProForLife;

    /** The card leads somewhere: the paywall, or managing the subscription. */
    val opens: Boolean get() = this != ProForLife

    companion object {
        fun of(entitlements: Entitlements): ProCardState = when {
            entitlements.isSubscriber -> Subscriber
            entitlements.isPro -> ProForLife
            else -> Free
        }
    }
}

/** The card's one line. */
fun proCardSubtitle(state: ProCardState, freePlaysLeft: Int): String = when (state) {
    ProCardState.Subscriber -> "Thank you. Manage your subscription here."
    ProCardState.ProForLife -> "Thank you. Pro is yours for life."
    ProCardState.Free -> when (freePlaysLeft) {
        0 -> "Your free plays of the piano are used"
        1 -> "1 free play of the piano left"
        else -> "$freePlaysLeft of ${FreePlayAllowance.FREE} free plays of the piano left"
    }
}

/**
 * Advent Praise Pro at the top of More: one compact row. A small tile of the
 * paywall's scenery (the logo glowing in the gold light), the title, one line,
 * and a chevron. Free: opens the paywall and says how many free plays of the
 * piano are left. Pro never sees the paywall: a subscriber's card opens Google
 * Play's subscription page, a lifetime owner's just says thank you.
 */
@Composable
fun ProMoreCard(
    entitlements: Entitlements,
    freePlaysLeft: Int,
    onSeePro: () -> Unit,
    onManageSubscription: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val p = LocalSurface.current
    val palette = PaywallPalette(p)
    val state = ProCardState.of(entitlements)
    val subtitle = proCardSubtitle(state, freePlaysLeft)
    val shape = RoundedCornerShape(DS.Radius.card)
    val interaction = remember { MutableInteractionSource() }
    val tap = when (state) {
        ProCardState.Free -> onSeePro
        ProCardState.Subscriber -> onManageSubscription
        ProCardState.ProForLife -> null
    }
    Row(
        modifier
            .fillMaxWidth()
            .dsPress(interaction, tap != null)
            .clip(shape)
            .background(p.primary(DS.Fill.row), shape)
            .border(1.dp, palette.brass.copy(alpha = if (palette.isDark) 0.35f else 0.28f), shape)
            .then(if (tap != null) Modifier.clickable(interaction, indication = null, onClick = tap) else Modifier)
            .clearAndSetSemantics {
                contentDescription = "Advent Praise Pro, $subtitle"
                if (tap != null) {
                    role = Role.Button
                    onClick(if (state == ProCardState.Subscriber) "Opens your Google Play subscription" else "Opens Advent Praise Pro") { tap(); true }
                }
            }
            .padding(start = DS.Space.m, top = DS.Space.m, bottom = DS.Space.m, end = DS.Space.m + DS.Space.xxs),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Space.m),
    ) {
        Tile(palette)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(DS.Space.hair)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DS.Space.xxs)) {
                Text("Advent Praise Pro", style = DS.Type.rowTitle, color = p.foreground)
                if (entitlements.isPro) Icon(Icons.Rounded.Verified, null, tint = palette.brass, modifier = Modifier.size(15.dp))
            }
            Text(subtitle, style = DS.Type.detail, color = p.secondary)
        }
        if (state.opens) {
            Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, tint = p.secondary, modifier = Modifier.size(24.dp))
        }
    }
}

/** The logo in the light, small. Decoration only; capped so the row stays a row at the largest text sizes. */
@Composable
private fun Tile(palette: PaywallPalette) {
    val scaled = with(LocalDensity.current) { (48.dp.toPx() * fontScale).toDp() }
    val size = min(scaled, 64.dp)
    Box(
        Modifier.size(size).clip(RoundedCornerShape(DS.Radius.tile)).background(palette.ground).clearAndSetSemantics {},
        contentAlignment = Alignment.Center,
    ) {
        PaywallLight(palette, intensity = 0.9f)
        PaywallLogo(palette, width = size * 0.42f)
    }
}
