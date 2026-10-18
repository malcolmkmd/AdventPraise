package com.mDev.AdventPraise.billing

import android.app.Activity
import com.mDev.AdventPraise.analytics.AnalyticsEvent
import com.mDev.AdventPraise.analytics.PaywallContext
import com.mDev.AdventPraise.analytics.PaywallOutcome
import com.mDev.AdventPraise.analytics.PurchaseFailure
import com.mDev.AdventPraise.analytics.RestoreSource
import com.mDev.AdventPraise.settings.MemoryStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

private val annual = OfferingPackage("\$rc_annual", "ap_pro_annual", "R199.99",
    SubscriptionTerm(1, SubscriptionTerm.Unit.Year), SubscriptionTerm(3, SubscriptionTerm.Unit.Day))
private val lifetime = OfferingPackage("\$rc_lifetime", "ap_pro_lifetime", "R349.99")
private val proCustomer = CustomerSnapshot(setOf("pro"), setOf("ap_pro_annual"))
private val allFeatures = ProFeature.entries

/** RevenueCat as the store sees it, scripted per test (iOS FakePurchasesClient). */
class FakePurchasesClient : PurchasesClient {
    override var isConfigured = true
    var configureCount = 0
    var customerNow = CustomerSnapshot()
    var offering: OfferingSnapshot? = OfferingSnapshot("default", listOf(annual, lifetime))
    var trialEligible = true
    var offeringError: Exception? = null
    var offeringRequests = 0
    var tipPrices = mapOf("ap_tip_amen" to "R19.99", "ap_tip_hallelujah" to "R49.99", "ap_tip_hosanna" to "R99.99")
    /** null: the purchase goes through and the customer has Pro. */
    var nextPurchase: PurchaseOutcome? = null
    var nextRestore: RestoreOutcome = RestoreOutcome.Restored(CustomerSnapshot())
    val boughtPackages = mutableListOf<String>()
    val boughtProducts = mutableListOf<String>()
    private val updates = MutableSharedFlow<CustomerSnapshot>(extraBufferCapacity = 8)

    override fun configure() { configureCount++ }
    override fun customerUpdates(): Flow<CustomerSnapshot> = updates
    fun report(customer: CustomerSnapshot) {
        customerNow = customer
        updates.tryEmit(customer)
    }
    override suspend fun customer() = customerNow
    override suspend fun offering(id: String?): OfferingSnapshot? {
        offeringRequests++
        offeringError?.let { throw it }
        return offering
    }
    override suspend fun prices(productIds: List<String>) = tipPrices.filterKeys { it in productIds }
    override suspend fun isEligibleForTrial(pkg: OfferingPackage) = trialEligible && pkg.freeTrial != null
    override suspend fun purchase(activity: Activity?, pkg: OfferingPackage): PurchaseOutcome {
        boughtPackages += pkg.id
        nextPurchase?.let { return it }
        customerNow = proCustomer
        return PurchaseOutcome.Completed(customerNow)
    }
    override suspend fun purchase(activity: Activity?, productId: String): PurchaseOutcome {
        boughtProducts += productId
        return nextPurchase ?: PurchaseOutcome.Completed(customerNow)
    }
    override suspend fun restore() = nextRestore
}

class EntitlementsTest {
    @Test fun nothingActiveOpensNothing() {
        val none = Entitlements.none
        assertFalse(none.isPro || none.unlocksPlayer || none.hasPurchases)
        allFeatures.forEach { assertFalse("$it should be locked", none.unlocks(it)) }
    }

    @Test fun theProEntitlementOpensEverything() {
        val pro = Entitlements(setOf("pro"), setOf("ap_pro_annual"))
        assertTrue(pro.isPro && pro.unlocksPlayer)
        allFeatures.forEach { assertTrue("$it should be open", pro.unlocks(it)) }
    }

    @Test fun aMidiPianoBuyerIsPro() {
        val midi = Entitlements(setOf("pro"), setOf("ap_midi_unlock"))
        assertTrue(midi.isPro && midi.unlocks(ProFeature.AirPlay) && midi.unlocks(ProFeature.SheetMusic))
    }

    @Test fun productsWithoutTheEntitlementOpenNothing() {
        val owned = Entitlements(emptySet(), setOf("ap_hymnal_tswana", "ap_pro_annual"))
        assertFalse(owned.isPro)
        assertTrue(owned.hasPurchases)
        assertFalse(Entitlements(setOf("something_else")).isPro)
    }

    @Test fun theLiveProductIDsAreKept() {
        assertEquals("pro", PurchaseConfig.PRO_ENTITLEMENT)
        assertEquals("ap_pro_annual", PurchaseConfig.PRO_PRODUCT_ID)
        assertEquals("\$rc_annual", PurchaseConfig.PRO_PACKAGE_ID)
        assertEquals("ap_pro_lifetime", PurchaseConfig.LEGACY_LIFETIME_PRODUCT_ID)
        assertEquals("ap_midi_unlock", PurchaseConfig.LEGACY_MIDI_PRODUCT_ID)
        assertEquals(setOf("ap_pro_annual", "ap_pro_lifetime", "ap_midi_unlock"), PurchaseConfig.PRO_ENTITLEMENT_PRODUCT_IDS)
        assertEquals(listOf("ap_tip_amen", "ap_tip_hallelujah", "ap_tip_hosanna"), PurchaseConfig.TIP_PRODUCT_IDS)
        assertNull(PurchaseConfig.OFFERING_ID)
    }

    @Test fun featuresReportThemselvesToAnalyticsByName() {
        assertEquals(listOf("player", "air_play", "mirroring", "support", "sheet_music"), ProFeature.entries.map { it.analyticsName })
    }

    @Test fun thePaywallNeverShowsForPro() {
        val subscriber = Entitlements(setOf("pro"), setOf("ap_pro_annual"))
        val lifetimeOwner = Entitlements(setOf("pro"), setOf("ap_pro_lifetime"))
        val midiOwner = Entitlements(setOf("pro"), setOf("ap_midi_unlock"))
        assertTrue(ProPaywallRule.presents(ProFeature.Player, true, Entitlements.none))
        assertFalse(ProPaywallRule.presents(ProFeature.Player, false, Entitlements.none))
        assertFalse(ProPaywallRule.presents(null, true, Entitlements.none))
        for (owner in listOf(subscriber, lifetimeOwner, midiOwner)) assertFalse(ProPaywallRule.presents(ProFeature.Support, true, owner))
        assertTrue(subscriber.isSubscriber && !subscriber.ownsProForLife)
        assertTrue(lifetimeOwner.ownsProForLife && !lifetimeOwner.isSubscriber)
        assertTrue(midiOwner.ownsProForLife)
        assertFalse("a lapsed subscription", Entitlements(emptySet(), setOf("ap_pro_annual")).isPro)
    }
}

class StorefrontTest {
    private val tips = PurchaseConfig.TIP_PRODUCT_IDS
    private fun prices(ids: List<String>) = ids.associateWith { "R1.00" }

    @Test fun proComesFromTheOfferingsAnnualPackage() {
        val front = Storefront.from(OfferingSnapshot("default", listOf(lifetime, annual)), prices(tips))
        assertFalse(front.proFailed || front.tipsFailed || front.anyFailed)
        assertEquals("ap_pro_annual", front.proOption?.id)
        assertEquals("\$rc_annual", front.proOption?.pkg?.id)
        assertEquals("R199.99", front.proOption?.price)
        assertEquals(tips, front.tips.map { it.id })
    }

    @Test fun midiPianoAndLifetimeAreNeverOffered() {
        val midi = OfferingPackage("midi", "ap_midi_unlock", "R79.99")
        assertEquals("ap_pro_annual", Storefront.from(OfferingSnapshot("default", listOf(midi, annual)), emptyMap()).proOption?.id)
        assertTrue(Storefront.from(OfferingSnapshot("default", listOf(midi)), emptyMap()).proFailed)
        assertTrue(Storefront.from(OfferingSnapshot("default", listOf(lifetime)), emptyMap()).proFailed)
    }

    @Test fun theAnnualPackageWinsOverAnotherPackageOfPro() {
        val custom = OfferingPackage("pro_custom", "ap_pro_annual", "R199.99")
        assertEquals("\$rc_annual", Storefront.from(OfferingSnapshot("default", listOf(custom, annual)), emptyMap()).proOption?.pkg?.id)
    }

    @Test fun theOfferAndButtonFollowTrialEligibility() {
        val eligible = UnlockOption(annual, isTrialEligible = true)
        assertEquals("3 days free, then R199.99/year. Cancel anytime.", eligible.offerLine)
        assertEquals("Start 3-Day Free Trial", eligible.callToAction)
        assertTrue(eligible.renewalTerms.contains("when the free trial ends"))
        assertTrue(eligible.renewalTerms.contains("Renews automatically each year"))
        val used = UnlockOption(annual, isTrialEligible = false)
        assertEquals("R199.99/year. Cancel anytime.", used.offerLine)
        assertEquals("Subscribe", used.callToAction)
        assertTrue(used.renewalTerms.startsWith("Payment is charged to your Google Play account when you confirm."))
        val noTrial = UnlockOption(OfferingPackage("\$rc_annual", "ap_pro_annual", "\$11.99", SubscriptionTerm(1, SubscriptionTerm.Unit.Year)), true)
        assertEquals("\$11.99/year. Cancel anytime.", noTrial.offerLine)
        assertEquals("Subscribe", noTrial.callToAction)
        val week = UnlockOption(annual.copy(freeTrial = SubscriptionTerm(1, SubscriptionTerm.Unit.Week)), true)
        assertEquals("1 week free, then R199.99/year. Cancel anytime.", week.offerLine)
        assertEquals("Start 1-Week Free Trial", week.callToAction)
    }

    @Test fun eachScreenIsJudgedOnItsOwn() {
        val noOffering = Storefront.from(null, prices(tips))
        assertTrue(noOffering.proFailed)
        assertFalse(noOffering.tipsFailed)
        assertTrue(Storefront.from(OfferingSnapshot("default", listOf(annual)), emptyMap()).tipsFailed)
        val oneTip = Storefront.from(null, prices(listOf(tips[1])))
        assertEquals(listOf(tips[1]), oneTip.tips.map { it.id })
    }

    @Test fun aRetryKeepsWhatLoadedBefore() {
        val loaded = Storefront.from(OfferingSnapshot("default", listOf(annual)), prices(tips))
        assertEquals(loaded, loaded.keeping(Storefront.from(null, emptyMap())))
        assertEquals(loaded, Storefront().keeping(loaded))
    }
}

class PurchaseStoreTest {
    private fun store(client: FakePurchasesClient = FakePurchasesClient()) =
        PurchaseStore(client, CoroutineScope(Dispatchers.Unconfined))

    private fun loaded(client: FakePurchasesClient = FakePurchasesClient()) = store(client).also { runBlocking { it.loadStorefront() } }

    @Test fun thePaywallIsFedFromTheOffering() {
        val s = loaded()
        assertFalse(s.proOptionFailed || s.tipsFailed)
        val pro = s.proOption!!
        assertEquals("ap_pro_annual", pro.id)
        assertTrue(pro.isTrialEligible)
        assertEquals("3 days free, then R199.99/year. Cancel anytime.", pro.offerLine)
        assertEquals(listOf("R19.99", "R49.99", "R99.99"), s.tips.map { it.price })
    }

    @Test fun aFailedLoadOffersTryAgainOnEveryScreen() = runBlocking {
        val client = FakePurchasesClient().apply { offeringError = IllegalStateException("offline"); tipPrices = emptyMap() }
        val s = loaded(client)
        assertTrue(s.proOptionFailed && s.tipsFailed)
        client.offeringError = null
        client.tipPrices = mapOf("ap_tip_amen" to "R19.99")
        s.loadStorefront()
        assertFalse(s.proOptionFailed || s.tipsFailed)
        assertEquals("R199.99", s.proOption?.price)
    }

    @Test fun buyingProMakesItPro() = runBlocking {
        val client = FakePurchasesClient()
        val s = loaded(client)
        assertFalse(s.isPro)
        assertTrue(s.purchase(null, s.proOption!!, ProFeature.Player))
        assertEquals(listOf("\$rc_annual"), client.boughtPackages)
        assertTrue(s.isPro && s.isPlayerUnlocked && s.unlocks(ProFeature.AirPlay))
        assertFalse(s.purchasing)
        assertNull(s.message)
    }

    @Test fun cancellingSaysNothing() = runBlocking {
        val s = loaded(FakePurchasesClient().apply { nextPurchase = PurchaseOutcome.Cancelled })
        assertFalse(s.purchase(null, s.proOption!!, ProFeature.Player))
        assertNull(s.message)
    }

    @Test fun aPendingPaymentWaitsWithAFriendlyMessage() = runBlocking {
        val s = loaded(FakePurchasesClient().apply { nextPurchase = PurchaseOutcome.Pending })
        assertFalse(s.purchase(null, s.proOption!!, ProFeature.Player))
        assertTrue(s.message!!.contains("waiting for approval"))
    }

    @Test fun aPurchaseWithoutTheEntitlementSaysToRestore() = runBlocking {
        val s = loaded(FakePurchasesClient().apply { nextPurchase = PurchaseOutcome.Completed(CustomerSnapshot(emptySet(), setOf("ap_pro_lifetime"))) })
        assertFalse(s.purchase(null, s.proOption!!, ProFeature.SheetMusic))
        assertTrue(s.message!!.contains("isn’t active yet"))
    }

    @Test fun aStoreErrorShowsItsMessage() = runBlocking {
        val s = loaded(FakePurchasesClient().apply { nextPurchase = PurchaseOutcome.Failed(PurchaseFailure.NotAllowed, "Purchases aren’t allowed on this device.") })
        s.purchase(null, s.proOption!!, ProFeature.Player)
        assertEquals("Purchases aren’t allowed on this device.", s.message)
        assertFalse(s.isPro)
    }

    @Test fun anUnavailablePackageReloadsTheOffering() = runBlocking {
        val client = FakePurchasesClient().apply { nextPurchase = PurchaseOutcome.Failed(PurchaseFailure.Unavailable, "") }
        val s = loaded(client)
        assertEquals(1, client.offeringRequests)
        s.purchase(null, s.proOption!!, ProFeature.Player)
        assertTrue(s.message!!.contains("isn’t available right now"))
        assertEquals(2, client.offeringRequests)
    }

    @Test fun aTipUnlocksNothingAndSaysThankYou() = runBlocking {
        val client = FakePurchasesClient()
        val s = loaded(client)
        val tip = s.tips.first()
        s.tip(null, tip)
        assertEquals(listOf("ap_tip_amen"), client.boughtProducts)
        assertEquals(tip, s.thankYouForTip)
        assertFalse(s.isPro)
        assertNull(s.tipping)
    }

    @Test fun aCancelledTipSaysNothing() = runBlocking {
        val s = loaded(FakePurchasesClient().apply { nextPurchase = PurchaseOutcome.Cancelled })
        s.tip(null, s.tips.last())
        assertNull(s.thankYouForTip)
        assertNull(s.message)
    }

    @Test fun restoreSaysWhatItFound() = runBlocking {
        val cases = listOf(
            CustomerSnapshot(setOf("pro"), setOf("ap_pro_annual")) to "Advent Praise Pro has been restored.",
            CustomerSnapshot(setOf("pro"), setOf("ap_midi_unlock")) to "Advent Praise Pro has been restored.",
            CustomerSnapshot() to "No previous purchases were found for this Google Account.",
            CustomerSnapshot(emptySet(), setOf("ap_hymnal_tswana")) to "Your purchases have been restored. Advent Praise Pro isn’t among them.",
        )
        for ((customer, text) in cases) {
            val s = store(FakePurchasesClient().apply { nextRestore = RestoreOutcome.Restored(customer) })
            s.restore(RestoreSource.Paywall)
            assertEquals(text, s.message)
            assertFalse(s.isRestoring)
        }
        val cancelled = store(FakePurchasesClient().apply { nextRestore = RestoreOutcome.Cancelled })
        cancelled.restore(RestoreSource.Paywall)
        assertNull(cancelled.message)
        val failed = store(FakePurchasesClient().apply { nextRestore = RestoreOutcome.Failed })
        failed.restore(RestoreSource.More)
        assertTrue(failed.message!!.contains("Couldn’t restore purchases"))
    }

    @Test fun launchReadsWhatIsOwnedAndFollowsChanges() {
        val client = FakePurchasesClient().apply { customerNow = proCustomer }
        val s = store(client)
        s.start()
        assertEquals(1, client.configureCount)
        assertTrue(s.hasLoadedEntitlements && s.isPro)
        s.start()
        assertEquals("started once", 1, client.configureCount)
        client.report(CustomerSnapshot())   // refunded
        assertFalse(s.isPro)
        client.report(proCustomer)          // bought on another device
        assertTrue(s.isPro)
    }

    @Test fun withoutAKeyPurchasesStayOff() {
        val s = store(FakePurchasesClient().apply { isConfigured = false })
        s.start()
        assertTrue(s.hasLoadedEntitlements)
        assertFalse(s.isPro)
    }

    @Test fun someoneWhoHadTheTrialIsOfferedSubscribe() {
        val pro = loaded(FakePurchasesClient().apply { trialEligible = false }).proOption!!
        assertFalse(pro.isTrialEligible)
        assertNull(pro.trial)
        assertEquals("Subscribe", pro.callToAction)
    }

    @Test fun lifetimeAndMidiOwnersNeverSeeThePaywall() {
        for (product in listOf("ap_pro_lifetime", "ap_midi_unlock")) {
            val s = store(FakePurchasesClient().apply { customerNow = CustomerSnapshot(setOf("pro"), setOf(product)) })
            s.start()
            assertTrue(product, s.isPro)
            assertTrue(s.entitlements.ownsProForLife && !s.entitlements.isSubscriber)
            allFeatures.forEach { assertFalse(ProPaywallRule.presents(it, true, s.entitlements)) }
        }
    }

    @Test fun theManagementPageFallsBackToGooglePlay() {
        assertEquals("https://play.google.com/store/account/subscriptions?sku=ap_pro_annual&package=com.mDev.AdventPraise",
            store().manageSubscriptionUrl)
    }

    @Test fun purchaseEventsKeepTheirNames() {
        val started = AnalyticsEvent.PurchaseStarted("ap_pro_annual", ProFeature.Player)
        assertEquals("purchase_started", started.name)
        assertEquals(mapOf("product" to "ap_pro_annual", "feature" to "player"), started.properties)
        assertEquals("pending", AnalyticsEvent.PurchaseFailed("p", ProFeature.Support, PurchaseFailure.Pending).properties["reason"])
        assertEquals("not_activated", PurchaseFailure.NotActivated.key)
        assertEquals("paywall", AnalyticsEvent.RestoreStarted(RestoreSource.Paywall).properties["source"])
        assertEquals("sheet_music", AnalyticsEvent.PaywallViewed(ProFeature.SheetMusic, PaywallContext.SheetMusic).properties["feature"])
        assertEquals("unlocked", AnalyticsEvent.PaywallDismissed(ProFeature.Player, PaywallContext.Reader, PaywallOutcome.Unlocked).properties["outcome"])
        assertEquals("tip_failed", AnalyticsEvent.TipFailed("ap_tip_amen", PurchaseFailure.Unavailable).name)
    }
}

class FreePlaysTest {
    private class Memory(var value: Int? = null) : FreePlayStorage {
        var writes = 0
        override fun read() = value
        override fun write(used: Int) { value = used; writes++ }
    }

    @Test fun fiveFreePlaysThenNone() {
        var allowance = FreePlayAllowance()
        assertEquals(5, FreePlayAllowance.FREE)
        assertEquals(5, allowance.remaining)
        for (play in 1..5) {
            allowance = allowance.spend()!!
            assertEquals(5 - play, allowance.remaining)
        }
        assertTrue(allowance.isUsedUp)
        assertNull(allowance.spend())
        assertTrue(FreePlayAllowance(4).isLastPlay)
        assertFalse(FreePlayAllowance(3).isLastPlay)
        assertFalse(FreePlayAllowance(5).isLastPlay)
    }

    @Test fun clampsWhatIsStored() {
        for ((stored, used, remaining) in listOf(Triple(-3, 0, 5), Triple(0, 0, 5), Triple(2, 2, 3), Triple(5, 5, 0), Triple(9, 9, 0))) {
            assertEquals(used, FreePlayAllowance(stored).used)
            assertEquals(remaining, FreePlayAllowance(stored).remaining)
        }
    }

    @Test fun theHigherStoredCountWins() {
        assertEquals(0, FreePlayAllowance.reconciled(listOf(null, null)).used)
        assertEquals(3, FreePlayAllowance.reconciled(listOf(null, 3)).used)
        assertEquals(4, FreePlayAllowance.reconciled(listOf(2, 4)).used)
        assertEquals(5, FreePlayAllowance.reconciled(listOf(5, 1)).used)
        assertEquals(0, FreePlayAllowance.reconciled(emptyList()).used)
    }

    @Test fun spendingIsSavedToEveryStoreAndOutlastsALaunch() {
        val a = Memory()
        val b = Memory()
        val plays = FreePlays(listOf(a, b))
        assertEquals(4, plays.spend())
        assertEquals(3, plays.spend())
        assertEquals(2, a.value)
        assertEquals(2, b.value)
        repeat(3) { plays.spend() }
        assertTrue(FreePlays(listOf(a, b)).isUsedUp)
    }

    @Test fun spendingPastTheLimitChangesNothing() {
        val store = Memory(5)
        val plays = FreePlays(listOf(store))
        val writes = store.writes
        assertEquals(0, plays.spend())
        assertEquals(writes, store.writes)
    }

    @Test fun aLowerCountIsBroughtUp() {
        val a = Memory(4)
        val b = Memory(1)
        assertEquals(1, FreePlays(listOf(a, b)).remaining)
        assertEquals(4, b.value)
    }

    @Test fun nothingPlayedDuringTheTourCountsOrLocks() {
        val store = Memory(2)
        val plays = FreePlays(listOf(store))
        plays.isTourActive = true
        assertEquals(3, plays.spend())
        assertEquals(2, store.value)
        plays.isTourActive = false
        assertEquals(2, plays.spend())
        val usedUp = FreePlays(listOf(Memory(5)))
        assertTrue(usedUp.locksNewPlay)
        usedUp.isTourActive = true
        assertTrue(usedUp.isUsedUp)
        assertFalse(usedUp.locksNewPlay)
    }

    @Test fun theNamesAreVersionedAndKeptApart() {
        assertEquals(3, setOf(FreePlayStorageName.LEGACY, FreePlayStorageName.RELEASE, FreePlayStorageName.DEBUG).size)
        assertEquals(FreePlayStorageName.DEBUG, FreePlayStorageName.current)   // unit tests run the debug build
        val store = MemoryStore()
        StoreFreePlayStorage(store).write(3)
        assertEquals(3, store.getInt("freePlays.v2.debug.used"))
        assertNull(StoreFreePlayStorage(store, "freePlays.v2.used").read())
    }
}
