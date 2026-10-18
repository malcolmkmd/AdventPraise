package com.mDev.AdventPraise.billing

import android.app.Activity
import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.analytics.ErrorDomain
import com.mDev.AdventPraise.analytics.PurchaseFailure
import com.mDev.AdventPraise.analytics.RestoreSource
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

/**
 * Pro as the paywall sells it: the offering's annual package, its price and
 * free trial as Google Play gives them, and whether this account can still
 * have the trial (UnlockOption on iOS).
 */
data class UnlockOption(
    val pkg: OfferingPackage,
    /** Checked after the offering loads; false until then. */
    val isTrialEligible: Boolean = false,
) {
    /** The product ID ("ap_pro_annual"); analytics sends this. */
    val id: String get() = pkg.productId
    /** Google Play's localized price: "R199.99". */
    val price: String get() = pkg.price
    /** The free trial this buyer would get, if any. */
    val trial: SubscriptionTerm? get() = if (isTrialEligible) pkg.freeTrial else null

    /** "3 days free, then R199.99/year. Cancel anytime." Without the trial: "R199.99/year. Cancel anytime." */
    val offerLine: String
        get() {
            val recurring = recurring(price, pkg.period)
            val trial = trial ?: return "$recurring. Cancel anytime."
            return "${length(trial)} free, then $recurring. Cancel anytime."
        }

    /** "Start 3-Day Free Trial", or "Subscribe" without one. */
    val callToAction: String get() = trial?.let { "Start ${adjective(it)} Free Trial" } ?: "Subscribe"

    /** The auto-renewal disclosure under the offer, in Google Play's terms. */
    val renewalTerms: String
        get() {
            val period = pkg.period?.let(::periodName) ?: "period"
            val charge = if (trial == null) "Payment is charged to your Google Play account when you confirm."
            else "Payment is charged to your Google Play account when the free trial ends."
            return "$charge Renews automatically each $period until you cancel. " +
                "Manage or cancel anytime in Google Play › Payments & subscriptions."
        }

    /** The first milestone's names. */
    val offer: String get() = offerLine
    val buttonTitle: String get() = callToAction

    companion object {
        /** "R199.99/year" */
        fun recurring(price: String, period: SubscriptionTerm?): String {
            period ?: return price
            return if (period.value == 1) "$price/${periodName(period)}" else "$price/${length(period)}"
        }

        fun periodName(term: SubscriptionTerm): String = when (term.unit) {
            SubscriptionTerm.Unit.Day -> "day"
            SubscriptionTerm.Unit.Week -> "week"
            SubscriptionTerm.Unit.Month -> "month"
            SubscriptionTerm.Unit.Year -> "year"
        }

        /** "3 days", "1 week" */
        fun length(term: SubscriptionTerm): String =
            if (term.value == 1) "1 ${periodName(term)}" else "${term.value} ${periodName(term)}s"

        /** "3-Day", "1-Week" */
        fun adjective(term: SubscriptionTerm): String =
            "${term.value}-${periodName(term).replaceFirstChar { it.uppercase() }}"
    }
}

/** A tip the Support screen offers, with its Google Play price. Equal by product ID, as on iOS. */
class TipOption(val id: String, val name: String, val blurb: String, val icon: TipIcon, val price: String) {
    override fun equals(other: Any?) = other is TipOption && other.id == id
    override fun hashCode() = id.hashCode()
    override fun toString() = "TipOption($id, $price)"
}

/**
 * What one load produced, judged per screen: the paywall needs Pro from the
 * offering, the Support screen needs the tips. Each is missing on its own.
 */
data class Storefront(val proOption: UnlockOption? = null, val tips: List<TipOption> = emptyList()) {
    val proFailed: Boolean get() = proOption == null
    val tipsFailed: Boolean get() = tips.isEmpty()
    val anyFailed: Boolean get() = proFailed || tipsFailed

    /** `next` where it found something, what was here before where it didn't. */
    fun keeping(next: Storefront) = Storefront(next.proOption ?: proOption, next.tips.ifEmpty { tips })

    companion object {
        /**
         * Pro is the offering's package selling `ap_pro_annual` (the
         * `$rc_annual` package first). Nothing else is sold: never the
         * Lifetime package, never MIDI Piano.
         */
        fun from(offering: OfferingSnapshot?, tipPrices: Map<String, String>): Storefront {
            val pro = offering?.packages.orEmpty().filter { it.productId == PurchaseConfig.PRO_PRODUCT_ID }
            val pkg = pro.firstOrNull { it.id == PurchaseConfig.PRO_PACKAGE_ID } ?: pro.firstOrNull()
            return Storefront(
                proOption = pkg?.let { UnlockOption(it) },
                tips = PurchaseConfig.TIPS.mapNotNull { d -> tipPrices[d.productId]?.let(d::option) },
            )
        }
    }
}

/** What the store asks the UI to make felt (iOS plays these haptics from the store). */
enum class StoreFeedback { PurchaseComplete, Success, Warning, Error }

/**
 * Purchases through RevenueCat ([PurchasesClient]), as iOS's PurchaseStore.
 * What is owned is whatever RevenueCat's CustomerInfo says: read at launch,
 * after every purchase and restore, and on every change it reports. The
 * rules are [Entitlements]. The paywall and Support screen only see plain
 * values ([UnlockOption], [TipOption]); each loads on its own.
 *
 * State is Compose snapshot state; outside Compose read it with
 * `snapshotFlow { store.isPro }`.
 */
class PurchaseStore(
    private var client: PurchasesClient,
    private val scope: CoroutineScope,
    private val packageName: String = "com.mDev.AdventPraise",
    /** Screenshot tests and debug launches: the answer is given, whatever RevenueCat says. */
    private var forced: Entitlements? = null,
) {
    constructor(app: Application, scope: CoroutineScope) : this(PurchasesClients.live(app), scope, app.packageName)

    var isRestoring by mutableStateOf(false)
        private set
    /** True once the entitlements have been read at least once. */
    var hasLoadedEntitlements by mutableStateOf(false)
        private set
    /** What this customer has, and the rules for what that opens. */
    var entitlements by mutableStateOf(Entitlements.none)
        private set
    /** The options loaded, each null or empty until loaded or when it couldn't be. */
    var storefront by mutableStateOf(Storefront())
        private set
    var isLoadingOptions by mutableStateOf(false)
        private set
    /** The product being bought (Pro), while Google Play's sheet is up. */
    var purchasingId by mutableStateOf<String?>(null)
        private set
    /** The tip being bought. */
    var tipping by mutableStateOf<String?>(null)
        private set
    /** A tip went through; the Support screen thanks the buyer until this is cleared. */
    var thankYouForTip by mutableStateOf<TipOption?>(null)
    var message by mutableStateOf<String?>(null)
    /** Where Google Play manages this customer's subscription. */
    var managementUrl by mutableStateOf<String?>(null)
        private set

    /** Haptics for the UI to play. */
    var onFeedback: ((StoreFeedback) -> Unit)? = null

    private var updates: Job? = null

    // Shorthands

    val isConfigured: Boolean get() = client.isConfigured
    val isPro: Boolean get() = entitlements.isPro
    val isPlayerUnlocked: Boolean get() = entitlements.unlocksPlayer
    fun unlocks(feature: ProFeature): Boolean = entitlements.unlocks(feature)
    val proOption: UnlockOption? get() = storefront.proOption
    val tips: List<TipOption> get() = storefront.tips
    /** Pro's price couldn't be loaded: the paywall offers Try again. */
    val proOptionFailed: Boolean get() = !isLoadingOptions && storefront.proFailed
    /** No tip loaded: the Support screen shows its no-tips state with Try again. */
    val tipsFailed: Boolean get() = !isLoadingOptions && storefront.tipsFailed
    val purchasing: Boolean get() = purchasingId != null
    /** The first milestone's name. */
    val hasLoaded: Boolean get() = hasLoadedEntitlements

    /** Google Play's page for this subscription, to change or cancel it. */
    val manageSubscriptionUrl: String
        get() = managementUrl ?: "https://play.google.com/store/account/subscriptions?sku=${PurchaseConfig.PRO_PRODUCT_ID}&package=$packageName"

    /** Configures RevenueCat, then follows what this customer owns. Once, at launch. */
    fun start() {
        if (updates != null || hasLoadedEntitlements && forced != null) return
        forced?.let { given ->
            apply(CustomerSnapshot(given.active, given.purchased))
            return
        }
        client.configure()
        if (!client.isConfigured) {
            hasLoadedEntitlements = true
            Analytics.setEntitlements(entitlements)
            return
        }
        updates = scope.launch { client.customerUpdates().collect { apply(it) } }
        scope.launch {
            try {
                apply(client.customer())
            } catch (e: Exception) {
                Analytics.error(ErrorDomain.Purchase, "customer_info", e)
            }
        }
    }

    /**
     * Debug launches only (`uiDebugPro`, `uiDebugFree`, `uiDebugPaywall`): prices
     * from [client] (the preview store) and, when [entitlements] is given, that
     * answer whatever RevenueCat says.
     */
    fun useForDebug(client: PurchasesClient, entitlements: Entitlements?) {
        updates?.cancel()
        updates = null
        this.client = client
        forced = entitlements
        storefront = Storefront()
        apply(CustomerSnapshot(entitlements?.active.orEmpty(), entitlements?.purchased.orEmpty()))
    }

    /**
     * Loads the offering (Pro's package and price) and the tips' prices.
     * Each is judged on its own; what loaded before is kept, so a retry
     * only has to find what is missing.
     */
    suspend fun loadStorefront() {
        if (isLoadingOptions) return
        isLoadingOptions = true
        try {
            val offering = try {
                client.offering(PurchaseConfig.OFFERING_ID)
            } catch (e: Exception) {
                Analytics.error(ErrorDomain.Products, e)
                null
            }
            val tipPrices = client.prices(PurchaseConfig.TIP_PRODUCT_IDS)
            var next = Storefront.from(offering, tipPrices)
            next.proOption?.let { option ->
                next = next.copy(proOption = option.copy(isTrialEligible = client.isEligibleForTrial(option.pkg)))
            }
            storefront = storefront.keeping(next)
            if (storefront.proFailed) Analytics.error(ErrorDomain.Products, "no_pro_option")
            if (storefront.tipsFailed) Analytics.error(ErrorDomain.Products, "no_tips")
        } finally {
            isLoadingOptions = false
        }
    }

    /**
     * Buys Pro. True when Pro is active afterwards. `feature` is what the
     * paywall led with, for analytics; the product is sent as its ID.
     */
    suspend fun purchase(activity: Activity?, option: UnlockOption, feature: ProFeature): Boolean {
        Analytics.track(AnalyticsEvent.PurchaseStarted(option.id, feature))
        purchasingId = option.id
        try {
            when (val outcome = client.purchase(activity, option.pkg)) {
                is PurchaseOutcome.Completed -> {
                    apply(outcome.customer)
                    if (isPro) {
                        onFeedback?.invoke(StoreFeedback.PurchaseComplete)
                        Analytics.track(AnalyticsEvent.PurchaseCompleted(option.id, feature))
                    } else {
                        message = "The purchase went through, but Advent Praise Pro isn’t active yet. Try Restore purchases."
                        onFeedback?.invoke(StoreFeedback.Warning)
                        Analytics.track(AnalyticsEvent.PurchaseFailed(option.id, feature, PurchaseFailure.NotActivated))
                    }
                }
                PurchaseOutcome.Cancelled -> Analytics.track(AnalyticsEvent.PurchaseCancelled(option.id, feature))
                PurchaseOutcome.Pending -> {
                    message = "Your purchase is waiting for approval. Advent Praise Pro unlocks as soon as it’s approved."
                    onFeedback?.invoke(StoreFeedback.Warning)
                    Analytics.track(AnalyticsEvent.PurchaseFailed(option.id, feature, PurchaseFailure.Pending))
                }
                is PurchaseOutcome.Failed -> if (outcome.reason == PurchaseFailure.Unavailable) {
                    message = "Advent Praise Pro isn’t available right now. Check your connection and try again."
                    onFeedback?.invoke(StoreFeedback.Warning)
                    Analytics.track(AnalyticsEvent.PurchaseFailed(option.id, feature, PurchaseFailure.Unavailable))
                    purchasingId = null
                    loadStorefront()
                } else {
                    message = outcome.message
                    onFeedback?.invoke(StoreFeedback.Error)
                    Analytics.track(AnalyticsEvent.PurchaseFailed(option.id, feature, outcome.reason))
                }
            }
        } finally {
            purchasingId = null
        }
        return isPro
    }

    /** Buys a tip. It unlocks nothing; success sets [thankYouForTip]. */
    suspend fun tip(activity: Activity?, tip: TipOption) {
        Analytics.track(AnalyticsEvent.TipStarted(tip.id))
        tipping = tip.id
        try {
            when (val outcome = client.purchase(activity, tip.id)) {
                is PurchaseOutcome.Completed -> {
                    onFeedback?.invoke(StoreFeedback.PurchaseComplete)
                    Analytics.track(AnalyticsEvent.TipCompleted(tip.id))
                    thankYouForTip = tip
                }
                PurchaseOutcome.Cancelled -> Analytics.track(AnalyticsEvent.TipCancelled(tip.id))
                PurchaseOutcome.Pending -> {
                    message = "Your tip is waiting for approval. Thank you all the same."
                    onFeedback?.invoke(StoreFeedback.Warning)
                    Analytics.track(AnalyticsEvent.TipFailed(tip.id, PurchaseFailure.Pending))
                }
                is PurchaseOutcome.Failed -> if (outcome.reason == PurchaseFailure.Unavailable) {
                    message = "Tips aren’t available right now. Check your connection and try again."
                    onFeedback?.invoke(StoreFeedback.Warning)
                    Analytics.track(AnalyticsEvent.TipFailed(tip.id, PurchaseFailure.Unavailable))
                    tipping = null
                    loadStorefront()
                } else {
                    message = outcome.message
                    onFeedback?.invoke(StoreFeedback.Error)
                    Analytics.track(AnalyticsEvent.TipFailed(tip.id, outcome.reason))
                }
            }
        } finally {
            tipping = null
        }
    }

    /** Re-syncs this Google Account's purchases. */
    suspend fun restore(source: RestoreSource) {
        Analytics.track(AnalyticsEvent.RestoreStarted(source))
        isRestoring = true
        try {
            when (val outcome = client.restore()) {
                RestoreOutcome.Cancelled -> Analytics.track(AnalyticsEvent.RestoreFailed)
                RestoreOutcome.Failed -> {
                    message = "Couldn’t restore purchases. Check your connection and try again."
                    onFeedback?.invoke(StoreFeedback.Error)
                    Analytics.track(AnalyticsEvent.RestoreFailed)
                }
                is RestoreOutcome.Restored -> {
                    apply(outcome.customer)
                    message = when {
                        isPro -> "Advent Praise Pro has been restored."
                        !entitlements.hasPurchases -> "No previous purchases were found for this Google Account."
                        else -> "Your purchases have been restored. Advent Praise Pro isn’t among them."
                    }
                    onFeedback?.invoke(if (isPro) StoreFeedback.Success else StoreFeedback.Warning)
                    Analytics.track(AnalyticsEvent.RestoreCompleted(entitlements.hasPurchases, isPro))
                }
            }
        } finally {
            isRestoring = false
        }
    }

    @Deprecated("Use RestoreSource", ReplaceWith("restore(RestoreSource)"))
    suspend fun restore(source: String) = restore(RestoreSource.entries.firstOrNull { it.key == source } ?: RestoreSource.More)

    private fun apply(customer: CustomerSnapshot) {
        entitlements = forced ?: Entitlements(customer.activeEntitlements, customer.purchasedProductIds)
        managementUrl = customer.managementUrl
        hasLoadedEntitlements = true
        Analytics.setEntitlements(entitlements)
    }
}
