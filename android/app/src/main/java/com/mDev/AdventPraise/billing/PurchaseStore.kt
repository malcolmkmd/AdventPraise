package com.mDev.AdventPraise.billing

import android.app.Activity
import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.mDev.AdventPraise.BuildConfig
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.revenuecat.purchases.CustomerInfo
import com.revenuecat.purchases.LogLevel
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.PurchaseParams
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import com.revenuecat.purchases.PurchasesErrorCode
import com.revenuecat.purchases.PurchasesException
import com.revenuecat.purchases.PurchasesTransactionException
import com.revenuecat.purchases.awaitCustomerInfo
import com.revenuecat.purchases.awaitOfferings
import com.revenuecat.purchases.awaitPurchase
import com.revenuecat.purchases.awaitRestore
import com.revenuecat.purchases.interfaces.UpdatedCustomerInfoListener
import com.revenuecat.purchases.models.Period
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/** The RevenueCat set-up, shared with iOS (PurchaseConfig.swift, docs/revenuecat.md). */
object PurchaseConfig {
    /** The entitlement that is Pro. */
    const val PRO_ENTITLEMENT = "pro"
    /**
     * Pro: the annual auto-renewing subscription with a free trial. Same
     * product ID on Google Play as on the App Store; its base plan is
     * `annual`, so RevenueCat calls it "ap_pro_annual:annual".
     */
    const val ANNUAL_PRODUCT_ID = "ap_pro_annual"
    /** The offering the paywall shows; null is RevenueCat's current offering. */
    val OFFERING_ID: String? = null
    /** One-off tips, cheapest first (consumables; no entitlement). Not sold on Android yet. */
    val TIP_PRODUCT_IDS = listOf("ap_tip_amen", "ap_tip_hallelujah", "ap_tip_hosanna")
}

/** Something Pro unlocks; the paywall leads with it. `analyticsName` is iOS's. */
enum class ProFeature(val analyticsName: String) {
    Player("player"),
    Support("support"),
}

/** A subscription's length, or a free trial's: "1 year", "3 days". */
data class BillingPeriod(val value: Int, val unit: String) {
    val length: String get() = "$value $unit${if (value == 1) "" else "s"}"
    val per: String get() = if (value == 1) "/$unit" else "/$length"
}

/**
 * Pro as the paywall sells it: the offering's annual package with its
 * Google Play price and the free trial this account can still start.
 */
data class UnlockOption(
    val packageId: String,
    val productId: String,
    val price: String,
    val period: BillingPeriod?,
    val freeTrial: BillingPeriod?,
) {
    /** "3 days free, then R199.99/year. Cancel anytime." (iOS's words.) */
    val offer: String
        get() {
            val price = price + (period?.per ?: "")
            return freeTrial?.let { "${it.length} free, then $price. Cancel anytime." } ?: "$price. Cancel anytime."
        }
    val buttonTitle: String get() = if (freeTrial != null) "Start free trial" else "Subscribe · $price${period?.per ?: ""}"
    val renewalTerms: String
        get() {
            val charge = if (freeTrial == null) "Payment is charged to your Google Play account when you confirm."
            else "Payment is charged to your Google Play account when the free trial ends, unless you cancel before then."
            val every = period?.let { if (it.value == 1) "every ${it.unit}" else "every ${it.length}" } ?: "every period"
            return "$charge Advent Praise Pro renews automatically $every at the same price until you cancel. " +
                "Manage or cancel in Google Play › Payments & subscriptions."
        }
}

/**
 * Purchases through RevenueCat, the same project and `pro` entitlement as
 * iOS. The paywall is fed from the current offering (the Lifetime package
 * selling `ap_pro_lifetime`); what is owned is whatever CustomerInfo says,
 * read at launch, after every purchase and restore, and on every change
 * RevenueCat reports. The messages and analytics match iOS.
 */
class PurchaseStore(private val app: Application, private val scope: CoroutineScope) {
    var isPro by mutableStateOf(false)
        private set
    var hasLoaded by mutableStateOf(false)
        private set
    var proOption by mutableStateOf<UnlockOption?>(null)
        private set
    var isLoadingOptions by mutableStateOf(false)
        private set
    var purchasing by mutableStateOf(false)
        private set
    var isRestoring by mutableStateOf(false)
        private set
    var message by mutableStateOf<String?>(null)

    private var packages: Map<String, Package> = emptyMap()
    private var purchasedProducts: Set<String> = emptySet()
    /** Where Google Play manages this customer's subscription. */
    var managementUrl by mutableStateOf<String?>(null)
        private set

    val isConfigured: Boolean get() = BuildConfig.REVENUECAT_API_KEY.isNotEmpty()
    val proOptionFailed: Boolean get() = !isLoadingOptions && proOption == null

    fun start() {
        if (!isConfigured) {
            hasLoaded = true
            Analytics.setPro(false)
            return
        }
        Purchases.logLevel = if (BuildConfig.DEBUG) LogLevel.DEBUG else LogLevel.WARN
        Purchases.configure(PurchasesConfiguration.Builder(app, BuildConfig.REVENUECAT_API_KEY).build())
        Purchases.sharedInstance.updatedCustomerInfoListener = UpdatedCustomerInfoListener { apply(it) }
        scope.launch {
            try {
                apply(Purchases.sharedInstance.awaitCustomerInfo())
            } catch (e: PurchasesException) {
                Analytics.error("purchase", "customer_info.${e.code.code}")
            }
        }
    }

    /** Loads Pro's package and price from the offering. What loaded before is kept. */
    suspend fun loadStorefront() {
        if (isLoadingOptions) return
        if (!isConfigured) { proOption = null; return }
        isLoadingOptions = true
        try {
            val offerings = Purchases.sharedInstance.awaitOfferings()
            val offering = PurchaseConfig.OFFERING_ID?.let { offerings[it] } ?: offerings.current
            // The package selling the annual subscription (the Annual package first).
            val pro = offering?.availablePackages.orEmpty()
                .filter { it.product.id.substringBefore(':') == PurchaseConfig.ANNUAL_PRODUCT_ID }
            val chosen = pro.firstOrNull { it.identifier == "\$rc_annual" } ?: pro.firstOrNull()
            if (chosen != null) {
                packages = packages + (chosen.identifier to chosen)
                val product = chosen.product
                proOption = UnlockOption(
                    packageId = chosen.identifier,
                    productId = product.id,
                    price = product.price.formatted,
                    period = product.period?.let(::period),
                    // Google Play only offers the free phase to accounts that can still have it.
                    freeTrial = product.defaultOption?.freePhase?.billingPeriod?.let(::period),
                )
            }
        } catch (e: PurchasesException) {
            Analytics.error("products", "${e.code.code}")
        } finally {
            isLoadingOptions = false
        }
        if (proOption == null) Analytics.error("products", "no_pro_option")
    }

    /** Buys Pro. True when Pro is active afterwards. */
    suspend fun purchase(activity: Activity, option: UnlockOption, feature: ProFeature): Boolean {
        val product = option.productId
        Analytics.track(AnalyticsEvent.PurchaseStarted(product, feature.analyticsName))
        val pkg = packages[option.packageId]
        if (!isConfigured || pkg == null) {
            message = "Advent Praise Pro isn’t available right now. Check your connection and try again."
            Analytics.track(AnalyticsEvent.PurchaseFailed(product, feature.analyticsName, "unavailable"))
            loadStorefront()
            return false
        }
        purchasing = true
        try {
            val result = Purchases.sharedInstance.awaitPurchase(PurchaseParams.Builder(activity, pkg).build())
            apply(result.customerInfo)
            if (isPro) {
                Analytics.track(AnalyticsEvent.PurchaseCompleted(product, feature.analyticsName))
            } else {
                message = "The purchase went through, but Advent Praise Pro isn’t active yet. Try Restore purchases."
                Analytics.track(AnalyticsEvent.PurchaseFailed(product, feature.analyticsName, "not_activated"))
            }
        } catch (e: PurchasesTransactionException) {
            if (e.userCancelled || e.code == PurchasesErrorCode.PurchaseCancelledError) {
                Analytics.track(AnalyticsEvent.PurchaseCancelled(product, feature.analyticsName))
            } else {
                val (reason, text) = failure(e.code)
                message = text
                Analytics.track(AnalyticsEvent.PurchaseFailed(product, feature.analyticsName, reason))
                if (reason == "store_error") Analytics.error("purchase", "${e.code.code}")
            }
        } catch (e: PurchasesException) {
            val (reason, text) = failure(e.code)
            message = text
            Analytics.track(AnalyticsEvent.PurchaseFailed(product, feature.analyticsName, reason))
        } finally {
            purchasing = false
        }
        return isPro
    }

    /** Re-syncs this Google Account's purchases. */
    suspend fun restore(source: String) {
        Analytics.track(AnalyticsEvent.RestoreStarted(source))
        if (!isConfigured) {
            message = "Couldn’t restore purchases. Check your connection and try again."
            Analytics.track(AnalyticsEvent.RestoreFailed)
            return
        }
        isRestoring = true
        try {
            apply(Purchases.sharedInstance.awaitRestore())
            message = when {
                isPro -> "Advent Praise Pro has been restored."
                purchasedProducts.isEmpty() -> "No previous purchases were found for this Google Account."
                else -> "Your purchases have been restored. Advent Praise Pro isn’t among them."
            }
            Analytics.track(AnalyticsEvent.RestoreCompleted(purchasedProducts.isNotEmpty(), isPro))
        } catch (e: PurchasesException) {
            message = "Couldn’t restore purchases. Check your connection and try again."
            Analytics.track(AnalyticsEvent.RestoreFailed)
            Analytics.error("restore", "${e.code.code}")
        } finally {
            isRestoring = false
        }
    }

    private fun apply(info: CustomerInfo) {
        isPro = info.entitlements.active.containsKey(PurchaseConfig.PRO_ENTITLEMENT)
        purchasedProducts = info.allPurchasedProductIds - PurchaseConfig.TIP_PRODUCT_IDS.toSet()
        managementUrl = info.managementURL?.toString()
        hasLoaded = true
        Analytics.setPro(isPro)
    }

    /** Google Play's page for this subscription, to change or cancel it. */
    val manageSubscriptionUrl: String
        get() = managementUrl ?: "https://play.google.com/store/account/subscriptions?sku=" +
            "${PurchaseConfig.ANNUAL_PRODUCT_ID}&package=${app.packageName}"

    private fun period(p: Period): BillingPeriod? {
        val unit = when (p.unit) {
            Period.Unit.DAY -> "day"
            Period.Unit.WEEK -> "week"
            Period.Unit.MONTH -> "month"
            Period.Unit.YEAR -> "year"
            else -> return null
        }
        return BillingPeriod(p.value, unit)
    }

    /** RevenueCat's errors in the words iOS uses; Google Play stands in for the App Store. */
    private fun failure(code: PurchasesErrorCode): Pair<String, String> = when (code) {
        PurchasesErrorCode.PaymentPendingError ->
            "pending" to "Your purchase is waiting for approval. Advent Praise Pro unlocks as soon as it’s approved."
        PurchasesErrorCode.NetworkError ->
            "store_error" to "Couldn’t reach Google Play. Check your connection and try again. You haven’t been charged."
        PurchasesErrorCode.PurchaseNotAllowedError ->
            "not_allowed" to "Purchases aren’t allowed on this device."
        PurchasesErrorCode.ProductNotAvailableForPurchaseError ->
            "unavailable" to "Advent Praise Pro isn’t available right now. Check your connection and try again."
        PurchasesErrorCode.ProductAlreadyPurchasedError ->
            "store_error" to "This Google Account already owns Advent Praise Pro. Try Restore purchases."
        else -> "store_error" to "The purchase didn’t go through. You haven’t been charged."
    }
}
