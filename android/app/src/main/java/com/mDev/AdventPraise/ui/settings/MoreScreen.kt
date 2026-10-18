package com.mDev.AdventPraise.ui.settings

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.Verified
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.BuildConfig
import com.mDev.AdventPraise.R
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.audio.FreePlays
import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.reader.LegalDocument
import com.mDev.AdventPraise.reader.Screen
import com.mDev.AdventPraise.ui.Eyebrow
import com.mDev.AdventPraise.ui.SectionTitle
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface
import kotlinx.coroutines.launch

/** More (MoreSheet.swift): Pro first, then reading settings, purchases and about. */
@Composable
fun MoreScreen(services: AppServices) {
    val model = services.reader
    val settings = services.settings
    val store = services.store
    val p = LocalSurface.current
    val scope = rememberCoroutineScope()
    val uriHandler = LocalUriHandler.current
    var sharesUsage by remember { mutableStateOf(Analytics.isEnabled) }
    LaunchedEffect(Unit) { Analytics.screen("more") }

    Column(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.statusBars)) {
        Row(Modifier.fillMaxWidth().padding(horizontal = DS.Space.s, vertical = DS.Space.xs), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(DS.Size.hitTarget).clip(CircleShape).clickable { model.screen = Screen.Reader }, contentAlignment = Alignment.Center) {
                Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "Back to the hymn", tint = p.foreground)
            }
            Text("More", style = DS.Type.sheetTitle, color = p.foreground, modifier = Modifier.padding(start = DS.Space.xs))
        }
        Column(
            Modifier.fillMaxWidth().weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = DS.Space.l),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(Modifier.widthIn(max = DS.Space.lecternMaxWidth).fillMaxWidth()) {
                Eyebrow("Advent Praise ${BuildConfig.VERSION_NAME}", p.secondary, Modifier.padding(start = DS.Space.xxs, top = DS.Space.s, bottom = DS.Space.m), tracking = 0.9f)

                // Pro first: one row, the free plays left or thanks; opens the paywall.
                val shape = RoundedCornerShape(DS.Radius.card)
                Row(
                    Modifier.fillMaxWidth().clip(shape).background(p.gold.copy(alpha = if (p.isDark) 0.12f else 0.16f))
                        .border(1.dp, p.brass.copy(alpha = 0.35f), shape)
                        .clickable { model.showPaywall(ProFeature.Support, "more") }
                        .padding(DS.Space.m),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(DS.Space.m),
                ) {
                    Box(Modifier.size(48.dp).clip(RoundedCornerShape(DS.Radius.tile)).background(DS.Palette.stage), contentAlignment = Alignment.Center) {
                        Image(painterResource(R.drawable.sda_logo), contentDescription = null, colorFilter = ColorFilter.tint(DS.Palette.goldDark),
                            modifier = Modifier.size(30.dp))
                    }
                    Column(Modifier.weight(1f)) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DS.Space.xxs)) {
                            Text("Advent Praise Pro", style = DS.Type.rowTitle, color = p.foreground)
                            if (store.isPro) Icon(Icons.Rounded.Verified, contentDescription = "Active", tint = p.brass, modifier = Modifier.size(16.dp))
                        }
                        val remaining = services.freePlays.remaining
                        Text(
                            when {
                                store.isPro -> "Thank you. Your Pro subscription is active."
                                remaining == 0 -> "Your free plays of the piano are used"
                                remaining == 1 -> "1 free play of the piano left"
                                else -> "$remaining of ${FreePlays.FREE} free plays of the piano left"
                            },
                            style = DS.Type.detail, color = p.secondary,
                        )
                    }
                    Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, contentDescription = null, tint = p.secondary)
                }

                SectionTitle("Reading")
                Group {
                    ToggleRow("Chorus after every verse", settings.repeatChorus) {
                        settings.updateRepeatChorus(it)
                        Analytics.track(AnalyticsEvent.SettingChanged("repeat_chorus", it))
                    }
                    ToggleRow("Haptics", settings.haptics) {
                        settings.updateHaptics(it)
                        Analytics.track(AnalyticsEvent.SettingChanged("haptics", it))
                    }
                }

                SectionTitle("Purchases")
                Group {
                    Row(
                        Modifier.fillMaxWidth().heightIn(min = DS.Size.row).clickable(enabled = !store.isRestoring) {
                            scope.launch { store.restore("more") }
                        }.padding(horizontal = DS.Space.m),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text("Restore purchases", style = DS.Type.label, color = p.tint, modifier = Modifier.weight(1f))
                        if (store.isRestoring) CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
                    }
                    if (store.isPro) {
                        LinkRow("Manage subscription") { uriHandler.openUri(store.manageSubscriptionUrl) }
                    }
                }

                SectionTitle("About")
                Group {
                    ToggleRow("Share anonymous usage", sharesUsage) {
                        sharesUsage = it
                        Analytics.isEnabled = it
                    }
                    LinkRow("Terms of Use") { model.document = LegalDocument.Terms }
                    LinkRow("Privacy Policy") { model.document = LegalDocument.Privacy }
                }
                Text(
                    "Usage counts are anonymous: which features are used, never your name, searches or the words of hymns. " +
                        "Hymns and accompaniment are the same as Advent Praise for iPhone and iPad.",
                    style = DS.Type.caption, color = p.secondary,
                    modifier = Modifier.padding(horizontal = DS.Space.xxs, vertical = DS.Space.s),
                )
                Box(Modifier.windowInsetsPadding(WindowInsets.navigationBars).padding(bottom = DS.Space.l))
            }
        }
    }
}

@Composable
private fun Group(content: @Composable ColumnScope.() -> Unit) {
    val p = LocalSurface.current
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(DS.Radius.card)).background(p.foreground.copy(alpha = DS.Fill.row)),
        content = content,
    )
}

@Composable
private fun LinkRow(title: String, onClick: () -> Unit) {
    val p = LocalSurface.current
    Row(
        Modifier.fillMaxWidth().heightIn(min = DS.Size.row).clickable(onClick = onClick).padding(horizontal = DS.Space.m),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, style = DS.Type.label, color = p.foreground, modifier = Modifier.weight(1f))
        Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, contentDescription = null, tint = p.secondary)
    }
}

@Composable
private fun ToggleRow(title: String, isOn: Boolean, onChange: (Boolean) -> Unit) {
    val p = LocalSurface.current
    Row(
        Modifier.fillMaxWidth().heightIn(min = DS.Size.row).clickable { onChange(!isOn) }.padding(horizontal = DS.Space.m),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, style = DS.Type.label, color = p.foreground, modifier = Modifier.weight(1f))
        Switch(checked = isOn, onCheckedChange = onChange)
    }
}
