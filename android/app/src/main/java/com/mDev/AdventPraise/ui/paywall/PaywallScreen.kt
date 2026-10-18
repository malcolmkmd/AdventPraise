// OWNER: shell
package com.mDev.AdventPraise.ui.paywall

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Cast
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.LibraryMusic
import androidx.compose.material.icons.rounded.Piano
import androidx.compose.material.icons.rounded.Psychology
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material.icons.rounded.Verified
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.R
import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.reader.LegalDocument
import com.mDev.AdventPraise.ui.design.Eyebrow
import com.mDev.AdventPraise.ui.design.findActivity
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import kotlinx.coroutines.launch

/**
 * The Advent Praise Pro paywall (ProPaywall.swift): warm gold light, the
 * church logo, "Sing without limits", what Pro opens, one buy button with
 * the price exactly as Google Play gives it through the RevenueCat
 * offering, and Restore purchases. Pro is bought once: no plans, no trial.
 * Buying (or restoring) Pro closes it.
 */
@Composable
fun PaywallScreen(services: AppServices, feature: ProFeature, onClose: () -> Unit) {
    val store = services.store
    val p = LocalSurface.current
    val scope = rememberCoroutineScope()
    val activity = LocalContext.current.findActivity()

    LaunchedEffect(Unit) { if (store.proOption == null) store.loadStorefront() }

    Box(Modifier.fillMaxSize().background(p.paywallGround)) {
        // The light: gold rising from the bottom (iOS draws raised hands in it).
        Canvas(Modifier.fillMaxSize()) {
            drawRect(
                Brush.radialGradient(
                    colors = listOf(p.gold.copy(alpha = if (p.isDark) 0.38f else 0.30f), p.gold.copy(alpha = 0f)),
                    center = Offset(size.width / 2, size.height * 1.02f),
                    radius = size.width * 0.95f,
                ),
            )
        }
        Column(
            Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.statusBars).windowInsetsPadding(WindowInsets.navigationBars),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(
                Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Column(
                    Modifier.widthIn(max = DS.Space.lecternMaxWidth).fillMaxWidth().padding(top = 56.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(DS.Space.l),
                ) {
                    Image(painterResource(R.drawable.sda_logo), contentDescription = null,
                        colorFilter = ColorFilter.tint(if (p.isDark) p.gold else p.brass), modifier = Modifier.size(64.dp))
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(DS.Space.s)) {
                        Eyebrow("Advent Praise Pro", if (p.isDark) p.gold else p.brass, tracking = 1.6f)
                        Text("Sing without limits", style = DS.Type.display, color = textColor(), textAlign = TextAlign.Center)
                        Text(lead(feature), style = DS.Type.rowBody, color = secondaryColor(), textAlign = TextAlign.Center)
                    }
                    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(DS.Space.s)) {
                        FeatureLine(Icons.Rounded.Piano, "Unlimited MIDI sing-along player")
                        Eyebrow("Coming to Android", secondaryColor(), Modifier.padding(top = DS.Space.s))
                        FeatureLine(Icons.Rounded.LibraryMusic, "Sheet music to read and play from", soon = true)
                        FeatureLine(Icons.Rounded.Cast, "Clean worship display on any TV or projector", soon = true)
                        FeatureLine(Icons.Rounded.Tune, "Pitch pipe", soon = true)
                        FeatureLine(Icons.Rounded.Psychology, "Unlimited Memorise", soon = true)
                    }
                    Offer(services)
                    Legal(
                        onRestore = { scope.launch { store.restore("paywall") } },
                        restoring = store.isRestoring,
                        onTerms = { services.reader.document = LegalDocument.Terms },
                        onPrivacy = { services.reader.document = LegalDocument.Privacy },
                    )
                }
                Box(Modifier.height(DS.Space.l))
            }
            // The offer and the call to action, under the thumb.
            val option = store.proOption
            if (!store.isPro && option != null) {
                val enabled = !store.purchasing && !store.isRestoring && activity != null
                Text(option.offer, style = DS.Type.label, color = textColor(), textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = 24.dp).padding(top = DS.Space.s))
                Box(
                    Modifier
                        .padding(horizontal = 24.dp, vertical = DS.Space.m)
                        .widthIn(max = DS.Space.lecternMaxWidth)
                        .fillMaxWidth()
                        .heightIn(min = 54.dp)
                        .clip(RoundedCornerShape(DS.Radius.key))
                        .background(p.brass.copy(alpha = if (enabled) 1f else DS.Fill.disabled))
                        .clickable(enabled = enabled) {
                            val host = activity ?: return@clickable
                            scope.launch { store.purchase(host, option, feature) }
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    if (store.purchasing) {
                        CircularProgressIndicator(Modifier.size(22.dp), color = p.onTint, strokeWidth = 2.dp)
                    } else {
                        Text(option.buttonTitle, style = DS.Type.button, color = if (p.isDark) DS.Palette.stage else androidxWhite)
                    }
                }
            }
        }
        Box(
            Modifier
                .align(Alignment.TopEnd)
                .windowInsetsPadding(WindowInsets.statusBars)
                .padding(DS.Space.m)
                .size(DS.Size.hitTarget)
                .clip(CircleShape)
                .background(p.elevated.copy(alpha = 0.9f))
                .clickable(onClick = onClose),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Rounded.Close, contentDescription = "Close", tint = textColor())
        }
    }
}

private val androidxWhite = androidx.compose.ui.graphics.Color.White

private fun lead(feature: ProFeature): String = when (feature) {
    ProFeature.Player -> "You’ve had your free plays of the piano. Pro keeps it playing with you, and opens everything below."
    ProFeature.Support -> "Everything below, in one yearly subscription."
    ProFeature.AirPlay -> "A clean worship display on any TV or projector, with your phone as the remote. Pro opens it, and everything below."
    ProFeature.Mirroring -> "Your screen is being mirrored. Pro shows a clean worship display on any TV or projector instead: big words, no phone, and your phone as the remote."
    ProFeature.SheetMusic -> "Sheet music to read and play from, on phone and tablet. Hymn of the Day’s is free every day. Pro opens the rest, and everything below."
}

@Composable
private fun textColor() = LocalSurface.current.let { if (it.isDark) androidx.compose.ui.graphics.Color(0xFFF4F1EA) else it.foreground }

@Composable
private fun secondaryColor() = textColor().copy(alpha = 0.72f)

@Composable
private fun FeatureLine(icon: ImageVector, text: String, soon: Boolean = false) {
    val p = LocalSurface.current
    Row(
        Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Space.m),
    ) {
        Box(
            Modifier.size(30.dp).clip(CircleShape).background(p.gold.copy(alpha = if (p.isDark) 0.16f else 0.2f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = if (p.isDark) p.gold else p.brass, modifier = Modifier.size(16.dp))
        }
        Text(text, style = DS.Type.rowTitle, color = if (soon) secondaryColor() else textColor(), modifier = Modifier.weight(1f))
    }
}

/** The renewal terms (or, for Pro, the thank-you); the offer itself sits over the button. */
@Composable
private fun Offer(services: AppServices) {
    val store = services.store
    val p = LocalSurface.current
    val uriHandler = LocalUriHandler.current
    when {
        store.isPro -> {
            val shape = RoundedCornerShape(DS.Radius.tile)
            Row(
                Modifier.fillMaxWidth().clip(shape).background(p.gold.copy(alpha = if (p.isDark) 0.14f else 0.18f))
                    .border(1.dp, p.brass.copy(alpha = 0.5f), shape).padding(DS.Space.m),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(DS.Space.m),
            ) {
                Icon(Icons.Rounded.Verified, contentDescription = null, tint = if (p.isDark) p.gold else p.brass)
                Column {
                    Text("Pro is yours", style = DS.Type.panelTitle, color = textColor())
                    Text("Thank you for singing with us.", style = DS.Type.caption, color = secondaryColor())
                    Text("Manage subscription", style = DS.Type.caption.copy(fontWeight = FontWeight.SemiBold), color = p.tint,
                        modifier = Modifier.padding(top = DS.Space.xxs).clickable { uriHandler.openUri(store.manageSubscriptionUrl) })
                }
            }
        }
        store.proOption != null -> Text(
            store.proOption?.renewalTerms.orEmpty(),
            style = DS.Type.caption, color = secondaryColor(), textAlign = TextAlign.Center,
        )
        store.isLoadingOptions -> Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DS.Space.s)) {
            CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
            Text("Getting prices from Google Play…", style = DS.Type.detail, color = secondaryColor())
        }
        else -> {
            val scope = rememberCoroutineScope()
            Column(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(DS.Radius.card)).background(textColor().copy(alpha = DS.Fill.row)).padding(DS.Space.m),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(DS.Space.xs),
            ) {
                Text("Couldn’t reach Google Play for Pro’s price. Check your connection and try again.",
                    style = DS.Type.detail, color = secondaryColor(), textAlign = TextAlign.Center)
                Text("Try again", style = DS.Type.button, color = p.tint,
                    modifier = Modifier.clip(RoundedCornerShape(DS.Radius.chip)).clickable { scope.launch { store.loadStorefront() } }
                        .padding(horizontal = DS.Space.m, vertical = DS.Space.s))
            }
        }
    }
}

/** Restore purchases, the Terms of Use and the Privacy Policy, under the offer. */
@Composable
private fun Legal(onRestore: () -> Unit, restoring: Boolean, onTerms: () -> Unit, onPrivacy: () -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DS.Space.xxs)) {
        if (restoring) {
            Box(Modifier.padding(DS.Space.s)) { CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp) }
        } else {
            LegalLink("Restore purchases", onRestore)
        }
        Text("·", style = DS.Type.caption, color = secondaryColor())
        LegalLink("Terms of Use", onTerms)
        Text("·", style = DS.Type.caption, color = secondaryColor())
        LegalLink("Privacy Policy", onPrivacy)
    }
}

@Composable
private fun LegalLink(text: String, onClick: () -> Unit) {
    Text(text, style = DS.Type.caption.copy(fontWeight = FontWeight.Medium), color = secondaryColor(),
        modifier = Modifier.clip(RoundedCornerShape(DS.Radius.chip)).clickable(onClick = onClick).padding(DS.Space.s))
}
