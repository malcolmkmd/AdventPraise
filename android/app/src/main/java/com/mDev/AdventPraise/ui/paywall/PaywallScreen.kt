// OWNER: shell
package com.mDev.AdventPraise.ui.paywall

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Cast
import androidx.compose.material.icons.rounded.LibraryMusic
import androidx.compose.material.icons.rounded.NotificationsActive
import androidx.compose.material.icons.rounded.Piano
import androidx.compose.material.icons.rounded.Psychology
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material.icons.rounded.Verified
import androidx.compose.material.icons.rounded.Widgets
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.analytics.RestoreSource
import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.billing.PurchaseStore
import com.mDev.AdventPraise.billing.UnlockOption
import com.mDev.AdventPraise.reader.LegalDocument
import com.mDev.AdventPraise.ui.design.GlassButton
import com.mDev.AdventPraise.ui.design.findActivity
import com.mDev.AdventPraise.ui.legal.LegalSheet
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import kotlinx.coroutines.launch

/*
 * The Advent Praise Pro paywall (ProPaywall.swift): a full sheet over warm gold
 * light and a crowd of raised hands (PaywallScenery). It opens when a free user
 * taps Play with the free plays used up, a TV, sheet music, or from More. The
 * church logo and "Sing without limits", short lines on what Pro opens, one buy
 * button with the price exactly as Google Play gives it (the RevenueCat
 * offering's `$rc_annual` package; nothing is hard-coded, and if it can't be
 * loaded the sheet says so and offers Try again), and Restore purchases, Terms
 * and Privacy. Pro is the annual subscription alone: "3 days free, then
 * R199.99/year. Cancel anytime." with the trial and price from Google Play,
 * "Start 3-Day Free Trial" (or "Subscribe" once the trial has been had), and
 * the renewal terms. It never shows for anyone who has Pro (subscribers, and
 * 7.0.x buyers of Pro or MIDI Piano, who keep it for life). Unlocking what the
 * gate asked for closes the sheet and carries on with what was asked for.
 */

/** What the paywall's offer shows (the `offer` and `actions` of ProPaywallView). */
sealed interface PaywallOffer {
    /** Pro is active (it closes at once): the thank-you card, nothing to buy. */
    data object Active : PaywallOffer
    /** The offering is loading. */
    data object Loading : PaywallOffer
    /** No annual package: the sheet says so and offers Try again. */
    data object Failed : PaywallOffer
    /** "3 days free, then R199.99/year. Cancel anytime.", the renewal terms and the button. */
    data class Ready(val option: UnlockOption) : PaywallOffer {
        val offerLine: String get() = option.offerLine
        val renewalTerms: String get() = option.renewalTerms
        val callToAction: String get() = option.callToAction
    }

    companion object {
        fun of(store: PurchaseStore): PaywallOffer = of(store.isPro, store.proOption, store.isLoadingOptions)

        fun of(isPro: Boolean, option: UnlockOption?, isLoading: Boolean): PaywallOffer = when {
            isPro -> Active
            option != null -> Ready(option)
            isLoading -> Loading
            else -> Failed
        }
    }
}

/** The lines on what Pro opens, as iOS lists them, told for Android (Live Activity → notification, widgets → Home screen). */
val ProFeatureLines: List<Pair<ImageVector, String>> = listOf(
    Icons.Rounded.Piano to "Unlimited MIDI sing-along player",
    Icons.Rounded.LibraryMusic to "Sheet music to read and play from",
    Icons.Rounded.Cast to "Clean worship display on any TV or projector",
    Icons.Rounded.NotificationsActive to "Church mode controls in your notifications",
    Icons.Rounded.Widgets to "Presenter widgets for the Home screen",
    Icons.Rounded.Tune to "Pitch pipe",
    Icons.Rounded.Psychology to "Unlimited Memorise",
)

/** The lead under the title, for what the paywall opened for. */
fun paywallLead(feature: ProFeature): String = when (feature) {
    ProFeature.Player -> "You’ve had your free plays of the piano. Pro keeps it playing with you, and opens everything below."
    ProFeature.AirPlay -> "A clean worship display on any TV or projector, with your phone as the remote. Pro opens it, and everything below."
    ProFeature.Mirroring -> "Your screen is being mirrored. Pro shows a clean worship display on any TV or projector instead: big words, no phone, and your phone as the remote."
    ProFeature.SheetMusic -> "Sheet music to read and play from, on phone and tablet. Hymn of the Day’s is free every day. Pro opens the rest, and everything below."
    ProFeature.Support -> "Everything below, on every device signed in with your Google Account."
}

/**
 * The Destination.Paywall content. Pro never sees it (it closes before it is
 * seen); Pro arriving closes it and carries on with what the gate asked for.
 */
@Composable
fun PaywallScreen(services: AppServices, feature: ProFeature, onClose: () -> Unit) {
    val store = services.store
    LaunchedEffect(store.isPro) {
        if (!store.isPro) return@LaunchedEffect
        if (feature != ProFeature.Support && store.unlocks(feature)) onUnlocked(services, feature)
        onClose()
    }
    val activity = LocalContext.current.findActivity()
    val scope = rememberCoroutineScope()
    PaywallContent(
        store = store,
        feature = feature,
        onClose = onClose,
        onPurchase = { option -> scope.launch { store.purchase(activity, option, feature) } },
    )
}

/** What a gate asked for, once Pro opens it: the piano plays the open hymn (`proPaywall(onUnlocked:)` in RootView). */
private fun onUnlocked(services: AppServices, feature: ProFeature) {
    if (feature != ProFeature.Player) return
    val hymnal = services.reader.hymnal ?: return
    val hymn = services.reader.hymn ?: return
    services.player.start(hymn, hymnal.info)
}

/** The paywall itself, on plain values: previews and screenshots give it a store of their own. */
@Composable
fun PaywallContent(
    store: PurchaseStore,
    feature: ProFeature,
    onClose: () -> Unit,
    onPurchase: (UnlockOption) -> Unit,
) {
    val scope = rememberCoroutineScope()
    val opened = rememberPaywallOpening()
    var legal by remember { mutableStateOf<LegalDocument?>(null) }
    LaunchedEffect(Unit) { if (store.proOption == null) store.loadStorefront() }
    val offer = PaywallOffer.of(store)

    Box(Modifier.fillMaxSize()) {
        PaywallChrome(
            opened = opened,
            onClose = onClose,
            moreHint = "See everything in Pro",
            page = {
                Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(DS.Space.l + DS.Space.xxs)) {
                    PaywallHeader("Advent Praise Pro", "Sing without limits", paywallLead(feature))
                    Column(
                        Modifier.fillMaxWidth().semantics { contentDescription = "What Pro opens" },
                        verticalArrangement = Arrangement.spacedBy(DS.Space.s),
                    ) {
                        ProFeatureLines.forEachIndexed { index, (icon, text) ->
                            FeatureLine(icon, text, Modifier.paywallRise(opened, delayMs = 250L + index * 50L))
                        }
                    }
                    Offer(store, offer) { scope.launch { store.loadStorefront() } }
                    PaywallLegal(
                        store,
                        restoreHint = "Unlocks Pro if this Google Account has subscribed or bought it before",
                        onRestore = { scope.launch { store.restore(RestoreSource.Paywall) } },
                        onTerms = { legal = LegalDocument.Terms },
                        onPrivacy = { legal = LegalDocument.Privacy },
                    )
                }
            },
            actions = {
                // No price (offline, or not set up), or Pro already: nothing to buy.
                if (offer is PaywallOffer.Ready) {
                    GlassButton(
                        offer.callToAction,
                        onClick = { onPurchase(offer.option) },
                        tint = PaywallPalette(LocalSurface.current).brass,
                        isLoading = store.purchasingId == offer.option.id,
                        fullWidth = true,
                        enabled = !store.purchasing && !store.isRestoring,
                    )
                }
            },
        )
        // The in-app Terms and Privacy Policy, over the paywall, with Done.
        LegalSheet(legal) { legal = null }
    }
}

/** The offer in words, the thank-you once Pro is active, or Try again. */
@Composable
private fun Offer(store: PurchaseStore, offer: PaywallOffer, onRetry: () -> Unit) {
    val p = LocalSurface.current
    when (offer) {
        PaywallOffer.Active -> ProActiveCard()
        is PaywallOffer.Ready -> Column(
            Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(DS.Space.xs),
        ) {
            Text(offer.offerLine, style = DS.Type.rowTitle, color = p.foreground, textAlign = TextAlign.Center)
            Text(offer.renewalTerms, style = DS.Type.caption, color = p.secondary, textAlign = TextAlign.Center)
        }
        PaywallOffer.Loading, PaywallOffer.Failed ->
            PaywallPriceStatus(store, "Couldn’t reach Google Play for Pro’s price. Check your connection and try again.", onRetry)
    }
}

/** Shown in place of the offer once Pro is active. */
@Composable
private fun ProActiveCard() {
    val p = LocalSurface.current
    val palette = PaywallPalette(p)
    val shape = RoundedCornerShape(DS.Radius.tile)
    Row(
        Modifier
            .fillMaxWidth()
            .background(palette.gold.copy(alpha = if (palette.isDark) 0.14f else 0.18f), shape)
            .border(1.dp, palette.brass.copy(alpha = 0.5f), shape)
            .padding(DS.Space.m)
            .semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Space.m),
    ) {
        Icon(Icons.Rounded.Verified, null, tint = palette.brass, modifier = Modifier.size(28.dp))
        Column(verticalArrangement = Arrangement.spacedBy(DS.Space.hair)) {
            Text("Pro is yours", style = DS.Type.panelTitle, color = p.foreground)
            Text("Thank you for singing with us.", style = DS.Type.caption, color = p.secondary)
        }
    }
}
