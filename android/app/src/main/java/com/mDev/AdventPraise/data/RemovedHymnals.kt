package com.mDev.AdventPraise.data

/**
 * Hymnals the iOS 7.0 betas shipped and 7.0 doesn't (RemovedHymnals.swift).
 * Saved state that names one falls back to English on iOS. The Android app
 * is new, so nothing it saved can name one; this is kept so data synced or
 * imported from iOS (playlists, plans) reads the same way.
 */
class RemovedHymnals(private val english: Hymnal) {
    /** The English hymn that is hymn `number` of `key`, or null when no match is known. */
    fun englishNumber(number: Int, key: String): Int? {
        val last = cisNumbered[key] ?: return null
        if (number > last) return null
        return english.hymn(number)?.number
    }

    companion object {
        /** Key → language, for naming the English copies of playlists and plans. */
        val languages: Map<String, String> = mapOf(
            "twi" to "Twi", "pt" to "Português", "es" to "Español", "ru" to "Русский",
            "dg" to "Français", "kinyarwanda" to "Kinyarwanda", "tumbuka" to "Tumbuka", "abagusii" to "Abagusii",
            "tonga" to "Tonga", "dholuo" to "Dholuo", "xitsonga" to "Xitsonga", "sepedi" to "Sepedi",
            "gikuyu" to "Kikuyu", "icibemba" to "Icibemba", "swahili" to "Swahili",
        )

        /** Numbered like Christ In Song up to this hymn. */
        private val cisNumbered: Map<String, Int> = mapOf(
            "xitsonga" to 300, "tonga" to 300, "tumbuka" to 300, "sepedi" to 300, "icibemba" to 300, "kinyarwanda" to 200,
        )

        fun contains(key: String): Boolean = key in languages

        /** "Sabbath · Tonga" */
        fun copyName(name: String, key: String): String = "$name · ${languages[key] ?: key}"
    }
}
