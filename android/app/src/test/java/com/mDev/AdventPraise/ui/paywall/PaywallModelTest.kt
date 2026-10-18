package com.mDev.AdventPraise.ui.paywall

import com.mDev.AdventPraise.analytics.RestoreSource
import com.mDev.AdventPraise.billing.CustomerSnapshot
import com.mDev.AdventPraise.billing.Entitlements
import com.mDev.AdventPraise.billing.FakePurchasesClient
import com.mDev.AdventPraise.billing.OfferingPackage
import com.mDev.AdventPraise.billing.OfferingSnapshot
import com.mDev.AdventPraise.billing.ProFeature
import com.mDev.AdventPraise.billing.ProPaywallRule
import com.mDev.AdventPraise.billing.PurchaseStore
import com.mDev.AdventPraise.billing.RestoreOutcome
import com.mDev.AdventPraise.billing.SubscriptionTerm
import com.mDev.AdventPraise.ui.more.ProCardState
import com.mDev.AdventPraise.ui.more.proCardSubtitle
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** The paywall's view of the store (ProPaywallView's offer and actions), and the Pro card in More. */
class PaywallModelTest {
    private val annual = OfferingPackage("\$rc_annual", "ap_pro_annual", "R199.99",
        SubscriptionTerm(1, SubscriptionTerm.Unit.Year), SubscriptionTerm(3, SubscriptionTerm.Unit.Day))
    private val lifetime = OfferingPackage("\$rc_lifetime", "ap_pro_lifetime", "R349.99")

    private fun store(client: FakePurchasesClient = FakePurchasesClient(), forced: Entitlements? = null) =
        PurchaseStore(client, CoroutineScope(Dispatchers.Unconfined), forced = forced)

    private fun loaded(client: FakePurchasesClient = FakePurchasesClient()) = store(client).also { runBlocking { it.loadStorefront() } }

    @Test fun onlyTheAnnualPackageIsSold() {
        val offer = PaywallOffer.of(loaded()) as PaywallOffer.Ready
        assertEquals("ap_pro_annual", offer.option.id)
        assertEquals("\$rc_annual", offer.option.pkg.id)
    }

    @Test fun anOfferingWithoutTheAnnualPackageSellsNothing() {
        val client = FakePurchasesClient().apply { offering = OfferingSnapshot("default", listOf(lifetime)) }
        assertEquals(PaywallOffer.Failed, PaywallOffer.of(loaded(client)))
    }

    @Test fun theTrialLineComesFromTheStore() {
        val offer = PaywallOffer.of(loaded()) as PaywallOffer.Ready
        assertEquals("3 days free, then R199.99/year. Cancel anytime.", offer.offerLine)
        assertEquals("Start 3-Day Free Trial", offer.callToAction)
        assertTrue(offer.renewalTerms.startsWith("Payment is charged to your Google Play account when the free trial ends."))
        assertTrue(offer.renewalTerms.contains("Google Play › Payments & subscriptions"))
    }

    @Test fun withoutTheTrialItSubscribes() {
        val client = FakePurchasesClient().apply { trialEligible = false }
        val offer = PaywallOffer.of(loaded(client)) as PaywallOffer.Ready
        assertEquals("R199.99/year. Cancel anytime.", offer.offerLine)
        assertEquals("Subscribe", offer.callToAction)
        assertTrue(offer.renewalTerms.startsWith("Payment is charged to your Google Play account when you confirm."))
    }

    @Test fun noPriceOffersTryAgainWhileLoadingShowsTheSpinner() {
        val client = FakePurchasesClient().apply { offering = null }
        val s = loaded(client)
        assertEquals(PaywallOffer.Failed, PaywallOffer.of(s))
        assertEquals(PaywallOffer.Loading, PaywallOffer.of(isPro = false, option = null, isLoading = true))
        // Try again finds it.
        client.offering = OfferingSnapshot("default", listOf(annual, lifetime))
        runBlocking { s.loadStorefront() }
        assertTrue(PaywallOffer.of(s) is PaywallOffer.Ready)
    }

    @Test fun restoringProTurnsTheOfferIntoTheThankYou() = runBlocking {
        val client = FakePurchasesClient().apply { nextRestore = RestoreOutcome.Restored(CustomerSnapshot(setOf("pro"), setOf("ap_pro_annual"))) }
        val s = loaded(client)
        s.restore(RestoreSource.Paywall)
        assertEquals(PaywallOffer.Active, PaywallOffer.of(s))
        assertEquals("Advent Praise Pro has been restored.", s.message)
    }

    @Test fun restoringNothingKeepsTheOffer() = runBlocking {
        val none = loaded(FakePurchasesClient())
        none.restore(RestoreSource.Paywall)
        assertTrue(PaywallOffer.of(none) is PaywallOffer.Ready)
        assertEquals("No previous purchases were found for this Google Account.", none.message)

        val failed = loaded(FakePurchasesClient().apply { nextRestore = RestoreOutcome.Failed })
        failed.restore(RestoreSource.Paywall)
        assertTrue(PaywallOffer.of(failed) is PaywallOffer.Ready)
        assertTrue(failed.message!!.startsWith("Couldn’t restore purchases"))
        assertFalse(failed.isRestoring)

        val cancelled = loaded(FakePurchasesClient().apply { nextRestore = RestoreOutcome.Cancelled })
        cancelled.restore(RestoreSource.Paywall)
        assertEquals(null, cancelled.message)
    }

    @Test fun proForLifeNeverSeesThePaywall() {
        for (product in listOf("ap_pro_lifetime", "ap_midi_unlock")) {
            val forLife = Entitlements(setOf("pro"), setOf(product))
            assertTrue(forLife.ownsProForLife)
            ProFeature.entries.forEach { assertFalse("$product, $it", ProPaywallRule.presents(it, true, forLife)) }
            // More's card thanks them and opens nothing.
            assertEquals(ProCardState.ProForLife, ProCardState.of(forLife))
            assertFalse(ProCardState.of(forLife).opens)
            assertEquals("Thank you. Pro is yours for life.", proCardSubtitle(ProCardState.of(forLife), 0))
            // A paywall that did open shows the thank-you, nothing to buy.
            assertEquals(PaywallOffer.Active, PaywallOffer.of(store(forced = forLife).apply { start() }))
        }
    }

    @Test fun theProCardFollowsWhatIsOwned() {
        val subscriber = Entitlements(setOf("pro"), setOf("ap_pro_annual"))
        assertEquals(ProCardState.Subscriber, ProCardState.of(subscriber))
        assertTrue(ProCardState.of(subscriber).opens)
        assertEquals("Thank you. Manage your subscription here.", proCardSubtitle(ProCardState.Subscriber, 5))
        assertEquals(ProCardState.Free, ProCardState.of(Entitlements.none))
        assertEquals("5 of 5 free plays of the piano left", proCardSubtitle(ProCardState.Free, 5))
        assertEquals("1 free play of the piano left", proCardSubtitle(ProCardState.Free, 1))
        assertEquals("Your free plays of the piano are used", proCardSubtitle(ProCardState.Free, 0))
    }

    @Test fun theScrollHintShowsUntilTheFirstScroll() {
        assertTrue(PaywallScrollState.from(offset = 0f, remaining = 200f, density = 1f, scrolled = false).showsHint)
        // A few points left isn't "more".
        assertFalse(PaywallScrollState.from(offset = 0f, remaining = 40f, density = 1f, scrolled = false).showsHint)
        val scrolled = PaywallScrollState.from(offset = 20f, remaining = 200f, density = 1f, scrolled = false)
        assertTrue(scrolled.scrolled)
        assertFalse(scrolled.showsHint)
    }

    @Test fun theCrowdIsTheSameEveryTime() {
        val a = PraiseCrowd.layout(411f, 184f)
        val b = PraiseCrowd.layout(411f, 184f)
        assertEquals(a, b)
        // Back rows first, so the front row draws over them.
        assertEquals(2, a.first().depth)
        assertEquals(0, a.last().depth)
        // The front row spans the width.
        val front = a.filter { it.depth == 0 }
        assertTrue(front.minOf { it.x - it.width / 2 } < 0f && front.maxOf { it.x + it.width / 2 } > 411f)
    }
}
