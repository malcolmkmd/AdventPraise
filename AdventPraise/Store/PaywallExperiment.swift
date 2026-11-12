//
//  PaywallExperiment.swift
//  Advent Praise
//
//  RevenueCat Experiments serves a different current offering per customer.
//  The paywall reads three metadata strings from that offering and nothing
//  else: which variant this is, which package is shown first and selected,
//  and which call to action to use. Missing or unrecognised metadata is
//  variant A, which is the paywall as it was: annual first and selected,
//  and the subscribe button it already had.
//
//  Trial length and the zero price are never taken from the metadata. They
//  come from each product (introductory free trial, price formatter).
//

import Foundation

/// How the current offering asks the paywall to present itself.
struct PaywallExperiment: Equatable, Sendable {
    enum Variant: String, Sendable {
        case a, b
    }

    /// `default` is the subscribe button the paywall already used.
    /// `tryForZero` offers "Try for R0.00" when the selected plan has a
    /// free trial this Apple Account can still start.
    enum CTA: String, Sendable {
        case `default`
        case tryForZero = "try_for_zero"
    }

    enum MetadataKey {
        static let variant = "paywall_variant"
        static let firstPackage = "first_package"
        static let cta = "cta"
        static let all = [variant, firstPackage, cta]
    }

    var variant: Variant
    /// `$rc_annual` or `$rc_monthly`. The plan shown first and selected.
    var firstPackageID: String
    var cta: CTA
    /// Set once an offering has loaded. Nil until then, so analytics does
    /// not call a customer variant A before RevenueCat has answered.
    var offeringID: String?

    /// No offering yet. The paywall still lays out as variant A.
    static let unknown = PaywallExperiment(
        variant: .a,
        firstPackageID: PurchaseConfig.proPackageID,
        cta: .default,
        offeringID: nil)

    var isKnown: Bool { offeringID != nil }

    /// `paywall_variant` and `offering_id`, once an offering has loaded.
    /// Empty before that: the events still send, without a guessed variant.
    var analyticsProperties: [String: Any] {
        guard let offeringID else { return [:] }
        return ["paywall_variant": variant.rawValue, "offering_id": offeringID]
    }

    func merging(into properties: [String: Any]) -> [String: Any] {
        guard !analyticsProperties.isEmpty else { return properties }
        return properties.merging(analyticsProperties) { _, new in new }
    }

    /// `metadata` is the offering's metadata, values already strings.
    /// An empty dictionary is variant A for that offering.
    static func parsing(metadata: [String: String], offeringID: String) -> PaywallExperiment {
        func field(_ key: String) -> String {
            metadata[key, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let variant = Variant(rawValue: field(MetadataKey.variant).lowercased()) ?? .a
        let requestedFirst = field(MetadataKey.firstPackage)
        let firstPackageID = requestedFirst == PurchaseConfig.proPackageID
            || requestedFirst == PurchaseConfig.monthlyPackageID
            ? requestedFirst
            : PurchaseConfig.proPackageID
        let cta = CTA(rawValue: field(MetadataKey.cta).lowercased()) ?? .default
        return PaywallExperiment(variant: variant, firstPackageID: firstPackageID, cta: cta, offeringID: offeringID)
    }
}

/// The buy button, and the small line under it when the offering asks for one.
struct PaywallPurchaseButton: Equatable, Sendable {
    var title: String
    /// "3 days free, then R29.99/month". Nil for the ordinary subscribe button.
    var detail: String?
}

extension UnlockOption {
    /// The button for this offering's CTA. `try_for_zero` is "Try for R0.00"
    /// only when this plan has a free trial the buyer can still use, and the
    /// product could format zero in its own currency. Otherwise the ordinary
    /// subscribe button, whose price stays on the plan.
    func purchaseButton(cta: PaywallExperiment.CTA) -> PaywallPurchaseButton {
        switch cta {
        case .default:
            return PaywallPurchaseButton(title: callToAction, detail: nil)
        case .tryForZero:
            guard let trial, let zero = package.zeroPrice, !zero.isEmpty else {
                return PaywallPurchaseButton(title: callToAction, detail: nil)
            }
            let then = Self.recurring(price: price, period: package.period)
            return PaywallPurchaseButton(
                title: String(localized: "Try for \(zero)"),
                detail: String(localized: "\(Self.length(trial)) free, then \(then)"))
        }
    }
}

/// Zero in a product's currency. The live store uses the product's own
/// `priceFormatter` (its locale and currency). The currency-and-locale form
/// is the same formatter for tests and for a product that didn't hand one over.
enum ProductPriceFormat {
    static func zero(formatter: NumberFormatter) -> String? {
        let used = (formatter.copy() as? NumberFormatter) ?? formatter
        return used.string(from: NSDecimalNumber.zero)
    }

    static func zero(formatter: NumberFormatter?, currencyCode: String?) -> String? {
        if let formatter, let formatted = zero(formatter: formatter), !formatted.isEmpty {
            return formatted
        }
        guard let currencyCode, !currencyCode.isEmpty else { return nil }
        return zero(currencyCode: currencyCode, locale: formatter?.locale ?? .current)
    }

    static func zero(currencyCode: String, locale: Locale) -> String? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSDecimalNumber.zero)
    }
}
