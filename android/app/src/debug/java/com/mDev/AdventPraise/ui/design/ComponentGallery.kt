package com.mDev.AdventPraise.ui.design

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Share
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.mDev.AdventPraise.settings.ReadingSurface
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import com.mDev.AdventPraise.ui.theme.ReadingStyle
import com.mDev.AdventPraise.ui.theme.SurfaceGround
import com.mDev.AdventPraise.ui.theme.VesperTheme

/**
 * Every component on every surface, for design review (ComponentGallery.swift).
 * Debug builds only. The Lectern's ReaderToolbar belongs to the reader area and
 * joins the gallery when it is ported.
 */
@Composable
fun ComponentGallery(
    initialSurface: ReadingSurface = ReadingSurface.Paper,
    scrolls: Boolean = true,
) {
    var surface by remember { mutableStateOf(initialSurface) }
    var style by remember { mutableStateOf(ReadingStyle()) }
    var digits by remember { mutableStateOf("30") }
    VesperTheme(surface) {
        SurfaceGround(Modifier.fillMaxSize()) {
            Column(
                Modifier
                    .fillMaxSize()
                    .then(if (scrolls) Modifier.verticalScroll(rememberScrollState()) else Modifier)
                    .statusBarsPadding()
                    .padding(DS.Space.l),
                verticalArrangement = Arrangement.spacedBy(DS.Space.l),
            ) {
                Text("Vesper", style = DS.Type.display, color = LocalSurface.current.foreground)
                SurfacePicker(surface) { surface = it }
                Section("Reading") {
                    ChapterVerseBlock(1, listOf("Blessed assurance, Jesus is mine!", "Oh, what a foretaste of glory divine!"),
                        style = style, state = BlockState.Current)
                    ChorusBlock(listOf("This is my story, this is my song,"), style = style)
                    ChapterVerseBlock(2, listOf("Perfect submission, perfect delight,"), style = style, state = BlockState.Dimmed)
                }
                Section("Buttons") {
                    GlassButton("Primary", {}, fullWidth = true)
                    GlassButton("Secondary", {}, kind = GlassButtonKind.Secondary, fullWidth = true)
                    Row(horizontalArrangement = Arrangement.spacedBy(DS.Space.m)) {
                        GlassButton("Close", {}, icon = Icons.Rounded.Close, kind = GlassButtonKind.Icon)
                        GlassButton("New playlist", {}, icon = Icons.Rounded.Add, kind = GlassButtonKind.Icon)
                        GlassButton("Share", {}, icon = Icons.Rounded.Share, kind = GlassButtonKind.Icon)
                    }
                }
                Section("Rows") {
                    HymnRow(DSPreview.hymns[2], {}, isFavourite = true, isCurrent = true)
                    HymnRow(DSPreview.hymns[3], {}, snippet = "Rock of Ages, cleft for me", highlight = "cleft")
                }
                Section("Hymnals") {
                    LanguageTileGrid(DSPreview.hymnals.take(4)) { hymnal, m ->
                        LanguageTile(hymnal, DSPreview.access(hymnal), {}, m)
                    }
                }
                Section("Number pad") {
                    HymnNumberPad(digits, { digits = it }, DSPreview::title, {})
                }
                Section("Text") {
                    ReadingSizeControl(style, { style = it })
                    ReadingFontPicker(style, { style = it })
                }
            }
        }
    }
}

@Composable
private fun Section(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(DS.Space.s)) {
        Eyebrow(title, LocalSurface.current.secondary)
        content()
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SurfacePicker(surface: ReadingSurface, onChange: (ReadingSurface) -> Unit) {
    val p = LocalSurface.current
    SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
        ReadingSurface.entries.forEachIndexed { i, s ->
            SegmentedButton(
                selected = s == surface,
                onClick = { onChange(s) },
                shape = SegmentedButtonDefaults.itemShape(i, ReadingSurface.entries.size),
                icon = {},
                colors = SegmentedButtonDefaults.colors(activeContainerColor = p.elevated, inactiveContainerColor = p.primary(DS.Fill.inset),
                    activeContentColor = p.foreground, inactiveContentColor = p.foreground),
            ) { Text(s.label, style = DS.Type.caption, maxLines = 1) }
        }
    }
}
