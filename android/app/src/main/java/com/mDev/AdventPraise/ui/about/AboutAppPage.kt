// OWNER: shell
package com.mDev.AdventPraise.ui.about

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.LineBreak
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.BuildConfig
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsScreen
import com.mDev.AdventPraise.ui.design.Eyebrow
import com.mDev.AdventPraise.ui.paywall.PaywallLight
import com.mDev.AdventPraise.ui.paywall.PaywallLogo
import com.mDev.AdventPraise.ui.paywall.PaywallPalette
import com.mDev.AdventPraise.ui.root.AppNavigator
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface

/*
 * More → About → About Advent Praise (AboutAppView.swift): the church logo in
 * a little of the paywall's light, a short note from Malcolm, who makes the
 * app, and the version and build. The Privacy Policy and the Terms of Use are
 * one tap further, as More's pages. Keep the note humble and true: who makes
 * the app, why, and thanks to the people who bought translations in earlier
 * versions. Nothing more is claimed.
 */

private val paragraphs = listOf(
    "I’m Malcolm Kumwenda, an independent developer from South Africa, and I make Advent Praise on my own.",
    "I built it to carry the hymns of the Seventh-day Adventist Church in the languages of Southern Africa, so that the songs we sing together are close at hand, in church and wherever else you sing them.",
    "To everyone who bought a translation in an earlier version of Advent Praise: thank you. Your support is greatly appreciated.",
    "If these hymns are a blessing to you, I’m grateful to have had a small part in it.",
)

/** About Advent Praise as a More page (the host scrolls it). */
@Composable
fun AboutAppPage(services: AppServices, navigator: AppNavigator) {
    AboutAppContent(onPrivacy = navigator::openPrivacy, onTerms = navigator::openTerms)
}

@Composable
fun AboutAppContent(onPrivacy: () -> Unit, onTerms: () -> Unit) {
    LaunchedEffect(Unit) { Analytics.screen(AnalyticsScreen.AboutApp) }
    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.TopCenter) {
        Column(
            Modifier
                .widthIn(max = DS.Space.readingMeasure)
                .fillMaxWidth()
                .padding(horizontal = DS.Space.l + DS.Space.xxs)
                .padding(bottom = DS.Space.l * 2)
                .windowInsetsPadding(WindowInsets.navigationBars),
            verticalArrangement = Arrangement.spacedBy(DS.Space.l),
        ) {
            Header()
            Letter()
            Details(onPrivacy, onTerms)
        }
    }
}

@Composable
private fun Header() {
    val p = LocalSurface.current
    val palette = PaywallPalette(p)
    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.BottomCenter) {
        // A glow that fades out on every side, rather than a box of light.
        Box(
            Modifier
                .matchParentSize()
                .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
                .drawWithContent {
                    drawContent()
                    drawRect(
                        Brush.radialGradient(0.2f to Color.Black, 1f to Color.Transparent,
                            center = Offset(size.width / 2, size.height * 0.62f), radius = maxOf(size.width, size.height) / 2),
                        blendMode = BlendMode.DstIn,
                    )
                    drawRect(Brush.verticalGradient(0.5f to Color.Black, 1f to Color.Transparent), blendMode = BlendMode.DstIn)
                },
            contentAlignment = Alignment.BottomCenter,
        ) {
            Box(Modifier.fillMaxWidth().height(260.dp)) { PaywallLight(palette, intensity = 0.5f) }
        }
        Column(
            Modifier.fillMaxWidth().padding(bottom = DS.Space.l),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(DS.Space.s),
        ) {
            PaywallLogo(palette, Modifier.padding(top = DS.Space.m, bottom = DS.Space.xs), width = 56.dp)
            Text("Advent Praise", style = DS.Type.display, color = p.foreground, modifier = Modifier.semantics { heading() })
            Text(
                "Hymns of the Seventh-day Adventist Church in the languages of Southern Africa",
                style = DS.Type.rowBody.copy(lineBreak = LineBreak.Heading), color = p.secondary, textAlign = TextAlign.Center,
            )
        }
    }
}

@Composable
private fun Letter() {
    val p = LocalSurface.current
    val palette = PaywallPalette(p)
    Column(verticalArrangement = Arrangement.spacedBy(DS.Space.m + DS.Space.xxs)) {
        Eyebrow("A note from Malcolm", palette.brass, Modifier.semantics { heading() }, tracking = 1.4f)
        paragraphs.forEach { Text(it, style = DS.Type.rowBody.copy(lineHeight = 27.sp), color = p.foreground) }
        Column(Modifier.padding(top = DS.Space.xxs).semantics(mergeDescendants = true) {}, verticalArrangement = Arrangement.spacedBy(DS.Space.hair)) {
            Text("With thanks,", style = DS.Type.rowBody, color = p.foreground)
            Text(
                "Malcolm Kumwenda",
                style = DS.Type.rowBody.copy(fontFamily = FontFamily.Serif, fontStyle = FontStyle.Italic, fontWeight = FontWeight.Normal,
                    fontSize = 22.sp, lineHeight = 28.sp),
                color = palette.brass, modifier = Modifier.padding(top = DS.Space.xxs),
            )
            Text("Independent developer, South Africa", style = DS.Type.caption, color = p.secondary)
        }
    }
}

@Composable
private fun Details(onPrivacy: () -> Unit, onTerms: () -> Unit) {
    val p = LocalSurface.current
    Column(
        Modifier
            .padding(top = DS.Space.s)
            .fillMaxWidth()
            .clip(RoundedCornerShape(DS.Radius.tile))
            .background(p.primary(DS.Fill.row)),
    ) {
        DetailRow("Version", BuildConfig.VERSION_NAME)
        Divider()
        DetailRow("Build", BuildConfig.VERSION_CODE.toString())
        Divider()
        LinkRow("Privacy Policy", onPrivacy)
        Divider()
        LinkRow("Terms of Use", onTerms)
    }
}

@Composable
private fun Divider() = HorizontalDivider(Modifier.padding(start = DS.Space.m), thickness = 0.5.dp, color = LocalSurface.current.primary(DS.Fill.stroke))

@Composable
private fun DetailRow(title: String, value: String) {
    val p = LocalSurface.current
    Row(
        Modifier.fillMaxWidth().heightIn(min = 46.dp).padding(horizontal = DS.Space.m).semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, style = DS.Type.label, color = p.foreground)
        Spacer(Modifier.weight(1f))
        SelectionContainer {
            Text(value, style = DS.Type.label.copy(fontFeatureSettings = "tnum"), color = p.secondary)
        }
    }
}

@Composable
private fun LinkRow(title: String, onClick: () -> Unit) {
    val p = LocalSurface.current
    Row(
        Modifier.fillMaxWidth().heightIn(min = 46.dp).clickable(role = Role.Button, onClick = onClick).padding(horizontal = DS.Space.m),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Space.m),
    ) {
        Text(title, style = DS.Type.label, color = p.foreground, modifier = Modifier.weight(1f))
        Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, tint = p.secondary, modifier = Modifier.size(18.dp))
    }
}
