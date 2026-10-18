// OWNER: shell
package com.mDev.AdventPraise.ui.legal

import android.content.res.AssetManager
import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInParent
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mDev.AdventPraise.BuildConfig
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsScreen
import com.mDev.AdventPraise.analytics.FeatureBoardConfig
import com.mDev.AdventPraise.reader.LegalDocument
import com.mDev.AdventPraise.ui.design.Eyebrow
import com.mDev.AdventPraise.ui.root.SheetContainer
import com.mDev.AdventPraise.ui.theme.DS
import com.mDev.AdventPraise.ui.theme.LocalSurface

/*
 * The Terms of Use and the Privacy Policy (TermsOfUseView, PrivacyPolicyView),
 * told for Google Play and Android where the subject is the store or the
 * platform. The Terms include "Hymn content and ownership" read from the
 * shared legal/hymn-content-terms.md (an APK asset), word for word as iOS
 * shows it. Opened as More's pages (More → About, and About Advent Praise),
 * and from the paywall in a sheet of their own with Done.
 */

/** One titled section of the Terms or the Privacy Policy (PolicySectionCopy). */
data class LegalSection(
    val id: String,
    val title: String,
    val paragraphs: List<String>,
    /** One quiet line after the paragraphs, in small secondary text. */
    val note: String? = null,
)

/** The section the shared Markdown file fills. */
const val HYMN_CONTENT_SECTION = "ownership"

/** The Terms or the Privacy Policy as a More page (Destination.Terms / Destination.Privacy). */
@Composable
fun LegalScreen(document: LegalDocument, onClose: () -> Unit) {
    LegalPage(document)
}

/**
 * The page itself: the title with the version and date, the policy's "In
 * short" box, then every section. [startAt] scrolls to a section's id
 * (screenshots of the hymn content section).
 */
@Composable
fun LegalPage(document: LegalDocument, modifier: Modifier = Modifier, startAt: String? = null) {
    val p = LocalSurface.current
    val assets = LocalContext.current.assets
    val sections = remember(document) {
        when (document) {
            LegalDocument.Terms -> LegalCopy.terms(LegalCopy.sharedSections(assets, "hymn-content-terms.md"))
            LegalDocument.Privacy -> LegalCopy.privacy(FeatureBoardConfig.isEnabled)
        }
    }
    LaunchedEffect(document) { Analytics.screen(if (document == LegalDocument.Terms) AnalyticsScreen.Terms else AnalyticsScreen.Privacy) }
    val scroll = rememberScrollState()
    var target by remember { mutableFloatStateOf(-1f) }
    var scrolled by remember { mutableStateOf(false) }
    LaunchedEffect(target) { if (target >= 0f && !scrolled) { scroll.scrollTo(target.toInt()); scrolled = true } }

    Box(modifier.fillMaxSize().verticalScroll(scroll), contentAlignment = Alignment.TopCenter) {
        Column(
            Modifier
                .widthIn(max = DS.Space.readingMeasure)
                .fillMaxWidth()
                .padding(horizontal = DS.Space.l + DS.Space.xxs)
                .padding(top = DS.Space.m, bottom = DS.Space.l * 2)
                .windowInsetsPadding(WindowInsets.navigationBars),
            verticalArrangement = Arrangement.spacedBy(DS.Space.l + DS.Space.xs),
        ) {
            PolicyHeader(if (document == LegalDocument.Terms) "Terms of Use" else "Privacy Policy")
            if (document == LegalDocument.Privacy) InShort(LegalCopy.privacyInShort)
            sections.forEach { section ->
                PolicySection(
                    section,
                    if (section.id == startAt) Modifier.onGloballyPositioned { target = it.positionInParent().y } else Modifier,
                )
            }
        }
    }
}

/** The Terms or Privacy Policy over another sheet (the paywall), with Done. [document] null: closed. */
@Composable
fun LegalSheet(document: LegalDocument?, onDismiss: () -> Unit) {
    // Kept while the sheet slides away, so its page doesn't change under it.
    var shown by remember { mutableStateOf(document) }
    var mounted by remember { mutableStateOf(document != null) }
    SideEffect { if (document != null) { shown = document; mounted = true } }
    val page = shown ?: return
    if (!mounted) return
    SheetContainer(
        title = if (page == LegalDocument.Terms) "Terms" else "Privacy",
        visible = document != null,
        onDismissRequest = onDismiss,
        onGone = { mounted = false },
    ) { LegalPage(page) }
}

/** The title, then the app version and the date it was last changed. */
@Composable
private fun PolicyHeader(title: String) {
    val p = LocalSurface.current
    Column(verticalArrangement = Arrangement.spacedBy(DS.Space.xs)) {
        Text(title, style = DS.Type.display, color = p.foreground, modifier = Modifier.semantics { heading() })
        Text("Advent Praise ${BuildConfig.VERSION_NAME} · Updated October 2026", style = DS.Type.detail, color = p.secondary)
    }
}

/** The short version, before the detail. */
@Composable
private fun InShort(lines: List<String>) {
    val p = LocalSurface.current
    Column(
        Modifier
            .fillMaxWidth()
            .background(p.tint.copy(alpha = DS.Fill.tintActive), RoundedCornerShape(DS.Radius.tile))
            .padding(DS.Space.m + DS.Space.xxs)
            .semantics(mergeDescendants = true) {},
        verticalArrangement = Arrangement.spacedBy(DS.Space.s),
    ) {
        Eyebrow("In short", p.brass)
        lines.forEach { line ->
            Row(horizontalArrangement = Arrangement.spacedBy(DS.Space.s)) {
                Icon(Icons.Rounded.Check, null, tint = p.tint, modifier = Modifier.padding(top = 3.dp).size(14.dp))
                Text(line, style = DS.Type.rowBody, color = p.foreground)
            }
        }
    }
}

@Composable
private fun PolicySection(section: LegalSection, modifier: Modifier = Modifier) {
    val p = LocalSurface.current
    Column(modifier, verticalArrangement = Arrangement.spacedBy(DS.Space.s + DS.Space.xxs)) {
        Text(section.title, style = DS.Type.panelTitle, color = p.foreground, modifier = Modifier.semantics { heading() })
        section.paragraphs.forEach { paragraph ->
            Text(inlineMarkdown(paragraph), style = DS.Type.rowBody.copy(lineHeight = 26.sp), color = p.foreground)
        }
        section.note?.let { Text(it, style = DS.Type.detail, color = p.secondary) }
    }
}

/** **Bold** spans, as the iOS policy's LocalizedStringKey shows them. */
private fun inlineMarkdown(text: String): AnnotatedString = buildAnnotatedString {
    text.split("**").forEachIndexed { i, part ->
        if (i % 2 == 1) withStyle(SpanStyle(fontWeight = FontWeight.SemiBold)) { append(part) } else append(part)
    }
}

object LegalCopy {
    /**
     * A shared Markdown file from legal/ as sections: each heading starts one,
     * blank lines split paragraphs, "- " items become bullets. Empty if the
     * file isn't there. The first section is [HYMN_CONTENT_SECTION].
     */
    fun sharedSections(assets: AssetManager, name: String): List<LegalSection> {
        val text = runCatching { assets.open(name).bufferedReader().use { it.readText() } }.getOrNull() ?: return emptyList()
        return parseSections(text)
    }

    fun parseSections(text: String): List<LegalSection> {
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
            if (paragraphs.isNotEmpty()) {
                val id = if (sections.isEmpty()) HYMN_CONTENT_SECTION else "shared.${sections.size}"
                sections += LegalSection(id, title, paragraphs.toList())
            }
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

    /** TermsOfUse.sections, with Pro and the tips told for Google Play. */
    fun terms(shared: List<LegalSection>): List<LegalSection> = listOf(
        LegalSection("who", "Who makes Advent Praise", listOf(
            "Advent Praise is made by Malcolm Kumwenda and published by MDEVSA (PTY) LTD, a company in South Africa. By using the app you agree to these terms.",
        )),
        LegalSection("hymns", "The hymns", listOf(
            "The hymn texts are provided for personal devotion and for congregational worship: reading, singing and showing them in church. Please don’t sell them, or copy them out of the app to publish elsewhere.",
        )),
    ) + shared + listOf(
        LegalSection("pro", "Advent Praise Pro", listOf(
            "Pro is an annual auto-renewing subscription with a 3-day free trial. It is sold and charged by Google through Google Play, under Google Play’s terms.",
            "Payment is charged to your Google Play account at confirmation of purchase or, if you start with the free trial, at the end of the trial. The subscription renews automatically each year unless it is cancelled before the end of the current period.",
            "You can manage or cancel the subscription in Google Play › Payments & subscriptions.",
            "If you bought Pro (or the MIDI Piano) as a one-time purchase, you keep Pro for life.",
            "Refunds are handled by Google under Google Play’s refund policies. To ask for one, use your order history in Google Play.",
        )),
        LegalSection("tips", "Tips", listOf(
            "Tips are a voluntary thank you, also paid through Google Play. They unlock nothing and don’t change how the app works.",
        )),
        LegalSection("warranty", "No warranty", listOf(
            "Advent Praise is provided “as is”. Care has gone into the hymns, translations, scripture references and accompaniment, but they may contain mistakes, and the app may not always be available or free of faults.",
        )),
        LegalSection("liability", "Limitation of liability", listOf(
            "As far as the law allows, Malcolm Kumwenda and MDEVSA (PTY) LTD are not liable for any indirect or consequential loss from using the app, and their total liability is limited to the amount you paid for it. Nothing here limits rights you have under consumer law that can’t be excluded.",
        )),
        LegalSection("law", "Governing law", listOf("These terms are governed by the laws of the Republic of South Africa.")),
        LegalSection("changes", "Changes", listOf(
            "These terms may change as the app does. Changes come in an app update, and the version and date above show which terms you are reading. Using the app after an update means you accept them.",
        )),
    )

    val privacyInShort: List<String> = listOf(
        "No account, no sign-in and no advertising.",
        "Your favourites, playlists and settings stay on your phone.",
        "Anonymous usage counts help improve the app, and you can switch them off.",
        "Purchases are made with Google Play. We never see your payment details.",
    )

    /** PrivacyPolicy.sections, told for Android and Google Play. The feature board's section only with a board. */
    fun privacy(hasFeatureBoard: Boolean): List<LegalSection> = buildList {
        add(LegalSection("who", "Who makes Advent Praise", listOf(
            "Advent Praise is made by Malcolm Kumwenda, an independent developer in South Africa. This policy explains what the app does with information, in plain words.",
        )))
        add(LegalSection("device", "On your phone", listOf(
            "There are no accounts. Advent Praise never asks for your name, email address or phone number.",
            "Your favourites, playlists, service plans, recent hymns, pitch notes and settings are stored only on your device. The hymns and their piano accompaniment come inside the app, so reading and singing work without the internet.",
            "The number of free plays of the piano you have used is also kept in Android’s backup of the app, so that it isn’t reset by reinstalling the app.",
        )))
        add(LegalSection("usage", "Anonymous usage", listOf(
            "To learn which features are used and what to improve, the app can send anonymous usage counts to PostHog, an analytics service, on servers in the European Union.",
            "These say what happened in the app: for example, that a hymn was opened (its hymnal and number), that church mode started, or how many results a search found. They include the app and Android versions, the device model, language, time zone and screen size.",
            "They never include your name, the words you search for, the names of your playlists or the text of hymns. Your location isn’t looked up from your IP address. There are no crash reports and no recordings of the screen.",
            "Each install has a random ID that isn’t tied to you, your Google Account or your device. **You can switch usage off in More → Share anonymous usage.** Switching it off stops sending and deletes that ID.",
        )))
        add(LegalSection("tracking", "No tracking or advertising", listOf(
            "Advent Praise has no ads. It doesn’t use the advertising ID, doesn’t track you across other apps and websites, and doesn’t sell or share information with data brokers.",
        )))
        add(LegalSection("purchases", "Purchases", listOf(
            "Advent Praise Pro and tips are bought through Google Play, and Google handles the payment. To know whether Pro is yours on each of your devices, the app sends your Google Play purchase records to RevenueCat, a purchase service, with a random ID for this install. Neither RevenueCat nor we ever see your name, card or Google Account details.",
            "Usage counts can record that a purchase was started or completed, with the product’s name, but never the price or any receipt.",
        )))
        add(LegalSection("content", "Content we include", listOf(
            "The hymns, their accompaniment and the scripture references come inside the app. Christ In Song and its translations come from the texts of earlier versions of Advent Praise. The SDA Hymnal’s words are those of the Seventh-day Adventist Hymnal, 1985.",
            "Scripture references come from the hymns’ own words, the texts printed in Christ in Song (1908) and the Hymnary.org scripture index. Collections follow the topical sections of the Seventh-day Adventist Hymnal (1985), as listed on Hymnary.org.",
        ), note = "The piano accompaniment uses MIDI files, and the sheet music is engraved from scores, from The Cyber Hymnal (hymntime.com)."))
        if (hasFeatureBoard) {
            add(LegalSection("board", "Feature requests", listOf(
                "Vote on features opens a board run by Features.Vote. Your requests, comments and votes are sent there with a random ID for this phone, and others can read what you post. Your name and email aren’t sent, so please don’t type them in.",
            )))
        }
        add(LegalSection("links", "Links to other sites", listOf(
            "Some links leave the app, such as scripture passages on Bible.com. Those sites have their own privacy policies.",
        )))
        add(LegalSection("children", "Children", listOf(
            "Advent Praise is for everyone who sings. It doesn’t collect personal information from anyone, children included.",
        )))
        add(LegalSection("changes", "Changes", listOf(
            "If what the app does with information changes, this policy changes with it, in the same update. The version and date above show which one you are reading.",
        )))
    }
}
