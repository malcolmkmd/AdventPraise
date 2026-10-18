package com.mDev.AdventPraise.church.display

import android.graphics.Bitmap
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.times
import com.mDev.AdventPraise.church.ChurchState
import com.mDev.AdventPraise.data.Block
import com.mDev.AdventPraise.settings.ReadingFont
import com.mDev.AdventPraise.settings.ReadingSettings
import com.mDev.AdventPraise.ui.root.SDALogoShape
import com.mDev.AdventPraise.ui.theme.DS

/**
 * The worship display (ExternalHymnView on iOS): church mode on a TV or
 * projector. The brand ground, the verse being sung as large as the room
 * needs, the hymn's number and title across the top and where the verse is
 * along the bottom. Between hymns (church mode closed) a title page; Blank
 * shows only the ground and a faint mark; an announcement or a picture
 * replaces the words. Laid out on a 1080-high screen and scaled to this
 * one. Always dark, whatever the phone's appearance; no phone UI reaches it.
 *
 * @param worshipPointSize the phone's church mode size: its A− / A+ scale the TV too.
 * @param image the picture for [ChurchState.image]'s id.
 */
@Composable
fun WorshipDisplay(
    state: ChurchState,
    worshipPointSize: Float,
    largePrint: Boolean,
    modifier: Modifier = Modifier,
    image: (String) -> Bitmap? = { null },
) {
    BoxWithConstraints(modifier.fillMaxSize().clearAndSetSemantics {}) {
        // Laid out on a 1080-point-high screen and scaled to this one.
        val unit = maxHeight / 1080f
        val page = page(state)
        WorshipDisplayGround(unit, showsMark = page is Page.Blank)
        Crossfade(page, animationSpec = tween(450, easing = DS.Motion.easeInOut), label = "worship-page") { shown ->
            when (shown) {
                Page.Blank -> Box(Modifier.fillMaxSize())
                is Page.Special -> Special(state, shown, unit, image)
                is Page.Verse -> Verse(shown, unit, worshipPointSize, largePrint, maxWidth)
                is Page.Title -> TitleCard(shown, unit)
            }
        }
    }
}

/** What the TV shows; equal pages don't cross-fade. */
private sealed interface Page {
    data object Blank : Page
    data class Special(val imageId: String?, val announcement: String?) : Page
    data class Verse(
        val key: String, val number: Int, val title: String, val block: Block, val position: String,
        val index: Int, val count: Int, val chorusLabel: String,
    ) : Page
    data class Title(val key: String, val hymnalName: String, val number: Int, val title: String) : Page
}

private fun page(state: ChurchState): Page {
    val hymn = state.hymn
    val key = "${state.hymnalId}-${hymn?.number}"
    if (state.isShowingSpecial) return Page.Special(state.image, state.announcement)
    if (state.isBlanked) return Page.Blank
    val block = state.block
    if (state.isActive && hymn != null && block != null) {
        return Page.Verse("$key-${state.index}", hymn.number, hymn.title, block, state.position, state.index,
            state.sequence.size, state.chorusLabel)
    }
    if (hymn == null) return Page.Blank
    return Page.Title(key, state.hymnalName, hymn.number, hymn.title)
}

/**
 * The worship display's ground: the Stage, lit from below with evergreen and
 * a little gold, still, so the words keep full contrast. Blank shows only
 * this and a faint mark.
 */
@Composable
fun WorshipDisplayGround(unit: Dp, showsMark: Boolean = false) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Canvas(Modifier.fillMaxSize()) {
            drawRect(DS.Palette.stage)
            drawRect(Brush.radialGradient(
                listOf(DS.Palette.evergreen.copy(alpha = 0.55f), DS.Palette.evergreen.copy(alpha = 0f)),
                center = Offset(size.width * 0.5f, size.height * 1.15f),
                radius = maxOf(size.width, size.height) * 0.75f,
            ))
            drawRect(Brush.radialGradient(
                listOf(Gold.copy(alpha = 0.14f), Color.Transparent),
                center = Offset(size.width * 0.5f, size.height * 1.05f),
                radius = (size.width * 0.4f).coerceAtLeast(1f),
            ))
        }
        androidx.compose.animation.AnimatedVisibility(
            showsMark,
            enter = androidx.compose.animation.fadeIn(tween(450)),
            exit = androidx.compose.animation.fadeOut(tween(450)),
        ) {
            Logo(Modifier.size(140 * unit, 140 * unit / SDALogoShape.ASPECT_RATIO).alpha(0.16f))
        }
    }
}

/** The church logo in the paywall's gold. */
@Composable
internal fun Logo(modifier: Modifier) {
    Canvas(modifier) {
        drawPath(SDALogoShape.path(Rect(Offset.Zero, size)), LogoGradient)
    }
}

private val Gold = Color(0xFFE2B560)
private val LogoGradient = Brush.verticalGradient(listOf(Color(0xFFF3D68C), Gold, Color(0xFFB9892F)))

@Composable
private fun Dp.sp(): TextUnit = with(LocalDensity.current) { this@sp.toSp() }

private val Serif = FontFamily.Serif

// MARK: Verse

@Composable
private fun Verse(page: Page.Verse, unit: Dp, worshipPointSize: Float, largePrint: Boolean, width: Dp) {
    val isChorus = page.block is Block.Chorus
    // 84 pt on 1080 at the phone's default size; the phone's text size buttons
    // scale it. A verse too long for the screen shrinks to fit.
    val phoneScale = worshipPointSize / ReadingSettings.DEFAULT_WORSHIP_POINT_SIZE
    val pointSize = 84 * unit * phoneScale * (if (largePrint) 1.15f else 1f)
    val lyricSize = if (isChorus) pointSize * DS.Chorus.sizeRatio(ReadingFont.Serif) else pointSize
    val lyricStyle = TextStyle(
        fontFamily = if (isChorus) DS.Chorus.family(ReadingFont.Serif) else Serif,
        fontWeight = if (isChorus) DS.Chorus.weight else FontWeight.SemiBold,
        fontStyle = if (isChorus) DS.Chorus.style else null,
        color = Color.White,
        textAlign = TextAlign.Center,
        // The system line height plus iOS's compact leading at worship scale.
        lineHeight = (1.2f + 0.18f * 0.6f).em,
        shadow = Shadow(Color.Black.copy(alpha = 0.35f), Offset(0f, with(LocalDensity.current) { (2 * unit).toPx() }),
            with(LocalDensity.current) { (12 * unit).toPx() }),
    )
    Column(Modifier.fillMaxSize().padding(start = 96 * unit, end = 96 * unit, top = 64 * unit, bottom = 56 * unit)) {
        Header(page.number, page.title, unit)
        Spacer(Modifier.height(32 * unit))
        Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
            Column(
                Modifier.widthIn(max = minOf(width * 0.88f, pointSize * 24)),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(22 * unit),
            ) {
                if (isChorus) {
                    BasicText(
                        page.chorusLabel.uppercase(),
                        style = TextStyle(fontWeight = FontWeight.Bold, fontSize = (26 * unit).sp(),
                            letterSpacing = (4 * unit).sp(), color = DS.Palette.brassOnDark),
                    )
                }
                BasicText(
                    page.block.lines.joinToString("\n"),
                    style = lyricStyle,
                    autoSize = TextAutoSize.StepBased(
                        minFontSize = (lyricSize * 0.3f).sp(), maxFontSize = lyricSize.sp(), stepSize = (lyricSize * 0.02f).sp(),
                    ),
                )
            }
        }
        Spacer(Modifier.height(32 * unit))
        Footer(page.position, page.index, page.count, unit)
    }
}

/** The number in brass beside the title, across the top. */
@Composable
private fun Header(number: Int, title: String, unit: Dp) {
    Row(horizontalArrangement = Arrangement.spacedBy(22 * unit)) {
        BasicText(
            number.toString(),
            Modifier.alignByBaseline(),
            style = TextStyle(fontFamily = Serif, fontWeight = FontWeight.SemiBold, fontSize = (44 * unit).sp(),
                fontFeatureSettings = "tnum", color = DS.Palette.brassOnDark),
        )
        BasicText(
            title,
            Modifier.alignByBaseline().weight(1f),
            style = TextStyle(fontFamily = Serif, fontWeight = FontWeight.SemiBold, fontSize = (36 * unit).sp(),
                color = Color.White.copy(alpha = 0.82f)),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            autoSize = TextAutoSize.StepBased((36 * 0.6f * unit).sp(), (36 * unit).sp(), (unit).sp()),
        )
    }
}

/** Where the verse is: "Verse 2 of 4" and a dot for each block. */
@Composable
private fun Footer(position: String, index: Int, count: Int, unit: Dp) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(22 * unit)) {
        Box(Modifier.weight(1f).height(1.dp).background(DS.Palette.brassOnDark.copy(alpha = 0.35f)))
        BasicText(
            position.uppercase(),
            style = TextStyle(fontWeight = FontWeight.Bold, fontSize = (24 * unit).sp(), letterSpacing = (3 * unit).sp(),
                color = Color.White.copy(alpha = 0.62f)),
            maxLines = 1,
        )
        if (count in 2..12) {
            Row(horizontalArrangement = Arrangement.spacedBy(10 * unit)) {
                repeat(count) { i ->
                    Box(Modifier.size(11 * unit).background(
                        if (i == index) DS.Palette.brassOnDark else Color.White.copy(alpha = 0.28f), CircleShape,
                    ))
                }
            }
        }
        Box(Modifier.weight(1f).height(1.dp).background(DS.Palette.brassOnDark.copy(alpha = 0.35f)))
    }
}

// MARK: Between hymns

/** Church mode closed: the hymn about to be sung, as a title page. */
@Composable
private fun TitleCard(page: Page.Title, unit: Dp) {
    Column(
        Modifier.fillMaxSize().padding(120 * unit),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(26 * unit, Alignment.CenterVertically),
    ) {
        Logo(Modifier.size(92 * unit, 92 * unit / SDALogoShape.ASPECT_RATIO).alpha(0.9f))
        BasicText(
            page.hymnalName.uppercase(),
            style = TextStyle(fontWeight = FontWeight.Bold, fontSize = (26 * unit).sp(), letterSpacing = (4 * unit).sp(),
                color = DS.Palette.brassOnDark),
        )
        BasicText(
            page.number.toString(),
            style = TextStyle(fontFamily = Serif, fontWeight = FontWeight.SemiBold, fontSize = (180 * unit).sp(),
                fontFeatureSettings = "tnum", color = DS.Palette.brassOnDark, lineHeight = 1.1.em),
        )
        BasicText(
            page.title,
            style = TextStyle(fontFamily = Serif, fontWeight = FontWeight.SemiBold, color = Color.White,
                textAlign = TextAlign.Center),
            maxLines = 3,
            autoSize = TextAutoSize.StepBased((76 * 0.5f * unit).sp(), (76 * unit).sp(), (2 * unit).sp()),
        )
    }
}

// MARK: Announcement and image

/**
 * A picture fills the screen (aspect-fit on black); an announcement sits
 * large and centred, on a scrim and at the bottom when it's over a picture.
 */
@Composable
private fun Special(state: ChurchState, page: Page.Special, unit: Dp, image: (String) -> Bitmap?) {
    val bitmap = page.imageId?.let(image)
    Box(Modifier.fillMaxSize()) {
        if (page.imageId != null) {
            Box(Modifier.fillMaxSize().background(Color.Black))
            if (bitmap != null) {
                Image(bitmap.asImageBitmap(), contentDescription = null, Modifier.fillMaxSize(), contentScale = ContentScale.Fit)
            }
        }
        val text = page.announcement
        if (!text.isNullOrEmpty()) {
            val overImage = page.imageId != null
            Box(
                Modifier.fillMaxSize().padding(120 * unit),
                contentAlignment = if (overImage) Alignment.BottomCenter else Alignment.Center,
            ) {
                BasicText(
                    text,
                    Modifier
                        .then(if (overImage) Modifier.background(Color.Black.copy(alpha = 0.55f), RoundedCornerShape(36 * unit)) else Modifier)
                        .padding(horizontal = 64 * unit, vertical = 40 * unit)
                        .heightIn(max = 1080 * unit),
                    style = TextStyle(fontFamily = Serif, fontWeight = FontWeight.SemiBold, color = Color.White,
                        textAlign = TextAlign.Center, lineHeight = 1.32.em),
                    autoSize = TextAutoSize.StepBased((76 * 0.4f * unit).sp(), (76 * unit).sp(), (2 * unit).sp()),
                )
            }
        }
    }
}
