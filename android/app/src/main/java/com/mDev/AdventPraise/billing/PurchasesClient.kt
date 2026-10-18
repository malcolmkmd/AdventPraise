package com.mDev.AdventPraise.billing

import android.app.Activity
import android.app.Application
import com.mDev.AdventPraise.BuildConfig
import com.mDev.AdventPraise.analytics.Analytics
import com.mDev.AdventPraise.analytics.ErrorDomain
import com.mDev.AdventPraise.analytics.PurchaseFailure
import com.revenuecat.purchases.CustomerInfo
import com.revenuecat.purchases.LogLevel
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.ProductType
import com.revenuecat.purchases.PurchaseParams
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import com.revenuecat.purchases.PurchasesErrorCode
import com.revenuecat.purchases.PurchasesException
import com.revenuecat.purchases.PurchasesTransactionException
import com.revenuecat.purchases.awaitCustomerInfo
import com.revenuecat.purchases.awaitGetProducts
import com.revenuecat.purchases.awaitOfferings
import com.revenuecat.purchases.awaitPurchase
import com.revenuecat.purchases.awaitRestore
import com.revenuecat.purchases.interfaces.UpdatedCustomerInfoListener
import com.revenuecat.purchases.models.Period
import com.revenuecat.purchases.models.StoreProduct
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.emptyFlow
import kotlinx.coroutines.flow.onStart

// Values: PurchaseStore only ever sees these (PurchasesClient.swift).

/** What RevenueCat says about this customer. */
data class CustomerSnapshot(
    /** Active entitlement identifiers ("pro"). */
    val activeEntitlements: Set<String> = emptySet(),
    /** Products bought, tips left out. */
    val purchasedProductIds: Set<String> = emptySet(),
    /** Where Google Play manages this customer's subscription. */
    val managementUrl: String? = null,
)

/** A subscription's length, as the store gives it. */
data class SubscriptionTerm(val value: Int, val unit: Unit) {
    enum class Unit { Day, Week, Month, Year }

    /** In days, roughly (a free trial is days or weeks). */
    val days: Int
        get() = when (unit) {
            Unit.Day -> value
            Unit.Week -> value * 7
            Unit.Month -> value * 30
            Unit.Year -> value * 365
        }
}

/** One package of an offering, with its Google Play price. */
data class OfferingPackage(
    /** The RevenueCat package identifier ("\$rc_annual"). */
    val id: String,
    /** The store product behind it ("ap_pro_annual"; Google Play's base plan is left off). */
    val productId: String,
    /** Google Play's localized price: "R199.99". */
    val price: String,
    /** How long one period of a subscription is; null for a one-time product. */
    val period: SubscriptionTerm? = null,
    /** The free trial, if the product offers one. */
    val freeTrial: SubscriptionTerm? = null,
)

/** An offering as the paywall needs it. */
data class OfferingSnapshot(val id: String, val packages: List<OfferingPackage>)

/** How one purchase ended. */
sealed interface PurchaseOutcome {
    /** Paid, with what the customer has now. */
    data class Completed(val customer: CustomerSnapshot) : PurchaseOutcome
    data object Cancelled : PurchaseOutcome
    /** A pending payment: it may still go through. */
    data object Pending : PurchaseOutcome
    /** `message` is for the buyer; the reason is for analytics. */
    data class Failed(val reason: PurchaseFailure, val message: String) : PurchaseOutcome
}

/** How Restore purchases ended. */
sealed interface RestoreOutcome {
    data class Restored(val customer: CustomerSnapshot) : RestoreOutcome
    data object Cancelled : RestoreOutcome
    data object Failed : RestoreOutcome
}

/**
 * The one door to RevenueCat. [PurchaseStore] talks to this and only sees
 * plain values, so its rules can be tested with a stand-in and no network.
 */
interface PurchasesClient {
    /** Has an API key, so RevenueCat can be asked anything. */
    val isConfigured: Boolean
    /** Once, at launch. */
    fun configure()
    /** The customer after every change (purchases on another device, approvals, refunds). */
    fun customerUpdates(): Flow<CustomerSnapshot>
    suspend fun customer(): CustomerSnapshot
    /** The offering by identifier, or the current one; null when none is set up. Throws when it can't load. */
    suspend fun offering(id: String?): OfferingSnapshot?
    /** Google Play prices by product ID, for the products that loaded. */
    suspend fun prices(productIds: List<String>): Map<String, String>
    /** Whether this Google Account can still have the free trial of a package of the last offering loaded. */
    suspend fun isEligibleForTrial(pkg: OfferingPackage): Boolean
    /** Buys a package of the last offering loaded. Google Play needs the activity on screen. */
    suspend fun purchase(activity: Activity?, pkg: OfferingPackage): PurchaseOutcome
    /** Buys a product by ID (a tip) whose price was loaded. */
    suspend fun purchase(activity: Activity?, productId: String): PurchaseOutcome
    suspend fun restore(): RestoreOutcome
}

object PurchasesClients {
    /** The client the app runs with: RevenueCat with a key; debug builds without one get the preview store. */
    fun live(app: Application): PurchasesClient {
        if (BuildConfig.REVENUECAT_API_KEY.isEmpty() && BuildConfig.DEBUG) return PreviewPurchasesClient()
        return RevenueCatPurchasesClient(app, BuildConfig.REVENUECAT_API_KEY)
    }
}

/** RevenueCat's Android SDK: the same project and `pro` entitlement as iOS. */
class RevenueCatPurchasesClient(private val app: Application, private val apiKey: String) : PurchasesClient {
    /** The packages of the last offering loaded, and tip products, by ID. */
    private val packages = mutableMapOf<String, Package>()
    private val products = mutableMapOf<String, StoreProduct>()
    private val updates = MutableSharedFlow<CustomerSnapshot>(replay = 1, extraBufferCapacity = 8, onBufferOverflow = BufferOverflow.DROP_OLDEST)

    override val isConfigured: Boolean get() = apiKey.isNotEmpty() && Purchases.isConfigured

    override fun configure() {
        if (apiKey.isEmpty() || Purchases.isConfigured) return
        Purchases.logLevel = if (BuildConfig.DEBUG) LogLevel.DEBUG else LogLevel.WARN
        Purchases.configure(PurchasesConfiguration.Builder(app, apiKey).build())
        Purchases.sharedInstance.updatedCustomerInfoListener = UpdatedCustomerInfoListener { updates.tryEmit(snapshot(it)) }
    }

    override fun customerUpdates(): Flow<CustomerSnapshot> = if (isConfigured) updates else emptyFlow()

    override suspend fun customer(): CustomerSnapshot =
        if (!isConfigured) CustomerSnapshot() else snapshot(Purchases.sharedInstance.awaitCustomerInfo())

    override suspend fun offering(id: String?): OfferingSnapshot? {
        if (!isConfigured) return null
        val offerings = Purchases.sharedInstance.awaitOfferings()
        val offering = id?.let { offerings[it] } ?: offerings.current ?: return null
        for (pkg in offering.availablePackages) packages[pkg.identifier] = pkg
        return OfferingSnapshot(offering.identifier, offering.availablePackages.map { pkg ->
            val product = pkg.product
            OfferingPackage(
                id = pkg.identifier,
                productId = product.id.substringBefore(':'),
                price = product.price.formatted,
                period = product.period?.let(::term),
                freeTrial = product.subscriptionOptions?.freeTrial?.freePhase?.billingPeriod?.let(::term),
            )
        })
    }

    /** Google Play only offers a free phase to accounts that can still have it: the default option carries it then. */
    override suspend fun isEligibleForTrial(pkg: OfferingPackage): Boolean {
        if (!isConfigured || pkg.freeTrial == null) return false
        return packages[pkg.id]?.product?.defaultOption?.freePhase != null
    }

    override suspend fun prices(productIds: List<String>): Map<String, String> {
        if (!isConfigured) return emptyMap()
        return try {
            Purchases.sharedInstance.awaitGetProducts(productIds, ProductType.INAPP).associate { product ->
                products[product.id] = product
                product.id to product.price.formatted
            }
        } catch (e: PurchasesException) {
            Analytics.error(ErrorDomain.Products, "tips.${e.code.code}", e)
            emptyMap()
        }
    }

    override suspend fun purchase(activity: Activity?, pkg: OfferingPackage): PurchaseOutcome {
        val found = packages[pkg.id]
        if (!isConfigured || found == null || activity == null) return unavailable
        return attempt { Purchases.sharedInstance.awaitPurchase(PurchaseParams.Builder(activity, found).build()).customerInfo }
    }

    override suspend fun purchase(activity: Activity?, productId: String): PurchaseOutcome {
        val product = products[productId]
        if (!isConfigured || product == null || activity == null) return unavailable
        return attempt { Purchases.sharedInstance.awaitPurchase(PurchaseParams.Builder(activity, product).build()).customerInfo }
    }

    override suspend fun restore(): RestoreOutcome {
        if (!isConfigured) return RestoreOutcome.Failed
        return try {
            RestoreOutcome.Restored(snapshot(Purchases.sharedInstance.awaitRestore()))
        } catch (e: PurchasesException) {
            if (e.code == PurchasesErrorCode.PurchaseCancelledError) return RestoreOutcome.Cancelled
            Analytics.error(ErrorDomain.Restore, "${e.code.code}", e)
            RestoreOutcome.Failed
        }
    }

    private suspend fun attempt(buy: suspend () -> CustomerInfo): PurchaseOutcome = try {
        PurchaseOutcome.Completed(snapshot(buy()))
    } catch (e: PurchasesTransactionException) {
        if (e.userCancelled) PurchaseOutcome.Cancelled else outcome(e.code, e)
    } catch (e: PurchasesException) {
        outcome(e.code, e)
    }

    private fun term(period: Period): SubscriptionTerm? {
        val unit = when (period.unit) {
            Period.Unit.DAY -> SubscriptionTerm.Unit.Day
            Period.Unit.WEEK -> SubscriptionTerm.Unit.Week
            Period.Unit.MONTH -> SubscriptionTerm.Unit.Month
            Period.Unit.YEAR -> SubscriptionTerm.Unit.Year
            else -> return null
        }
        return SubscriptionTerm(period.value, unit)
    }

    private fun snapshot(info: CustomerInfo) = CustomerSnapshot(
        activeEntitlements = info.entitlements.active.keys,
        purchasedProductIds = info.allPurchasedProductIds.map { it.substringBefore(':') }.toSet() - PurchaseConfig.TIP_PRODUCT_IDS.toSet(),
        managementUrl = info.managementURL?.toString(),
    )

    /**
     * RevenueCat's errors in the words iOS uses, Google Play standing in for
     * the App Store. The buyer is never told they were charged when they weren't.
     */
    private fun outcome(code: PurchasesErrorCode, error: Throwable): PurchaseOutcome = when (code) {
        PurchasesErrorCode.PurchaseCancelledError -> PurchaseOutcome.Cancelled
        PurchasesErrorCode.PaymentPendingError -> PurchaseOutcome.Pending
        PurchasesErrorCode.NetworkError -> PurchaseOutcome.Failed(PurchaseFailure.StoreError,
            "Couldn’t reach Google Play. Check your connection and try again. You haven’t been charged.")
        PurchasesErrorCode.PurchaseNotAllowedError -> PurchaseOutcome.Failed(PurchaseFailure.NotAllowed,
            "Purchases aren’t allowed on this device.")
        PurchasesErrorCode.ProductNotAvailableForPurchaseError -> unavailable
        PurchasesErrorCode.ProductAlreadyPurchasedError -> PurchaseOutcome.Failed(PurchaseFailure.StoreError,
            "This Google Account already owns Advent Praise Pro. Try Restore purchases.")
        PurchasesErrorCode.InvalidReceiptError, PurchasesErrorCode.MissingReceiptFileError -> {
            Analytics.error(ErrorDomain.Purchase, "${code.code}", error)
            PurchaseOutcome.Failed(PurchaseFailure.Unverified, "Google Play couldn’t confirm this purchase. Try Restore purchases in a moment.")
        }
        else -> {
            Analytics.error(ErrorDomain.Purchase, "${code.code}", error)
            PurchaseOutcome.Failed(PurchaseFailure.StoreError, "The purchase didn’t go through. You haven’t been charged.")
        }
    }

    private companion object {
        val unavailable = PurchaseOutcome.Failed(PurchaseFailure.Unavailable,
            "This isn’t available right now. Check your connection and try again.")
    }
}

/**
 * Fixed prices (the iOS StoreKit configuration's, in rand) and purchases
 * that pretend to go through: previews, screenshot tests and debug builds
 * without a RevenueCat key. Never in a release build.
 */
class PreviewPurchasesClient(private val trialUsed: Boolean = false) : PurchasesClient {
    private var current = CustomerSnapshot()
    private val updates = MutableSharedFlow<CustomerSnapshot>(replay = 1, extraBufferCapacity = 8)

    override val isConfigured = true
    override fun configure() {}
    override fun customerUpdates(): Flow<CustomerSnapshot> = updates.onStart { emit(current) }
    override suspend fun customer() = current

    override suspend fun offering(id: String?) = OfferingSnapshot("default", listOf(
        OfferingPackage(PurchaseConfig.PRO_PACKAGE_ID, PurchaseConfig.PRO_PRODUCT_ID, PRO_PRICE,
            SubscriptionTerm(1, SubscriptionTerm.Unit.Year), SubscriptionTerm(3, SubscriptionTerm.Unit.Day)),
        OfferingPackage("\$rc_lifetime", PurchaseConfig.LEGACY_LIFETIME_PRODUCT_ID, LIFETIME_PRICE),
    ))

    override suspend fun prices(productIds: List<String>) = TIP_PRICES.filterKeys { it in productIds }
    override suspend fun isEligibleForTrial(pkg: OfferingPackage) = pkg.freeTrial != null && !trialUsed

    override suspend fun purchase(activity: Activity?, pkg: OfferingPackage): PurchaseOutcome {
        delay(600)
        current = current.copy(
            activeEntitlements = current.activeEntitlements + PurchaseConfig.PRO_ENTITLEMENT,
            purchasedProductIds = current.purchasedProductIds + pkg.productId,
        )
        updates.tryEmit(current)
        return PurchaseOutcome.Completed(current)
    }

    override suspend fun purchase(activity: Activity?, productId: String): PurchaseOutcome {
        delay(600)
        return PurchaseOutcome.Completed(current)
    }

    override suspend fun restore(): RestoreOutcome = RestoreOutcome.Restored(current)

    companion object {
        const val PRO_PRICE = "R199.99"
        const val LIFETIME_PRICE = "R349.99"
        val TIP_PRICES = mapOf("ap_tip_amen" to "R19.99", "ap_tip_hallelujah" to "R49.99", "ap_tip_hosanna" to "R99.99")
    }
}
