package com.mDev.AdventPraise.ui.root

import androidx.activity.compose.PredictiveBackHandler
import androidx.compose.animation.core.Animatable
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.paneTitle
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import com.mDev.AdventPraise.ui.theme.rememberReduceMotion
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

/*
 * The presentation containers the root draws around each area's content, so
 * every sheet, cover and dialog behaves alike: in the window (one z-order, and
 * screenshot tests see them), animated in and out, with predictive back.
 */

/**
 * A large sheet (`.sheet` with a NavigationStack): the reading surface, a grabber,
 * an inline title with Done, and Back while a page is pushed. Drag the top band
 * down or press Back (predictive) to close. [showsBar] false for screens with their
 * own chrome (the paywall, Support).
 */
@Composable
fun SheetContainer(
    title: String?,
    visible: Boolean,
    onDismissRequest: () -> Unit,
    onGone: () -> Unit,
    showsBar: Boolean = true,
    onBack: (() -> Unit)? = null,
    content: @Composable () -> Unit,
) {
    val p = LocalSurface.current
    val reduceMotion = rememberReduceMotion()
    val offset = remember { Animatable(1f) }
    val scope = rememberCoroutineScope()
    val spec = DS.Motion.adaptive(DS.Motion.criticalSpring<Float>(0.4f), reduceMotion)
    LaunchedEffect(visible) {
        if (visible) offset.animateTo(0f, spec) else { offset.animateTo(1f, spec); onGone() }
    }
    PredictiveBackHandler(enabled = visible) { progress ->
        try {
            progress.collect { if (onBack == null) offset.snapTo(it.progress * 0.15f) }
            if (onBack != null) onBack() else onDismissRequest()
        } catch (e: CancellationException) {
            offset.animateTo(0f, spec)
        }
    }
    Box(Modifier.fillMaxSize()) {
        Box(
            Modifier
                .fillMaxSize()
                .graphicsLayer { alpha = 1f - offset.value }
                .background(Color.Black.copy(alpha = 0.36f))
                .clickable(remember { MutableInteractionSource() }, null, onClick = onDismissRequest),
        )
        val shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)
        Column(
            Modifier
                .align(Alignment.BottomCenter)
                .windowInsetsPadding(WindowInsets.statusBars)
                .padding(top = 10.dp)
                .widthIn(max = 700.dp)
                .fillMaxSize()
                .graphicsLayer {
                    translationY = if (reduceMotion) 0f else offset.value * size.height
                    alpha = if (reduceMotion) 1f - offset.value else 1f
                }
                .shadow(16.dp, shape)
                .clip(shape)
                .background(p.background)
                .semantics { title?.let { paneTitle = it } },
        ) {
            // The top band is the drag handle.
            Box(
                Modifier
                    .fillMaxWidth()
                    .pointerInput(Unit) {
                        detectVerticalDragGestures(
                            onVerticalDrag = { change, dy ->
                                change.consume()
                                scope.launch { offset.snapTo((offset.value + dy / size.height.coerceAtLeast(1) / 3f).coerceIn(0f, 1f)) }
                            },
                            onDragEnd = { scope.launch { if (offset.value > 0.08f) onDismissRequest() else offset.animateTo(0f, spec) } },
                            onDragCancel = { scope.launch { offset.animateTo(0f, spec) } },
                        )
                    },
            ) {
                Column {
                    Box(Modifier.fillMaxWidth().height(DS.Space.xs + 5.dp + DS.Space.xxs), contentAlignment = Alignment.BottomCenter) {
                        Box(Modifier.size(36.dp, 5.dp).background(p.primary(0.28f), RoundedCornerShape(50)))
                    }
                    if (showsBar) SheetBar(title, onBack, onDone = onDismissRequest)
                }
            }
            Box(Modifier.weight(1f).fillMaxWidth()) { content() }
        }
    }
}

/** The sheet's inline bar: Back (on a page), the title, Done. */
@Composable
private fun SheetBar(title: String?, onBack: (() -> Unit)?, onDone: () -> Unit) {
    val p = LocalSurface.current
    Box(Modifier.fillMaxWidth().heightIn(min = DS.Size.hitTarget).padding(horizontal = DS.Space.xs)) {
        if (onBack != null) {
            Box(
                Modifier
                    .align(Alignment.CenterStart)
                    .size(DS.Size.hitTarget)
                    .clip(RoundedCornerShape(50))
                    .clickable(onClick = onBack)
                    .semantics { contentDescription = "Back"; role = Role.Button },
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.AutoMirrored.Rounded.ArrowBack, null, tint = p.tint) }
        }
        if (title != null) {
            Text(
                title, style = DS.Type.label.copy(fontWeight = FontWeight.SemiBold), color = p.foreground,
                maxLines = 1, overflow = TextOverflow.Ellipsis, textAlign = TextAlign.Center,
                modifier = Modifier.align(Alignment.Center).padding(horizontal = 72.dp).semantics { heading() },
            )
        }
        Box(
            Modifier
                .align(Alignment.CenterEnd)
                .heightIn(min = DS.Size.hitTarget)
                .clip(RoundedCornerShape(50))
                .clickable(onClick = onDone)
                .padding(horizontal = DS.Space.m)
                .semantics { role = Role.Button },
            contentAlignment = Alignment.Center,
        ) { Text("Done", style = DS.Type.label.copy(fontWeight = FontWeight.SemiBold), color = p.tint) }
    }
}

/**
 * Covers the screen (`.fullScreenCover`): rises from the bottom; predictive Back
 * shrinks it a little with the gesture, then closes it.
 */
@Composable
fun FullScreenContainer(
    visible: Boolean,
    onDismissRequest: () -> Unit,
    onGone: () -> Unit,
    content: @Composable () -> Unit,
) {
    val p = LocalSurface.current
    val reduceMotion = rememberReduceMotion()
    val offset = remember { Animatable(1f) }
    val back = remember { Animatable(0f) }
    val spec = DS.Motion.adaptive(DS.Motion.criticalSpring<Float>(0.4f), reduceMotion)
    LaunchedEffect(visible) {
        if (visible) offset.animateTo(0f, spec) else { offset.animateTo(1f, spec); onGone() }
    }
    PredictiveBackHandler(enabled = visible) { progress ->
        try {
            progress.collect { back.snapTo(it.progress) }
            onDismissRequest()
            back.snapTo(0f)
        } catch (e: CancellationException) {
            back.animateTo(0f, spec)
        }
    }
    Box(
        Modifier
            .fillMaxSize()
            .graphicsLayer {
                translationY = if (reduceMotion) 0f else offset.value * size.height
                alpha = if (reduceMotion) 1f - offset.value else 1f
                val s = 1f - 0.1f * back.value
                scaleX = s; scaleY = s
                shape = RoundedCornerShape((28 * back.value).dp)
                clip = back.value > 0f
            }
            .background(p.background),
    ) { content() }
}

/** A small card over a dim (an alert or a prompt). Tapping outside or Back closes it. */
@Composable
fun DialogContainer(
    visible: Boolean,
    onDismissRequest: () -> Unit,
    onGone: () -> Unit,
    content: @Composable () -> Unit,
) {
    val p = LocalSurface.current
    val fade = remember { Animatable(0f) }
    LaunchedEffect(visible) {
        if (visible) fade.animateTo(1f, DS.Motion.quick()) else { fade.animateTo(0f, DS.Motion.quick()); onGone() }
    }
    PredictiveBackHandler(enabled = visible) { progress ->
        try { progress.collect {}; onDismissRequest() } catch (_: CancellationException) {}
    }
    Box(Modifier.fillMaxSize().graphicsLayer { alpha = fade.value }, contentAlignment = Alignment.Center) {
        Box(
            Modifier
                .fillMaxSize()
                .background(Color.Black.copy(alpha = 0.36f))
                .clickable(remember { MutableInteractionSource() }, null, onClick = onDismissRequest),
        )
        Column(
            Modifier
                .padding(DS.Space.gutter)
                .widthIn(max = 320.dp)
                .fillMaxWidth()
                .shadow(16.dp, RoundedCornerShape(DS.Radius.panel))
                .clip(RoundedCornerShape(DS.Radius.panel))
                .background(p.elevated)
                .padding(DS.Space.l),
            verticalArrangement = Arrangement.spacedBy(DS.Space.m),
        ) { content() }
    }
}

/** A row of dialog buttons, trailing, as AlertDialog lays them out. */
@Composable
fun DialogButtons(content: @Composable () -> Unit) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(DS.Space.s, Alignment.End)) { content() }
}
