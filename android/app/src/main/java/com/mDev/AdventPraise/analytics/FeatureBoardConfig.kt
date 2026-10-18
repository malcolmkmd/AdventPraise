package com.mDev.AdventPraise.analytics

/**
 * Features.Vote settings for More → Help us improve → Vote on features
 * (FeatureBoardConfig.swift), kept free of any SDK. The board slug comes
 * from the build (iOS: the FEATURES_VOTE_API_KEY Info.plist key); without
 * one there is no More row and no network call. Anonymous: never a name,
 * email, custom id or token; new requests carry only the app version and platform.
 */
object FeatureBoardConfig {
    /** Another app's board. Refused even if pasted in by mistake. */
    val REFUSED_SLUGS = setOf("myklippa")

    const val PLATFORM = "android"
    const val ALLOW_ANONYMOUS_VOTING = true
    const val ALLOW_ANONYMOUS_COMMENTS = true
    const val REQUIRE_EMAIL_FOR_CREATE = false
    const val SHOW_WATERMARK = true

    /** Set once at launch from the build's key (AppServices); null: no board. */
    var slug: String? = null
        private set

    /** The More row and the board only exist when there is one. */
    val isEnabled: Boolean get() = slug != null

    fun configure(rawKey: String?) {
        slug = slug(rawKey)
    }

    /** The key, trimmed. Null when missing, empty, an unexpanded `$(…)` setting, or another app's board. */
    fun slug(raw: String?): String? {
        val value = raw?.trim() ?: return null
        if (value.isEmpty() || value.startsWith("\$(") || value.lowercase() in REFUSED_SLUGS) return null
        return value
    }

    /** `post_metadata` on new requests. Never a name, email, id or token. */
    fun metadata(appVersion: String): Map<String, String> = mapOf("app_version" to appVersion, "platform" to PLATFORM)
}
