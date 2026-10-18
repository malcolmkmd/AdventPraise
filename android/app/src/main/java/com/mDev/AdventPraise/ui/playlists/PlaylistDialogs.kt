// OWNER: church
package com.mDev.AdventPraise.ui.playlists

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.ui.design.dsShape
import com.mDev.AdventPraise.ui.root.AppNavigator
import com.mDev.AdventPraise.ui.root.DialogButtons
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface

/**
 * New Playlist / Rename Playlist (playlistNamePrompt): a name field with
 * Create or Save. A blank name uses the placeholder ("Playlist 3", or the
 * old name). Create makes a playlist holding the open hymn and opens it in
 * the editor. The root host draws the dialog card; [onDismiss] closes it.
 */
@Composable
fun PlaylistNameDialog(services: AppServices, navigator: AppNavigator, playlistId: String?, onDismiss: () -> Unit) {
    val hymnal = services.reader.hymnal
    val book = services.playlists
    val existing = if (playlistId != null && hymnal != null) book.playlist(hymnal.id, playlistId) else null
    val placeholder = existing?.name ?: hymnal?.let { book.nextName(it.id) } ?: "Playlist 1"
    PlaylistNamePrompt(
        title = if (playlistId == null) "New Playlist" else "Rename Playlist",
        initialName = existing?.name.orEmpty(),
        placeholder = placeholder,
        confirmTitle = if (playlistId == null) "Create" else "Save",
        onCancel = onDismiss,
    ) { name ->
        if (hymnal == null) { onDismiss(); return@PlaylistNamePrompt }
        if (playlistId == null) {
            val number = services.reader.hymn?.number ?: run { onDismiss(); return@PlaylistNamePrompt }
            val created = book.create(hymnal.id, name, number)
            if (created.isFirstEver) PlaylistReveal.pending = true
            services.reader.closeLectern()
            onDismiss()
            navigator.openPlaylist(created.playlist.id)
        } else {
            book.rename(hymnal.id, playlistId, name)
            onDismiss()
        }
    }
}

/** The prompt itself, from plain values (for the screenshot tests too). */
@Composable
internal fun PlaylistNamePrompt(
    title: String,
    initialName: String,
    placeholder: String,
    confirmTitle: String,
    onCancel: () -> Unit,
    autoFocus: Boolean = true,
    onCommit: (String) -> Unit,
) {
    val p = LocalSurface.current
    var draft by rememberSaveable(stateSaver = TextFieldValue.Saver) {
        mutableStateOf(TextFieldValue(initialName, TextRange(0, initialName.length)))
    }
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { if (autoFocus) runCatching { focus.requestFocus() } }
    DialogTitle(title)
    Text("Leave it blank to use “$placeholder”.", style = DS.Type.detail, color = p.secondary,
        textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
    val field = DS.Type.body.copy(color = p.foreground)
    BasicTextField(
        value = draft,
        onValueChange = { draft = it },
        textStyle = field,
        singleLine = true,
        cursorBrush = SolidColor(p.tint),
        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Done),
        keyboardActions = KeyboardActions(onDone = { onCommit(draft.text) }),
        modifier = Modifier
            .fillMaxWidth()
            .focusRequester(focus)
            .clip(dsShape(DS.Radius.badge))
            .background(p.background)
            .border(1.dp, p.foreground.copy(alpha = DS.Fill.stroke), dsShape(DS.Radius.badge))
            .padding(horizontal = DS.Space.m, vertical = 10.dp),
        decorationBox = { inner ->
            Box {
                if (draft.text.isEmpty()) Text(placeholder, style = field.copy(color = p.secondary.copy(alpha = 0.6f)), maxLines = 1)
                inner()
            }
        },
    )
    DialogButtons {
        DialogButton("Cancel", onClick = onCancel)
        DialogButton(confirmTitle, bold = true) { onCommit(draft.text) }
    }
}

/**
 * Delete “name”? The hymns stay in the hymnal; only this playlist is
 * removed. Delete also closes the playlist's editor if it's open.
 */
@Composable
fun PlaylistDeleteDialog(services: AppServices, navigator: AppNavigator, playlistId: String, onDismiss: () -> Unit) {
    val hymnal = services.reader.hymnal
    val list = hymnal?.let { services.playlists.playlist(it.id, playlistId) }
    // Kept while the card fades, after the playlist is gone.
    val name = remember { list?.name.orEmpty() }
    PlaylistDeletePrompt(name, onCancel = onDismiss) {
        PlaylistEditorModel(services.playlists, services.queue, { hymnal?.id }, playlistId).delete()
        onDismiss()
        navigator.dismiss(com.mDev.AdventPraise.ui.root.Destination.PlaylistEditor(playlistId))
    }
}

@Composable
internal fun PlaylistDeletePrompt(name: String, onCancel: () -> Unit, onDelete: () -> Unit) {
    val p = LocalSurface.current
    DialogTitle("Delete “$name”?")
    Text("The hymns stay in the hymnal; only this playlist is removed.", style = DS.Type.detail, color = p.secondary,
        textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
    DialogButtons {
        DialogButton("Cancel", onClick = onCancel)
        DialogButton("Delete", bold = true, color = DS.Palette.destructive, onClick = onDelete)
    }
}

@Composable
private fun DialogTitle(text: String) {
    Text(
        text, style = DS.Type.label.copy(fontWeight = FontWeight.SemiBold, fontSize = DS.Type.body.fontSize),
        color = LocalSurface.current.foreground, textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth().semantics { heading() },
    )
}

@Composable
private fun DialogButton(title: String, bold: Boolean = false, color: Color? = null, onClick: () -> Unit) {
    val p = LocalSurface.current
    Box(
        Modifier
            .heightIn(min = DS.Size.hitTarget)
            .clip(dsShape(DS.Radius.badge))
            .clickable(role = Role.Button, onClick = onClick)
            .padding(horizontal = DS.Space.m),
        contentAlignment = Alignment.Center,
    ) {
        Text(title, style = DS.Type.label.copy(fontWeight = if (bold) FontWeight.SemiBold else FontWeight.Normal), color = color ?: p.tint)
    }
}

