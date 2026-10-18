// OWNER: music
package com.mDev.AdventPraise.ui.pitchpipe

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.VolumeUp
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.Remove
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.analytics.AnalyticsScreen
import com.mDev.AdventPraise.analytics.PitchPipeAction
import com.mDev.AdventPraise.audio.PitchPipePlayer
import com.mDev.AdventPraise.extras.Pitch
import com.mDev.AdventPraise.extras.PitchNotes
import com.mDev.AdventPraise.extras.StartingNote
import com.mDev.AdventPraise.settings.ReadingSettings
import com.mDev.AdventPraise.settings.SharedPreferencesStore
import com.mDev.AdventPraise.ui.design.Eyebrow
import com.mDev.AdventPraise.ui.design.HapticEvent
import com.mDev.AdventPraise.ui.design.Haptics
import com.mDev.AdventPraise.ui.design.dsPress
import com.mDev.AdventPraise.ui.design.dsShape
import com.mDev.AdventPraise.ui.root.AppNavigator
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import com.mDev.AdventPraise.ui.theme.rememberReduceMotion

/**
 * The pitch pipe (PitchPipeView): the hymn's starting note (the hymnal's,
 * or the singer's own), one big button to sound it, and a chromatic
 * keyboard to choose. A page in More (with [hymnNumber] from a service plan)
 * or in About this hymn; the container draws the title. Free, as on iOS.
 */
@Composable
fun PitchPipeScreen(services: AppServices, navigator: AppNavigator, hymnNumber: Int?) {
    val hymnal = services.reader.hymnal
    val hymn = hymnNumber?.let { hymnal?.hymn(it) } ?: services.reader.hymn
    if (hymnal == null || hymn == null) return
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val notes = remember { PitchNotes(services.catalogs.assets, SharedPreferencesStore(context, ReadingSettings.PREFS_NAME)) }
    val pipe = remember { PitchPipePlayer(scope) }
    val published = remember(hymnal.id, hymn.number) { notes.published(hymnal.id, hymn.number) }
    var chosen by remember(hymnal.id, hymn.number) { mutableStateOf(notes.custom(hymnal.id, hymn.number)) }
    var octave by remember(hymnal.id, hymn.number) {
        mutableIntStateOf((chosen ?: published?.midi)?.let { it / 12 - 1 } ?: 4)
    }
    DisposableEffect(Unit) { onDispose { pipe.shutdown() } }
    LaunchedEffect(Unit) { Analytics.screen(AnalyticsScreen.PitchPipe) }

    fun choose(midi: Int?) {
        chosen = midi
        notes.setCustom(midi, hymnal.id, hymn.number)
    }

    PitchPipeContent(
        hymnNumber = hymn.number,
        title = hymn.title,
        published = published,
        chosen = chosen,
        sounding = pipe.sounding,
        octave = octave,
        onOctave = { octave = it.coerceIn(Pitch.OCTAVES) },
        onSound = { note ->
            if (pipe.sounding == note) pipe.stop() else {
                pipe.play(note)
                Analytics.track(AnalyticsEvent.PitchPipeUsed(if (chosen != null) PitchPipeAction.CustomNote else PitchPipeAction.PublishedNote))
            }
            Haptics.play(HapticEvent.MediumImpact)
        },
        onKey = { midi ->
            choose(midi)
            pipe.play(midi)
            Haptics.play(HapticEvent.Selection)
            Analytics.track(AnalyticsEvent.PitchPipeUsed(PitchPipeAction.KeyChosen))
        },
        onUseHymnalNote = { choose(null) },
    )
}

/** The pitch pipe's face, from plain values (also the screenshot tests'). */
@Composable
fun PitchPipeContent(
    hymnNumber: Int,
    title: String,
    published: StartingNote?,
    chosen: Int?,
    sounding: Int?,
    octave: Int,
    onOctave: (Int) -> Unit,
    onSound: (Int) -> Unit,
    onKey: (Int) -> Unit,
    onUseHymnalNote: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val p = LocalSurface.current
    val publishedMidi = published?.midi
    // The singer's choice wins over the published note.
    val note = chosen ?: publishedMidi
    Box(modifier.fillMaxSize().verticalScroll(rememberScrollState()), contentAlignment = Alignment.TopCenter) {
        Column(
            Modifier.widthIn(max = 520.dp).fillMaxWidth().padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Eyebrow("Hymn $hymnNumber", p.secondary, tracking = 1.2f)
                Text(title, style = DS.Type.sheetTitle, color = p.foreground, textAlign = TextAlign.Center)
                val key = published?.key
                val line = when {
                    !key.isNullOrEmpty() -> "Key of $key"
                    publishedMidi == null -> "No starting note on file for this hymn. Choose one below and it will be remembered."
                    else -> null
                }
                if (line != null) {
                    Text(line, style = DS.Type.detail.copy(fontSize = 14.sp, lineHeight = 19.sp), color = p.secondary, textAlign = TextAlign.Center)
                }
            }
            SoundButton(note = note, isCustom = chosen != null, sounding = sounding != null, onSound = onSound)
            Keyboard(note = note, octave = octave, onOctave = onOctave, onKey = onKey)
            if (chosen != null && publishedMidi != null) {
                Box(
                    Modifier.heightIn(min = DS.Size.hitTarget).clip(RoundedCornerShape(DS.Radius.key))
                        .clickable(role = Role.Button, onClick = onUseHymnalNote).padding(horizontal = DS.Space.m),
                    contentAlignment = Alignment.Center,
                ) { Text("Use the hymnal’s note", style = DS.Type.button, color = p.tint) }
            }
        }
    }
}

@Composable
private fun SoundButton(note: Int?, isCustom: Boolean, sounding: Boolean, onSound: (Int) -> Unit) {
    val p = LocalSurface.current
    val interaction = remember { MutableInteractionSource() }
    // Solid tint with onTint; with no note yet, an outlined circle with full-contrast text.
    val ink = if (note == null) p.foreground else p.onTint
    val reduceMotion = rememberReduceMotion()
    // The speaker's waves breathe while the note sounds (iOS's variable-colour effect).
    val pulse = if (sounding && !reduceMotion) {
        rememberInfiniteTransition(label = "pipe").animateFloat(1f, 0.45f, infiniteRepeatable(tween(600), RepeatMode.Reverse), label = "pulse").value
    } else 1f
    Column(
        Modifier
            .semantics { contentDescription = note?.let { "Sound ${Pitch.name(it)}" } ?: "No note chosen" }
            .dsPress(interaction, note != null)
            .size(180.dp)
            .clip(CircleShape)
            .background(if (note == null) p.elevated else p.tint, CircleShape)
            .border(1.5.dp, if (note == null) p.controlBorder else Color.Transparent, CircleShape)
            .clickable(interaction, indication = null, enabled = note != null, role = Role.Button) { note?.let(onSound) },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterVertically),
    ) {
        Icon(
            if (sounding) Icons.AutoMirrored.Rounded.VolumeUp else Icons.Rounded.MusicNote,
            contentDescription = null, tint = ink, modifier = Modifier.size(34.dp).alpha(pulse),
        )
        Text(note?.let(Pitch::name) ?: "—", color = ink,
            style = DS.Type.display.copy(fontFamily = FontFamily.Serif, fontWeight = FontWeight.Bold, fontSize = 34.sp, lineHeight = 40.sp))
        Text(
            (if (note == null) "Choose a note" else if (isCustom) "Your note" else "Starting note").uppercase(),
            color = ink, style = DS.Type.caption.copy(fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp),
        )
    }
}

@Composable
private fun Keyboard(note: Int?, octave: Int, onOctave: (Int) -> Unit, onKey: (Int) -> Unit) {
    val p = LocalSurface.current
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("CHOOSE A NOTE", color = p.secondary, modifier = Modifier.semantics { heading() },
                style = DS.Type.caption.copy(fontSize = 13.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp))
            Spacer(Modifier.weight(1f))
            OctaveStepper(octave, onOctave)
        }
        for (row in 0 until 3) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for (column in 0 until 4) {
                    val semitone = row * 4 + column
                    val midi = (octave + 1) * 12 + semitone
                    NoteKey(Pitch.names[semitone], Pitch.name(midi), note == midi, Modifier.weight(1f)) { onKey(midi) }
                }
            }
        }
    }
}

/** "Octave 4  [−|+]", as iOS's Stepper draws it. */
@Composable
private fun OctaveStepper(octave: Int, onOctave: (Int) -> Unit) {
    val p = LocalSurface.current
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DS.Space.s)) {
        Text("Octave $octave", style = DS.Type.detail.copy(fontSize = 14.sp), color = p.foreground)
        Row(
            Modifier.clip(RoundedCornerShape(9.dp)).background(p.primary(DS.Fill.inset)),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            StepperHalf(Icons.Rounded.Remove, "Lower octave", octave > Pitch.OCTAVES.first) { onOctave(octave - 1) }
            Box(Modifier.size(width = 1.dp, height = 18.dp).background(p.primary(DS.Fill.stroke)))
            StepperHalf(Icons.Rounded.Add, "Higher octave", octave < Pitch.OCTAVES.last) { onOctave(octave + 1) }
        }
    }
}

@Composable
private fun StepperHalf(icon: ImageVector, label: String, enabled: Boolean, onClick: () -> Unit) {
    val p = LocalSurface.current
    Box(
        Modifier.size(width = 47.dp, height = 32.dp)
            .semantics { contentDescription = label }
            .clickable(enabled = enabled, role = Role.Button) { Haptics.play(HapticEvent.Selection); onClick() },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = if (enabled) p.foreground else p.primary(DS.Fill.disabled), modifier = Modifier.size(18.dp))
    }
}

/** One key: selected is solid tint with onTint; otherwise elevated with an outline. */
@Composable
private fun NoteKey(name: String, spoken: String, isSelected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val p = LocalSurface.current
    val interaction = remember { MutableInteractionSource() }
    val fill by animateColorAsState(if (isSelected) p.tint else p.elevated, DS.Motion.select(), label = "key")
    val shape = dsShape(DS.Radius.key)
    Box(
        modifier
            .semantics { contentDescription = spoken; selected = isSelected }
            .dsPress(interaction)
            .heightIn(min = 48.dp)
            .clip(shape)
            .background(fill, shape)
            .border(1.dp, if (isSelected) Color.Transparent else p.controlBorder, shape)
            .clickable(interaction, indication = null, role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(name, color = if (isSelected) p.onTint else p.foreground,
            style = DS.Type.rowTitle.copy(fontSize = 18.sp, lineHeight = 23.sp))
    }
}
