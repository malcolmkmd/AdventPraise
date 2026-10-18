// OWNER: music
package com.mDev.AdventPraise.ui.player

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.SkipPrevious
import androidx.compose.material.icons.rounded.Speed
import androidx.compose.material3.Icon
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.audio.AccompanimentPlayer
import com.mDev.AdventPraise.audio.PassClock
import com.mDev.AdventPraise.audio.PlaybackPosition
import com.mDev.AdventPraise.settings.PlaybackTempo
import com.mDev.AdventPraise.ui.design.HapticEvent
import com.mDev.AdventPraise.ui.design.Haptics
import com.mDev.AdventPraise.ui.design.dsPress
import com.mDev.AdventPraise.ui.root.AppNavigator
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import com.mDev.AdventPraise.ui.theme.rememberReduceMotion
import com.mDev.AdventPraise.ui.tour.TourTarget
import com.mDev.AdventPraise.ui.tour.tourTarget

/**
 * The accompaniment's transport in the Lectern (LecternPlayerStrip): it
 * unfolds above the Lectern's row once the open hymn starts playing and
 * stays while it is paused: a scrub bar across all the verses, then Restart,
 * the verse being played and the tempo. Play / pause is the round button in
 * the row ([LecternPlayButton]). Inside the Lectern's glass: no glass of its own.
 *
 * Draws nothing while the open hymn isn't the one up in the player; the
 * reader places it under the collapsed row or the hymn tray.
 */
@Composable
fun LecternPlayer(services: AppServices, navigator: AppNavigator) {
    val playback = LecternPlayback(services)
    if (!playback.showsTransport) return
    val player = services.player
    LecternPlayerStrip(
        elapsed = player.elapsed,
        duration = player.duration,
        rate = player.tempo.rate.toDouble(),
        verseLabel = verseLabel(player.position, player.passCount),
        tempo = player.tempo,
        onSeek = player::seek,
        onRestart = { player.restart(); Haptics.play(HapticEvent.LightImpact) },
        onTempo = { step -> player.stepTempo(step); Haptics.play(HapticEvent.Selection) },
        modifier = Modifier.tourTarget(TourTarget.Transport),
    )
}

/** "Verse 2 of 4", "Chorus" for a chorus-only hymn, nothing before the first pass. */
fun verseLabel(position: PlaybackPosition?, passCount: Int): String {
    if (position == null || passCount <= 0) return ""
    if (position.verse == 0) return "Chorus"
    return "Verse ${position.pass} of $passCount"
}

/**
 * The play button's logic for the Lectern row (LecternView on iOS): whether
 * the open hymn is the player's, playing, locked behind the free plays, and
 * the row's status line. The reader's row draws [LecternPlayButton] with it.
 */
class LecternPlayback(private val services: AppServices) {
    private val player: AccompanimentPlayer get() = services.player
    private val hymn get() = services.reader.hymn
    private val hymnal get() = services.reader.hymnal

    /** The player has this hymn (and not the same number in another hymnal). */
    val isPlayersHymn: Boolean get() {
        val h = hymn ?: return false
        val book = hymnal ?: return false
        return player.isHymn(book.id, h)
    }
    val isPlaying: Boolean get() = player.isPlaying && isPlayersHymn
    /** The play button shows: the hymn has a file and audio works here. */
    val hasAccompaniment: Boolean get() = hymn?.hasAccompaniment == true && player.isAvailable
    /** The transport shows from the first play until the hymn stops or finishes. */
    val showsTransport: Boolean get() = isPlayersHymn && player.isActive && player.isAvailable
    /** Play would start a new play (the hymn isn't up in the player). */
    private val playStartsNewPlay: Boolean get() = !(isPlayersHymn && player.isActive)
    /** Play opens the paywall: the lock on the button. */
    val playIsLocked: Boolean get() = playStartsNewPlay && !services.store.isPlayerUnlocked && services.freePlays.locksNewPlay

    /**
     * What the row says under the title. [playlistProgress] is the reader's
     * "Playlist · 2 of 5" while a playlist runs.
     */
    fun statusLine(playlistProgress: String? = null): String {
        val book = hymnal ?: return ""
        if (isPlayersHymn && player.isActive) return if (player.isPlaying) "Playing · piano" else "Paused · piano"
        if (playlistProgress != null) return playlistProgress
        if (hymn?.hasAccompaniment != true) return book.name
        // A quiet word before the last free play.
        if (!services.store.isPlayerUnlocked && !services.freePlays.isTourActive && services.freePlays.allowance.isLastPlay) {
            return "1 free play left"
        }
        return "${book.name} · piano ready"
    }

    /** Play / pause the open hymn; a locked new play opens the paywall instead (no haptic then). */
    fun playTapped() {
        val h = hymn ?: return
        val book = hymnal ?: return
        val starting = !isPlaying
        if (isPlayersHymn) player.toggle() else player.start(h, book.info)
        if (starting && !player.transport.state.value.isActive) return
        Haptics.play(HapticEvent.toggle(starting))
    }
}

/**
 * The round play / pause button at the start of the Lectern row
 * (ReaderToolbar's playButton): solid tint, a brass lock badge when a play
 * would open the paywall. Folds away when the hymn has no accompaniment.
 */
@Composable
fun LecternPlayButton(services: AppServices, modifier: Modifier = Modifier) {
    val playback = LecternPlayback(services)
    LecternPlayButtonFace(
        isPlaying = playback.isPlaying,
        isLocked = playback.playIsLocked,
        hasAccompaniment = playback.hasAccompaniment,
        onClick = playback::playTapped,
        modifier = modifier.tourTarget(TourTarget.Play),
    )
}

@Composable
fun LecternPlayButtonFace(
    isPlaying: Boolean,
    isLocked: Boolean,
    hasAccompaniment: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val p = LocalSurface.current
    val reduceMotion = rememberReduceMotion()
    val interaction = remember { MutableInteractionSource() }
    val shown by animateFloatAsState(if (hasAccompaniment) 1f else 0f, DS.Motion.lectern(), label = "play-shown")
    val width = (DS.Size.hitTarget + DS.Space.s) * shown
    Box(modifier.widthIn(max = width).alpha(shown)) {
        Box(
            Modifier
                .semantics {
                    contentDescription = if (isPlaying) "Pause accompaniment" else "Play accompaniment"
                    if (isLocked) stateDescription = "Advent Praise Pro. Shows what Pro includes."
                }
                .scale(if (reduceMotion) 1f else 0.5f + 0.5f * shown)
                .dsPress(interaction, hasAccompaniment)
                .shadow(6.dp, CircleShape, clip = false, ambientColor = p.tint.copy(alpha = 0.35f), spotColor = p.tint.copy(alpha = 0.35f))
                .size(DS.Size.hitTarget)
                .clip(CircleShape)
                .background(p.tint, CircleShape)
                .clickable(interaction, indication = null, enabled = hasAccompaniment, role = Role.Button, onClick = onClick),
            contentAlignment = Alignment.Center,
        ) {
            AnimatedContent(isPlaying, transitionSpec = { fadeIn(DS.Motion.quick()) togetherWith fadeOut(DS.Motion.quick()) }, label = "play-icon") { playing ->
                Icon(if (playing) Icons.Rounded.Pause else Icons.Rounded.PlayArrow, contentDescription = null, tint = p.onTint, modifier = Modifier.size(24.dp))
            }
        }
        if (isLocked) {
            Box(
                Modifier.align(Alignment.TopStart).offset(x = DS.Size.hitTarget - 13.dp, y = (-3).dp)
                    .size(16.dp).background(p.brass, CircleShape),
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Rounded.Lock, contentDescription = null, tint = p.onTint, modifier = Modifier.size(9.dp)) }
        }
    }
}

/**
 * The strip itself, from plain values: the scrub bar with elapsed and total
 * time (at the chosen tempo), then two matching pills either side of the
 * verse, which stays centred.
 */
@Composable
fun LecternPlayerStrip(
    elapsed: Double,
    duration: Double,
    rate: Double,
    verseLabel: String,
    tempo: PlaybackTempo,
    onSeek: (Double) -> Unit,
    onRestart: () -> Unit,
    onTempo: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val p = LocalSurface.current
    Column(
        modifier.fillMaxWidth().padding(horizontal = DS.Space.panel).padding(top = DS.Space.xs),
        verticalArrangement = Arrangement.spacedBy(DS.Space.xs),
    ) {
        PlayerScrubber(elapsed, duration, rate, onSeek)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DS.Space.s)) {
            Box(Modifier.weight(1f), contentAlignment = Alignment.CenterStart) {
                PlayerPill("Restart", Icons.Rounded.SkipPrevious, "Plays from the start of verse 1", onRestart)
            }
            Text(verseLabel, style = DS.Type.caption, color = p.secondary, maxLines = 1, textAlign = TextAlign.Center)
            Box(Modifier.weight(1f), contentAlignment = Alignment.CenterEnd) {
                PlayerPill(tempo.label, Icons.Rounded.Speed, "Tempo, ${tempo.label}. Changes to the next tempo") { onTempo(1) }
            }
        }
    }
}

/** A transport control: icon and word in a quiet capsule, 44 dp tall and at least 44 dp wide. */
@Composable
private fun PlayerPill(title: String, icon: ImageVector, description: String, onClick: () -> Unit) {
    val p = LocalSurface.current
    val interaction = remember { MutableInteractionSource() }
    Row(
        Modifier
            .semantics { contentDescription = description }
            .dsPress(interaction)
            .heightIn(min = DS.Size.hitTarget)
            .widthIn(min = DS.Size.hitTarget)
            .clip(CircleShape)
            .background(p.primary(DS.Fill.inset), CircleShape)
            .clickable(interaction, indication = null, role = Role.Button, onClick = onClick)
            .padding(horizontal = DS.Space.m),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Space.xs),
    ) {
        Icon(icon, contentDescription = null, tint = p.foreground, modifier = Modifier.size(16.dp))
        Text(title, style = DS.Type.caption.copy(fontWeight = FontWeight.SemiBold), color = p.foreground, maxLines = 1)
    }
}

/** The scrub bar: dragging moves the thumb and seeks on release. Times are wall clock (÷ tempo). */
@Composable
private fun PlayerScrubber(elapsed: Double, duration: Double, rate: Double, onSeek: (Double) -> Unit) {
    val p = LocalSurface.current
    var dragging by remember { mutableStateOf<Double?>(null) }
    val shown = dragging ?: elapsed
    val digits = DS.Type.caption.copy(fontFeatureSettings = "tnum")
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DS.Space.s)) {
        Text(PassClock.clock(shown / rate), style = digits, color = p.secondary, modifier = Modifier.widthIn(min = 36.dp))
        Slider(
            value = shown.toFloat().coerceIn(0f, maxOf(duration, 1.0).toFloat()),
            onValueChange = { dragging = it.toDouble() },
            onValueChangeFinished = { dragging?.let(onSeek); dragging = null },
            valueRange = 0f..maxOf(duration, 1.0).toFloat(),
            colors = SliderDefaults.colors(
                thumbColor = p.tint,
                activeTrackColor = p.tint,
                inactiveTrackColor = p.primary(DS.Fill.stroke),
            ),
            modifier = Modifier.weight(1f).semantics {
                contentDescription = "Position"
                stateDescription = "${PassClock.clock(shown / rate)} of ${PassClock.clock(duration / rate)}"
            },
        )
        Text(PassClock.clock(duration / rate), style = digits, color = p.secondary,
            modifier = Modifier.widthIn(min = 36.dp), textAlign = TextAlign.End)
    }
}
