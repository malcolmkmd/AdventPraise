package com.mDev.AdventPraise.ui.design

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.automirrored.outlined.Backspace
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface

/**
 * The "Go" flow (HymnNumberPad): type a number, watch the title resolve, press Go.
 * Keys are opaque (they sit inside glass); only the pad as a whole floats.
 * A hardware keyboard works too: digits, Backspace and Enter.
 *
 * The digits are hoisted: the caller owns them and may refuse one (past the end
 * of the hymnal) by not taking it, playing its own limit haptic.
 *
 * @param title resolves a number to a title; null = no such hymn in this hymnal.
 * @param isStandalone draws its own glass (tablet popover, church mode); false inside the Lectern.
 */
@Composable
fun HymnNumberPad(
    digits: String,
    onDigitsChange: (String) -> Unit,
    title: (Int) -> String?,
    onGo: (Int) -> Unit,
    modifier: Modifier = Modifier,
    recents: List<DSHymnSummary> = emptyList(),
    maxDigits: Int = 4,
    isStandalone: Boolean = true,
    onSearchInstead: (() -> Unit)? = null,
) {
    val number = digits.toIntOrNull()
    val resolved = number?.let(title)
    val focus = remember { FocusRequester() }

    fun push(digit: String) {
        if (digits.length >= maxDigits) { Haptics.play(HapticEvent.Limit); return }
        val proposed = if (digits == "0") digit else digits + digit
        onDigitsChange(proposed)
        Haptics.play(HapticEvent.KeyPress)
    }
    fun backspace() {
        if (digits.isEmpty()) return
        onDigitsChange(digits.dropLast(1))
        Haptics.play(HapticEvent.KeyPress)
    }
    fun go() {
        // The hymn opening is felt as its page turn (the reader plays it).
        if (number == null || resolved == null) { Haptics.play(HapticEvent.Limit); return }
        onGo(number)
    }

    val pad = @Composable {
        Column(
            Modifier
                .padding(DS.Space.panel)
                .focusRequester(focus)
                .focusable()
                .onKeyEvent { event ->
                    if (event.type != KeyEventType.KeyDown) return@onKeyEvent false
                    when (event.key) {
                        Key.Backspace, Key.Delete -> { backspace(); true }
                        Key.Enter, Key.NumPadEnter -> { go(); true }
                        else -> {
                            val c = event.nativeKeyEvent.unicodeChar.toChar()
                            if (c.isDigit()) { push(c.toString()); true } else false
                        }
                    }
                },
            verticalArrangement = Arrangement.spacedBy(DS.Space.m),
        ) {
            Readout(digits, onSearchInstead)
            Preview(digits, number, resolved)
            if (recents.isNotEmpty()) RecentRow(recents) { onDigitsChange(it.number.toString()); Haptics.play(HapticEvent.Selection) }
            Keys(digits.isEmpty(), resolved != null, ::push, ::backspace, ::go)
        }
    }
    if (isStandalone) {
        Box(modifier.dsGlass(dsShape(DS.Radius.panel), DS.GlassDepth.Capsule)) { OnGlass(pad) }
    } else {
        Box(modifier) { pad() }
    }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
}

@Composable
private fun Readout(digits: String, onSearchInstead: (() -> Unit)?) {
    val p = LocalSurface.current
    Row(horizontalArrangement = Arrangement.spacedBy(DS.Space.s), verticalAlignment = Alignment.CenterVertically) {
        Box(
            Modifier
                .weight(1f)
                .heightIn(min = DS.Size.hitTarget)
                .background(p.primary(DS.Fill.inset), dsShape(DS.Radius.tile))
                .padding(horizontal = DS.Space.panel)
                .clearAndSetSemantics {
                    contentDescription = "Hymn number"
                    stateDescription = digits.ifEmpty { "empty" }
                },
            contentAlignment = Alignment.CenterStart,
        ) {
            if (digits.isEmpty()) {
                Text("Hymn number", style = DS.Type.label.copy(fontWeight = FontWeight.Normal), color = p.secondary)
            } else {
                Text(digits, style = DS.Type.padReadout.copy(fontFeatureSettings = "tnum"), color = p.foreground)
            }
        }
        if (onSearchInstead != null) {
            val interaction = remember { MutableInteractionSource() }
            Box(
                Modifier
                    .dsPress(interaction)
                    .heightIn(min = DS.Size.hitTarget)
                    .clip(dsShape(DS.Radius.tile))
                    .background(p.elevated.copy(alpha = 0.85f))
                    .border(1.dp, p.controlBorder, dsShape(DS.Radius.tile))
                    .clickable(interaction, null, onClick = onSearchInstead)
                    .padding(horizontal = DS.Space.m)
                    .clearAndSetSemantics { contentDescription = "Search by words instead"; role = Role.Button },
                contentAlignment = Alignment.Center,
            ) {
                Text("Abc", style = DS.Type.button, color = p.foreground)
            }
        }
    }
}

@Composable
private fun Preview(digits: String, number: Int?, resolved: String?) {
    val p = LocalSurface.current
    AnimatedContent(
        targetState = Triple(digits.isEmpty(), number, resolved),
        transitionSpec = { fadeIn(DS.Motion.quick()) togetherWith fadeOut(DS.Motion.quick()) },
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 46.dp)
            .padding(horizontal = DS.Space.xxs)
            .clearAndSetSemantics {
                liveRegion = LiveRegionMode.Polite
                contentDescription = when {
                    resolved != null && number != null -> "$number, $resolved"
                    digits.isEmpty() -> "The title appears as you type."
                    else -> "No hymn with that number"
                }
            },
        label = "pad-preview",
    ) { (empty, n, t) ->
        Column(verticalArrangement = Arrangement.spacedBy(DS.Space.hair)) {
            when {
                t != null && n != null -> {
                    Text(t, style = DS.Type.panelTitle, color = p.foreground, maxLines = 2, overflow = TextOverflow.Ellipsis)
                    Eyebrow("Hymn $n", p.brass, tracking = 0.7f)
                }
                empty -> Text("The title appears as you type.", style = DS.Type.detail, color = p.secondary)
                else -> Text("No hymn with that number", style = DS.Type.rowBody.copy(fontStyle = FontStyle.Italic), color = p.secondary)
            }
        }
    }
}

@Composable
private fun RecentRow(recents: List<DSHymnSummary>, onPick: (DSHymnSummary) -> Unit) {
    val p = LocalSurface.current
    Row(
        Modifier.horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(DS.Space.xs),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Eyebrow("Recent", p.secondary)
        recents.take(3).forEach { hymn ->
            // 32 dp chip, 44 dp tall hit area.
            Box(
                Modifier
                    .heightIn(min = DS.Size.hitTarget)
                    .clickable { onPick(hymn) }
                    .clearAndSetSemantics { contentDescription = "Recent: ${hymn.number}, ${hymn.title}"; role = Role.Button },
                contentAlignment = Alignment.Center,
            ) {
                Row(
                    Modifier
                        .heightIn(min = 32.dp)
                        .widthIn(max = 140.dp)
                        .background(p.elevated.copy(alpha = 0.85f), RoundedCornerShape(50))
                        .border(BorderStroke(1.dp, p.controlBorder), RoundedCornerShape(50))
                        .padding(horizontal = 10.dp),
                    horizontalArrangement = Arrangement.spacedBy(DS.Space.xxs),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    val style = DS.Type.caption.copy(fontWeight = FontWeight.SemiBold)
                    Text(hymn.number.toString(), style = style, color = p.brass)
                    Text(hymn.title, style = style, color = p.foreground, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
        }
    }
}

@Composable
private fun Keys(
    isEmpty: Boolean,
    canGo: Boolean,
    push: (String) -> Unit,
    backspace: () -> Unit,
    go: () -> Unit,
) {
    val p = LocalSurface.current
    val height = DS.Size.padKey
    Column(verticalArrangement = Arrangement.spacedBy(DS.Space.s)) {
        listOf(1, 4, 7).forEach { first ->
            Row(horizontalArrangement = Arrangement.spacedBy(DS.Space.s)) {
                (first until first + 3).forEach { n -> PadKey(n.toString(), height, Modifier.weight(1f)) { push(n.toString()) } }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(DS.Space.s)) {
            Box(
                Modifier
                    .weight(1f)
                    .heightIn(min = height)
                    .clickable(enabled = !isEmpty, onClick = backspace)
                    .clearAndSetSemantics { contentDescription = "Delete last digit"; role = Role.Button },
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.AutoMirrored.Outlined.Backspace, null, tint = p.secondary.copy(alpha = if (isEmpty) DS.Fill.disabled else p.secondary.alpha))
            }
            PadKey("0", height, Modifier.weight(1f)) { push("0") }
            GoKey(height, canGo, Modifier.weight(1f), go)
        }
    }
}

@Composable
private fun PadKey(label: String, height: Dp, modifier: Modifier, onClick: () -> Unit) {
    val p = LocalSurface.current
    val interaction = remember { MutableInteractionSource() }
    val shape = dsShape(DS.Radius.key)
    Box(
        modifier
            .dsPress(interaction)
            .heightIn(min = height)
            .clip(shape)
            .background(p.elevated.copy(alpha = 0.85f))
            .border(1.dp, p.primary(DS.Fill.hairline), shape)
            .clickable(interaction, null, role = Role.Button, onClick = onClick)
            .clearAndSetSemantics { contentDescription = label; role = Role.Button },
        contentAlignment = Alignment.Center,
    ) {
        Text(label, style = DS.Type.padDigit, color = p.foreground)
    }
}

/**
 * Enabled: solid surface tint with the onTint label. Disabled: an empty dashed key
 * with secondary text, so it still reads but never looks pressable.
 */
@Composable
private fun GoKey(height: Dp, enabled: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val p = LocalSurface.current
    val interaction = remember { MutableInteractionSource() }
    val shape = dsShape(DS.Radius.key)
    val color = if (enabled) p.onTint else p.secondary
    Row(
        modifier
            .dsPress(interaction, enabled)
            .heightIn(min = height)
            .clip(shape)
            .background(if (enabled) p.tint else p.tint.copy(alpha = 0f))
            .drawBehind {
                if (!enabled) {
                    val r = DS.Radius.key.toPx()
                    drawRoundRect(
                        p.controlBorder, cornerRadius = CornerRadius(r, r),
                        style = Stroke(1.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 3.dp.toPx()))),
                    )
                }
            }
            .clickable(interaction, null, enabled = enabled, role = Role.Button, onClick = onClick)
            .clearAndSetSemantics {
                contentDescription = "Go to hymn"
                if (!enabled) stateDescription = "Enter a hymn number first"
            },
        horizontalArrangement = Arrangement.spacedBy(DS.Space.xxs, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Label("Go", systemImage: "arrow.right"): the arrow leads.
        Icon(Icons.AutoMirrored.Rounded.ArrowForward, null, tint = color, modifier = Modifier.size(18.dp))
        Text("Go", style = DS.Type.button, color = color, maxLines = 1)
    }
}
