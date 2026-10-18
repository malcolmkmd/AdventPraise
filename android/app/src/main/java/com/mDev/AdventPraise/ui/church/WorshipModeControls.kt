package com.mDev.AdventPraise.ui.church

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.HighlightOff
import androidx.compose.material.icons.outlined.Image
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material.icons.rounded.Cast
import androidx.compose.material.icons.rounded.ChatBubble
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.FormatSize
import androidx.compose.material.icons.rounded.Language
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.SkipNext
import androidx.compose.material.icons.rounded.TextDecrease
import androidx.compose.material.icons.rounded.TextIncrease
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material.icons.rounded.Tv
import androidx.compose.material.icons.rounded.Visibility
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.disabled
import androidx.compose.ui.semantics.invisibleToUser
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mDev.AdventPraise.ui.design.Eyebrow
import com.mDev.AdventPraise.ui.design.dsGlass
import com.mDev.AdventPraise.ui.design.dsPress
import com.mDev.AdventPraise.ui.design.dsShape
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import com.mDev.AdventPraise.ui.theme.rememberReduceMotion
import com.mDev.AdventPraise.ui.tour.TourTarget
import com.mDev.AdventPraise.ui.tour.tourTarget

/** The TV button: hidden, Pro's chooser, or (without Pro) a button that opens the paywall. */
enum class WorshipTv { Hidden, Locked, Available }

/** The phone as the worship display's remote (Next hymn, Blank), while it's up. */
class WorshipRemote(
    val isBlanked: Boolean,
    val hasNextHymn: Boolean,
    val onToggleBlank: () -> Unit,
    val onNextHymn: () -> Unit,
)

/** Church mode's presenter actions behind the actions button (Blank, Announcement, Show image, Clear). */
class WorshipActions(
    val isBlanked: Boolean,
    val hasAnnouncement: Boolean,
    val hasImage: Boolean,
    /** Without Pro, presenter actions open the paywall. */
    val isLocked: Boolean,
    val onToggleBlank: () -> Unit,
    val onAnnouncement: () -> Unit,
    val onImage: () -> Unit,
    val onClear: () -> Unit,
) {
    /** The TV shows something other than the words. */
    val isTVOverridden: Boolean get() = isBlanked || hasAnnouncement || hasImage
    val statusLabel: String
        get() = when {
            hasImage -> "Image on TV"
            hasAnnouncement -> "Announcement on TV"
            isBlanked -> "TV blank"
            else -> ""
        }
}

/** Which of the controls' popovers is open. */
enum class WorshipPopover { NumberPad, Translations, Actions }

/** Leave, TV and globe: their own row, so a little smaller. */
private val BarSize = 52.dp
/** The presenter actions button. */
private val TopSize = 60.dp
/** More blocks than this and the dots stop being countable at a glance. */
private const val MAX_DOTS = 12

/**
 * The overlay for reading in church (WorshipModeControls): a few large
 * controls floating over the words. Top, two rows so a long title never
 * shares a line with buttons: leave on the leading edge, the remote's Next
 * hymn and Blank, the TV and the globe trailing; under them the hymn card
 * (number in brass, the title over up to three lines, "Verse 2 of 4" and
 * progress dots; tap it to jump to another number). Bottom, where a thumb
 * already is: previous, the presenter actions (text size and the TV), next.
 *
 * The parent owns verse state and hides the controls after ~4 s idle
 * ([isVisible]); hidden, they take no touches, so a tap reaches the words
 * and brings them back. Popovers are opaque, dark panels anchored to their
 * button.
 */
@Composable
fun WorshipModeControls(
    hymnNumber: Int,
    title: String,
    position: String,
    step: Int,
    stepCount: Int,
    language: String,
    canGoBack: Boolean,
    canGoForward: Boolean,
    canShrinkText: Boolean,
    canEnlargeText: Boolean,
    isVisible: Boolean,
    tv: WorshipTv,
    isOnExternalScreen: Boolean,
    remote: WorshipRemote?,
    actions: WorshipActions?,
    popover: WorshipPopover?,
    onPopover: (WorshipPopover?) -> Unit,
    onTv: () -> Unit,
    onPrevious: () -> Unit,
    onNext: () -> Unit,
    onExit: () -> Unit,
    onTextSmaller: () -> Unit,
    onTextLarger: () -> Unit,
    onTopBarHeight: (Dp) -> Unit,
    modifier: Modifier = Modifier,
    numberPad: @Composable () -> Unit,
    translations: @Composable () -> Unit,
) {
    val reduceMotion = rememberReduceMotion()
    val alpha by animateFloatAsState(if (isVisible) 1f else 0f, DS.Motion.adaptive(DS.Motion.focus(), reduceMotion), label = "controls")
    val density = LocalDensity.current
    // Chrome only, capped like iOS's accessibility1; the lyric follows the font scale on its own.
    val capped = Density(density.density, minOf(density.fontScale, 1.6f))
    val live = isVisible
    var barHeight by remember { mutableStateOf(0.dp) }

    CompositionLocalProvider(LocalDensity provides capped) {
        Box(modifier.fillMaxSize()) {
            Column(
                Modifier
                    .fillMaxSize()
                    .graphicsLayer { this.alpha = alpha }
                    .then(if (live) Modifier else Modifier.semantics { invisibleToUser() })
                    .windowInsetsPadding(WindowInsets.safeDrawing)
                    .padding(horizontal = DS.Space.l, vertical = DS.Space.s),
            ) {
                // Top: leave · remote · TV · translation, then what's showing (tap to jump).
                Column(
                    Modifier.onSizeChanged {
                        barHeight = with(density) { it.height.toDp() }
                        onTopBarHeight(barHeight)
                    },
                    verticalArrangement = Arrangement.spacedBy(DS.Space.panel),
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DS.Space.m)) {
                        WorshipButton(Icons.Rounded.Close, "Leave worship mode", BarSize, live, modifier = Modifier.tourTarget(TourTarget.ChurchLeave), onClick = onExit)
                        Spacer(Modifier.weight(1f))
                        if (remote != null) {
                            WorshipButton(Icons.Rounded.SkipNext, "Next hymn", BarSize, live, enabled = remote.hasNextHymn,
                                hint = "Shows the next hymn on the big screen", onClick = remote.onNextHymn)
                            WorshipButton(
                                if (remote.isBlanked) Icons.Filled.VisibilityOff else Icons.Outlined.VisibilityOff,
                                if (remote.isBlanked) "Show the words" else "Blank the screen", BarSize, live,
                                prominent = remote.isBlanked, hint = "Blanks the big screen, or shows the words again",
                                onClick = remote.onToggleBlank,
                            )
                        }
                        when (tv) {
                            WorshipTv.Hidden -> Unit
                            WorshipTv.Locked -> WorshipButton(Icons.Rounded.Cast, "TV", BarSize, live,
                                hint = "Showing the hymn on a TV or projector needs Advent Praise Pro", onClick = onTv)
                            WorshipTv.Available -> WorshipButton(Icons.Rounded.Cast, "TV", BarSize, live,
                                active = isOnExternalScreen, hint = "Shows the words on a TV or projector", onClick = onTv)
                        }
                        WorshipButton(Icons.Rounded.Language, "Translation", BarSize, live, value = language,
                            hint = "Shows this hymn in another hymnal") { onPopover(WorshipPopover.Translations) }
                    }
                    HymnCard(hymnNumber, title, position, step, stepCount, isOnExternalScreen, live) {
                        onPopover(WorshipPopover.NumberPad)
                    }
                }
                Spacer(Modifier.weight(1f))
                // Bottom: previous · text size and the presenter actions · next.
                Row(verticalAlignment = Alignment.CenterVertically) {
                    WorshipButton(Icons.AutoMirrored.Rounded.KeyboardArrowLeft, "Previous verse", DS.Size.worshipHitTarget, live,
                        enabled = canGoBack, onClick = onPrevious)
                    Spacer(Modifier.weight(1f))
                    WorshipButton(actionsIcon(actions), "Presenter actions", TopSize, live,
                        prominent = actions?.isTVOverridden == true, value = actions?.statusLabel.orEmpty(),
                        modifier = Modifier.tourTarget(TourTarget.ChurchActions)) {
                        onPopover(WorshipPopover.Actions)
                    }
                    Spacer(Modifier.weight(1f))
                    // The one primary action on this screen: the only prominent control.
                    WorshipButton(Icons.AutoMirrored.Rounded.KeyboardArrowRight, "Next verse", DS.Size.worshipHitTarget, live,
                        enabled = canGoForward, prominent = true, onClick = onNext)
                }
            }

            // Popovers, anchored to their buttons; a tap outside or Back closes them.
            BackHandler(enabled = popover != null) { onPopover(null) }
            if (popover != null) {
                Box(Modifier.fillMaxSize().clickable(remember { MutableInteractionSource() }, null) { onPopover(null) })
            }
            Box(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing).padding(horizontal = DS.Space.l, vertical = DS.Space.s)) {
                Popover(popover == WorshipPopover.Translations, Alignment.TopEnd, Modifier.padding(top = BarSize + DS.Space.s)) { translations() }
                Popover(popover == WorshipPopover.NumberPad, Alignment.TopCenter, Modifier.padding(top = barHeight + DS.Space.s)) { numberPad() }
                Popover(popover == WorshipPopover.Actions, Alignment.BottomCenter, Modifier.padding(bottom = DS.Size.worshipHitTarget + DS.Space.s)) {
                    ActionsPanel(actions, canShrinkText, canEnlargeText, onTextSmaller, onTextLarger) { onPopover(null) }
                }
            }
        }
    }
}

private fun actionsIcon(actions: WorshipActions?): ImageVector = when {
    actions == null -> Icons.Rounded.FormatSize
    actions.hasImage -> Icons.Filled.Image
    actions.hasAnnouncement -> Icons.Rounded.ChatBubble
    actions.isBlanked -> Icons.Filled.VisibilityOff
    else -> Icons.Rounded.Tune
}

/** An opaque dark panel over the words (glass over white lyrics washes out). */
@Composable
private fun BoxScope.Popover(visible: Boolean, alignment: Alignment, modifier: Modifier, content: @Composable () -> Unit) {
    val reduceMotion = rememberReduceMotion()
    AnimatedVisibility(
        visible,
        modifier = modifier.align(alignment),
        enter = if (reduceMotion) fadeIn(DS.Motion.reduced()) else fadeIn(DS.Motion.quick()) + scaleIn(DS.Motion.quick(), initialScale = 0.92f),
        exit = if (reduceMotion) fadeOut(DS.Motion.reduced()) else fadeOut(DS.Motion.quick()) + scaleOut(DS.Motion.quick(), targetScale = 0.92f),
    ) {
        val p = LocalSurface.current
        val shape = dsShape(DS.Radius.panel)
        Box(
            Modifier
                .graphicsLayer { shadowElevation = 24f; this.shape = shape; clip = true }
                .background(p.elevated, shape)
                .clickable(remember { MutableInteractionSource() }, null) {},
        ) { content() }
    }
}

/** Text size, then the presenter actions (Blank, Announcement, Show image, Clear the TV). */
@Composable
private fun ActionsPanel(
    actions: WorshipActions?,
    canShrinkText: Boolean,
    canEnlargeText: Boolean,
    onTextSmaller: () -> Unit,
    onTextLarger: () -> Unit,
    close: () -> Unit,
) {
    val p = LocalSurface.current
    Column(
        Modifier.widthIn(min = 280.dp).width(300.dp).padding(DS.Space.l),
        verticalArrangement = Arrangement.spacedBy(DS.Space.m),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DS.Space.s)) {
            Text("Text size", style = DS.Type.label, color = p.highContrastForeground, modifier = Modifier.weight(1f))
            WorshipButton(Icons.Rounded.TextDecrease, "Smaller text", BarSize, true, enabled = canShrinkText, onClick = onTextSmaller)
            WorshipButton(Icons.Rounded.TextIncrease, "Larger text", BarSize, true, enabled = canEnlargeText, onClick = onTextLarger)
        }
        if (actions != null) {
            HorizontalDivider(color = p.foreground.copy(alpha = DS.Fill.stroke))
            ActionRow(if (actions.isBlanked) "Show the words" else "Blank the TV",
                if (actions.isBlanked) Icons.Rounded.Visibility else Icons.Outlined.VisibilityOff,
                locked = actions.isLocked, on = actions.isBlanked) { close(); actions.onToggleBlank() }
            ActionRow("Announcement", Icons.Outlined.ChatBubbleOutline, locked = actions.isLocked,
                on = actions.hasAnnouncement) { close(); actions.onAnnouncement() }
            ActionRow("Show image", Icons.Outlined.Image, locked = actions.isLocked,
                on = actions.hasImage) { close(); actions.onImage() }
            if (actions.hasAnnouncement || actions.hasImage) {
                ActionRow("Clear the TV", Icons.Outlined.HighlightOff, locked = false, on = false) { close(); actions.onClear() }
            }
        }
    }
}

@Composable
private fun ActionRow(title: String, icon: ImageVector, locked: Boolean, on: Boolean, onClick: () -> Unit) {
    val p = LocalSurface.current
    val interaction = remember { MutableInteractionSource() }
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = DS.Size.hitTarget)
            .dsPress(interaction)
            .clickable(interaction, null, role = Role.Button, onClick = onClick)
            .semantics(mergeDescendants = true) {
                if (locked) stateDescription = "Needs Advent Praise Pro" else if (on) stateDescription = "On"
            },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Space.m),
    ) {
        Icon(icon, null, tint = p.highContrastForeground, modifier = Modifier.width(24.dp))
        Text(title, style = DS.Type.body.copy(fontWeight = FontWeight.Medium), color = p.highContrastForeground, modifier = Modifier.weight(1f))
        if (locked) Icon(Icons.Rounded.Lock, null, tint = p.highContrastForeground, modifier = Modifier.size(14.dp))
        else if (on) Icon(Icons.Rounded.Check, null, tint = p.tint, modifier = Modifier.size(14.dp))
    }
}

/**
 * What's showing: the number in brass beside the title, "Verse 2 of 4" and
 * the dots. From large text up the number gets its own line (with the
 * position) so the title keeps the full width. Tap it to jump to a number.
 */
@Composable
private fun HymnCard(
    number: Int,
    title: String,
    position: String,
    step: Int,
    stepCount: Int,
    isOnExternalScreen: Boolean,
    live: Boolean,
    onClick: () -> Unit,
) {
    val p = LocalSurface.current
    val stacks = LocalDensity.current.fontScale >= 1.15f
    val shape = dsShape(DS.Radius.card)
    val interaction = remember { MutableInteractionSource() }
    val description = "Hymn $number, $title. $position" + if (isOnExternalScreen) ". Also on the big screen." else ""
    val numberLabel = @Composable {
        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(DS.Space.xxs)) {
            AnimatedContent(number, transitionSpec = { fadeIn(DS.Motion.quick()) togetherWith fadeOut(DS.Motion.quick()) }, label = "card-number") {
                Text(it.toString(), style = DS.Type.display.copy(fontFeatureSettings = "tnum"), color = p.brass, maxLines = 1)
            }
            Icon(Icons.Rounded.ExpandMore, null, tint = p.brass, modifier = Modifier.padding(bottom = 8.dp).size(16.dp))
        }
    }
    val titleLabel = @Composable {
        Text(title, style = DS.Type.rowTitle, color = p.highContrastForeground, maxLines = 3, overflow = TextOverflow.Ellipsis)
    }
    val positionLabel = @Composable {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DS.Space.s)) {
            if (isOnExternalScreen) Icon(Icons.Rounded.Tv, null, tint = p.tint, modifier = Modifier.size(12.dp))
            Eyebrow(position, p.secondary)
            if (stepCount in 2..MAX_DOTS && !stacks) ProgressDots(step, stepCount)
        }
    }
    Box(
        Modifier
            .widthIn(max = DS.Space.lecternMaxWidth)
            .fillMaxWidth()
            .dsPress(interaction, live)
            .dsGlass(shape, DS.GlassDepth.Card)
            .then(if (live) Modifier.clickable(interaction, null, role = Role.Button, onClick = onClick) else Modifier)
            .clearAndSetSemantics {
                contentDescription = description
                role = Role.Button
                if (live) onClick("Opens the number pad to jump to another hymn") { onClick(); true }
            }
            .padding(horizontal = DS.Space.s + DS.Space.m, vertical = DS.Space.xs + DS.Space.s),
    ) {
        if (stacks) {
            Column(verticalArrangement = Arrangement.spacedBy(DS.Space.xxs)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    numberLabel(); Spacer(Modifier.weight(1f)); positionLabel()
                }
                titleLabel()
            }
        } else {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DS.Space.m)) {
                numberLabel()
                Column(verticalArrangement = Arrangement.spacedBy(DS.Space.xxs)) { titleLabel(); positionLabel() }
            }
        }
    }
}

/** Already said by the position label: decoration only. */
@Composable
private fun ProgressDots(step: Int, count: Int) {
    val p = LocalSurface.current
    val reduceMotion = rememberReduceMotion()
    Row(Modifier.clearAndSetSemantics {}, horizontalArrangement = Arrangement.spacedBy(DS.Space.xxs)) {
        repeat(count) { i ->
            val color by animateColorAsState(
                if (i == step) p.brass else p.secondary.copy(alpha = p.secondary.alpha * 0.45f),
                DS.Motion.adaptive(DS.Motion.quick(), reduceMotion), label = "dot",
            )
            Box(Modifier.size(5.dp).background(color, CircleShape))
        }
    }
}

/**
 * A round worship control: glass on the dark ground, or the solid tint when
 * [prominent] (next, and the TV's states that override the words). Disabled
 * reads clearly across a pew (40 %). [live] false while the controls are
 * hidden: no touches, so a tap reaches the words.
 */
@Composable
internal fun WorshipButton(
    icon: ImageVector,
    label: String,
    size: Dp,
    live: Boolean,
    enabled: Boolean = true,
    prominent: Boolean = false,
    active: Boolean = false,
    value: String = "",
    hint: String? = null,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    val p = LocalSurface.current
    val interaction = remember { MutableInteractionSource() }
    val fill = if (prominent) Modifier.background(p.tint, CircleShape) else Modifier.dsGlass(CircleShape, DS.GlassDepth.Capsule)
    val tint = when {
        prominent -> p.onTint
        active -> p.tint
        else -> p.highContrastForeground
    }
    Box(
        modifier
            .size(size)
            .graphicsLayer { alpha = if (enabled) 1f else DS.Fill.disabled }
            .dsPress(interaction, enabled && live)
            .then(fill)
            .clip(CircleShape)
            .then(if (live && enabled) Modifier.clickable(interaction, null, role = Role.Button, onClick = onClick) else Modifier)
            .clearAndSetSemantics {
                contentDescription = label
                role = Role.Button
                if (value.isNotEmpty()) stateDescription = value
                if (!enabled) disabled()
                if (live && enabled) onClick(hint) { onClick(); true }
            },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, null, tint = tint, modifier = Modifier.size(size * 0.42f))
    }
}
