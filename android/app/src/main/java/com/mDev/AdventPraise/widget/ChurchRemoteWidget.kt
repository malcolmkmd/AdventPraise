package com.mDev.AdventPraise.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.datastore.preferences.core.Preferences
import androidx.glance.ColorFilter
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionSendBroadcast
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import com.mDev.AdventPraise.R
import com.mDev.AdventPraise.church.ChurchRemoteAction
import com.mDev.AdventPraise.church.ChurchWidgetState
import com.mDev.AdventPraise.church.WidgetLink
import com.mDev.AdventPraise.church.notification.ChurchRemoteReceiver

/**
 * The Church Remote (Home Screen): the hymn you're on, and while
 * presenting the verse, Previous / Next, Blank and Next hymn (Pro: they run
 * in the app's process; without Pro they open the paywall). Not presenting:
 * Present, Number and Favourites, and Hymn of the Day on the large size.
 */
class ChurchRemoteWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Responsive(WidgetSizes.all)

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val prefs = currentState<Preferences>()
            val json = prefs[WidgetStore.churchKey] ?: WidgetStore.churchJson(LocalContext.current)
            ChurchRemoteContent(ChurchWidgetState.fromJson(json) ?: ChurchWidgetState.placeholder)
        }
    }
}

class ChurchRemoteWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = ChurchRemoteWidget()
}

@Composable
internal fun ChurchRemoteContent(state: ChurchWidgetState) {
    val context = LocalContext.current
    val family = currentFamily()
    val small = family == WidgetFamily.Small
    val large = family == WidgetFamily.Large
    val gap = if (small) 6.dp else 10.dp
    val root = GlanceModifier
        .fillMaxSize()
        .appWidgetBackground()
        .background(WidgetColors.evergreen)
        .cornerRadius(22.dp)
        .padding(16.dp)
    Column(if (state.isPro && state.isPresenting) root.clickable(openLink(context, WidgetLink.Present.url)) else root) {
        Header(state, small, large)
        Spacer(GlanceModifier.defaultWeight())
        if (state.isPresenting) {
            Row(GlanceModifier.fillMaxWidth()) {
                Remote(context, state, ChurchRemoteAction.Previous, "Previous", R.drawable.ic_church_previous, enabled = state.canGoBack,
                    modifier = GlanceModifier.defaultWeight())
                Spacer(GlanceModifier.width(8.dp))
                Remote(context, state, ChurchRemoteAction.Next, "Next", R.drawable.ic_church_next, prominent = true,
                    modifier = GlanceModifier.defaultWeight())
            }
            if (!small) {
                Spacer(GlanceModifier.height(gap))
                Row(GlanceModifier.fillMaxWidth()) {
                    Remote(context, state, ChurchRemoteAction.Blank, if (state.isBlanked) "Show" else "Blank",
                        if (state.isBlanked) R.drawable.ic_church_show else R.drawable.ic_church_blank, modifier = GlanceModifier.defaultWeight())
                    Spacer(GlanceModifier.width(8.dp))
                    Remote(context, state, ChurchRemoteAction.NextHymn, "Next hymn", R.drawable.ic_church_next_hymn,
                        enabled = state.hasNextHymn, modifier = GlanceModifier.defaultWeight())
                }
            }
        } else {
            Link(context, state, WidgetLink.Present, "Present", R.drawable.ic_church_present, prominent = true,
                modifier = GlanceModifier.fillMaxWidth())
            if (!small) {
                Spacer(GlanceModifier.height(gap))
                Row(GlanceModifier.fillMaxWidth()) {
                    Link(context, state, WidgetLink.NumberPad, "Number", R.drawable.ic_church_number, modifier = GlanceModifier.defaultWeight())
                    Spacer(GlanceModifier.width(8.dp))
                    Link(context, state, WidgetLink.Favourites, "Favourites", R.drawable.ic_church_favourites, modifier = GlanceModifier.defaultWeight())
                }
            }
        }
        if (large) {
            Spacer(GlanceModifier.height(gap))
            Row(GlanceModifier.fillMaxWidth()) {
                if (state.isPresenting) {
                    Link(context, state, WidgetLink.NumberPad, "Number", R.drawable.ic_church_number, modifier = GlanceModifier.defaultWeight())
                    Spacer(GlanceModifier.width(8.dp))
                }
                Link(context, state, WidgetLink.HymnOfTheDay, "Hymn of the day", R.drawable.ic_church_sparkles, modifier = GlanceModifier.defaultWeight())
                if (state.isPresenting) {
                    Spacer(GlanceModifier.width(8.dp))
                    Link(context, state, WidgetLink.Favourites, "Favourites", R.drawable.ic_church_favourites, modifier = GlanceModifier.defaultWeight())
                }
            }
        }
    }
}

@Composable
private fun Header(state: ChurchWidgetState, small: Boolean, large: Boolean) {
    Column {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(state.hymnNumber.toString(), style = style(if (small) Title2 else Title, WidgetColors.brass, FontWeight.Medium, serif = true), maxLines = 1)
            if (state.isOnTV) {
                Spacer(GlanceModifier.width(6.dp))
                Image(ImageProvider(R.drawable.ic_church_tv), contentDescription = null, modifier = GlanceModifier.size(12.dp),
                    colorFilter = ColorFilter.tint(color(WidgetColors.brass)))
                Spacer(GlanceModifier.width(3.dp))
                Text("On TV", style = style(Caption2, WidgetColors.brass, FontWeight.Medium))
            }
        }
        Spacer(GlanceModifier.height(2.dp))
        Text(state.title, style = style(if (small) Subheadline else Headline, WidgetColors.white, serif = true), maxLines = if (large) 3 else 2)
        Spacer(GlanceModifier.height(2.dp))
        Text(if (state.isPresenting) state.position else state.hymnal, style = style(Caption, WidgetColors.white.copy(alpha = 0.75f)), maxLines = 1)
    }
}

/** Previous / Next / Blank / Next hymn: run in the app while Pro, otherwise the paywall. */
@Composable
private fun Remote(
    context: Context,
    state: ChurchWidgetState,
    action: ChurchRemoteAction,
    title: String,
    icon: Int,
    modifier: GlanceModifier,
    enabled: Boolean = true,
    prominent: Boolean = false,
) {
    val tap = if (state.isPro) actionSendBroadcast(ChurchRemoteReceiver.intent(context, action, fromWidget = true))
    else openLink(context, WidgetLink.Paywall.url)
    Pill(title, icon, tap, modifier, prominent = prominent, enabled = enabled || !state.isPro)
}

/** Opens the app (Present is Pro: the paywall otherwise). */
@Composable
private fun Link(
    context: Context,
    state: ChurchWidgetState,
    link: WidgetLink,
    title: String,
    icon: Int,
    modifier: GlanceModifier,
    prominent: Boolean = false,
) {
    val target = if (link == WidgetLink.Present && !state.isPro) WidgetLink.Paywall else link
    Pill(title, icon, openLink(context, target.url), modifier, prominent = prominent)
}
