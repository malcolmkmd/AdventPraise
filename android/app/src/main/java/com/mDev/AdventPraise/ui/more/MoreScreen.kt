// OWNER: shell
package com.mDev.AdventPraise.ui.more

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.TouchApp
import androidx.compose.material.icons.outlined.FilterNone
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.automirrored.outlined.MenuBook
import androidx.compose.material.icons.outlined.Layers
import androidx.compose.material.icons.automirrored.outlined.Send
import com.mDev.AdventPraise.ui.design.Glyphs
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.Lightbulb
import androidx.compose.material.icons.outlined.PanTool
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material.icons.rounded.FormatListNumbered
import androidx.compose.material.icons.rounded.Repeat
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.BuildConfig
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.analytics.AnalyticsScreen
import com.mDev.AdventPraise.analytics.ExternalLink
import com.mDev.AdventPraise.analytics.FeatureBoardConfig
import com.mDev.AdventPraise.analytics.ToggleSetting
import com.mDev.AdventPraise.analytics.ToolSource
import com.mDev.AdventPraise.billing.Entitlements
import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.extras.ExtraSheet
import com.mDev.AdventPraise.extras.Pitch
import com.mDev.AdventPraise.extras.PitchNotes
import com.mDev.AdventPraise.settings.ReadingSettings
import com.mDev.AdventPraise.settings.SharedPreferencesStore
import com.mDev.AdventPraise.ui.design.InsetGroup
import com.mDev.AdventPraise.ui.root.AppNavigator
import com.mDev.AdventPraise.ui.root.LocalAppNavigator
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import com.mDev.AdventPraise.ui.tour.TourTarget
import com.mDev.AdventPraise.ui.tour.tourTarget

/*
 * More (MoreSheet.swift), a sheet with its own pages: the Pro card on top,
 * then reading switches (and Haptics, church mode and Replay tour), tools, the
 * feature board, support and about (with the Share anonymous usage switch).
 * Opened from the More tile in the Lectern's hymn tray. The tools, About
 * Advent Praise, the Privacy Policy and the Terms of Use push inside More
 * under its bar: Back pops, Done closes More from any depth. Support Advent
 * Praise and Vote on features open as sheets over More. Church mode, the tour
 * and the Pro paywall close More first and open once it has gone. There is no
 * email: the app has no contact address. Translation, theme and text are in
 * the reader menu; About this hymn there too, Memorise in the tray.
 */

/** Where Recommend and Rate lead: Advent Praise on Google Play. */
const val PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=com.mDev.AdventPraise"
/** AppInfo.shareText. */
const val SHARE_TEXT = "Advent Praise — Christ In Song in 9 languages."

/** The Tools rows, in order (ExtraSheet.toolsOrder). */
val MoreTools = listOf(ExtraSheet.Scripture, ExtraSheet.Collections, ExtraSheet.Pitch, ExtraSheet.Planner)

/** What More's rows do. The app wires them to the navigator; screenshots pass nothing. */
class MoreActions(
    val onSeePro: () -> Unit = {},
    val onManageSubscription: () -> Unit = {},
    val onChurchMode: () -> Unit = {},
    val onReplayTour: () -> Unit = {},
    val onTool: (ExtraSheet) -> Unit = {},
    val onFeatureBoard: () -> Unit = {},
    val onSupport: () -> Unit = {},
    val onRecommend: () -> Unit = {},
    val onRate: () -> Unit = {},
    val onAboutApp: () -> Unit = {},
    val onPrivacy: () -> Unit = {},
    val onTerms: () -> Unit = {},
)

/** More's root page (Destination.More), under the sheet's "More" bar with Done. */
@Composable
fun MoreScreen(services: AppServices) {
    val navigator = LocalAppNavigator.current
    val context = LocalContext.current
    val store = services.store
    val reader = services.reader
    val settings = services.settings
    val pitchNotes = remember { PitchNotes(services.catalogs.assets, SharedPreferencesStore(context, ReadingSettings.PREFS_NAME)) }
    val hymnal = reader.hymnal?.info?.id
    val number = reader.hymn?.number
    val pitch = if (hymnal != null && number != null) pitchNotes.note(hymnal, number)?.let(Pitch::name) else null

    MoreContent(
        entitlements = store.entitlements,
        freePlaysLeft = services.freePlays.remaining,
        repeatChorus = settings.repeatChorus,
        onRepeatChorus = { settings.updateRepeatChorus(it); Analytics.track(AnalyticsEvent.SettingChanged(ToggleSetting.RepeatChorus, it)) },
        haptics = settings.haptics,
        onHaptics = { settings.updateHaptics(it); Analytics.track(AnalyticsEvent.SettingChanged(ToggleSetting.Haptics, it)) },
        sharesUsage = Analytics.isEnabled,
        onSharesUsage = { Analytics.isEnabled = it },
        pitchDetail = pitch,
        showsFeatureBoard = FeatureBoardConfig.isEnabled,
        actions = moreActions(navigator, context, store.manageSubscriptionUrl),
    )
}

private fun moreActions(navigator: AppNavigator, context: Context, manageUrl: String) = MoreActions(
    // Pro first; the paywall opens once More has gone.
    onSeePro = { navigator.leaveMore { navigator.openPaywall(ProFeature.Support, "reader") } },
    onManageSubscription = { context.openUrl(manageUrl) },
    onChurchMode = { navigator.openChurchMode("more") },
    // The onboarding tour again, over the reader once More has gone.
    onReplayTour = { navigator.leaveMore { navigator.openTour("more") } },
    onTool = { tool ->
        Analytics.track(AnalyticsEvent.ToolOpened(tool, ToolSource.More))
        when (tool) {
            ExtraSheet.Scripture -> navigator.openScriptureIndex()
            ExtraSheet.Collections -> navigator.openCollections()
            ExtraSheet.Pitch -> navigator.openPitchPipe()
            ExtraSheet.Planner -> navigator.openServicePlanner()
            else -> Unit
        }
    },
    onFeatureBoard = { navigator.openFeatureBoard() },
    // The tips, for everyone, in a sheet like the paywall's; closing it comes back here.
    onSupport = { navigator.openSupport() },
    onRecommend = {
        Analytics.track(AnalyticsEvent.ShareOpened)
        Analytics.screen(AnalyticsScreen.Share)
        val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, "$SHARE_TEXT\n$PLAY_STORE_URL")
        runCatching { context.startActivity(Intent.createChooser(send, null).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
    },
    onRate = {
        Analytics.track(AnalyticsEvent.ExternalLinkOpened(ExternalLink.RateApp))
        val market = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=${context.packageName}")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try { context.startActivity(market) } catch (_: ActivityNotFoundException) { context.openUrl(PLAY_STORE_URL) }
    },
    onAboutApp = { navigator.openAboutApp() },
    // The policy (the MIDI files' credit is in it), then the terms.
    onPrivacy = { navigator.openPrivacy() },
    onTerms = { navigator.openTerms() },
)

private fun Context.openUrl(url: String) {
    runCatching { startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
}

/** More's root on plain values (previews and screenshots). */
@Composable
fun MoreContent(
    entitlements: Entitlements,
    freePlaysLeft: Int,
    repeatChorus: Boolean,
    onRepeatChorus: (Boolean) -> Unit,
    haptics: Boolean,
    onHaptics: (Boolean) -> Unit,
    sharesUsage: Boolean,
    onSharesUsage: (Boolean) -> Unit,
    pitchDetail: String?,
    showsFeatureBoard: Boolean,
    actions: MoreActions,
    modifier: Modifier = Modifier,
) {
    val p = LocalSurface.current
    // Also on the way back from a page: the root is visited again.
    LaunchedEffect(Unit) { Analytics.screen(AnalyticsScreen.More) }
    Box(modifier.fillMaxSize().verticalScroll(rememberScrollState()), contentAlignment = Alignment.TopCenter) {
        Column(
            Modifier
                .widthIn(max = DS.Space.lecternMaxWidth)
                .fillMaxWidth()
                .padding(horizontal = DS.Space.l, vertical = DS.Space.m)
                .windowInsetsPadding(WindowInsets.navigationBars),
            verticalArrangement = Arrangement.spacedBy(DS.Space.m),
        ) {
            com.mDev.AdventPraise.ui.design.Eyebrow("Advent Praise ${BuildConfig.VERSION_NAME}", p.secondary,
                Modifier.padding(horizontal = DS.Space.xxs), tracking = 0.9f)

            // Pro first: one row, the free plays left or thanks.
            ProMoreCard(entitlements, freePlaysLeft, actions.onSeePro, actions.onManageSubscription,
                Modifier.tourTarget(TourTarget.ProCard))

            // Translation, theme and text are in the reader menu (the globe).
            InsetGroup(title = "Reading") {
                MoreToggleRow("Chorus after every verse", Icons.Rounded.Repeat, repeatChorus, onRepeatChorus)
                MoreToggleRow("Haptics", Icons.Outlined.TouchApp, haptics, onHaptics)
                MoreRow("Church mode", Icons.Outlined.FilterNone, detail = "One verse at a time", onClick = actions.onChurchMode)
                MoreRow("Replay tour", Icons.Outlined.AutoAwesome, detail = "8 short steps", isLast = true, onClick = actions.onReplayTour)
            }
            InsetGroup(title = "Tools") {
                MoreTools.forEach { tool ->
                    MoreRow(
                        toolTitle(tool), toolIcon(tool),
                        detail = when (tool) {
                            ExtraSheet.Collections -> "Worship, Gospel…"
                            ExtraSheet.Pitch -> pitchDetail
                            else -> null
                        },
                        isLast = tool == MoreTools.last(),
                    ) { actions.onTool(tool) }
                }
            }
            // No email: requests and corrections go to the board, when there is one.
            if (showsFeatureBoard) {
                InsetGroup(title = "Help us improve") {
                    MoreRow("Vote on features", Icons.Outlined.Lightbulb, detail = "Or request one", isLast = true, onClick = actions.onFeatureBoard)
                }
            }
            InsetGroup(title = "Support") {
                MoreRow("Support Advent Praise", Icons.Outlined.FavoriteBorder, detail = "Leave a tip",
                    modifier = Modifier.tourTarget(TourTarget.SupportRow), onClick = actions.onSupport)
                MoreRow("Recommend Advent Praise", Icons.AutoMirrored.Outlined.Send, onClick = actions.onRecommend)
                MoreRow("Rate on Google Play", Icons.Outlined.StarOutline, isLast = true, onClick = actions.onRate)
            }
            InsetGroup(title = "About") {
                MoreRow("About Advent Praise", Icons.Outlined.Info, detail = BuildConfig.VERSION_NAME, onClick = actions.onAboutApp)
                MoreRow("Privacy Policy", Icons.Outlined.PanTool, onClick = actions.onPrivacy)
                MoreRow("Terms of Use", Icons.Outlined.Description, onClick = actions.onTerms)
                MoreToggleRow("Share anonymous usage", Icons.Outlined.BarChart, sharesUsage, onSharesUsage, isLast = true)
            }
            Text(
                "Anonymous usage is a count of which features are used, so we know what to improve. It never includes your name, the words of hymns or what you search for.",
                style = DS.Type.caption, color = p.secondary,
                modifier = Modifier.padding(horizontal = DS.Space.xxs).padding(top = 0.dp),
            )
        }
    }
}

private fun toolTitle(tool: ExtraSheet): String = when (tool) {
    ExtraSheet.Scripture -> "Scripture index"
    ExtraSheet.Collections -> "Collections"
    ExtraSheet.Pitch -> "Pitch pipe"
    ExtraSheet.Planner -> "Service planner"
    else -> tool.key
}

private fun toolIcon(tool: ExtraSheet): ImageVector = when (tool) {
    ExtraSheet.Scripture -> Icons.AutoMirrored.Outlined.MenuBook
    ExtraSheet.Collections -> Icons.Outlined.Layers
    ExtraSheet.Pitch -> Glyphs.TuningFork
    else -> Icons.Rounded.FormatListNumbered
}

/** A row that leads somewhere (MoreRow): icon, title, an optional detail, a chevron. */
@Composable
fun MoreRow(
    title: String,
    icon: ImageVector,
    modifier: Modifier = Modifier,
    detail: String? = null,
    isLast: Boolean = false,
    onClick: () -> Unit,
) {
    val p = LocalSurface.current
    Column(modifier) {
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
                Text(detail, style = DS.Type.caption, color = p.secondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, tint = p.secondary, modifier = Modifier.size(24.dp))
        }
        if (!isLast) RowDivider()
    }
}

@Composable
private fun MoreToggleRow(title: String, icon: ImageVector, isOn: Boolean, onChange: (Boolean) -> Unit, isLast: Boolean = false) {
    val p = LocalSurface.current
    Column {
        Row(
            Modifier
                .fillMaxWidth()
                .heightIn(min = 46.dp)
                .clickable(role = Role.Switch) { onChange(!isOn) }
                .semantics { stateDescription = if (isOn) "On" else "Off" }
                .padding(horizontal = DS.Space.m),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(DS.Space.m),
        ) {
            Box(Modifier.width(28.dp), contentAlignment = Alignment.Center) {
                Icon(icon, null, tint = p.tint, modifier = Modifier.size(20.dp))
            }
            Text(title, style = DS.Type.label, color = p.foreground, modifier = Modifier.weight(1f))
            Switch(
                checked = isOn, onCheckedChange = null,
                colors = SwitchDefaults.colors(checkedTrackColor = p.tint, checkedThumbColor = p.onTint),
            )
        }
        if (!isLast) RowDivider()
    }
}

@Composable
private fun RowDivider() =
    HorizontalDivider(Modifier.padding(start = 52.dp), thickness = 0.5.dp, color = LocalSurface.current.primary(DS.Fill.stroke))
