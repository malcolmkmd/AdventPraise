package com.mDev.AdventPraise.ui.design

import com.mDev.AdventPraise.settings.LyricScale
import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.FormatAlignLeft
import androidx.compose.material.icons.rounded.FormatAlignCenter
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mDev.AdventPraise.settings.LineSpacing
import com.mDev.AdventPraise.settings.ReadingFont
import com.mDev.AdventPraise.settings.ReadingSurface
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import com.mDev.AdventPraise.ui.theme.ReadingStyle
import com.mDev.AdventPraise.ui.theme.SurfacePalette

/*
 * Typography and reading-surface controls (AppearanceControls.swift), as sections
 * the reader menu's Theme and Text panels lay out. They hang over the lyrics, so
 * every change previews live on the page below. Each reads LocalSurface and
 * draws no glass of its own. State is hoisted: each takes a value and a setter.
 */

/** Text size: a slider between smaller and larger "A" buttons, in points. */
@Composable
fun ReadingSizeControl(style: ReadingStyle, onChange: (ReadingStyle) -> Unit, modifier: Modifier = Modifier) {
    val p = LocalSurface.current
    val last = style.scale.steps.size - 1
    Column(modifier, verticalArrangement = Arrangement.spacedBy(DS.Space.s)) {
        Row(verticalAlignment = Alignment.Bottom) {
            SectionLabel("Text size", Modifier.weight(1f))
            Text("${style.basePointSize.toInt()} pt", style = DS.Type.detail.copy(fontFeatureSettings = "tnum"), color = p.secondary)
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            SizeStepButton(15f, "Smaller text", enabled = style.step > 0) { onChange(style.withStep(style.step - 1)) }
            Slider(
                value = style.step.toFloat(),
                onValueChange = { onChange(style.withStep(Math.round(it))) },
                valueRange = 0f..last.toFloat(),
                steps = (last - 1).coerceAtLeast(0),
                colors = SliderDefaults.colors(thumbColor = p.tint, activeTrackColor = p.tint, inactiveTrackColor = p.primary(DS.Fill.stroke),
                    activeTickColor = p.onTint.copy(alpha = 0.6f), inactiveTickColor = p.primary(0.3f)),
                modifier = Modifier.weight(1f).semantics {
                    contentDescription = "Text size"
                    stateDescription = "${style.basePointSize.toInt()} points"
                },
            )
            SizeStepButton(24f, "Larger text", enabled = style.step < last) { onChange(style.withStep(style.step + 1)) }
        }
        Text("Also follows your phone’s font size setting.", style = DS.Type.caption, color = p.secondary, modifier = Modifier.fillMaxWidth())
    }
}

/** Print size, line spacing and alignment: a segmented row each. */
@Composable
fun ReadingLayoutControls(style: ReadingStyle, onChange: (ReadingStyle) -> Unit, modifier: Modifier = Modifier) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(DS.Space.m)) {
        LabelledRow("Print") {
            Segmented(
                options = listOf(LyricScale.Standard, LyricScale.LargePrint),
                selected = if (style.scale == LyricScale.LargePrint) LyricScale.LargePrint else LyricScale.Standard,
                label = { Text(DS.lyricScaleName(it), maxLines = 1) },
                description = { DS.lyricScaleName(it) },
                modifier = Modifier.widthIn(max = 260.dp),
            ) { onChange(style.withScale(it)) }
        }
        LabelledRow("Spacing") {
            Segmented(
                options = LineSpacing.entries,
                selected = style.lineSpacing,
                label = { Text(it.label, maxLines = 1) },
                description = { it.label },
                modifier = Modifier.widthIn(max = 260.dp),
            ) { onChange(style.copy(lineSpacing = it)) }
        }
        LabelledRow("Alignment") {
            Segmented(
                options = listOf(false, true),
                selected = style.centered,
                label = { Icon(if (it) Icons.Rounded.FormatAlignCenter else Icons.AutoMirrored.Rounded.FormatAlignLeft, null, Modifier.size(18.dp)) },
                description = { if (it) "Align centre" else "Align left" },
                modifier = Modifier.width(120.dp),
            ) { onChange(style.copy(centered = it)) }
        }
    }
}

/** Serif or sans: side by side, stacked when they don't fit. */
@Composable
fun ReadingFontPicker(style: ReadingStyle, onChange: (ReadingStyle) -> Unit, modifier: Modifier = Modifier) {
    BoxWithConstraints(modifier.fillMaxWidth()) {
        val sideBySide = maxWidth >= 320.dp
        val cards = @Composable { m: Modifier ->
            ReadingFont.entries.forEach { font ->
                FontCard(font, style.font == font, m) { onChange(style.copy(font = font)) }
            }
        }
        if (sideBySide) {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) { cards(Modifier.weight(1f)) }
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(DS.Space.s)) { cards(Modifier.fillMaxWidth()) }
        }
    }
}

/** The reading surfaces as swatches, each drawn in its own ground and ink. */
@Composable
fun ReadingSurfacePicker(surface: ReadingSurface, onChange: (ReadingSurface) -> Unit, modifier: Modifier = Modifier) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(DS.Space.s)) {
        SectionLabel("Reading surface")
        BoxWithConstraints(Modifier.fillMaxWidth()) {
            // Adaptive columns of at least 58 dp, as iOS's grid.
            val spacing = DS.Space.s
            val columns = ((maxWidth + spacing) / (58.dp + spacing)).toInt().coerceIn(1, ReadingSurface.entries.size)
            Column(verticalArrangement = Arrangement.spacedBy(spacing)) {
                ReadingSurface.entries.chunked(columns).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(spacing)) {
                        row.forEach { candidate ->
                            SurfaceSwatch(candidate, candidate == surface, Modifier.weight(1f)) {
                                if (candidate != surface) Haptics.play(HapticEvent.Selection)
                                onChange(candidate)
                            }
                        }
                        repeat(columns - row.size) { Box(Modifier.weight(1f)) }
                    }
                }
            }
        }
    }
}

// MARK: Pieces

@Composable
private fun SectionLabel(text: String, modifier: Modifier = Modifier) {
    Eyebrow(text, LocalSurface.current.secondary, modifier.semantics { heading() })
}

@Composable
private fun LabelledRow(title: String, control: @Composable () -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DS.Space.m)) {
        SectionLabel(title, Modifier.weight(1f))
        control()
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun <T> Segmented(
    options: List<T>,
    selected: T,
    label: @Composable (T) -> Unit,
    description: (T) -> String,
    modifier: Modifier = Modifier,
    onSelect: (T) -> Unit,
) {
    val p = LocalSurface.current
    SingleChoiceSegmentedButtonRow(modifier) {
        options.forEachIndexed { index, option ->
            SegmentedButton(
                selected = option == selected,
                onClick = {
                    if (option != selected) Haptics.play(HapticEvent.Selection)
                    onSelect(option)
                },
                shape = SegmentedButtonDefaults.itemShape(index, options.size),
                icon = {},
                colors = SegmentedButtonDefaults.colors(
                    activeContainerColor = p.elevated,
                    activeContentColor = p.foreground,
                    activeBorderColor = p.primary(DS.Fill.stroke),
                    inactiveContainerColor = p.primary(DS.Fill.inset),
                    inactiveContentColor = p.foreground,
                    inactiveBorderColor = p.primary(DS.Fill.stroke),
                ),
                modifier = Modifier.semantics { contentDescription = description(option) },
            ) {
                CompositionLocalText { label(option) }
            }
        }
    }
}

@Composable
private fun CompositionLocalText(content: @Composable () -> Unit) {
    androidx.compose.material3.ProvideTextStyle(DS.Type.label.copy(fontSize = 13.sp), content)
}

@Composable
private fun SizeStepButton(glyph: Float, label: String, enabled: Boolean, onClick: () -> Unit) {
    val p = LocalSurface.current
    val interaction = remember { MutableInteractionSource() }
    Box(
        Modifier
            .dsPress(interaction, enabled)
            .size(DS.Size.hitTarget)
            .clip(dsShape(DS.Radius.chip))
            .background(p.primary(DS.Fill.inset))
            .clickable(interaction, null, enabled = enabled) {
                Haptics.play(HapticEvent.Selection)
                onClick()
            }
            .clearAndSetSemantics { contentDescription = label; role = Role.Button },
        contentAlignment = Alignment.Center,
    ) {
        Text("A", style = TextStyle(fontFamily = FontFamily.Serif, fontWeight = FontWeight.SemiBold, fontSize = glyph.sp),
            color = p.foreground.copy(alpha = if (enabled) 1f else DS.Fill.disabled))
    }
}

@Composable
private fun FontCard(font: ReadingFont, isSelected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val p = LocalSurface.current
    val shape = dsShape(DS.Radius.card)
    val fill by animateColorAsState(if (isSelected) p.tint.copy(alpha = DS.Fill.tintSelected) else p.primary(DS.Fill.inset), DS.Motion.select(), label = "font-fill")
    val stroke by animateColorAsState(if (isSelected) p.tint else Color.Transparent, DS.Motion.select(), label = "font-stroke")
    Row(
        modifier
            .heightIn(min = 72.dp)
            .clip(shape)
            .background(fill)
            .border(1.5.dp, stroke, shape)
            .clickable { if (!isSelected) Haptics.play(HapticEvent.Selection); onClick() }
            .padding(horizontal = DS.Space.panel, vertical = DS.Space.s)
            .clearAndSetSemantics { contentDescription = "${font.label}, ${font.detail}"; role = Role.Button; selected = isSelected },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Space.m),
    ) {
        Text("Aa", style = TextStyle(fontFamily = DS.lyricFamily(font), fontWeight = FontWeight.Medium, fontSize = 28.sp), color = p.foreground)
        Column(verticalArrangement = Arrangement.spacedBy(DS.Space.hair)) {
            Text(font.label, style = DS.Type.label.copy(fontWeight = FontWeight.Bold), color = p.foreground)
            Text(font.detail, style = DS.Type.caption, color = p.secondary)
        }
    }
}

/** A surface preview: its own ground and ink, so it reads true on any sheet. */
@Composable
private fun SurfaceSwatch(candidate: ReadingSurface, isSelected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val current = LocalSurface.current
    val own = SurfacePalette.of(candidate)
    val shape = dsShape(DS.Radius.tile)
    Box(
        modifier
            .border(5.dp, current.tint.copy(alpha = if (isSelected) 0.18f else 0f), dsShape(DS.Radius.tile + 3.dp))
            .padding(3.dp)
            .clearAndSetSemantics { contentDescription = candidate.label; role = Role.Button; selected = isSelected },
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .heightIn(min = 76.dp)
                .clip(shape)
                .background(own.background)
                .border(if (isSelected) 2.dp else 1.dp, if (isSelected) current.tint else current.primary(DS.Fill.stroke), shape)
                .clickable(onClick = onClick),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(DS.Space.xs, Alignment.CenterVertically),
        ) {
            Text("Aa", style = TextStyle(fontFamily = FontFamily.Serif, fontWeight = FontWeight.Medium, fontSize = 22.sp), color = own.foreground)
            Text(candidate.label, style = DS.Type.eyebrow(0.4f).copy(fontWeight = FontWeight.SemiBold), color = own.foreground, maxLines = 1)
        }
    }
}
