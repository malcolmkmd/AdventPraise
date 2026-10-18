// OWNER: shell
package com.mDev.AdventPraise.ui.legal

import android.content.res.AssetManager
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.sp
import com.mDev.AdventPraise.BuildConfig
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.reader.LegalDocument
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface

/** One titled section of the Terms or the Privacy Policy. */
data class LegalSection(val title: String, val paragraphs: List<String>)

/**
 * The Terms of Use and the Privacy Policy, in the iOS app's style
 * (TermsOfUseView, PrivacyPolicyView), told for Google Play. The Terms
 * include "Hymn content and ownership" from legal/hymn-content-terms.md,
 * the text the iOS app shares, read from the APK's assets.
 */
@Composable
fun LegalScreen(document: LegalDocument, onClose: () -> Unit) {
    val p = LocalSurface.current
    val assets = LocalContext.current.assets
    val sections = remember(document) {
        when (document) {
            LegalDocument.Terms -> LegalCopy.terms(LegalCopy.sharedSections(assets, "hymn-content-terms.md"))
            LegalDocument.Privacy -> LegalCopy.privacy
        }
    }
    LaunchedEffect(document) { Analytics.screen(if (document == LegalDocument.Terms) "terms" else "privacy") }

    Column(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.statusBars)) {
        Row(Modifier.fillMaxWidth().padding(DS.Space.s), horizontalArrangement = Arrangement.End) {
            Box(Modifier.size(DS.Size.hitTarget).clip(CircleShape).clickable(onClick = onClose), contentAlignment = Alignment.Center) {
                Icon(Icons.Rounded.Close, contentDescription = "Close", tint = p.foreground)
            }
        }
        Column(
            Modifier.fillMaxWidth().weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = DS.Space.l + DS.Space.xxs),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(
                Modifier.widthIn(max = DS.Space.readingMeasure).fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(DS.Space.l + DS.Space.xs),
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(DS.Space.xs)) {
                    Text(if (document == LegalDocument.Terms) "Terms of Use" else "Privacy Policy",
                        style = DS.Type.display, color = p.foreground)
                    Text("Advent Praise ${BuildConfig.VERSION_NAME} · Updated October 2026", style = DS.Type.detail, color = p.secondary)
                }
                sections.forEach { section ->
                    Column(verticalArrangement = Arrangement.spacedBy(DS.Space.s + DS.Space.xxs)) {
                        Text(section.title, style = DS.Type.panelTitle, color = p.foreground)
                        section.paragraphs.forEach { paragraph ->
                            Text(inlineMarkdown(paragraph), style = DS.Type.rowBody.copy(lineHeight = 22.sp), color = p.foreground)
                        }
                    }
                }
                Box(Modifier.windowInsetsPadding(WindowInsets.navigationBars).padding(bottom = DS.Space.l))
            }
        }
    }
}

/** **Bold** spans, as the iOS policy's LocalizedStringKey shows them. */
private fun inlineMarkdown(text: String): AnnotatedString = buildAnnotatedString {
    val parts = text.split("**")
    parts.forEachIndexed { i, part ->
        if (i % 2 == 1) withStyle(SpanStyle(fontWeight = FontWeight.SemiBold)) { append(part) } else append(part)
    }
}

object LegalCopy {
    /**
     * A shared Markdown file from legal/ as sections: each heading starts one,
     * blank lines split paragraphs, "- " items become bullets. Empty if the
     * file isn't there.
     */
    fun sharedSections(assets: AssetManager, name: String): List<LegalSection> {
        val text = runCatching { assets.open(name).bufferedReader().use { it.readText() } }.getOrNull() ?: return emptyList()
        val sections = mutableListOf<LegalSection>()
        var title = "Hymn content and ownership"
        val paragraphs = mutableListOf<String>()
        val current = StringBuilder()
        fun endParagraph() {
            if (current.isNotBlank()) paragraphs += current.toString().trim()
            current.clear()
        }
        fun endSection() {
            endParagraph()
            if (paragraphs.isNotEmpty()) sections += LegalSection(title, paragraphs.toList())
            paragraphs.clear()
        }
        for (raw in text.lines()) {
            val line = raw.trim()
            when {
                line.startsWith("#") -> {
                    endSection()
                    title = line.trimStart('#').trim()
                }
                line.isEmpty() -> endParagraph()
                line.startsWith("- ") || line.startsWith("* ") -> {
                    endParagraph()
                    paragraphs += "•  " + line.drop(2).trim()
                }
                line.startsWith("<!--") -> Unit
                else -> {
                    if (current.isNotEmpty()) current.append(' ')
                    current.append(line)
                }
            }
        }
        endSection()
        return sections
    }

    fun terms(shared: List<LegalSection>): List<LegalSection> = listOf(
        LegalSection("Who makes Advent Praise", listOf(
            "Advent Praise is made by Malcolm Kumwenda and published by MDEVSA (PTY) LTD, a company in South Africa. By using the app you agree to these terms.",
        )),
        LegalSection("The hymns", listOf(
            "The hymn texts are provided for personal devotion and for congregational worship: reading, singing and showing them in church. Please don’t sell them, or copy them out of the app to publish elsewhere.",
        )),
    ) + shared + listOf(
        LegalSection("Advent Praise Pro", listOf(
            "Pro is an annual subscription, with a free trial for new subscribers where one is offered. It is sold and charged by Google through Google Play, under Google Play’s terms.",
            "Payment is charged to your Google Play account when the free trial ends, or when you confirm the purchase if there is no trial. The subscription renews automatically every year at the price shown in the app until you cancel it. You can manage or cancel it at any time in Google Play › Payments & subscriptions; Pro then stays on until the end of the period you have paid for.",
            "Refunds are handled under Google Play’s refund policies.",
        )),
        LegalSection("No warranty", listOf(
            "Advent Praise is provided “as is”. Care has gone into the hymns, translations, scripture references and accompaniment, but they may contain mistakes, and the app may not always be available or free of faults.",
        )),
        LegalSection("Limitation of liability", listOf(
            "As far as the law allows, Malcolm Kumwenda and MDEVSA (PTY) LTD are not liable for any indirect or consequential loss from using the app, and their total liability is limited to the amount you paid for it. Nothing here limits rights you have under consumer law that can’t be excluded.",
        )),
        LegalSection("Governing law", listOf("These terms are governed by the laws of the Republic of South Africa.")),
        LegalSection("Changes", listOf(
            "These terms may change as the app does. Changes come in an app update, and the version and date above show which terms you are reading. Using the app after an update means you accept them.",
        )),
    )

    val privacy: List<LegalSection> = listOf(
        LegalSection("In short", listOf(
            "•  No account, no sign-in and no advertising.",
            "•  Your favourites and settings stay on your phone.",
            "•  Anonymous usage counts help improve the app, and you can switch them off.",
            "•  Purchases are made with Google Play. We never see your payment details.",
        )),
        LegalSection("Who makes Advent Praise", listOf(
            "Advent Praise is made by Malcolm Kumwenda, an independent developer in South Africa. This policy explains what the app does with information, in plain words.",
        )),
        LegalSection("On your phone", listOf(
            "There are no accounts. Advent Praise never asks for your name, email address or phone number.",
            "Your favourites, recent hymns and settings are stored only on your device. The hymns and their piano accompaniment come inside the app, so reading and singing work without the internet.",
        )),
        LegalSection("Anonymous usage", listOf(
            "To learn which features are used and what to improve, the app can send anonymous usage counts to PostHog, an analytics service, on servers in the European Union.",
            "These say what happened in the app: for example, that a hymn was opened (its hymnal and number), or how many results a search found. They include the app and Android versions, the device model, language, time zone and screen size.",
            "They never include your name, the words you search for or the text of hymns. There are no crash reports and no recordings of the screen.",
            "Each install has a random ID that isn’t tied to you or your Google Account. **You can switch usage off in More → Share anonymous usage.** Switching it off stops sending and deletes that ID.",
        )),
        LegalSection("No tracking or advertising", listOf(
            "Advent Praise has no ads. It doesn’t use the advertising ID, doesn’t track you across other apps and websites, and doesn’t sell or share information with data brokers.",
        )),
        LegalSection("Purchases", listOf(
            "Advent Praise Pro is bought through Google Play, and Google handles the payment. To know whether Pro is yours on each of your devices, the app sends your Google Play purchase records to RevenueCat, a purchase service, with a random ID for this install. Neither RevenueCat nor we ever see your name, card or Google Account details.",
            "Usage counts can record that a purchase was started or completed, with the product’s name, but never the price or any receipt.",
        )),
        LegalSection("Content we include", listOf(
            "The hymns, their accompaniment and the scripture references come inside the app. Christ In Song and its translations come from the texts of earlier versions of Advent Praise.",
            "The piano accompaniment uses MIDI files from The Cyber Hymnal (hymntime.com).",
        )),
        LegalSection("Children", listOf(
            "Advent Praise is for everyone who sings. It doesn’t collect personal information from anyone, children included.",
        )),
        LegalSection("Changes", listOf(
            "If what the app does with information changes, this policy changes with it, in the same update. The version and date above show which one you are reading.",
        )),
    )
}
