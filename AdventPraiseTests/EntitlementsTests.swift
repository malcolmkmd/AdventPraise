//
//  EntitlementsTests.swift
//  AdventPraiseTests
//
//  The rules behind the unlocks, with no RevenueCat: the `pro` entitlement
//  opens everything; the product IDs live buyers own are kept; the
//  storefront takes Pro from the offering and judges each screen on its
//  own; and the purchase events keep the names PostHog already has.
//

import Foundation
import Testing
@testable import Advent_Praise

struct EntitlementsTests {
    private let allFeatures: [ProFeature] = [.player, .airPlay, .mirroring, .support, .sheetMusic]

    @Test func nothingActiveOpensNothing() {
        let none = Entitlements.none
        #expect(!none.isPro)
        #expect(!none.unlocksPlayer)
        #expect(!none.hasPurchases)
        for feature in allFeatures {
            #expect(!none.unlocks(feature), "\(feature) should be locked")
        }
    }

    @Test func theProEntitlementOpensEverything() {
        let pro = Entitlements(active: [PurchaseConfig.proEntitlement], purchased: [PurchaseConfig.proProductID])
        #expect(pro.isPro)
        #expect(pro.unlocksPlayer)
        for feature in allFeatures {
            #expect(pro.unlocks(feature), "\(feature) should be open with Pro")
        }
    }

    /// 7.0.1's MIDI Piano buyers: RevenueCat attaches ap_midi_unlock to
    /// `pro`, so they have all of Pro, sheet music and AirPlay included.
    @Test func aMidiPianoBuyerIsPro() {
        let midi = Entitlements(active: [PurchaseConfig.proEntitlement], purchased: [PurchaseConfig.legacyMIDIProductID])
        #expect(midi.isPro)
        #expect(midi.unlocks(.airPlay))
        #expect(midi.unlocks(.sheetMusic))
        #expect(midi.unlocks(.player))
    }

    /// RevenueCat's entitlement decides, not the product list.
    @Test func productsWithoutTheEntitlementOpenNothing() {
        let owned = Entitlements(active: [], purchased: ["ap_hymnal_tswana", PurchaseConfig.proProductID])
        #expect(!owned.isPro)
        #expect(owned.hasPurchases)
        #expect(!owned.unlocks(.player))
        #expect(!Entitlements(active: ["something_else"]).isPro)
    }

    @Test func theLiveProductIDsAreKept() {
        #expect(PurchaseConfig.proEntitlement == "pro")
        #expect(PurchaseConfig.proProductID == "ap_pro_annual")
        #expect(PurchaseConfig.proPackageID == "$rc_annual")
        #expect(PurchaseConfig.monthlyProductID == "ap_pro_monthly")
        #expect(PurchaseConfig.monthlyPackageID == "$rc_monthly")
        #expect(PurchaseConfig.subscriptionProductIDs == ["ap_pro_annual", "ap_pro_monthly"])
        #expect(PurchaseConfig.legacyLifetimeProductID == "ap_pro_lifetime")
        #expect(PurchaseConfig.legacyMIDIProductID == "ap_midi_unlock")
        #expect(PurchaseConfig.proEntitlementProductIDs == ["ap_pro_annual", "ap_pro_monthly", "ap_pro_lifetime", "ap_midi_unlock"])
        #expect(PurchaseConfig.tipProductIDs == ["ap_tip_amen", "ap_tip_hallelujah", "ap_tip_hosanna"])
        #expect(PurchaseConfig.offeringID == nil, "the paywall shows RevenueCat's current offering")
    }

    /// The local StoreKit configurations still carry every live product.
    @Test func theStoreKitConfigurationHasEveryProduct() throws {
        let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        for name in ["Products.storekit", "AdventPraise-USD.storekit"] {
            let url = root.appending(path: "StoreKit/\(name)")
            let json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
            let products = try #require(json["products"] as? [[String: Any]])
            let groups = json["subscriptionGroups"] as? [[String: Any]] ?? []
            let subscriptions = groups.flatMap { $0["subscriptions"] as? [[String: Any]] ?? [] }
            let ids = Set((products + subscriptions).compactMap { $0["productID"] as? String })
            for id in PurchaseConfig.proEntitlementProductIDs.union(PurchaseConfig.tipProductIDs) {
                #expect(ids.contains(id), "\(id) is missing from \(name)")
            }
            // Annual is a yearly subscription with a three-day free trial.
            let annual = try #require(subscriptions.first { $0["productID"] as? String == PurchaseConfig.proProductID })
            #expect(annual["recurringSubscriptionPeriod"] as? String == "P1Y")
            let intro = try #require(annual["introductoryOffer"] as? [String: Any])
            #expect(intro["paymentMode"] as? String == "free")
            #expect(intro["subscriptionPeriod"] as? String == "P3D")
            // Monthly is in the same group, billed each month, with no trial.
            let monthly = try #require(subscriptions.first { $0["productID"] as? String == PurchaseConfig.monthlyProductID })
            #expect(monthly["recurringSubscriptionPeriod"] as? String == "P1M")
            #expect(monthly["subscriptionGroupID"] as? String == annual["subscriptionGroupID"] as? String)
            #expect(monthly["introductoryOffer"] == nil)
        }
    }

    @Test func featuresReportThemselvesToAnalyticsByName() {
        #expect(ProFeature.player.analyticsName == "player")
        #expect(ProFeature.airPlay.analyticsName == "air_play")
        #expect(ProFeature.mirroring.analyticsName == "mirroring")
        #expect(ProFeature.support.analyticsName == "support")
        #expect(ProFeature.sheetMusic.analyticsName == "sheet_music")
    }
}

/// What the offering and the tip prices produced.
struct StorefrontTests {
    private let tips = PurchaseConfig.tipProductIDs
    private let annual = OfferingPackage(id: "$rc_annual", productID: "ap_pro_annual", price: "R299.99",
                                         period: SubscriptionTerm(value: 1, unit: .year),
                                         freeTrial: SubscriptionTerm(value: 3, unit: .day),
                                         priceAmount: Decimal(string: "299.99"), currencyCode: "ZAR")
    private let monthly = OfferingPackage(id: "$rc_monthly", productID: "ap_pro_monthly", price: "R29.99",
                                          period: SubscriptionTerm(value: 1, unit: .month),
                                          priceAmount: Decimal(string: "29.99"), currencyCode: "ZAR")
    private let lifetime = OfferingPackage(id: "$rc_lifetime", productID: "ap_pro_lifetime", price: "R349.99")

    private func prices(_ ids: [String]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: ids.map { ($0, "R1.00") })
    }

    @Test func proComesFromTheOfferingsAnnualPackage() {
        let offering = OfferingSnapshot(id: "default", packages: [lifetime, monthly, annual])
        let front = Storefront.from(offering: offering, tipPrices: prices(tips))
        #expect(!front.proFailed)
        #expect(!front.tipsFailed)
        #expect(!front.anyFailed)
        #expect(front.proOption?.id == "ap_pro_annual")
        #expect(front.annual?.package.id == "$rc_annual")
        #expect(front.proOption?.price == "R299.99")
        #expect(front.monthly?.id == "ap_pro_monthly")
        #expect(front.monthly?.package.id == "$rc_monthly")
        #expect(front.monthly?.package.freeTrial == nil)
        #expect(front.tips.map(\.id) == tips, "cheapest first, in the config's order")
    }

    /// A package that only wears the monthly id, for some other product, is not sold.
    @Test func aStrayMonthlyPackageIsIgnored() {
        let stranger = OfferingPackage(id: "$rc_monthly", productID: "ap_something_else", price: "R9.99",
                                       period: SubscriptionTerm(value: 1, unit: .month))
        let front = Storefront.from(offering: OfferingSnapshot(id: "default", packages: [annual, stranger]), tipPrices: [:])
        #expect(front.monthly == nil)
        #expect(front.annual?.id == "ap_pro_annual")
    }

    @Test func theMonthlyPackageWinsOverAnotherPackageOfThatProduct() {
        let custom = OfferingPackage(id: "monthly_custom", productID: "ap_pro_monthly", price: "R29.99",
                                     period: SubscriptionTerm(value: 1, unit: .month))
        let front = Storefront.from(offering: OfferingSnapshot(id: "default", packages: [custom, monthly, annual]), tipPrices: [:])
        #expect(front.monthly?.package.id == "$rc_monthly")
    }

    @Test func monthlyMissingLeavesAnnual() {
        let front = Storefront.from(offering: OfferingSnapshot(id: "default", packages: [lifetime, annual]), tipPrices: [:])
        #expect(front.annual?.id == "ap_pro_annual")
        #expect(front.monthly == nil)
        #expect(!front.proFailed)
    }

    @Test func theSavingComesFromTheTwoStorePrices() throws {
        let zar = AnnualSaving.compare(annual: annual, monthly: monthly)
        #expect(zar?.percent == 17)
        #expect(zar?.amount == Decimal(string: "59.89"))
        #expect(zar?.currencyCode == "ZAR")
        let usdAnnual = OfferingPackage(id: "$rc_annual", productID: "ap_pro_annual", price: "$14.99",
                                        period: SubscriptionTerm(value: 1, unit: .year),
                                        freeTrial: SubscriptionTerm(value: 3, unit: .day),
                                        priceAmount: Decimal(string: "14.99"), currencyCode: "USD")
        let usdMonthly = OfferingPackage(id: "$rc_monthly", productID: "ap_pro_monthly", price: "$1.99",
                                         period: SubscriptionTerm(value: 1, unit: .month),
                                         priceAmount: Decimal(string: "1.99"), currencyCode: "USD")
        let usd = AnnualSaving.compare(annual: usdAnnual, monthly: usdMonthly)
        #expect(usd?.percent == 37)
        #expect(usd?.amount == Decimal(string: "8.89"))
        let formatted = try #require(usd?.formattedAmount(locale: Locale(identifier: "en_US")))
        #expect(formatted.contains("8.89"))
        #expect(formatted.contains("$"))
        // No number to show when the prices can't be compared.
        #expect(AnnualSaving.compare(annual: annual, monthly: usdMonthly) == nil)
        let same = OfferingPackage(id: "$rc_monthly", productID: "ap_pro_monthly", price: "R299.99",
                                   period: SubscriptionTerm(value: 1, unit: .month),
                                   priceAmount: Decimal(string: "24.99"), currencyCode: "ZAR")
        #expect(AnnualSaving.compare(annual: annual, monthly: same) == nil, "a year of monthly is not more")
        let unpriced = OfferingPackage(id: "$rc_monthly", productID: "ap_pro_monthly", price: "R29.99",
                                       period: SubscriptionTerm(value: 1, unit: .month))
        #expect(AnnualSaving.compare(annual: annual, monthly: unpriced) == nil)
    }

    /// MIDI Piano is no longer sold, even if an offering still lists it.
    @Test func midiPianoIsNeverOffered() {
        let midi = OfferingPackage(id: "midi", productID: "ap_midi_unlock", price: "R79.99")
        let both = Storefront.from(offering: OfferingSnapshot(id: "default", packages: [midi, annual]), tipPrices: [:])
        #expect(both.proOption?.id == "ap_pro_annual")
        let midiOnly = Storefront.from(offering: OfferingSnapshot(id: "default", packages: [midi]), tipPrices: [:])
        #expect(midiOnly.proFailed)
    }

    @Test func theAnnualPackageWinsOverAnotherPackageOfPro() {
        let custom = OfferingPackage(id: "pro_custom", productID: "ap_pro_annual", price: "R299.99")
        let front = Storefront.from(offering: OfferingSnapshot(id: "default", packages: [custom, annual]), tipPrices: [:])
        #expect(front.proOption?.package.id == "$rc_annual")
    }

    /// Lifetime stays in the offering until 7.1 ships; the paywall never sells it.
    @Test func lifetimeIsNeverOffered() {
        let lifetimeOnly = Storefront.from(offering: OfferingSnapshot(id: "default", packages: [lifetime]), tipPrices: [:])
        #expect(lifetimeOnly.proFailed)
        let first = Storefront.from(offering: OfferingSnapshot(id: "default", packages: [lifetime, annual]), tipPrices: [:])
        #expect(first.proOption?.package.id == "$rc_annual")
    }

    @Test func theOfferAndButtonFollowTrialEligibility() {
        let eligible = UnlockOption(package: annual, isTrialEligible: true)
        #expect(eligible.offerLine == "3 days free, then R299.99/year. Cancel anytime.")
        #expect(eligible.trialCallout == "3 days free")
        #expect(eligible.callToAction == "Start 3-Day Free Trial")
        #expect(eligible.renewalTerms.contains("when the free trial ends"))
        #expect(eligible.renewalTerms.contains("Renews automatically each year unless cancelled at least 24 hours before the end of the current year."))
        let used = UnlockOption(package: annual, isTrialEligible: false)
        #expect(used.offerLine == "R299.99/year. Cancel anytime.")
        #expect(used.callToAction == "Subscribe")
        // Eligible, but the product has no trial: no trial promised.
        let noTrial = UnlockOption(package: OfferingPackage(id: "$rc_annual", productID: "ap_pro_annual", price: "$11.99",
                                                            period: SubscriptionTerm(value: 1, unit: .year)), isTrialEligible: true)
        #expect(noTrial.offerLine == "$11.99/year. Cancel anytime.")
        #expect(noTrial.callToAction == "Subscribe")
        let week = UnlockOption(package: OfferingPackage(id: "$rc_annual", productID: "ap_pro_annual", price: "R299.99",
                                                         period: SubscriptionTerm(value: 1, unit: .year),
                                                         freeTrial: SubscriptionTerm(value: 1, unit: .week)), isTrialEligible: true)
        #expect(week.offerLine == "1 week free, then R299.99/year. Cancel anytime.")
        #expect(week.callToAction == "Start 1-Week Free Trial")
        // Monthly has no trial, even when the buyer would still be eligible for one.
        let month = UnlockOption(package: monthly, isTrialEligible: true)
        #expect(month.trial == nil)
        #expect(month.planName == "Monthly")
        #expect(month.priceLine == "R29.99/month")
        #expect(month.offerLine == "R29.99/month. Cancel anytime.")
        #expect(month.trialCallout == nil)
        #expect(month.callToAction == "Subscribe")
        #expect(!month.offerLine.contains("free"))
        #expect(!month.renewalTerms.contains("free trial"))
    }

    @Test func thePaywallNeverShowsForPro() {
        let free = Entitlements.none
        let subscriber = Entitlements(active: ["pro"], purchased: ["ap_pro_annual"])
        let monthlySubscriber = Entitlements(active: ["pro"], purchased: ["ap_pro_monthly"])
        let lifetimeOwner = Entitlements(active: ["pro"], purchased: ["ap_pro_lifetime"])
        let midiOwner = Entitlements(active: ["pro"], purchased: ["ap_midi_unlock"])
        #expect(ProPaywallRule.presents(.player, isEnabled: true, entitlements: free))
        #expect(!ProPaywallRule.presents(.player, isEnabled: false, entitlements: free))
        #expect(!ProPaywallRule.presents(nil, isEnabled: true, entitlements: free))
        for owner in [subscriber, monthlySubscriber, lifetimeOwner, midiOwner] {
            #expect(!ProPaywallRule.presents(.support, isEnabled: true, entitlements: owner))
        }
        #expect(subscriber.isSubscriber && !subscriber.ownsProForLife)
        #expect(monthlySubscriber.isSubscriber && !monthlySubscriber.ownsProForLife)
        #expect(lifetimeOwner.ownsProForLife && !lifetimeOwner.isSubscriber)
        #expect(midiOwner.ownsProForLife)
        // A lapsed subscription: no entitlement, so the paywall can show again.
        #expect(!Entitlements(active: [], purchased: ["ap_pro_annual"]).isPro)
    }

    @Test func noOfferingLeavesTheTips() {
        let front = Storefront.from(offering: nil, tipPrices: prices(tips))
        #expect(front.proFailed)
        #expect(!front.tipsFailed)
        #expect(front.tips.count == 3)
    }

    @Test func tipsMissingLeavesThePaywall() {
        let front = Storefront.from(offering: OfferingSnapshot(id: "default", packages: [annual]), tipPrices: [:])
        #expect(!front.proFailed)
        #expect(front.tipsFailed)
    }

    @Test func oneTipIsEnoughForTheSupportScreen() {
        let front = Storefront.from(offering: nil, tipPrices: prices([tips[1]]))
        #expect(!front.tipsFailed)
        #expect(front.tips.map(\.id) == [tips[1]])
    }

    @Test func aRetryKeepsWhatLoadedBefore() {
        let loaded = Storefront.from(offering: OfferingSnapshot(id: "default", packages: [annual, monthly]), tipPrices: prices(tips))
        let kept = loaded.keeping(.from(offering: nil, tipPrices: [:]))
        #expect(kept == loaded)
        #expect(kept.monthly?.id == "ap_pro_monthly")
        let empty = Storefront().keeping(loaded)
        #expect(empty == loaded)
    }
}

/// The purchase events keep the names and properties PostHog already has.
struct PurchaseAnalyticsTests {
    @Test func purchaseEvents() {
        let started = AnalyticsEvent.purchaseStarted(product: "ap_pro_lifetime", feature: .player)
        #expect(started.name == "purchase_started")
        #expect(started.properties["product"] as? String == "ap_pro_lifetime")
        #expect(started.properties["feature"] as? String == "player")
        #expect(AnalyticsEvent.purchaseCompleted(product: "ap_pro_lifetime", feature: .sheetMusic).name == "purchase_completed")
        #expect(AnalyticsEvent.purchaseCancelled(product: "ap_pro_lifetime", feature: .airPlay).name == "purchase_cancelled")
        let failed = AnalyticsEvent.purchaseFailed(product: "ap_pro_lifetime", feature: .support, reason: .pending)
        #expect(failed.name == "purchase_failed")
        #expect(failed.properties["reason"] as? String == "pending")
        #expect(PurchaseFailure.notActivated.rawValue == "not_activated")
        #expect(PurchaseFailure.storeError.rawValue == "store_error")
    }

    @Test func restoreAndTipEvents() {
        #expect(AnalyticsEvent.restoreStarted(source: .paywall).properties["source"] as? String == "paywall")
        let restored = AnalyticsEvent.restoreCompleted(foundPurchases: true, proActive: true)
        #expect(restored.name == "restore_completed")
        #expect(restored.properties["found_purchases"] as? Bool == true)
        #expect(restored.properties["pro_active"] as? Bool == true)
        #expect(AnalyticsEvent.restoreFailed.name == "restore_failed")
        #expect(AnalyticsEvent.tipStarted(product: "ap_tip_amen").name == "tip_started")
        #expect(AnalyticsEvent.tipCompleted(product: "ap_tip_amen").properties["product"] as? String == "ap_tip_amen")
        #expect(AnalyticsEvent.tipFailed(product: "ap_tip_amen", reason: .unavailable).name == "tip_failed")
    }

    @Test func paywallEvents() {
        let viewed = AnalyticsEvent.paywallViewed(feature: .sheetMusic, context: .sheetMusic)
        #expect(viewed.name == "paywall_viewed")
        #expect(viewed.properties["feature"] as? String == "sheet_music")
        #expect(AnalyticsEvent.paywallDismissed(feature: .player, context: .reader, outcome: .unlocked)
            .properties["outcome"] as? String == "unlocked")
    }
}
