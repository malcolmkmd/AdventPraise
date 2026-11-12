//
//  PaywallExperimentTests.swift
//  AdventPraiseTests
//
//  The current offering's metadata: missing values are variant A, and the
//  try-for-zero button follows each plan's own trial and price.
//

import Foundation
import Testing
@testable import Advent_Praise

@Suite("Paywall experiment metadata")
struct PaywallExperimentTests {
    private let annual = OfferingPackage(id: "$rc_annual", productID: "ap_pro_annual", price: "R299.99",
                                         period: SubscriptionTerm(value: 1, unit: .year),
                                         freeTrial: SubscriptionTerm(value: 3, unit: .day),
                                         priceAmount: Decimal(string: "299.99"), currencyCode: "ZAR",
                                         zeroPrice: "R0.00")
    private let monthly = OfferingPackage(id: "$rc_monthly", productID: "ap_pro_monthly", price: "R29.99",
                                          period: SubscriptionTerm(value: 1, unit: .month),
                                          priceAmount: Decimal(string: "29.99"), currencyCode: "ZAR",
                                          zeroPrice: "R0.00")

    @Test func noMetadataIsVariantA() {
        let experiment = PaywallExperiment.parsing(metadata: [:], offeringID: "default")
        #expect(experiment.variant == .a)
        #expect(experiment.firstPackageID == "$rc_annual")
        #expect(experiment.cta == .default)
        #expect(experiment.offeringID == "default")
        #expect(experiment.isKnown)
        #expect(experiment.analyticsProperties["paywall_variant"] as? String == "a")
        #expect(experiment.analyticsProperties["offering_id"] as? String == "default")
        let front = Storefront.from(offering: OfferingSnapshot(id: "default", packages: [monthly, annual]), tipPrices: [:])
        #expect(front.orderedPlans.map(\.id) == ["ap_pro_annual", "ap_pro_monthly"])
        #expect(front.orderedPlans.first?.purchaseButton(cta: front.experiment.cta).title == "Subscribe")
    }

    @Test func unknownValuesFallBackToVariantA() {
        let experiment = PaywallExperiment.parsing(metadata: [
            "paywall_variant": "c",
            "first_package": "$rc_lifetime",
            "cta": "buy_now",
        ], offeringID: "default")
        #expect(experiment == PaywallExperiment.parsing(metadata: [:], offeringID: "default"))
    }

    @Test func blankAndOddlyCasedValuesAreRead() {
        let experiment = PaywallExperiment.parsing(metadata: [
            "paywall_variant": " B ",
            "first_package": " $rc_monthly ",
            "cta": "Try_For_Zero",
        ], offeringID: "experiment_b")
        #expect(experiment.variant == .b)
        #expect(experiment.firstPackageID == "$rc_monthly")
        #expect(experiment.cta == .tryForZero)
    }

    @Test func variantWithoutAFirstPackageStaysAnnualFirst() {
        let front = Storefront.from(offering: OfferingSnapshot(id: "experiment_b", packages: [annual, monthly], metadata: [
            "paywall_variant": "b",
        ]), tipPrices: [:])
        #expect(front.experiment.variant == .b)
        #expect(front.experiment.cta == .default)
        #expect(front.orderedPlans.map(\.package.id) == ["$rc_annual", "$rc_monthly"])
    }

    @Test func monthlyFirstWhenThatPackageLoaded() {
        let week = OfferingPackage(id: "$rc_annual", productID: "ap_pro_annual", price: "R299.99",
                                   period: SubscriptionTerm(value: 1, unit: .year),
                                   freeTrial: SubscriptionTerm(value: 1, unit: .week),
                                   zeroPrice: "R0.00")
        let threeDays = OfferingPackage(id: "$rc_monthly", productID: "ap_pro_monthly", price: "R29.99",
                                        period: SubscriptionTerm(value: 1, unit: .month),
                                        freeTrial: SubscriptionTerm(value: 3, unit: .day),
                                        zeroPrice: "R0.00")
        let front = Storefront.from(offering: OfferingSnapshot(id: "experiment_b", packages: [week, threeDays], metadata: [
            "paywall_variant": "b",
            "first_package": "$rc_monthly",
            "cta": "try_for_zero",
        ]), tipPrices: [:])
        #expect(front.orderedPlans.map(\.package.id) == ["$rc_monthly", "$rc_annual"])
        let monthly = UnlockOption(package: threeDays, isTrialEligible: true)
        let annual = UnlockOption(package: week, isTrialEligible: true)
        #expect(monthly.trialCallout == "3 days free")
        #expect(annual.trialCallout == "1 week free")
        #expect(monthly.purchaseButton(cta: .tryForZero).detail == "3 days free, then R29.99/month")
        #expect(annual.purchaseButton(cta: .tryForZero).detail == "1 week free, then R299.99/year")
    }

    @Test func aMissingFirstPackageLeavesTheOneThatLoaded() {
        let front = Storefront.from(offering: OfferingSnapshot(id: "experiment_b", packages: [annual], metadata: [
            "first_package": "$rc_monthly",
            "paywall_variant": "b",
        ]), tipPrices: [:])
        #expect(front.orderedPlans.map(\.id) == ["ap_pro_annual"])
    }

    @Test func aFailedReloadKeepsTheKnownExperiment() {
        let loaded = Storefront.from(offering: OfferingSnapshot(id: "experiment_b", packages: [annual, monthly], metadata: [
            "paywall_variant": "b",
            "first_package": "$rc_monthly",
            "cta": "try_for_zero",
        ]), tipPrices: [:])
        let kept = loaded.keeping(.from(offering: nil, tipPrices: [:]))
        #expect(kept.experiment == loaded.experiment)
        #expect(kept.orderedPlans.map(\.package.id) == ["$rc_monthly", "$rc_annual"])
        let fresh = Storefront().keeping(loaded)
        #expect(fresh.experiment == loaded.experiment)
    }

    @Test func tryForZeroUsesTheProductZeroAndFallsBackWithoutATrial() {
        let eligible = UnlockOption(package: OfferingPackage(
            id: "$rc_monthly", productID: "ap_pro_monthly", price: "$1.99",
            period: SubscriptionTerm(value: 1, unit: .month),
            freeTrial: SubscriptionTerm(value: 3, unit: .day),
            zeroPrice: "$0.00"), isTrialEligible: true)
        let button = eligible.purchaseButton(cta: .tryForZero)
        #expect(button.title == "Try for $0.00")
        #expect(button.detail == "3 days free, then $1.99/month")
        #expect(eligible.purchaseButton(cta: .default).title == "Start 3-Day Free Trial")
        #expect(eligible.purchaseButton(cta: .default).detail == nil)

        let used = UnlockOption(package: eligible.package, isTrialEligible: false)
        let fallback = used.purchaseButton(cta: .tryForZero)
        #expect(fallback.title == "Subscribe")
        #expect(fallback.detail == nil)
        #expect(used.trialCallout == nil)
        #expect(!fallback.title.contains("Try for"))

        let noZero = UnlockOption(package: OfferingPackage(
            id: "$rc_annual", productID: "ap_pro_annual", price: "R299.99",
            period: SubscriptionTerm(value: 1, unit: .year),
            freeTrial: SubscriptionTerm(value: 1, unit: .week)), isTrialEligible: true)
        #expect(noZero.purchaseButton(cta: .tryForZero).title == "Start 1-Week Free Trial")
    }

    @Test func zeroFollowsTheProductFormatter() {
        let usd = NumberFormatter()
        usd.numberStyle = .currency
        usd.locale = Locale(identifier: "en_US")
        usd.currencyCode = "USD"
        #expect(ProductPriceFormat.zero(formatter: usd) == "$0.00")
        #expect(ProductPriceFormat.zero(currencyCode: "USD", locale: Locale(identifier: "en_US")) == "$0.00")
        let rand = ProductPriceFormat.zero(currencyCode: "ZAR", locale: Locale(identifier: "en_ZA"))
        #expect(rand?.contains("R") == true)
        #expect(rand?.contains("0") == true)
        #expect(ProductPriceFormat.zero(formatter: nil, currencyCode: nil) == nil)
    }

    @Test func knownExperimentsRideOnThePaywallEvents() {
        let experiment = PaywallExperiment.parsing(metadata: [
            "paywall_variant": "b",
            "first_package": "$rc_monthly",
            "cta": "try_for_zero",
        ], offeringID: "experiment_b")
        let viewed = AnalyticsEvent.paywallViewed(feature: .player, context: .reader, experiment: experiment)
        #expect(viewed.properties["paywall_variant"] as? String == "b")
        #expect(viewed.properties["offering_id"] as? String == "experiment_b")
        #expect(viewed.properties["feature"] as? String == "player")
        let started = AnalyticsEvent.purchaseStarted(product: "ap_pro_monthly", feature: .player, experiment: experiment)
        #expect(started.properties["paywall_variant"] as? String == "b")
        #expect(started.properties["offering_id"] as? String == "experiment_b")
        let failed = AnalyticsEvent.purchaseFailed(product: "ap_pro_monthly", feature: .player, reason: .storeError, experiment: experiment)
        #expect(failed.properties["reason"] as? String == "store_error")
        #expect(failed.properties["paywall_variant"] as? String == "b")
        let cancelled = AnalyticsEvent.purchaseCancelled(product: "ap_pro_monthly", feature: .airPlay, experiment: experiment)
        #expect(cancelled.properties["offering_id"] as? String == "experiment_b")
        #expect(PaywallExperiment.unknown.analyticsProperties.isEmpty)
    }
}
