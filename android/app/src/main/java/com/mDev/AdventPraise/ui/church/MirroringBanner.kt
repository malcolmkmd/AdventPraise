package com.mDev.AdventPraise.ui.church

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.background
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.church.display.ScreenMirroring
import com.mDev.AdventPraise.ui.design.dsPress
import com.mDev.AdventPraise.ui.root.LocalAppNavigator
import com.mDev.AdventPraise.ui.root.SDALogoShape
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.rememberReduceMotion

/**
 * The Go Pro banner while the screen is mirrored and the person isn't Pro,
 * else nothing (MirroringBannerSlot). Sends `mirroring_detected` once and
 * opens the paywall when tapped. The reader can put it under its Lectern too.
 */
@Composable
fun MirroringBannerSlot(services: AppServices, modifier: Modifier = Modifier, inChurchMode: Boolean = false) {
    val church by services.church.state.collectAsState()
    val mirroring = services.displays.mirroring
    val route = ScreenMirroring.bannerRoute(church.isPro, mirroring.isCaptured, church.isExternalScreenConnected)
    val navigator = LocalAppNavigator.current
    val reduceMotion = rememberReduceMotion()
    LaunchedEffect(route) { route?.let { mirroring.bannerShown(it, inChurchMode) } }
    AnimatedVisibility(
        route != null,
        modifier = modifier,
        enter = fadeIn(if (reduceMotion) DS.Motion.reduced() else DS.Motion.focus()),
        exit = fadeOut(if (reduceMotion) DS.Motion.reduced() else DS.Motion.focus()),
    ) {
        MirroringBanner { navigator.openPaywall(ProFeature.Mirroring, if (inChurchMode) "church_mode" else "reader") }
    }
}

/**
 * Logo, name and one line on a dark capsule (MirroringBanner): small on the
 * phone, legible across a room on the mirrored screen, the same on every surface.
 */
@Composable
fun MirroringBanner(onClick: () -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    val shape = RoundedCornerShape(50)
    val density = LocalDensity.current
    // Text stops growing at iOS's xLarge.
    val capped = Density(density.density, minOf(density.fontScale, 1.18f))
    val logoWidth = 26.dp
    Row(
        Modifier
            .dsPress(interaction)
            .shadow(8.dp, shape, ambientColor = Color.Black.copy(alpha = 0.35f), spotColor = Color.Black.copy(alpha = 0.35f))
            .background(DS.Palette.stageRaised, shape)
            .border(1.dp, DS.Palette.brassOnDark.copy(alpha = 0.4f), shape)
            .clickable(interaction, null, onClick = onClick)
            .clearAndSetSemantics {
                contentDescription = "Advent Praise. Go Pro for a clean worship display"
                role = Role.Button
                onClick("Your screen is being mirrored. Opens Advent Praise Pro.") { onClick(); true }
            }
            .padding(start = DS.Space.s, end = DS.Space.m, top = DS.Space.xs, bottom = DS.Space.xs),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Space.s),
    ) {
        Canvas(Modifier.size(logoWidth, logoWidth / SDALogoShape.ASPECT_RATIO)) {
            drawPath(SDALogoShape.path(Rect(Offset.Zero, size)), BannerLogo)
        }
        androidx.compose.runtime.CompositionLocalProvider(LocalDensity provides capped) {
            Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
                Text("Advent Praise", style = TextStyle(fontSize = 13.sp, lineHeight = 16.sp, fontWeight = FontWeight.SemiBold), color = Color.White, maxLines = 1)
                Text("Go Pro for a clean worship display", style = TextStyle(fontSize = 11.sp, lineHeight = 13.sp, fontWeight = FontWeight.Medium),
                    color = Color.White.copy(alpha = 0.72f), maxLines = 1)
            }
        }
    }
}

private val BannerLogo = Brush.verticalGradient(listOf(Color(0xFFF3D68C), Color(0xFFE2B560), Color(0xFFB9892F)))
