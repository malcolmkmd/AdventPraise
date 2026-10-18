package com.mDev.AdventPraise.widget

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.ColorFilter
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalSize
import androidx.glance.action.Action
import androidx.glance.action.clickable
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontFamily
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.mDev.AdventPraise.MainActivity

/** The widgets' and the Live Activity's evergreen and brass (AdventPraiseWidgets.swift). */
internal object WidgetColors {
    val evergreen = Color(0xFF12332A)
    val brass = Color(0xFFD6AD61)
    val white = Color.White
}

/** WidgetKit's families, from the size Glance lays out for. */
internal enum class WidgetFamily { Small, Medium, Large }

/** The three sizes the widgets are laid out for (systemSmall, systemMedium, systemLarge). */
internal object WidgetSizes {
    val small = DpSize(120.dp, 120.dp)
    val medium = DpSize(250.dp, 120.dp)
    val large = DpSize(250.dp, 250.dp)
    val all = setOf(small, medium, large)
}

@Composable
internal fun currentFamily(): WidgetFamily {
    val size = LocalSize.current
    return when {
        size.width < 200.dp -> WidgetFamily.Small
        size.height >= 220.dp -> WidgetFamily.Large
        else -> WidgetFamily.Medium
    }
}

internal fun color(c: Color) = ColorProvider(c)

/** iOS text styles at the default size, in the widget's own faces. */
internal fun style(size: TextUnit, color: Color, weight: FontWeight = FontWeight.Normal, serif: Boolean = false) =
    TextStyle(color = color(color), fontSize = size, fontWeight = weight, fontFamily = if (serif) FontFamily.Serif else null)

internal val Title = 28.sp
internal val Title2 = 22.sp
internal val Headline = 17.sp
internal val Subheadline = 15.sp
internal val Body = 17.sp
internal val Footnote = 13.sp
internal val Caption = 12.sp
internal val Caption2 = 11.sp

/** Opens the app on an `adventpraise://` link (a widget link, or a hymn). */
internal fun openLink(context: Context, url: String): Action =
    actionStartActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).setClass(context, MainActivity::class.java))

/**
 * A capsule button: icon and label, brass when prominent, else white at
 * 22 %; disabled reads at 40 % and takes no taps.
 */
@Composable
internal fun Pill(
    title: String,
    icon: Int,
    action: Action?,
    modifier: GlanceModifier = GlanceModifier,
    prominent: Boolean = false,
    enabled: Boolean = true,
) {
    val fill = if (prominent) WidgetColors.brass else WidgetColors.white.copy(alpha = 0.22f)
    val ink = (if (prominent) WidgetColors.evergreen else WidgetColors.white).let { if (enabled) it else it.copy(alpha = 0.4f) }
    Row(
        modifier
            .background(if (enabled) fill else fill.copy(alpha = fill.alpha * 0.6f))
            .cornerRadius(50.dp)
            .padding(horizontal = 8.dp, vertical = 7.dp)
            .let { if (enabled && action != null) it.clickable(action) else it },
        verticalAlignment = Alignment.CenterVertically,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Image(ImageProvider(icon), contentDescription = null, modifier = GlanceModifier.size(14.dp), colorFilter = ColorFilter.tint(color(ink)))
        Spacer(GlanceModifier.width(4.dp))
        Text(title, style = style(Footnote, ink, FontWeight.Medium), maxLines = 1)
    }
}

internal fun Dp.orZero(): Dp = if (value.isNaN()) 0.dp else this
