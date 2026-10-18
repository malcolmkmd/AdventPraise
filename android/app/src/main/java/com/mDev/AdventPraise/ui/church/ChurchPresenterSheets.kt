// OWNER: church
package com.mDev.AdventPraise.ui.church

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.PhotoLibrary
import androidx.compose.material.icons.rounded.Tv
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.church.display.ChurchImages
import com.mDev.AdventPraise.church.display.TvOutputState
import com.mDev.AdventPraise.church.display.TvRoute
import com.mDev.AdventPraise.church.display.TvRouteKind
import com.mDev.AdventPraise.settings.ReadingSurface
import com.mDev.AdventPraise.ui.design.GlassButton
import com.mDev.AdventPraise.ui.design.HapticEvent
import com.mDev.AdventPraise.ui.design.Haptics
import com.mDev.AdventPraise.ui.design.dsShape
import com.mDev.AdventPraise.ui.root.AppNavigator
import com.mDev.AdventPraise.ui.root.Destination
import com.mDev.AdventPraise.ui.root.SheetContainer
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import com.mDev.AdventPraise.ui.theme.SurfacePalette
import com.mDev.AdventPraise.ui.theme.VesperTheme
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Church mode's sheets, as iOS's `churchSheetStyle`: dark and opaque on the
 * worship ground, whatever the phone's appearance, with their own bar
 * (Cancel / Show, Done, Got it). The root host draws them in this container.
 */
@Composable
fun ChurchSheetContainer(visible: Boolean, onDismissRequest: () -> Unit, onGone: () -> Unit, content: @Composable () -> Unit) {
    VesperTheme(ReadingSurface.Black, worshipMode = true) {
        val black = LocalSurface.current
        // The sheet's ground is the raised black (DSSurface.black.elevated), not pure black.
        CompositionLocalProvider(LocalSurface provides black.copy(background = black.elevated)) {
            SheetContainer(title = null, visible = visible, onDismissRequest = onDismissRequest, onGone = onGone, showsBar = false) {
                content()
            }
        }
    }
}

/** A church sheet's bar: a leading and a trailing text button around the title. */
@Composable
private fun ChurchSheetBar(
    title: String,
    leading: Pair<String, () -> Unit>? = null,
    trailing: Pair<String, () -> Unit>? = null,
    trailingEnabled: Boolean = true,
) {
    val p = LocalSurface.current
    Box(Modifier.fillMaxWidth().heightIn(min = DS.Size.hitTarget).padding(horizontal = DS.Space.xs)) {
        leading?.let { (label, action) -> BarButton(label, true, FontWeight.Normal, Modifier.align(Alignment.CenterStart), action) }
        Text(
            title, style = DS.Type.label.copy(fontWeight = FontWeight.SemiBold), color = p.highContrastForeground,
            maxLines = 1, overflow = TextOverflow.Ellipsis, textAlign = TextAlign.Center,
            modifier = Modifier.align(Alignment.Center).padding(horizontal = 88.dp).semantics { heading() },
        )
        trailing?.let { (label, action) -> BarButton(label, trailingEnabled, FontWeight.SemiBold, Modifier.align(Alignment.CenterEnd), action) }
    }
}

@Composable
private fun BarButton(label: String, enabled: Boolean, weight: FontWeight, modifier: Modifier, onClick: () -> Unit) {
    val p = LocalSurface.current
    Box(
        modifier
            .heightIn(min = DS.Size.hitTarget)
            .clip(RoundedCornerShape(50))
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .padding(horizontal = DS.Space.m),
        contentAlignment = Alignment.Center,
    ) {
        Text(label, style = DS.Type.label.copy(fontWeight = weight), color = if (enabled) p.tint else p.secondary.copy(alpha = DS.Fill.disabled))
    }
}

/** An inset-grouped section on the dark sheet, with an optional header and footer. */
@Composable
private fun FormSection(header: String? = null, footer: String? = null, content: @Composable ColumnScope.() -> Unit) {
    val p = LocalSurface.current
    Column(verticalArrangement = Arrangement.spacedBy(DS.Space.xs)) {
        if (header != null) {
            Text(header, style = DS.Type.label.copy(fontWeight = FontWeight.SemiBold), color = p.highContrastForeground,
                modifier = Modifier.padding(horizontal = DS.Space.l).semantics { heading() })
        }
        Column(
            Modifier.fillMaxWidth().clip(dsShape(DS.Radius.tile)).background(p.primary(DS.Fill.hairline)),
            content = content,
        )
        if (footer != null) {
            Text(footer, style = DS.Type.detail, color = p.secondary, modifier = Modifier.padding(horizontal = DS.Space.l))
        }
    }
}

// MARK: - Announcement

/**
 * A notice for the big screen (ChurchAnnouncementSheet), with recent
 * messages. Show puts it large and centred on the TV; Clear takes it down.
 */
@Composable
fun ChurchAnnouncementSheet(services: AppServices, navigator: AppNavigator) {
    val session = services.church
    val state by session.state.collectAsState()
    val presenter = remember {
        ChurchPresenter(session, services.settings, services.appSettings, { navigator.openPaywall(it, "church_mode") }, close = {})
    }
    val dismiss = { navigator.dismiss(Destination.ChurchAnnouncement) }
    AnnouncementContent(
        current = state.announcement,
        recents = services.appSettings.announcementRecents,
        onRemoveRecent = services.appSettings::removeAnnouncement,
        onCancel = dismiss,
        onShow = { presenter.showAnnouncement(it); dismiss() },
        onClear = { presenter.clearAnnouncement(); dismiss() },
    )
}

@Composable
internal fun AnnouncementContent(
    current: String?,
    recents: List<String>,
    onRemoveRecent: (String) -> Unit,
    onCancel: () -> Unit,
    onShow: (String) -> Unit,
    onClear: () -> Unit,
    focusesField: Boolean = true,
) {
    val p = LocalSurface.current
    var text by remember { mutableStateOf(current.orEmpty()) }
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { if (focusesField) runCatching { focus.requestFocus() } }
    val trimmed = text.trim()
    Column(Modifier.fillMaxSize().imePadding()) {
        ChurchSheetBar("Announcement", leading = "Cancel" to onCancel, trailing = "Show" to { onShow(trimmed) }, trailingEnabled = trimmed.isNotEmpty())
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(DS.Space.l),
            verticalArrangement = Arrangement.spacedBy(DS.Space.l),
        ) {
            FormSection(footer = "Shows large and centred on the TV, over the blank screen or a picture.") {
                val style = TextStyle(fontFamily = FontFamily.Serif, fontSize = 20.sp, lineHeight = 25.sp, color = p.highContrastForeground)
                BasicTextField(
                    value = text,
                    onValueChange = { text = it },
                    textStyle = style,
                    cursorBrush = SolidColor(p.tint),
                    minLines = 3,
                    maxLines = 8,
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words),
                    modifier = Modifier.fillMaxWidth().focusRequester(focus).padding(horizontal = DS.Space.l, vertical = DS.Space.m),
                    decorationBox = { field ->
                        Box {
                            if (text.isEmpty()) Text("Welcome! Please silence your phones.", style = style.copy(color = p.secondary.copy(alpha = 0.6f)))
                            field()
                        }
                    },
                )
            }
            if (recents.isNotEmpty()) {
                FormSection(header = "Recent") {
                    recents.forEachIndexed { i, message ->
                        key(message) {
                            if (i > 0) HorizontalDivider(Modifier.padding(start = DS.Space.l), color = p.foreground.copy(alpha = DS.Fill.stroke))
                            RecentRow(message, onPick = { text = message }, onDelete = { onRemoveRecent(message) })
                        }
                    }
                }
            }
            if (current != null) {
                FormSection {
                    Text(
                        "Clear the announcement",
                        style = DS.Type.body,
                        color = Color(0xFFFF453A),
                        modifier = Modifier.fillMaxWidth().clickable(role = Role.Button, onClick = onClear)
                            .padding(horizontal = DS.Space.l, vertical = DS.Space.m),
                    )
                }
            }
        }
    }
}

/** A recent message: tap to use it, swipe left to delete it. */
@Composable
private fun RecentRow(message: String, onPick: () -> Unit, onDelete: () -> Unit) {
    val p = LocalSurface.current
    val dismiss = rememberSwipeToDismissBoxState()
    LaunchedEffect(dismiss.currentValue) {
        if (dismiss.currentValue == SwipeToDismissBoxValue.EndToStart) onDelete()
    }
    SwipeToDismissBox(
        dismiss,
        enableDismissFromStartToEnd = false,
        backgroundContent = {
            Box(Modifier.fillMaxSize().background(DS.Palette.destructive).padding(horizontal = DS.Space.l), contentAlignment = Alignment.CenterEnd) {
                Text("Delete", style = DS.Type.label, color = Color.White)
            }
        },
    ) {
        Text(
            message, style = DS.Type.body, color = p.highContrastForeground, maxLines = 2, overflow = TextOverflow.Ellipsis,
            modifier = Modifier.fillMaxWidth().background(p.background).clickable(onClick = onPick)
                .padding(horizontal = DS.Space.l, vertical = DS.Space.m),
        )
    }
}

// MARK: - Image

/**
 * A picture for the big screen (ChurchImageSheet): Android's photo picker
 * (no library permission), and the six recent pictures kept in the app's
 * own storage. It fills the TV on black; an announcement shows over it.
 */
@Composable
fun ChurchImageSheet(services: AppServices, navigator: AppNavigator) {
    val session = services.church
    val state by session.state.collectAsState()
    val images = services.displays.images
    val presenter = remember {
        ChurchPresenter(session, services.settings, services.appSettings, { navigator.openPaywall(it, "church_mode") }, close = {})
    }
    val dismiss = { navigator.dismiss(Destination.ChurchImage) }
    var recents by remember { mutableStateOf<List<ChurchImages.Entry>>(emptyList()) }
    var loading by remember { mutableStateOf(false) }
    var failed by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    LaunchedEffect(Unit) { recents = withContext(Dispatchers.IO) { images.recents() } }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        loading = true
        failed = false
        scope.launch {
            val entry = withContext(Dispatchers.IO) { images.add(uri) }
            loading = false
            if (entry == null) { failed = true; return@launch }
            presenter.showImage(entry.id)
            dismiss()
        }
    }
    ImageContent(
        current = state.image,
        recents = recents,
        loading = loading,
        failed = failed,
        onDone = dismiss,
        onChoose = { picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) },
        onPick = { entry -> presenter.showImage(entry.id); dismiss() },
        onClear = { presenter.clearImage(); dismiss() },
    )
}

@Composable
internal fun ImageContent(
    current: String?,
    recents: List<ChurchImages.Entry>,
    loading: Boolean,
    failed: Boolean,
    onDone: () -> Unit,
    onChoose: () -> Unit,
    onPick: (ChurchImages.Entry) -> Unit,
    onClear: () -> Unit,
) {
    val p = LocalSurface.current
    Column(Modifier.fillMaxSize()) {
        ChurchSheetBar("Show image", leading = "Done" to onDone)
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(DS.Space.l),
            verticalArrangement = Arrangement.spacedBy(DS.Space.l),
        ) {
            Row(
                Modifier.fillMaxWidth().heightIn(min = 50.dp).clip(dsShape(DS.Radius.key)).background(p.tint)
                    .clickable(role = Role.Button, onClick = onChoose).padding(horizontal = DS.Space.l),
                horizontalArrangement = Arrangement.spacedBy(DS.Space.s, Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Rounded.PhotoLibrary, null, tint = p.onTint, modifier = Modifier.size(20.dp))
                Text("Choose from Photos", style = DS.Type.label.copy(fontSize = 17.sp), color = p.onTint)
            }
            if (loading) Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = p.tint) }
            if (failed) Text("Couldn't open that picture.", style = DS.Type.detail, color = Color(0xFFFF453A))
            if (recents.isNotEmpty()) {
                Text("Recent", style = DS.Type.label.copy(fontSize = 17.sp), color = p.highContrastForeground, modifier = Modifier.semantics { heading() })
                BoxWithConstraints {
                    val columns = maxOf(1, ((maxWidth + DS.Space.s) / (100.dp + DS.Space.s)).toInt())
                    Column(verticalArrangement = Arrangement.spacedBy(DS.Space.s)) {
                        recents.chunked(columns).forEach { row ->
                            Row(horizontalArrangement = Arrangement.spacedBy(DS.Space.s)) {
                                row.forEach { entry ->
                                    val shape = RoundedCornerShape(10.dp)
                                    Image(
                                        entry.thumbnail.asImageBitmap(), contentDescription = "Recent picture",
                                        contentScale = ContentScale.Crop,
                                        modifier = Modifier.weight(1f).height(90.dp).clip(shape)
                                            .then(if (current == entry.id) Modifier.border(BorderStroke(3.dp, p.tint), shape) else Modifier)
                                            .clickable(role = Role.Button) { onPick(entry) },
                                    )
                                }
                                repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
                            }
                        }
                    }
                }
            }
            Text("The picture fills the TV on black. An announcement shows over it.", style = DS.Type.detail, color = p.secondary)
            if (current != null) {
                Text(
                    "Clear the picture", style = DS.Type.body, color = Color(0xFFFF453A),
                    modifier = Modifier.clickable(role = Role.Button, onClick = onClear).padding(vertical = DS.Space.xs),
                )
            }
        }
    }
}

// MARK: - Show on TV

/**
 * Church mode's TV button (Pro): the TVs [TvOutput] can see, and how to
 * cast the screen (ScreenMirroringHelpSheet). A second display, cabled or
 * cast from Android's Cast settings, gets the worship display at once;
 * Cast receivers (when that output lands) are picked here.
 */
@Composable
fun ScreenMirroringHelpSheet(services: AppServices, navigator: AppNavigator) {
    val tv by services.displays.tv.state.collectAsState()
    val context = LocalContext.current
    ShowOnTvContent(
        tv = tv,
        // A Cast TV in use: tapping it again stops casting (the words and the piano come back to the phone).
        onRoute = { route ->
            if (route.id == tv.connected?.id) services.displays.tv.disconnect() else services.displays.tv.select(route)
            Haptics.play(HapticEvent.Selection)
        },
        onCastSettings = { openCastSettings(context) },
        onDone = { navigator.dismiss(Destination.ScreenMirroringHelp) },
    )
}

@Composable
internal fun ShowOnTvContent(tv: TvOutputState, onRoute: (TvRoute) -> Unit, onCastSettings: () -> Unit, onDone: () -> Unit) {
    val p = LocalSurface.current
    Column(Modifier.fillMaxSize()) {
        ChurchSheetBar("Show on TV", trailing = "Got it" to onDone)
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(DS.Space.l),
            verticalArrangement = Arrangement.spacedBy(DS.Space.l),
        ) {
            if (tv.routes.isNotEmpty()) {
                FormSection(header = "TV") {
                    tv.routes.forEachIndexed { i, route ->
                        if (i > 0) HorizontalDivider(Modifier.padding(start = 56.dp), color = p.foreground.copy(alpha = DS.Fill.stroke))
                        val isOn = tv.connected?.id == route.id
                        Row(
                            Modifier.fillMaxWidth().heightIn(min = 52.dp)
                                .clickable(enabled = route.kind == TvRouteKind.Cast, role = Role.Button) { onRoute(route) }
                                .padding(horizontal = DS.Space.l),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(DS.Space.m),
                        ) {
                            Icon(Icons.Rounded.Tv, null, tint = if (isOn) p.tint else p.highContrastForeground, modifier = Modifier.size(22.dp))
                            Column(Modifier.weight(1f)) {
                                Text(route.name, style = DS.Type.body, color = p.highContrastForeground, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                if (isOn) {
                                    Text(if (tv.showsWorshipDisplay) "Showing the words" else "Connected", style = DS.Type.detail, color = p.secondary)
                                }
                            }
                            if (isOn) Icon(Icons.Rounded.Check, null, tint = p.tint, modifier = Modifier.size(18.dp))
                        }
                    }
                }
            }
            Text("For the best picture and instant verse changes, cast your screen.", style = DS.Type.body, color = p.highContrastForeground)
            Step(1, "Open Quick Settings (swipe down from the top of the screen).")
            Step(2, "Tap Cast or Screen Cast.")
            Step(3, "Choose your TV or projector.")
            Step(4, "Come back to Advent Praise. The words fill the TV, and this phone becomes the remote.")
            Text("A cable to a TV or projector works the same way.", style = DS.Type.detail, color = p.secondary)
            GlassButton("Open Cast settings", onClick = onCastSettings, kind = com.mDev.AdventPraise.ui.design.GlassButtonKind.Secondary, fullWidth = true)
        }
    }
}

@Composable
private fun Step(number: Int, text: String) {
    val p = LocalSurface.current
    Row(Modifier.semantics(mergeDescendants = true) {}, horizontalArrangement = Arrangement.spacedBy(DS.Space.m)) {
        Text("$number", style = DS.Type.label.copy(fontSize = 17.sp, fontFeatureSettings = "tnum"), color = p.highContrastForeground,
            textAlign = TextAlign.Center, modifier = Modifier.width(24.dp))
        Text(text, style = DS.Type.body, color = p.highContrastForeground)
    }
}

/** Android's Cast settings (wireless display), else the display settings. */
fun openCastSettings(context: Context) {
    val intents = listOf(Settings.ACTION_CAST_SETTINGS, Settings.ACTION_DISPLAY_SETTINGS, Settings.ACTION_SETTINGS)
    for (action in intents) {
        try {
            context.startActivity(Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            return
        } catch (_: ActivityNotFoundException) {
        } catch (_: SecurityException) {
        }
    }
}
