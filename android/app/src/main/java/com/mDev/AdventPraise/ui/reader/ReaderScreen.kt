package com.mDev.AdventPraise.ui.reader

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.data.Block
import com.mDev.AdventPraise.data.Hymn
import com.mDev.AdventPraise.data.Hymnal
import com.mDev.AdventPraise.reader.LecternState
import com.mDev.AdventPraise.settings.ReadingFont
import com.mDev.AdventPraise.settings.ReadingSettings
import com.mDev.AdventPraise.ui.Eyebrow
import com.mDev.AdventPraise.ui.rememberHaptic
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/**
 * The reader: the hymn on the person's surface, the globe (reader menu) at
 * the top and the Lectern at the bottom, as on iOS. Swipe sideways for the
 * next or previous hymn; tap to hide the chrome.
 */
@Composable
fun ReaderScreen(services: AppServices) {
    val model = services.reader
    val settings = services.settings
    val haptic = rememberHaptic(settings.haptics)
    val hymnal = model.hymnal
    val hymn = model.hymn
    val chromeOpen = model.isMenuOpen || model.lectern != LecternState.Collapsed

    // Opening another hymn stops the one playing.
    LaunchedEffect(hymnal?.id, hymn?.number) {
        if (hymnal != null && hymn != null && !services.player.isLoaded(hymnal.id, hymn)) services.player.stop()
    }

    Box(Modifier.fillMaxSize()) {
        if (hymnal != null && hymn != null) {
            HymnPage(hymnal, hymn, settings, onTap = model::toggleFocus, onNext = {
                if (model.goToNext() != null) haptic()
            }, onPrevious = {
                if (model.goToPrevious() != null) haptic()
            })
        }
        // A tap outside the open Lectern or menu closes it.
        if (chromeOpen) {
            Box(
                Modifier
                    .fillMaxSize()
                    .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {
                        model.toggleFocus()
                    },
            )
        }
        AnimatedVisibility(
            visible = !model.isFocused,
            enter = fadeIn() + slideInVertically { -it },
            exit = fadeOut() + slideOutVertically { -it },
            modifier = Modifier.align(Alignment.TopCenter),
        ) {
            ReaderMenu(services)
        }
        AnimatedVisibility(
            visible = !model.isFocused,
            enter = fadeIn() + slideInVertically { it },
            exit = fadeOut() + slideOutVertically { it },
            modifier = Modifier.align(Alignment.BottomCenter),
        ) {
            Lectern(services)
        }
    }
}

@Composable
private fun HymnPage(
    hymnal: Hymnal,
    hymn: Hymn,
    settings: ReadingSettings,
    onTap: () -> Unit,
    onNext: () -> Unit,
    onPrevious: () -> Unit,
) {
    val blocks = if (settings.repeatChorus) hymn.sungSequence else hymn.blocks
    val listState = rememberLazyListState()
    LaunchedEffect(hymnal.id, hymn.number) { listState.scrollToItem(0) }
    var dragX by remember { mutableFloatStateOf(0f) }
    val threshold = with(LocalDensity.current) { 72.dp.toPx() }
    val bars = WindowInsets.systemBars.asPaddingValues()

    LazyColumn(
        state = listState,
        modifier = Modifier
            .fillMaxSize()
            .pointerInput(hymnal.id, hymn.number) {
                detectHorizontalDragGestures(
                    onDragStart = { dragX = 0f },
                    onDragEnd = {
                        when {
                            dragX < -threshold -> onNext()
                            dragX > threshold -> onPrevious()
                        }
                        dragX = 0f
                    },
                    onDragCancel = { dragX = 0f },
                ) { change, amount ->
                    change.consume()
                    dragX += amount
                }
            }
            .pointerInput(Unit) { detectTapGestures(onTap = { onTap() }) }
            .graphicsLayer {
                translationX = dragX * 0.4f
                alpha = 1f - min(abs(dragX) / max(size.width, 1f), 1f) * 0.5f
            },
        contentPadding = PaddingValues(
            top = bars.calculateTopPadding() + 76.dp,
            bottom = bars.calculateBottomPadding() + 132.dp,
        ),
        verticalArrangement = Arrangement.spacedBy(DS.Space.block),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        item(key = "header") {
            Column(Modifier.readingMeasure()) { HymnHeader(hymnal, hymn, settings.centered) }
        }
        itemsIndexed(blocks, key = { index, _ -> "${hymnal.id}-${hymn.number}-$index" }) { _, block ->
            Column(Modifier.readingMeasure()) {
                when (block) {
                    is Block.Verse -> VerseBlock(block, settings)
                    is Block.Chorus -> ChorusBlock(block, hymnal.chorusLabel, settings)
                }
            }
        }
    }
}

/** The reading measure: 640 dp at most, 28 dp gutters. */
private fun Modifier.readingMeasure(): Modifier =
    widthIn(max = DS.Space.readingMeasure).fillMaxWidth().padding(horizontal = DS.Space.gutter)

@Composable
private fun HymnHeader(hymnal: Hymnal, hymn: Hymn, centered: Boolean) {
    val p = LocalSurface.current
    val numeral = TextStyle(fontFamily = FontFamily.Serif, fontSize = 46.sp, color = p.brass)
    val title = DS.Type.hymnTitle.copy(color = p.foreground, textAlign = if (centered) TextAlign.Center else TextAlign.Start)
    Column(
        Modifier
            .fillMaxWidth()
            .semantics(mergeDescendants = true) { heading(); contentDescription = "Hymn ${hymn.number}, ${hymn.title}" },
        horizontalAlignment = if (centered) Alignment.CenterHorizontally else Alignment.Start,
        verticalArrangement = Arrangement.spacedBy(DS.Space.xs),
    ) {
        if (centered) {
            Eyebrow(hymnal.name, p.brass, tracking = 1.6f)
            Text(hymn.number.toString(), style = numeral)
            Text(hymn.title, style = title)
            if (hymn.references.isNotEmpty()) {
                Eyebrow(hymn.references.joinToString(" · "), p.secondary, Modifier.padding(top = DS.Space.xxs), tracking = 1.1f)
            }
        } else {
            Text(hymn.number.toString(), style = numeral)
            Text(hymn.title, style = title)
            Eyebrow((listOf(hymnal.name) + hymn.references).joinToString(" · "), p.secondary,
                Modifier.padding(top = DS.Space.xxs), tracking = 1.1f)
        }
    }
}

/** Lyric type at the person's size, font, spacing and alignment. */
@Composable
private fun lyricStyle(settings: ReadingSettings, chorus: Boolean = false): TextStyle {
    val p = LocalSurface.current
    val serif = settings.font == ReadingFont.Serif
    // The chorus is a second voice: bold italic in the contrasting family.
    val family = when {
        !chorus -> if (serif) FontFamily.Serif else FontFamily.SansSerif
        serif -> FontFamily.SansSerif
        else -> FontFamily.Serif
    }
    val ratio = if (!chorus) 1f else if (serif) 0.92f else 1.06f
    val size = settings.pointSize * ratio
    val leading = settings.pointSize * settings.lineSpacing.leading * settings.leadingScale
    return TextStyle(
        fontFamily = family,
        fontSize = size.sp,
        lineHeight = (size * 1.2f + leading).sp,
        fontWeight = if (chorus) FontWeight.Bold else FontWeight.Normal,
        fontStyle = if (chorus) FontStyle.Italic else FontStyle.Normal,
        color = p.foreground,
        textAlign = if (settings.centered) TextAlign.Center else TextAlign.Start,
    )
}

private fun badgeSize(settings: ReadingSettings): Dp = max(DS.Size.verseBadge.value, settings.pointSize * 1.35f).dp

@Composable
private fun VerseBlock(verse: Block.Verse, settings: ReadingSettings) {
    val badge = badgeSize(settings)
    val text = verse.lines.joinToString("\n")
    if (settings.centered) {
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(DS.Space.xs)) {
            VerseBadge(verse.number, badge)
            Text(text, style = lyricStyle(settings), modifier = Modifier.fillMaxWidth())
        }
    } else {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(DS.Space.panel)) {
            VerseBadge(verse.number, badge, Modifier.padding(top = DS.Space.hair))
            Text(text, style = lyricStyle(settings), modifier = Modifier.weight(1f))
        }
    }
}

@Composable
private fun VerseBadge(number: Int, size: Dp, modifier: Modifier = Modifier) {
    val p = LocalSurface.current
    Box(modifier.size(size).semantics { contentDescription = "Verse $number" }, contentAlignment = Alignment.Center) {
        Text(
            number.toString(),
            style = TextStyle(fontFamily = FontFamily.Serif, fontWeight = FontWeight.Medium,
                fontSize = (size.value * 0.58f).sp, color = p.secondary),
        )
    }
}

@Composable
private fun ChorusBlock(chorus: Block.Chorus, label: String, settings: ReadingSettings) {
    val p = LocalSurface.current
    val text = chorus.lines.joinToString("\n")
    if (settings.centered) {
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(DS.Space.xs)) {
            Box(Modifier.padding(bottom = DS.Space.xxs).size(width = 24.dp, height = 2.dp)
                .clip(CircleShape).background(p.brass.copy(alpha = 0.7f)))
            Eyebrow(label, p.brass, tracking = 1.5f)
            Text(text, style = lyricStyle(settings, chorus = true), modifier = Modifier.fillMaxWidth())
        }
    } else {
        Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min).padding(start = badgeSize(settings) + DS.Space.panel)) {
            Box(Modifier.width(2.dp).fillMaxHeight().clip(RoundedCornerShape(1.dp)).background(p.brass.copy(alpha = 0.7f)))
            Column(Modifier.padding(start = DS.Space.panel), verticalArrangement = Arrangement.spacedBy(DS.Space.xs)) {
                Eyebrow(label, p.brass, tracking = 1.5f)
                Text(text, style = lyricStyle(settings, chorus = true))
            }
        }
    }
}
