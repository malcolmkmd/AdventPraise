// OWNER: shell
package com.mDev.AdventPraise.ui.more

import android.annotation.SuppressLint
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.animation.Crossfade
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Lightbulb
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.mDev.AdventPraise.AppServices
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.analytics.AnalyticsScreen
import com.mDev.AdventPraise.analytics.FeatureBoardConfig
import com.mDev.AdventPraise.ui.design.GlassButton
import com.mDev.AdventPraise.ui.design.HapticEvent
import com.mDev.AdventPraise.ui.design.Haptics
import com.mDev.AdventPraise.ui.root.AppNavigator
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface

/*
 * Vote on features (FeatureBoard.swift), a sheet over More, only when the
 * build has a Features.Vote board (FeatureBoardConfig.slug). The first time,
 * the sheet explains what leaves the phone before anything loads; the board
 * (and its first network call) waits for Continue. Features.Vote has no
 * Android SDK, so the board is its public web page, anonymous: no name,
 * email, id or token is ever passed.
 */

/** The board's public page. */
private fun boardUrl(slug: String) = "https://features.vote/board/$slug"

@Composable
fun FeatureBoardSheet(services: AppServices, navigator: AppNavigator) {
    val settings = services.appSettings
    var showsBoard by remember { mutableStateOf(settings.featureBoardDisclosedAt != null) }
    DisposableEffect(Unit) {
        val openedAt = System.currentTimeMillis()
        Analytics.track(AnalyticsEvent.FeatureBoardOpened(showsBoard))
        Analytics.screen(AnalyticsScreen.FeatureBoard)
        onDispose {
            Analytics.track(AnalyticsEvent.FeatureBoardClosed(((System.currentTimeMillis() - openedAt) / 1000).toInt(), showsBoard))
        }
    }
    val slug = FeatureBoardConfig.slug
    Crossfade(showsBoard && slug != null, label = "feature-board") { board ->
        if (board && slug != null) {
            Board(boardUrl(slug))
        } else {
            FeatureBoardDisclosure {
                settings.markFeatureBoardDisclosed()
                Analytics.track(AnalyticsEvent.FeatureBoardDisclosureAccepted)
                Haptics.play(HapticEvent.LightImpact)
                showsBoard = true
            }
        }
    }
}

/** First open only: what the board sends, before it sends anything. */
@Composable
fun FeatureBoardDisclosure(onContinue: () -> Unit) {
    val p = LocalSurface.current
    Box(Modifier.fillMaxSize().verticalScroll(rememberScrollState()), contentAlignment = Alignment.TopCenter) {
        Column(
            Modifier.widthIn(max = 560.dp).fillMaxWidth().padding(horizontal = DS.Space.l + DS.Space.xxs).padding(bottom = DS.Space.l),
            verticalArrangement = Arrangement.spacedBy(DS.Space.l),
        ) {
            Spacer(Modifier.height(DS.Space.top))
            Icon(Icons.Outlined.Lightbulb, null, tint = p.brass, modifier = Modifier.size(36.dp))
            Column(verticalArrangement = Arrangement.spacedBy(DS.Space.s)) {
                Text("Vote on features", style = DS.Type.sheetTitle, color = p.foreground, modifier = Modifier.semantics { heading() })
                Text("See what others have asked for, vote for the ones you want, or request your own.", style = DS.Type.rowBody, color = p.foreground)
                Text(
                    "Requests, comments and votes go to Features.Vote, which runs the board, with a random ID for this phone. Your name and email aren't sent, so please don't type them in.",
                    style = DS.Type.detail, color = p.secondary,
                )
            }
            GlassButton("Continue", onClick = onContinue, fullWidth = true)
        }
    }
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun Board(url: String) {
    val background = LocalSurface.current.background.toArgb()
    AndroidView(
        factory = { context ->
            WebView(context).apply {
                setBackgroundColor(background)
                settings.javaScriptEnabled = true
                settings.domStorageEnabled = true
                webViewClient = WebViewClient()
                loadUrl(url)
            }
        },
        modifier = Modifier.fillMaxSize(),
    )
}
