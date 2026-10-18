package com.mDev.AdventPraise.church

import com.mDev.AdventPraise.data.Json
import com.mDev.AdventPraise.data.jsonInt
import com.mDev.AdventPraise.data.jsonObject
import com.mDev.AdventPraise.data.jsonString

/**
 * The church remote's buttons: the ongoing notification's actions (iOS's
 * Live Activity intents) and the Church Remote widget's. `key` names them
 * in intents and deep links.
 */
enum class ChurchRemoteAction(val key: String) {
    Next("next"), Previous("previous"), End("end"), Blank("blank"), NextHymn("nextHymn");

    companion object {
        fun of(key: String?): ChurchRemoteAction? = entries.firstOrNull { it.key == key }
    }
}

/**
 * What the ongoing notification shows while presenting (iOS's
 * ChurchActivityAttributes.ContentState, Lock Screen and Dynamic Island).
 */
data class ChurchActivityState(
    val hymnal: String,
    val hymnNumber: Int,
    val title: String,
    /** "Verse 2 of 4", the chorus label, "Screen blank", "Image" or "Announcement". */
    val position: String,
    /** 1-based block of the sung sequence, and how many there are. */
    val step: Int,
    val stepCount: Int,
    val canGoBack: Boolean,
    /** The words are also on a TV (a second display or Cast). */
    val isOnTV: Boolean,
)

/**
 * What the Church Remote widget shows (ChurchWidgetState.swift), written by
 * the app and read by the Glance widget. Saved as JSON with the iOS field names.
 */
data class ChurchWidgetState(
    val hymnNumber: Int,
    val title: String,
    /** The hymnal's name. */
    val hymnal: String,
    /** "Verse 2 of 4", the chorus label, "Screen blank", or "" when not presenting. */
    val position: String,
    val isPresenting: Boolean,
    val isOnTV: Boolean,
    val isBlanked: Boolean,
    val isPro: Boolean,
    val hasNextHymn: Boolean,
    val canGoBack: Boolean,
) {
    fun toJson(): String = Json.write(linkedMapOf(
        "hymnNumber" to hymnNumber, "title" to title, "hymnal" to hymnal, "position" to position,
        "isPresenting" to isPresenting, "isOnTV" to isOnTV, "isBlanked" to isBlanked, "isPro" to isPro,
        "hasNextHymn" to hasNextHymn, "canGoBack" to canGoBack,
    ))

    companion object {
        const val WIDGET_KIND = "ChurchRemote"
        /** Where the app keeps it for the widget (iOS: the App Group's UserDefaults). */
        const val KEY = "churchWidget.state.v1"

        val placeholder = ChurchWidgetState(
            hymnNumber = 1, title = "Watchman Blow The Gospel Trumpet", hymnal = "Christ In Song",
            position = "", isPresenting = false, isOnTV = false, isBlanked = false, isPro = true,
            hasNextHymn = true, canGoBack = false,
        )

        fun fromJson(text: String?): ChurchWidgetState? = runCatching {
            val o = Json.parse(text!!).jsonObject()!!
            ChurchWidgetState(
                o["hymnNumber"].jsonInt()!!, o["title"].jsonString()!!, o["hymnal"].jsonString()!!, o["position"].jsonString()!!,
                o["isPresenting"] as Boolean, o["isOnTV"] as Boolean, o["isBlanked"] as Boolean, o["isPro"] as Boolean,
                o["hasNextHymn"] as Boolean, o["canGoBack"] as Boolean,
            )
        }.getOrNull()
    }
}

/** The widgets' deep links (WidgetLink on iOS): `adventpraise://<key>`. */
enum class WidgetLink(val key: String) {
    /** Open church mode on the current hymn (resume presenting). Pro. */
    Present("present"),
    Favourites("favourites"),
    HymnOfTheDay("hymn-of-the-day"),
    NumberPad("number-pad"),
    Paywall("paywall");

    val url: String get() = "adventpraise://$key"

    companion object {
        const val SCHEME = "adventpraise"

        fun of(host: String?): WidgetLink? = entries.firstOrNull { it.key == host }
    }
}

/** A parsed `adventpraise://` link: a widget link, or a hymn in a hymnal (Hymn of the Day). */
sealed interface AppLink {
    data class Widget(val link: WidgetLink) : AppLink
    /** `adventpraise://hymn/123?hymnal=english`: the number is only meaningful in its hymnal. */
    data class OpenHymn(val number: Int, val hymnalId: String?) : AppLink

    companion object {
        fun parse(url: String): AppLink? {
            val prefix = "${WidgetLink.SCHEME}://"
            if (!url.startsWith(prefix)) return null
            val rest = url.removePrefix(prefix)
            val (pathPart, query) = rest.split('?', limit = 2).let { it[0] to it.getOrNull(1) }
            val segments = pathPart.split('/').filter { it.isNotEmpty() }
            val host = segments.firstOrNull() ?: return null
            if (host == "hymn") {
                val number = segments.lastOrNull()?.toIntOrNull() ?: return null
                val hymnal = query?.split('&')?.map { it.split('=', limit = 2) }
                    ?.firstOrNull { it[0] == "hymnal" }?.getOrNull(1)
                return OpenHymn(number, hymnal)
            }
            return WidgetLink.of(host)?.let(::Widget)
        }
    }
}
