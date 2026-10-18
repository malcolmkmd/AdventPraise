package com.mDev.AdventPraise.ui.design

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Church
import androidx.compose.material.icons.rounded.FormatSize
import androidx.compose.material.icons.rounded.GraphicEq
import androidx.compose.material.icons.rounded.Language
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.settings.ReadingSurface
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import com.mDev.AdventPraise.ui.theme.SurfacePalette

/** One feature block on the What's New page (WhatsNewFeature). */
data class WhatsNewFeature(
    val icon: ImageVector,
    val title: String,
    val body: String,
    val usesBrass: Boolean = false,
) {
    companion object {
        /** The 7.0 feature set, in brief order, as iOS ships it (≤ 2 lines each at default size). */
        val advent7: List<WhatsNewFeature> = listOf(
            WhatsNewFeature(Icons.Rounded.Church, "Worship mode",
                "Big, high-contrast words for the pew. The screen stays awake; one tap moves to the next verse."),
            WhatsNewFeature(Icons.Rounded.FormatSize, "Large print",
                "Lyrics that grow with your text size, on paper, sepia or a dark page."),
            WhatsNewFeature(Icons.Rounded.Language, "Every hymnal, free",
                "All the hymnals, in every language, at no charge. Switch and keep your hymn number.", usesBrass = true),
            WhatsNewFeature(Icons.Rounded.GraphicEq, "Ask Siri",
                "“Open hymn 30 in Advent Praise.” Works from Shortcuts and the Action button too."),
        )
    }
}

/** What's New is always on the Stage: components inside read the Black surface. */
private val StageSurface = SurfacePalette.of(ReadingSurface.Black)

/** Provides the Stage's dark surface and its high-contrast ink to [content]. */
@Composable
fun OnStage(content: @Composable () -> Unit) {
    CompositionLocalProvider(
        LocalSurface provides StageSurface,
        LocalContentColor provides StageSurface.highContrastForeground,
        content = content,
    )
}

/**
 * "Welcome to Advent Praise 7" (WhatsNewSheet): a big serif title, four short
 * feature blocks, one primary action and Continue, always on the dark Stage.
 * In the app the drawer hosts [WhatsNewPage] and [WhatsNewActions]; this
 * standalone form is for the gallery and screenshots.
 */
@Composable
fun WhatsNewSheet(
    onPrimary: () -> Unit,
    onContinue: () -> Unit,
    modifier: Modifier = Modifier,
    features: List<WhatsNewFeature> = WhatsNewFeature.advent7,
    primaryTitle: String = "Try Worship Mode",
) {
    Box(modifier.fillMaxSize().stageBackground()) {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
            WhatsNewPage(features)
            Box(Modifier.padding(bottom = 140.dp))
        }
        Box(
            Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .background(Brush.verticalGradient(0f to DS.Palette.stage.copy(alpha = 0f), 0.5f to DS.Palette.stage.copy(alpha = 0.92f)))
                .navigationBarsPadding(),
        ) {
            WhatsNewActions(primaryTitle, onPrimary, onContinue)
        }
    }
}

/** The scrolling part: title and feature tiles. */
@Composable
fun WhatsNewPage(features: List<WhatsNewFeature> = WhatsNewFeature.advent7) {
    OnStage {
        val p = LocalSurface.current
        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.TopCenter) {
            Column(
                Modifier
                    .widthIn(max = 560.dp)
                    .fillMaxWidth()
                    .padding(start = DS.Space.l + DS.Space.xxs, end = DS.Space.l + DS.Space.xxs, top = DS.Space.top + DS.Space.m, bottom = DS.Space.l),
                verticalArrangement = Arrangement.spacedBy(DS.Space.l),
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(DS.Space.s)) {
                    Eyebrow("Advent Praise 7", p.brass, tracking = 1.5f)
                    Text("Welcome to\nAdvent Praise 7", style = DS.Type.display, color = p.highContrastForeground,
                        modifier = Modifier.clearAndSetSemantics { contentDescription = "Welcome to Advent Praise 7"; heading() })
                    Text("A quieter hymnal, rebuilt for reading and singing together.", style = DS.Type.rowBody, color = p.secondary)
                }
                Column(verticalArrangement = Arrangement.spacedBy(DS.Space.s)) {
                    features.forEach { FeatureTile(it) }
                }
            }
        }
    }
}

/** The pinned buttons. */
@Composable
fun WhatsNewActions(primaryTitle: String = "Try Worship Mode", onPrimary: () -> Unit, onContinue: () -> Unit) {
    OnStage {
        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.TopCenter) {
            Column(
                Modifier
                    .widthIn(max = 560.dp)
                    .fillMaxWidth()
                    .padding(start = DS.Space.l + DS.Space.xxs, end = DS.Space.l + DS.Space.xxs, top = DS.Space.m, bottom = DS.Space.s),
                verticalArrangement = Arrangement.spacedBy(DS.Space.s),
            ) {
                GlassButton(primaryTitle, onPrimary, fullWidth = true)
                GlassButton("Continue", onContinue, kind = GlassButtonKind.Secondary, fullWidth = true)
            }
        }
    }
}

/** Feature tiles are content, not controls: an opaque raised Stage card with a hairline. */
@Composable
private fun FeatureTile(feature: WhatsNewFeature) {
    val p = LocalSurface.current
    val accent = if (feature.usesBrass) p.brass else p.tint
    val shape = dsShape(DS.Radius.card)
    Row(
        Modifier
            .fillMaxWidth()
            .background(DS.Palette.stageRaised, shape)
            .border(1.dp, Color.White.copy(alpha = DS.Fill.hairline), shape)
            .padding(DS.Space.panel + 2.dp)
            .semantics(mergeDescendants = true) {},
        horizontalArrangement = Arrangement.spacedBy(DS.Space.panel),
    ) {
        Box(Modifier.size(44.dp).background(accent.copy(alpha = DS.Fill.tintOn), dsShape(DS.Radius.key)), contentAlignment = Alignment.Center) {
            Icon(feature.icon, null, tint = accent, modifier = Modifier.size(22.dp))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(DS.Space.xxs)) {
            Text(feature.title, style = DS.Type.rowTitle, color = p.highContrastForeground)
            Text(feature.body, style = DS.Type.detail, color = p.secondary)
        }
    }
}

/** The Stage: near-black with an Evergreen glow top-left and a brass one bottom-right. */
fun Modifier.stageBackground(alpha: Float = 1f): Modifier = drawBehind {
    drawRect(DS.Palette.stage.copy(alpha = alpha))
    drawRect(Brush.radialGradient(
        listOf(DS.Palette.evergreenOnDark.copy(alpha = 0.35f * alpha), Color.Transparent),
        center = Offset.Zero, radius = 520.dp.toPx(),
    ))
    drawRect(Brush.radialGradient(
        listOf(DS.Palette.brassOnDark.copy(alpha = 0.18f * alpha), Color.Transparent),
        center = Offset(size.width, size.height), radius = 420.dp.toPx(),
    ))
}

/** Lets callers lay the Stage under a box of their own. */
@Composable
fun StageBackground(modifier: Modifier = Modifier, content: @Composable BoxScope.() -> Unit = {}) {
    Box(modifier.stageBackground(), content = content)
}
