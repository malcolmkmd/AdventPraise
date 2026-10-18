// OWNER: extras
package com.mDev.AdventPraise.ui.extras

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.Crossfade
import androidx.compose.animation.SizeTransform
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FiniteAnimationSpec
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Lightbulb
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.Lightbulb
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.StarOutline
import androidx.compose.material.icons.rounded.TextFields
import androidx.compose.material.icons.rounded.Verified
import androidx.compose.material.icons.rounded.WorkspacePremium
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.analytics.AnalyticsScreen
import com.mDev.AdventPraise.analytics.MemoryReplay
import com.mDev.AdventPraise.extras.MemoryLevel
import com.mDev.AdventPraise.extras.MemoryProgress
import com.mDev.AdventPraise.extras.MemoryRound
import com.mDev.AdventPraise.settings.ReaderHistory
import com.mDev.AdventPraise.settings.SharedPreferencesStore
import com.mDev.AdventPraise.ui.design.Eyebrow
import com.mDev.AdventPraise.ui.design.dsShape
import com.mDev.AdventPraise.ui.root.AppNavigator
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import com.mDev.AdventPraise.ui.theme.rememberReduceMotion
import java.text.NumberFormat
import kotlin.math.PI
import kotlin.math.pow
import kotlin.math.sin

/*
 * Learn a verse by heart, as a game (MemoryGameView.swift). Some words are
 * hidden (A few, Half, Most or All, one round each); the singer fills them in
 * order by tapping the next word from four chips that could all fit. Blanks
 * give nothing away. A right word drops into place with a haptic and builds a
 * streak; every third in a row earns a hint. A wrong one shakes and is ruled
 * out. A finished stanza earns stars; finished with every word hidden, it is
 * learned by heart and the verse tab says so. Rules: MemoryRound; state and
 * actions: MemoriseGame. Memorise is free and unlimited, as on iOS.
 */

/** Memorise a verse and its word-chip game. In a sheet with Done. */
@Composable
fun MemoriseScreen(services: AppServices, navigator: AppNavigator, source: String) {
    val hymnal = services.reader.hymnal ?: return
    val hymn = services.reader.hymn ?: return
    val context = LocalContext.current
    val view = LocalView.current
    val scope = rememberCoroutineScope()
    val reduceMotion = rememberReduceMotion()
    val game = remember(hymnal.id, hymn.number) {
        MemoriseGame(
            hymn = hymn,
            chorusLabel = hymnal.chorusLabel,
            progress = MemoryProgress(SharedPreferencesStore(context, ReaderHistory.PREFS_NAME), hymnal.id, hymn.number),
            scope = scope,
            effects = MemoriseEffects.live { @Suppress("DEPRECATION") view.announceForAccessibility(it) },
            reduceMotion = reduceMotion,
        )
    }
    LaunchedEffect(game) { game.start() }
    AnalyticsScreenEffect(AnalyticsScreen.MemoryGame)
    MemoriseContent(game)
}

/** The game's whole screen, under the sheet's bar. */
@Composable
fun MemoriseContent(game: MemoriseGame, modifier: Modifier = Modifier) {
    @Suppress("UNUSED_VARIABLE") val moves = game.moves // the round is mutable: observe its moves
    val round = game.round
    val reduceMotion = rememberReduceMotion()
    Column(modifier.fillMaxSize()) {
        Box(Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()), contentAlignment = Alignment.TopCenter) {
            Column(
                Modifier.widthIn(max = 640.dp).fillMaxWidth().padding(DS.Space.l),
                verticalArrangement = Arrangement.spacedBy(DS.Space.l),
            ) {
                BlockPicker(game)
                LevelPicker(game)
                Scoreboard(game)
                Verse(game)
                AnimatedVisibility(
                    visible = round.isComplete,
                    enter = if (reduceMotion) fadeIn() else scaleIn(initialScale = 0.92f) + fadeIn(),
                    exit = if (reduceMotion) fadeOut() else scaleOut(targetScale = 0.92f) + fadeOut(),
                ) { Completion(game) }
            }
        }
        AnimatedVisibility(visible = !round.isComplete, enter = fadeIn(), exit = fadeOut()) { ChoicePanel(game) }
    }
}

// MARK: Pickers

@Composable
private fun BlockPicker(game: MemoriseGame) {
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(DS.Space.s)) {
        game.blocks.forEachIndexed { i, block ->
            val learned = game.isLearned(i)
            val name = game.name(block)
            ToolChip(
                isSelected = i == game.blockIndex,
                onClick = { game.selectBlock(i) },
                contentDescription = if (learned) "$name, learned by heart" else name,
            ) { color ->
                Text(name)
                if (learned) Icon(Icons.Rounded.CheckCircle, null, tint = color, modifier = Modifier.size(14.dp))
            }
        }
    }
}

@Composable
private fun LevelPicker(game: MemoriseGame) {
    val p = LocalSurface.current
    Column(verticalArrangement = Arrangement.spacedBy(DS.Space.xs)) {
        Eyebrow("Words hidden", p.secondary, Modifier.semantics { heading() })
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(DS.Space.s)) {
            MemoryLevel.entries.forEach { option ->
                val best = game.bestStars(option)
                val selected = option == game.level
                ToolChip(
                    isSelected = selected,
                    onClick = { game.selectLevel(option) },
                    contentDescription = if (best > 0) "${option.label} hidden, best ${if (best == 1) "1 star" else "$best stars"}" else "${option.label} hidden",
                ) {
                    Text(option.label)
                    if (best > 0) StarRow(count = best, shown = best, size = 9.dp, color = if (selected) p.onTint else p.brass)
                }
            }
        }
    }
}

// MARK: Score

@Composable
private fun Scoreboard(game: MemoriseGame) {
    val p = LocalSurface.current
    val round = game.round
    val reduceMotion = rememberReduceMotion()
    Column(
        Modifier.clearAndSetSemantics {
            contentDescription = "Score ${round.score}, streak ${round.streak}, ${round.hints} hints, ${round.filled.size} of ${round.targets.size} words found"
        },
        verticalArrangement = Arrangement.spacedBy(DS.Space.s),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DS.Space.m)) {
            Stat(round.score, "Score")
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DS.Space.xxs)) {
                Icon(
                    Icons.Rounded.LocalFireDepartment, null,
                    tint = if (round.streak >= MemoryRound.STREAK_PER_HINT) p.brass else p.secondary,
                    modifier = Modifier.size(18.dp).bounce(if (reduceMotion) 0 else round.streak),
                )
                Stat(round.streak, "Streak")
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DS.Space.xxs)) {
                Icon(
                    Icons.Rounded.Lightbulb, null,
                    tint = if (round.hints > 0) p.tint else p.secondary,
                    modifier = Modifier.size(18.dp).bounce(if (reduceMotion) 0 else round.hintsEarned),
                )
                Stat(round.hints, "Hints")
            }
            Spacer(Modifier.weight(1f))
            NumericText("${round.filled.size} of ${round.targets.size}", DS.Type.label.copy(fontFeatureSettings = "tnum"), p.secondary)
        }
        ProgressBar(round.progress)
        NoteLine(game.note)
    }
}

@Composable
private fun Stat(value: Int, label: String) {
    val p = LocalSurface.current
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DS.Space.xxs)) {
        NumericText(value.toString(), DS.Type.panelTitle.copy(fontFeatureSettings = "tnum"), p.foreground)
        // One line, whatever the score's width: "Streak", never "Strea / k".
        Text(label.uppercase(), style = DS.Type.eyebrow(), color = p.secondary, maxLines = 1, softWrap = false)
    }
}

/** A number that rolls when it changes (`.contentTransition(.numericText())`). */
@Composable
private fun NumericText(text: String, style: androidx.compose.ui.text.TextStyle, color: Color) {
    val reduceMotion = rememberReduceMotion()
    AnimatedContent(
        targetState = text,
        transitionSpec = {
            if (reduceMotion) fadeIn(DS.Motion.quick()) togetherWith fadeOut(DS.Motion.quick())
            else (slideInVertically(DS.Motion.quick()) { it / 2 } + fadeIn(DS.Motion.quick())) togetherWith
                (slideOutVertically(DS.Motion.quick()) { -it / 2 } + fadeOut(DS.Motion.quick())) using SizeTransform(clip = false)
        },
        label = "numeric",
    ) { Text(it, style = style, color = color, maxLines = 1, softWrap = false) }
}

/** A line that stays the height of one caption so nothing below jumps. */
@Composable
private fun NoteLine(note: MemoriseGame.Note?) {
    val p = LocalSurface.current
    val reduceMotion = rememberReduceMotion()
    Box(Modifier.fillMaxWidth().clip(androidx.compose.ui.graphics.RectangleShape)) {
        Text(" ", style = DS.Type.detail)
        AnimatedContent(
            targetState = note,
            contentKey = { it?.id },
            transitionSpec = {
                if (reduceMotion) fadeIn(DS.Motion.quick()) togetherWith fadeOut(DS.Motion.quick())
                else (slideInVertically(DS.Motion.quick()) { it } + fadeIn(DS.Motion.quick())) togetherWith
                    (slideOutVertically(DS.Motion.quick()) { it } + fadeOut(DS.Motion.quick()))
            },
            label = "note",
        ) { shown ->
            if (shown != null) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DS.Space.xxs)) {
                    Icon(noteIcon(shown.symbol), null, tint = p.brass, modifier = Modifier.size(15.dp))
                    Text(shown.text, style = DS.Type.detail.copy(fontWeight = FontWeight.SemiBold), color = p.brass)
                }
            }
        }
    }
}

private fun noteIcon(symbol: MemoriseGame.Note.Symbol): ImageVector = when (symbol) {
    MemoriseGame.Note.Symbol.Hint -> Icons.Rounded.Lightbulb
    MemoriseGame.Note.Symbol.Streak -> Icons.Rounded.LocalFireDepartment
    MemoriseGame.Note.Symbol.Letter -> Icons.Rounded.TextFields
}

/** A thin tint bar for the share of blanks filled. */
@Composable
private fun ProgressBar(value: Double) {
    val p = LocalSurface.current
    val reduceMotion = rememberReduceMotion()
    val fraction by animateFloatAsState(value.toFloat().coerceIn(0f, 1f), DS.Motion.adaptive(DS.Motion.quick(), reduceMotion), label = "progress")
    Box(Modifier.fillMaxWidth().height(6.dp).clip(CircleShape).background(p.controlBorder.copy(alpha = p.controlBorder.alpha * 0.35f))) {
        Box(Modifier.fillMaxWidth(fraction).height(6.dp).clip(CircleShape).background(p.tint))
    }
}

// MARK: Verse

@Composable
private fun Verse(game: MemoriseGame) {
    val round = game.round
    Column(
        Modifier.fillMaxWidth().clearAndSetSemantics { contentDescription = "${game.blockName}: ${game.spokenVerse}" },
        verticalArrangement = Arrangement.spacedBy(DS.Space.s),
    ) {
        round.lines.forEach { line ->
            ExtrasFlow(Modifier.fillMaxWidth()) {
                line.forEach { token -> Word(game, token) }
            }
        }
    }
}

@Composable
private fun Word(game: MemoriseGame, token: MemoryRound.Token) {
    val p = LocalSurface.current
    val reduceMotion = rememberReduceMotion()
    val round = game.round
    val hidden = round.isHidden(token.index)
    val drop: FiniteAnimationSpec<Float> = if (reduceMotion) tween(200) else bouncySpring(0.4f, 0.45f)
    AnimatedContent(
        targetState = hidden,
        transitionSpec = {
            val spec = drop
            if (reduceMotion) fadeIn(tween(200)) togetherWith fadeOut(tween(200))
            else if (targetState) (scaleIn(spec, 0.6f) + fadeIn()) togetherWith (scaleOut(spec, 1.4f) + fadeOut())
            else (scaleIn(spec, 1.4f) + fadeIn()) togetherWith (scaleOut(spec, 0.6f) + fadeOut()) using SizeTransform(clip = false)
        },
        label = "word",
    ) { isHidden ->
        if (isHidden) {
            BlankWord(game.blank(token), isCurrent = token.index == round.current)
        } else {
            val glowing = game.justFilled == token.index
            val glow by animateFloatAsState(if (glowing) 1f else 0f, DS.Motion.adaptive(tween(400, easing = DS.Motion.easeOut), reduceMotion), label = "glow")
            val scale by animateFloatAsState(if (glowing && !reduceMotion) 1.12f else 1f, drop, label = "pop")
            Text(
                token.text,
                style = serif(21f),
                color = p.foreground,
                modifier = Modifier
                    .graphicsLayer { scaleX = scale; scaleY = scale }
                    .drawBehind {
                        if (glow > 0f) {
                            val inset = DS.Space.xxs.toPx()
                            drawRoundRect(
                                p.brass.copy(alpha = DS.Fill.highlight * glow),
                                topLeft = androidx.compose.ui.geometry.Offset(-inset, 0f),
                                size = androidx.compose.ui.geometry.Size(size.width + inset * 2, size.height),
                                cornerRadius = CornerRadius(6.dp.toPx()),
                            )
                        }
                    },
            )
        }
    }
}

/**
 * A hidden word. The one to fill next sits in a tint wash with a firm tint
 * outline; later ones are dashed outlines. Text is full foreground on both.
 */
@Composable
private fun BlankWord(text: String, isCurrent: Boolean) {
    val p = LocalSurface.current
    Text(
        text,
        style = serif(21f),
        color = p.foreground,
        modifier = Modifier
            .drawBehind {
                val r = CornerRadius(6.dp.toPx())
                if (isCurrent) {
                    drawRoundRect(p.tint.copy(alpha = DS.Fill.tintOn), cornerRadius = r)
                    val w = 2.dp.toPx()
                    drawRoundRect(p.tint, topLeft = androidx.compose.ui.geometry.Offset(w / 2, w / 2),
                        size = androidx.compose.ui.geometry.Size(size.width - w, size.height - w), cornerRadius = r, style = Stroke(w))
                } else {
                    val w = 1.dp.toPx()
                    drawRoundRect(p.controlBorder, topLeft = androidx.compose.ui.geometry.Offset(w / 2, w / 2),
                        size = androidx.compose.ui.geometry.Size(size.width - w, size.height - w), cornerRadius = r,
                        style = Stroke(w, pathEffect = PathEffect.dashPathEffect(floatArrayOf(3.dp.toPx(), 3.dp.toPx()))))
                }
            }
            .padding(horizontal = DS.Space.xxs),
    )
}

// MARK: Choices

@Composable
private fun ChoicePanel(game: MemoriseGame) {
    val p = LocalSurface.current
    val round = game.round
    Column(
        Modifier
            .fillMaxWidth()
            .background(p.elevated)
            .drawBehind { drawRect(p.controlBorder.copy(alpha = p.controlBorder.alpha * 0.4f), size = androidx.compose.ui.geometry.Size(size.width, 1.dp.toPx())) }
            .windowInsetsPadding(WindowInsets.navigationBars)
            .padding(horizontal = DS.Space.l, vertical = DS.Space.m),
        verticalArrangement = Arrangement.spacedBy(DS.Space.m),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Which word comes next?", style = DS.Type.label, color = p.foreground, modifier = Modifier.semantics { heading() })
            Spacer(Modifier.weight(1f).widthIn(min = DS.Space.s))
            HintButton(game)
        }
        // Fresh chips for each blank.
        Crossfade(targetState = round.current, label = "chips") { _ ->
            Column(verticalArrangement = Arrangement.spacedBy(DS.Space.s)) {
                round.choices.chunked(2).forEach { pair ->
                    Row(horizontalArrangement = Arrangement.spacedBy(DS.Space.s)) {
                        pair.forEach { choice ->
                            WordChip(
                                choice,
                                isRuledOut = round.isRuledOut(choice),
                                shakes = game.shakes[choice] ?: 0,
                                modifier = Modifier.weight(1f),
                            ) { game.pick(choice) }
                        }
                        if (pair.size == 1) Spacer(Modifier.weight(1f))
                    }
                }
            }
        }
    }
}

@Composable
private fun HintButton(game: MemoriseGame) {
    val p = LocalSurface.current
    val round = game.round
    val enabled = round.canHint
    val hints = round.hints
    Row(
        Modifier
            .heightIn(min = DS.Size.hitTarget)
            .graphicsLayer { alpha = if (enabled) 1f else DS.Fill.disabled }
            .clip(dsShape(DS.Radius.chip))
            .clickable(enabled = enabled, role = Role.Button) { game.hint() }
            .semantics {
                contentDescription = "Hint"
                stateDescription = if (hints == 1) "1 left" else "$hints left"
            }
            .padding(horizontal = DS.Space.xxs),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Space.xs),
    ) {
        Box {
            Icon(Icons.Outlined.Lightbulb, null, tint = p.tint, modifier = Modifier.size(22.dp))
            Box(
                Modifier
                    .align(Alignment.TopEnd)
                    .offset(x = 10.dp, y = (-9).dp)
                    .defaultMinSize(16.dp, 16.dp)
                    .background(if (hints > 0) p.tint else p.secondary, CircleShape)
                    .padding(horizontal = 4.dp),
                contentAlignment = Alignment.Center,
            ) {
                NumericText(hints.toString(), DS.Type.caption.copy(fontWeight = FontWeight.Bold, fontFeatureSettings = "tnum", lineHeight = 14.sp), p.onTint)
            }
        }
        Spacer(Modifier.size(2.dp))
        Text("Hint", style = DS.Type.button, color = p.tint)
    }
}

/**
 * A word chip in the choice panel: the reading ground on the elevated panel,
 * with an outline. Ruled out after a wrong pick or a hint: struck through, dimmed.
 */
@Composable
private fun WordChip(text: String, isRuledOut: Boolean, shakes: Int, modifier: Modifier, onClick: () -> Unit) {
    val p = LocalSurface.current
    val reduceMotion = rememberReduceMotion()
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val shake by animateFloatAsState(shakes.toFloat(), tween(400, easing = LinearEasing), label = "shake")
    val dim by animateFloatAsState(if (isRuledOut) DS.Fill.disabled else 1f, DS.Motion.quick(), label = "ruled-out")
    val press by animateFloatAsState(if (pressed && !reduceMotion) 0.96f else 1f, DS.Motion.press(), label = "chip-press")
    val shape = dsShape(DS.Radius.key)
    val amount = if (reduceMotion) 0.dp else 9.dp
    Box(
        modifier
            .graphicsLayer {
                translationX = amount.toPx() * sin(shake * PI.toFloat() * 4)
                scaleX = press; scaleY = press
                alpha = dim
            }
            .heightIn(min = DS.Size.row)
            .clip(shape)
            .background(if (pressed) p.tint.copy(alpha = DS.Fill.tintOn) else p.background, shape)
            .border(if (pressed) 2.dp else 1.dp, if (pressed) p.tint else p.controlBorder, shape)
            .clickable(interaction, indication = null, enabled = !isRuledOut, role = Role.Button, onClick = onClick)
            .semantics {
                if (isRuledOut) stateDescription = "ruled out"
            }
            .padding(horizontal = DS.Space.m),
        contentAlignment = Alignment.Center,
    ) {
        BasicText(
            text,
            style = serif(19f, FontWeight.SemiBold).copy(
                color = p.foreground,
                textAlign = TextAlign.Center,
                textDecoration = if (isRuledOut) TextDecoration.LineThrough else null,
            ),
            maxLines = 1,
            autoSize = TextAutoSize.StepBased(minFontSize = (19 * 0.7).sp, maxFontSize = 19.sp),
        )
    }
}

// MARK: Completion

@Composable
private fun Completion(game: MemoriseGame) {
    val p = LocalSurface.current
    val reduceMotion = rememberReduceMotion()
    val round = game.round
    val level = game.level
    val learned = level == MemoryLevel.All
    val next = level.harder
    val nextBlock = if (game.blockIndex + 1 < game.blocks.size) game.blockIndex + 1 else null
    val shape = dsShape(DS.Radius.card)
    Column(
        Modifier
            .fillMaxWidth()
            .background(p.elevated, shape)
            .border(1.dp, p.controlBorder.copy(alpha = p.controlBorder.alpha * 0.5f), shape)
            .padding(DS.Space.l),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(DS.Space.m),
    ) {
        Icon(
            if (learned) Icons.Rounded.WorkspacePremium else Icons.Rounded.Verified, null,
            tint = p.brass,
            modifier = Modifier.size(52.dp).bounce(if (reduceMotion) 0 else game.starsShown),
        )
        Text(
            if (learned) "${game.blockName} learned by heart" else "${game.blockName}, round ${level.round} of 4",
            style = DS.Type.sheetTitle, color = p.foreground, textAlign = TextAlign.Center,
            modifier = Modifier.semantics { heading() },
        )
        StarRow(
            count = 3, shown = game.starsShown, size = 28.dp,
            modifier = Modifier.clearAndSetSemantics { contentDescription = if (round.stars == 1) "1 star" else "${round.stars} stars" },
        )
        Text(game.verdict, style = DS.Type.detail, color = p.secondary, textAlign = TextAlign.Center)
        Row(horizontalArrangement = Arrangement.spacedBy(DS.Space.l)) {
            Summary(round.score.toString(), "Score")
            Summary(round.bestStreak.toString(), "Best streak")
            Summary(percent(round.accuracy), "First try")
        }
        Column(verticalArrangement = Arrangement.spacedBy(DS.Space.s)) {
            if (next != null) {
                ToolButton("Next round: ${next.label.lowercase()} hidden", { game.replay(MemoryReplay.NextLevel) }, prominent = true)
            } else if (nextBlock != null) {
                ToolButton("Next: ${game.name(game.blocks[nextBlock])}", { game.replay(MemoryReplay.NextBlock) }, prominent = true)
            }
            ToolButton("Play again", { game.replay(MemoryReplay.Again) }, prominent = next == null && nextBlock == null)
            if (learned && level != MemoryLevel.Few) {
                ToolButton("Start over from a few", { game.replay(MemoryReplay.StartOver) })
            }
        }
    }
}

@Composable
private fun Summary(value: String, label: String) {
    val p = LocalSurface.current
    Column(Modifier.semantics(mergeDescendants = true) {}, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(DS.Space.hair)) {
        Text(value, style = DS.Type.panelTitle.copy(fontFeatureSettings = "tnum"), color = p.foreground)
        Eyebrow(label, p.secondary, tracking = 0.6f)
    }
}

private fun percent(value: Double): String =
    NumberFormat.getPercentInstance().apply { maximumFractionDigits = 0 }.format(value)

/** Up to three stars, [shown] of them lit (brass unless [color] says otherwise), the rest outlined. */
@Composable
private fun StarRow(count: Int, shown: Int, size: Dp, modifier: Modifier = Modifier, color: Color? = null) {
    val p = LocalSurface.current
    val reduceMotion = rememberReduceMotion()
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(size / 5)) {
        repeat(count) { i ->
            val lit = i < shown
            val scale by animateFloatAsState(if (lit || reduceMotion) 1f else 0.85f, if (reduceMotion) tween(0) else bouncySpring(0.35f, 0.4f), label = "star")
            Icon(
                if (lit) Icons.Rounded.Star else Icons.Rounded.StarOutline, null,
                tint = if (lit) color ?: p.brass else p.secondary,
                modifier = Modifier.size(size * 1.15f).graphicsLayer { scaleX = scale; scaleY = scale },
            )
        }
    }
}

// MARK: Motion

/** `.spring(duration:bounce:)`: a spring settling in about [seconds], overshooting by [bounce]. */
fun <T> bouncySpring(seconds: Float, bounce: Float): FiniteAnimationSpec<T> =
    spring(dampingRatio = 1f - bounce, stiffness = (2 * PI.toFloat() / seconds).pow(2))

/** `.symbolEffect(.bounce, value:)`: a quick pop whenever [trigger] changes (not on first show). */
@Composable
private fun Modifier.bounce(trigger: Int): Modifier {
    val scale = remember { Animatable(1f) }
    val first = remember { booleanArrayOf(true) }
    LaunchedEffect(trigger) {
        if (first[0]) { first[0] = false; return@LaunchedEffect }
        scale.animateTo(1.25f, tween(110, easing = DS.Motion.easeOut))
        scale.animateTo(1f, bouncySpring(0.3f, 0.4f))
    }
    return graphicsLayer { scaleX = scale.value; scaleY = scale.value }
}
