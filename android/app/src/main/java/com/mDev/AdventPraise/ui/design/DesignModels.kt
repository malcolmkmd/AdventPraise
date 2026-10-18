package com.mDev.AdventPraise.ui.design

import androidx.compose.runtime.Immutable
import com.mDev.AdventPraise.ui.theme.DS

/**
 * Plain value types the components take (PreviewFixtures.swift). The app maps
 * its own models (Hymn, HymnalInfo, the store) onto these, so the components
 * stay previewable and never import a feature's internals.
 */

/** One hymnal as the picker and tiles need it (DSHymnal). */
@Immutable
data class DSHymnal(
    /** hymnals.json key. */
    val id: String,
    /** "Christ In Song". */
    val name: String,
    /** "English". */
    val language: String,
    val color: DS.LanguageColor = DS.Language.color(id),
    /** A hymnal of its own (the SDA Hymnal): its own numbers, and a tile across the whole row. */
    val isOwnBook: Boolean = false,
)

/** Ownership of a hymnal, from the purchases layer (DSHymnalAccess). */
sealed interface DSHymnalAccess {
    data object Current : DSHymnalAccess
    data object Owned : DSHymnalAccess
    data class Locked(val price: String?) : DSHymnalAccess
    data object Purchasing : DSHymnalAccess
}

/** A row-sized summary of a hymn (DSHymnSummary). */
@Immutable
data class DSHymnSummary(val number: Int, val title: String, val firstLine: String? = null)

/** One block of a hymn's text (DSHymnBlock). */
sealed interface DSHymnBlock {
    data class Verse(val number: Int, val lines: List<String>) : DSHymnBlock
    data class Chorus(val lines: List<String>) : DSHymnBlock
}

/** Sample data for previews, the gallery and screenshot tests (DSPreview). */
object DSPreview {
    val hymnals: List<DSHymnal> = listOf(
        Triple("english", "Christ In Song", "English"), Triple("chichewa", "Khristu Mu Nyimbo", "Chichewa"),
        Triple("tswana", "Keresete Mo Kopelong", "Tswana"), Triple("xhosa", "UKristu Engomeni", "Xhosa"),
        Triple("sotho", "Keresete Pineng", "Sotho"), Triple("shona", "Kristu MuNzwiyo", "Shona"),
        Triple("venda", "Ngosha YaDzingosha", "Venda"), Triple("zulu", "UKrestu Esihlabelelweni", "Zulu"),
        Triple("ndebele", "UKrestu Esihlabelelweni", "Ndebele"), Triple("sdah", "SDA Hymnal (1985)", "English"),
    ).map { (id, name, language) -> DSHymnal(id, name, language, isOwnBook = id == "sdah") }

    /** Every hymnal is free; the purchasing and locked states stay previewable. */
    fun access(hymnal: DSHymnal): DSHymnalAccess = when (hymnal.id) {
        "english" -> DSHymnalAccess.Current
        "sotho" -> DSHymnalAccess.Purchasing
        "venda" -> DSHymnalAccess.Locked("$1.99")
        else -> DSHymnalAccess.Owned
    }

    val hymns: List<DSHymnSummary> = listOf(
        DSHymnSummary(1, "Holy, Holy, Holy", "Holy, holy, holy! Lord God Almighty!"),
        DSHymnSummary(18, "Lead, Kindly Light", "Lead, kindly Light, amid th'encircling gloom"),
        DSHymnSummary(30, "Blessed Assurance", "Blessed assurance, Jesus is mine!"),
        DSHymnSummary(254, "Rock of Ages", "Rock of Ages, cleft for me"),
    )

    fun title(number: Int): String? = hymns.firstOrNull { it.number == number }?.title

    val blocks: List<DSHymnBlock> = listOf(
        DSHymnBlock.Verse(1, listOf("Blessed assurance, Jesus is mine!", "Oh, what a foretaste of glory divine!",
            "Heir of salvation, purchase of God,", "Born of His Spirit, washed in His blood.")),
        DSHymnBlock.Chorus(listOf("This is my story, this is my song,", "Praising my Saviour all the day long;",
            "This is my story, this is my song,", "Praising my Saviour all the day long.")),
        DSHymnBlock.Verse(2, listOf("Perfect submission, perfect delight,", "Visions of rapture now burst on my sight;",
            "Angels descending bring from above", "Echoes of mercy, whispers of love.")),
    )
}
