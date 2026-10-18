// OWNER: extras
package com.mDev.AdventPraise.ui.extras

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.DirectionsWalk
import androidx.compose.material.icons.automirrored.rounded.MenuBook
import androidx.compose.material.icons.rounded.AccountBalance
import androidx.compose.material.icons.rounded.Book
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.material.icons.rounded.ChangeHistory
import androidx.compose.material.icons.rounded.ChatBubbleOutline
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.HourglassEmpty
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.ImportContacts
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.VolunteerActivism
import androidx.compose.material.icons.rounded.WbSunny
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.data.Hymnal
import com.mDev.AdventPraise.extras.Passage
import com.mDev.AdventPraise.ui.design.dsShape
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import com.mDev.AdventPraise.ui.theme.rememberReduceMotion

/*
 * What the extras pages are built from (DrawerPages.swift, ToolControls.swift,
 * MoreRow and HymnNumberRow on iOS): the page inset, a note, rows that lead on,
 * groups of hymns that open in the reader, a search field, the tool chip and
 * button styles, and the scripture chip.
 */

/** A page's body, inset like the drawer's root (DrawerPageLayout). */
@Composable
fun DrawerPageLayout(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier.fillMaxWidth().padding(horizontal = DS.Space.l),
        verticalArrangement = Arrangement.spacedBy(DS.Space.m),
        content = content,
    )
}

/** A secondary note under a group (DrawerNote). */
@Composable
fun DrawerNote(text: String, modifier: Modifier = Modifier) {
    Text(text, style = DS.Type.caption, color = LocalSurface.current.secondary, modifier = modifier.padding(horizontal = DS.Space.xxs))
}

/** A grouped section with an optional eyebrow (DSInsetGroup). */
@Composable
fun ExtrasGroup(title: String? = null, modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    val p = LocalSurface.current
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(DS.Space.xs)) {
        if (title != null) {
            com.mDev.AdventPraise.ui.design.Eyebrow(
                title, p.secondary,
                Modifier.padding(horizontal = DS.Space.xxs).semantics { heading() },
            )
        }
        Column(
            Modifier.fillMaxWidth().clip(dsShape(DS.Radius.tile)).background(p.primary(DS.Fill.row)),
            content = content,
        )
    }
}

/** iOS's Divider inside a group, inset from the leading edge. */
@Composable
fun RowDivider(modifier: Modifier = Modifier, inset: Dp = DS.Space.m) {
    Box(
        modifier
            .fillMaxWidth()
            .padding(start = inset)
            .height(0.5.dp)
            .background(LocalSurface.current.foreground.copy(alpha = 0.18f)),
    )
}

/** A row that leads on: icon, title, an optional detail, a chevron (MoreRow). */
@Composable
fun ExtrasRow(
    title: String,
    icon: ImageVector,
    onClick: () -> Unit,
    detail: String? = null,
    isLast: Boolean = false,
) {
    val p = LocalSurface.current
    Box {
        Row(
            Modifier
                .fillMaxWidth()
                .heightIn(min = 46.dp)
                .clickable(role = Role.Button, onClick = onClick)
                .padding(horizontal = DS.Space.m),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(DS.Space.m),
        ) {
            Box(Modifier.width(28.dp), contentAlignment = Alignment.Center) {
                Icon(icon, null, tint = p.tint, modifier = Modifier.size(20.dp))
            }
            Text(title, style = DS.Type.label, color = p.foreground, modifier = Modifier.weight(1f))
            if (detail != null) {
                Text(detail, style = DS.Type.caption, color = p.secondary, maxLines = 1, overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.widthIn(max = 180.dp), textAlign = TextAlign.End)
            }
            Icon(Icons.Rounded.ChevronRight, null, tint = p.secondary, modifier = Modifier.size(16.dp))
        }
        if (!isLast) RowDivider(Modifier.align(Alignment.BottomStart), inset = 52.dp)
    }
}

/** "12  Watchman Blow The Gospel Trumpet", or a muted row if the hymnal lacks the number (HymnNumberRow). */
@Composable
fun HymnNumberRow(hymnal: Hymnal, number: Int, modifier: Modifier = Modifier, caption: String? = null) {
    val p = LocalSurface.current
    val hymn = hymnal.hymn(number)
    Row(
        modifier.semantics(mergeDescendants = true) {},
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            number.toString(),
            style = DS.Type.body.copy(fontWeight = FontWeight.SemiBold, fontFeatureSettings = "tnum"),
            color = p.brass,
            textAlign = TextAlign.End,
            modifier = Modifier.defaultMinSize(minWidth = 36.dp),
        )
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                hymn?.title ?: "Not in ${hymnal.name}",
                style = DS.Type.body,
                color = if (hymn == null) p.secondary else p.foreground,
                maxLines = 2, overflow = TextOverflow.Ellipsis,
            )
            if (caption != null) Text(caption, style = DS.Type.caption, color = p.secondary)
        }
    }
}

/** Hymns that open in the reader, which closes the drawer or More (HymnNumberGroup). */
@Composable
fun HymnNumberGroup(title: String, hymnal: Hymnal, numbers: List<Int>, onOpen: (Int) -> Unit) {
    ExtrasGroup(title) {
        numbers.forEachIndexed { i, number ->
            Box {
                HymnNumberRow(
                    hymnal, number,
                    Modifier
                        .fillMaxWidth()
                        .heightIn(min = 46.dp)
                        .clickable(role = Role.Button) { onOpen(number) }
                        .padding(horizontal = DS.Space.m, vertical = DS.Space.xxs),
                )
                if (i != numbers.lastIndex) RowDivider(Modifier.align(Alignment.BottomStart))
            }
        }
    }
}

/** A search field for a page: the page filters as the user types (DrawerSearchField). */
@Composable
fun DrawerSearchField(prompt: String, text: String, onTextChange: (String) -> Unit) {
    val p = LocalSurface.current
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = DS.Size.hitTarget)
            .background(p.primary(DS.Fill.row), dsShape(DS.Radius.tile))
            .padding(horizontal = DS.Space.m),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Space.s),
    ) {
        Icon(Icons.Rounded.Search, null, tint = p.secondary, modifier = Modifier.size(20.dp))
        Box(Modifier.weight(1f)) {
            if (text.isEmpty()) Text(prompt, style = DS.Type.label.copy(fontWeight = FontWeight.Normal), color = p.secondary)
            BasicTextField(
                value = text,
                onValueChange = onTextChange,
                singleLine = true,
                textStyle = DS.Type.label.copy(fontWeight = FontWeight.Normal, color = p.foreground),
                cursorBrush = SolidColor(p.tint),
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.None, autoCorrectEnabled = false, imeAction = ImeAction.Search),
                modifier = Modifier.fillMaxWidth().semantics { contentDescription = prompt },
            )
        }
        if (text.isNotEmpty()) {
            Icon(
                Icons.Rounded.Cancel, "Clear", tint = p.secondary,
                modifier = Modifier.size(20.dp).clip(CircleShape).clickable(role = Role.Button) { onTextChange("") },
            )
        }
    }
}

/** Press feedback: a slight dip and dim (DSPressStyle / the tool styles' press). */
@Composable
internal fun Modifier.pressed(interaction: MutableInteractionSource, scale: Float, alpha: Float = 0.8f, enabled: Boolean = true): Modifier {
    val isPressed by interaction.collectIsPressedAsState()
    val reduce = rememberReduceMotion()
    val down = isPressed && enabled
    val s by animateFloatAsState(if (down && !reduce) scale else 1f, DS.Motion.press(), label = "press-scale")
    val a by animateFloatAsState(if (down) alpha else 1f, DS.Motion.press(), label = "press-alpha")
    return graphicsLayer { scaleX = s; scaleY = s; this.alpha = a }
}

/**
 * A selectable capsule (ToolChipStyle): verse tabs, levels, scripture. Selected:
 * solid tint with onTint text; otherwise `elevated` with a `controlBorder` outline.
 */
@Composable
fun ToolChip(
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    contentDescription: String? = null,
    content: @Composable RowScope.(color: Color) -> Unit,
) {
    val p = LocalSurface.current
    val interaction = remember { MutableInteractionSource() }
    val fill by animateColorAsState(if (isSelected) p.tint else p.elevated, DS.Motion.select(), label = "chip-fill")
    val ink by animateColorAsState(if (isSelected) p.onTint else p.foreground, DS.Motion.select(), label = "chip-ink")
    val stroke by animateColorAsState(if (isSelected) Color.Transparent else p.controlBorder, DS.Motion.select(), label = "chip-stroke")
    Row(
        modifier
            .pressed(interaction, 0.97f)
            .heightIn(min = DS.Size.hitTarget)
            .clip(CircleShape)
            .background(fill, CircleShape)
            .border(1.dp, stroke, CircleShape)
            .clickable(interaction, indication = null, role = Role.Button, onClick = onClick)
            .semantics {
                if (contentDescription != null) this.contentDescription = contentDescription
                this.selected = isSelected
            }
            .padding(horizontal = DS.Space.panel),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Space.xxs),
    ) {
        androidx.compose.runtime.CompositionLocalProvider(
            androidx.compose.material3.LocalTextStyle provides DS.Type.label.copy(color = ink),
        ) { content(ink) }
    }
}

/**
 * A full-width action (ToolButtonStyle). Prominent: solid tint, onTint label.
 * Plain: `elevated` with an outline and a tint label.
 */
@Composable
fun ToolButton(title: String, onClick: () -> Unit, modifier: Modifier = Modifier, prominent: Boolean = false, enabled: Boolean = true) {
    val p = LocalSurface.current
    val interaction = remember { MutableInteractionSource() }
    val shape = dsShape(DS.Radius.key)
    Box(
        modifier
            .fillMaxWidth()
            .pressed(interaction, 0.98f, enabled = enabled)
            .graphicsLayer { alpha = if (enabled) 1f else DS.Fill.disabled }
            .heightIn(min = DS.Size.hitTarget + 6.dp)
            .clip(shape)
            .background(if (prominent) p.tint else p.elevated, shape)
            .border(1.dp, if (prominent) Color.Transparent else p.controlBorder, shape)
            .clickable(interaction, indication = null, enabled = enabled, role = Role.Button, onClick = onClick)
            .padding(horizontal = DS.Space.m, vertical = DS.Space.xs),
        contentAlignment = Alignment.Center,
    ) {
        Text(title, style = DS.Type.button, color = if (prominent) p.onTint else p.tint, textAlign = TextAlign.Center)
    }
}

/** Left to right, wrapping onto new lines (FlowLayout). */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ExtrasFlow(
    modifier: Modifier = Modifier,
    spacing: Dp = DS.Space.xs,
    lineSpacing: Dp = DS.Space.xs,
    content: @Composable () -> Unit,
) {
    FlowRow(
        modifier,
        horizontalArrangement = Arrangement.spacedBy(spacing),
        verticalArrangement = Arrangement.spacedBy(lineSpacing),
        itemVerticalAlignment = Alignment.CenterVertically,
    ) { content() }
}

// MARK: Scripture

/** The YouVersion Bible app, which claims bible.com links. */
const val YOUVERSION_PACKAGE = "com.sirma.mobile.bible.android"

/**
 * Opens a passage's bible.com link in the YouVersion app when it's installed,
 * otherwise in the browser (on iOS, a universal link YouVersion claims).
 */
fun openBible(context: Context, url: String) {
    val uri = Uri.parse(url)
    val flags = if (context is android.app.Activity) 0 else Intent.FLAG_ACTIVITY_NEW_TASK
    val app = Intent(Intent.ACTION_VIEW, uri).setPackage(YOUVERSION_PACKAGE).addFlags(flags)
    try {
        context.startActivity(app)
    } catch (_: ActivityNotFoundException) {
        runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, uri).addCategory(Intent.CATEGORY_BROWSABLE).addFlags(flags)) }
    } catch (_: SecurityException) {
        runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, uri).addFlags(flags)) }
    }
}

/**
 * A passage as a capsule (ScriptureChip). Tapping opens it in YouVersion or on
 * bible.com; [onOpen] runs first (the caller's `scripture_opened`). Public so the
 * reader menu's About panel can use it too.
 */
@Composable
fun ScriptureChip(passage: Passage, modifier: Modifier = Modifier, isEcho: Boolean = false, title: String? = null, onOpen: () -> Unit = {}) {
    val context = LocalContext.current
    val label = title ?: passage.reference
    ToolChip(
        isSelected = false,
        onClick = {
            val url = passage.bibleUrl ?: return@ToolChip
            onOpen()
            openBible(context, url)
        },
        modifier = modifier.semantics {
            stateDescription = if (isEcho) "Echoed, not quoted" else ""
        },
        contentDescription = "$label. Opens in the Bible app",
    ) { color ->
        Icon(Icons.AutoMirrored.Rounded.MenuBook, null, tint = color, modifier = Modifier.size(15.dp))
        Text((if (isEcho) "≈ " else "") + label, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

// MARK: Text

/** "1 hymn", "12 hymns". */
fun hymnCount(count: Int): String = if (count == 1) "1 hymn" else "$count hymns"

/** The list form iOS's `.formatted(.list(type: .and))` gives: "A, B and C" (en_GB). */
fun andList(items: List<String>): String = when (items.size) {
    0 -> ""
    1 -> items[0]
    else -> items.dropLast(1).joinToString(", ") + " and " + items.last()
}

/** The closest Material symbol for an SF Symbol the extras data names. */
fun extrasIcon(symbol: String): ImageVector = when (symbol) {
    "hands.sparkles" -> Icons.Rounded.VolunteerActivism
    "triangle" -> Icons.Rounded.ChangeHistory
    "sun.max" -> Icons.Rounded.WbSunny
    "crown" -> Crown
    "flame" -> Icons.Rounded.LocalFireDepartment
    "book" -> Icons.AutoMirrored.Rounded.MenuBook
    "heart" -> Icons.Rounded.Favorite
    "building.columns" -> Icons.Rounded.AccountBalance
    "text.book.closed" -> Icons.Rounded.ImportContacts
    "hourglass" -> Icons.Rounded.HourglassEmpty
    "figure.walk" -> Icons.AutoMirrored.Rounded.DirectionsWalk
    "house" -> Icons.Rounded.Home
    "text.bubble" -> Icons.Rounded.ChatBubbleOutline
    else -> Icons.Rounded.Book
}

/** SF Symbols' crown, which Material lacks. */
val Crown: ImageVector by lazy {
    ImageVector.Builder("Crown", 24.dp, 24.dp, 24f, 24f).apply {
        path(fill = SolidColor(Color.Black)) {
            moveTo(3f, 7.5f); lineTo(7.5f, 11.5f); lineTo(12f, 4.5f); lineTo(16.5f, 11.5f); lineTo(21f, 7.5f)
            lineTo(19.2f, 17.5f); lineTo(4.8f, 17.5f); close()
            moveTo(5f, 19f); lineTo(19f, 19f); lineTo(19f, 20.8f); lineTo(5f, 20.8f); close()
        }
    }.build()
}

/** A plain text style helper for the serif reading faces the tools use (`scaledFont(size:design: .serif)`). */
internal fun serif(size: Float, weight: FontWeight = FontWeight.Normal): TextStyle =
    DS.Type.rowBody.copy(fontSize = androidx.compose.ui.unit.TextUnit(size, androidx.compose.ui.unit.TextUnitType.Sp),
        lineHeight = androidx.compose.ui.unit.TextUnit(size * 1.28f, androidx.compose.ui.unit.TextUnitType.Sp), fontWeight = weight)
