package com.mDev.AdventPraise.billing

/**
 * The products and the RevenueCat set-up, shared with iOS
 * (Store/PurchaseConfig.swift, docs/revenuecat.md).
 *
 * Every hymnal is free. Pro (the player beyond its free plays, church mode
 * on a TV, sheet music, the pitch pipe and unlimited Memorise) is the
 * RevenueCat entitlement `pro`, sold as an annual auto-renewing
 * subscription: `ap_pro_annual` (Google Play base plan `annual`, with a
 * 3-day free trial for new subscribers), the `$rc_annual` package of the
 * default offering. The paywall sells that package alone; the price and
 * trial are never written here, they come from Google Play through the
 * offering.
 *
 * Whoever bought Pro once (`ap_pro_lifetime`, iOS 7.0.x) or 7.0.1's MIDI
 * Piano (`ap_midi_unlock`) keeps Pro for life: RevenueCat attaches both to
 * `pro`. Tips are one-off consumables that unlock nothing.
 */
object PurchaseConfig {
    /** The entitlement that is Pro. */
    const val PRO_ENTITLEMENT = "pro"

    /** The offering the paywall shows; null is RevenueCat's current (default) offering. */
    val OFFERING_ID: String? = null

    /** Pro: the annual auto-renewing subscription. The only unlock on sale. */
    const val PRO_PRODUCT_ID = "ap_pro_annual"
    /** Its package in the offering. */
    const val PRO_PACKAGE_ID = "\$rc_annual"

    /** Pro bought once, sold in iOS 7.0.x. Not sold now; attached to `pro`, so owning it is Pro for life. */
    const val LEGACY_LIFETIME_PRODUCT_ID = "ap_pro_lifetime"
    /** MIDI Piano, iOS 7.0.1's cheaper unlock. Not sold now; attached to `pro`. */
    const val LEGACY_MIDI_PRODUCT_ID = "ap_midi_unlock"

    /** Every product that opens the `pro` entitlement in RevenueCat. Only [PRO_PRODUCT_ID] is offered. */
    val PRO_ENTITLEMENT_PRODUCT_IDS: Set<String> = setOf(PRO_PRODUCT_ID, LEGACY_LIFETIME_PRODUCT_ID, LEGACY_MIDI_PRODUCT_ID)

    /** One-off consumables, cheapest first. Each unlocks nothing. */
    val TIPS: List<TipDefinition> = listOf(
        TipDefinition("ap_tip_amen", "Amen", "A quiet thank you", TipIcon.Heart),
        TipDefinition("ap_tip_hallelujah", "Hallelujah", "Keeps the hymns ringing", TipIcon.MusicNote),
        TipDefinition("ap_tip_hosanna", "Hosanna", "Carries Advent Praise further", TipIcon.Sparkles),
    )

    val TIP_PRODUCT_IDS: List<String> get() = TIPS.map { it.productId }

    /** The first milestone's names. */
    const val ANNUAL_PRODUCT_ID = PRO_PRODUCT_ID
}

/** The symbol on a tip's row: iOS's heart.fill, music.note and sparkles. */
enum class TipIcon { Heart, MusicNote, Sparkles }

/** A tip as the config names it; the store adds the Google Play price. */
data class TipDefinition(val productId: String, val name: String, val blurb: String, val icon: TipIcon) {
    fun option(price: String) = TipOption(productId, name, blurb, icon, price)
}

/** Something Pro unlocks; the paywall leads with it. `analyticsName` is iOS's. */
enum class ProFeature(val analyticsName: String) {
    /** The accompaniment beyond its free plays. */
    Player("player"),
    /** Church mode on a TV or projector (iOS: AirPlay; Android: a second display or Cast). */
    AirPlay("air_play"),
    /** The Go Pro banner on a mirrored or captured screen. */
    Mirroring("mirroring"),
    /** Opened from More, not by a locked feature. */
    Support("support"),
    /** The whole page of a hymn's sheet music (Hymn of the Day's is free). */
    SheetMusic("sheet_music"),
}

/**
 * What this customer has, as RevenueCat reports it, and what that opens
 * (Entitlements on iOS). Pure values: the `pro` entitlement opens everything.
 */
data class Entitlements(
    /** Active RevenueCat entitlements ("pro"). */
    val active: Set<String> = emptySet(),
    /** Product IDs bought on this account. Tips are not counted. */
    val purchased: Set<String> = emptySet(),
) {
    /** Pro, however it was bought. */
    val isPro: Boolean get() = PurchaseConfig.PRO_ENTITLEMENT in active
    /** The MIDI player beyond its free plays. */
    val unlocksPlayer: Boolean get() = isPro
    /** Pro for life: bought once in iOS 7.0.x, or 7.0.1's MIDI Piano. */
    val ownsProForLife: Boolean
        get() = isPro && (PurchaseConfig.LEGACY_LIFETIME_PRODUCT_ID in purchased || PurchaseConfig.LEGACY_MIDI_PRODUCT_ID in purchased)
    /** Pro through the annual subscription (nothing bought for life). */
    val isSubscriber: Boolean get() = isPro && !ownsProForLife && PurchaseConfig.PRO_PRODUCT_ID in purchased
    /** Anything was ever bought (for Restore's message). */
    val hasPurchases: Boolean get() = purchased.isNotEmpty()

    /** Whether `feature` is open. Everything is Pro. */
    fun unlocks(feature: ProFeature): Boolean = isPro

    companion object {
        val none = Entitlements()
    }
}

/** Whether the paywall shows: never for Pro, whatever asked for it. */
object ProPaywallRule {
    fun presents(feature: ProFeature?, isEnabled: Boolean, entitlements: Entitlements): Boolean =
        isEnabled && feature != null && !entitlements.isPro
}
