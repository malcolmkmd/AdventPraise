//
//  PurchasesClient.swift
//  Advent Praise
//
//  The one door to RevenueCat. PurchaseStore talks to a `PurchasesClient`
//  and only ever sees plain values (who owns what, the offering's packages
//  with their App Store prices, how a purchase ended), so its rules can be
//  tested with a stand-in client and no network.
//
//  `RevenueCatPurchasesClient` is the real one. `PreviewPurchasesClient`
//  (DEBUG) serves fixed prices and pretends purchases go through: SwiftUI
//  previews, unit-test host launches and DEBUG builds without a key use it.
//

import Foundation
@preconcurrency import RevenueCat

// MARK: - Values

/// What RevenueCat says about this customer.
struct CustomerSnapshot: Equatable, Sendable {
    /// Active entitlement identifiers ("pro").
    var activeEntitlements: Set<String> = []
    /// Products bought, tips left out.
    var purchasedProductIDs: Set<String> = []
}

/// One package of an offering, with its App Store price.
struct OfferingPackage: Equatable, Sendable {
    /// The RevenueCat package identifier ("$rc_lifetime").
    let id: String
    /// The App Store product behind it.
    let productID: String
    /// The App Store's localized price: "R199.99".
    let price: String
}

/// An offering as the paywall needs it.
struct OfferingSnapshot: Equatable, Sendable {
    let id: String
    let packages: [OfferingPackage]
}

/// How one purchase ended.
enum PurchaseOutcome: Equatable, Sendable {
    /// Paid, with what the customer has now.
    case completed(CustomerSnapshot)
    case cancelled
    /// Ask to Buy, or the bank wants a check: it may still go through.
    case pending
    /// `message` is for the buyer; the reason is for analytics.
    case failed(PurchaseFailure, message: String)
}

/// How Restore purchases ended.
enum RestoreOutcome: Equatable, Sendable {
    case restored(CustomerSnapshot)
    /// The buyer closed the App Store sign-in.
    case cancelled
    case failed
}

@MainActor
protocol PurchasesClient: AnyObject {
    /// Has an API key, so RevenueCat can be asked anything.
    var isConfigured: Bool { get }
    /// Once, at launch.
    func configure()
    /// The customer now and after every change (purchases on another
    /// device, Ask to Buy approvals, refunds).
    func customerUpdates() -> AsyncStream<CustomerSnapshot>
    func customer() async throws -> CustomerSnapshot
    /// The offering by identifier, or the current one; nil when none is set up.
    func offering(id: String?) async throws -> OfferingSnapshot?
    /// App Store prices by product ID, for the products that loaded.
    func prices(of productIDs: [String]) async -> [String: String]
    /// Buys a package of the last offering loaded.
    func purchase(package: OfferingPackage) async -> PurchaseOutcome
    /// Buys a product by ID (a tip) whose price was loaded.
    func purchase(productID: String) async -> PurchaseOutcome
    func restore() async -> RestoreOutcome
}

enum PurchasesClients {
    /// The client the app runs with.
    @MainActor
    static func live() -> any PurchasesClient {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        let isPreview = environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        let isTestHost = environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil || environment["XCTestSessionIdentifier"] != nil
        if isPreview || isTestHost || PurchaseConfig.revenueCatAPIKey.isEmpty {
            return PreviewPurchasesClient()
        }
        #endif
        return RevenueCatPurchasesClient()
    }
}

// MARK: - RevenueCat

@MainActor
final class RevenueCatPurchasesClient: PurchasesClient {
    /// The packages of the last offering loaded, and tip products, by ID.
    private var packages: [String: Package] = [:]
    private var products: [String: StoreProduct] = [:]

    var isConfigured: Bool { !PurchaseConfig.revenueCatAPIKey.isEmpty && Purchases.isConfigured }

    func configure() {
        guard !PurchaseConfig.revenueCatAPIKey.isEmpty, !Purchases.isConfigured else { return }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: PurchaseConfig.revenueCatAPIKey)
    }

    func customerUpdates() -> AsyncStream<CustomerSnapshot> {
        guard isConfigured else { return AsyncStream { $0.finish() } }
        let infos = Purchases.shared.customerInfoStream
        let (stream, continuation) = AsyncStream.makeStream(of: CustomerSnapshot.self)
        let task = Task {
            for await info in infos { continuation.yield(Self.snapshot(info)) }
            continuation.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    func customer() async throws -> CustomerSnapshot {
        guard isConfigured else { return CustomerSnapshot() }
        return Self.snapshot(try await Purchases.shared.customerInfo())
    }

    func offering(id: String?) async throws -> OfferingSnapshot? {
        guard isConfigured else { return nil }
        let offerings = try await Purchases.shared.offerings()
        guard let offering = id.flatMap({ offerings.offering(identifier: $0) }) ?? offerings.current else { return nil }
        for package in offering.availablePackages { packages[package.identifier] = package }
        return OfferingSnapshot(id: offering.identifier, packages: offering.availablePackages.map { package in
            OfferingPackage(id: package.identifier,
                            productID: package.storeProduct.productIdentifier,
                            price: package.storeProduct.localizedPriceString)
        })
    }

    func prices(of productIDs: [String]) async -> [String: String] {
        guard isConfigured else { return [:] }
        var prices: [String: String] = [:]
        for product in await Purchases.shared.products(productIDs) {
            products[product.productIdentifier] = product
            prices[product.productIdentifier] = product.localizedPriceString
        }
        return prices
    }

    func purchase(package: OfferingPackage) async -> PurchaseOutcome {
        guard isConfigured, let found = packages[package.id] else { return Self.unavailable }
        do {
            return Self.outcome(of: try await Purchases.shared.purchase(package: found))
        } catch {
            return Self.outcome(of: error)
        }
    }

    func purchase(productID: String) async -> PurchaseOutcome {
        guard isConfigured, let product = products[productID] else { return Self.unavailable }
        do {
            return Self.outcome(of: try await Purchases.shared.purchase(product: product))
        } catch {
            return Self.outcome(of: error)
        }
    }

    func restore() async -> RestoreOutcome {
        guard isConfigured else { return .failed }
        do {
            return .restored(Self.snapshot(try await Purchases.shared.restorePurchases()))
        } catch let error as RevenueCat.ErrorCode where error == .purchaseCancelledError {
            return .cancelled
        } catch {
            Analytics.error(.restore, error)
            return .failed
        }
    }

    // MARK: Mapping

    private static let unavailable = PurchaseOutcome.failed(
        .unavailable, message: "This isn’t available right now. Check your connection and try again.")

    private static func snapshot(_ info: CustomerInfo) -> CustomerSnapshot {
        CustomerSnapshot(activeEntitlements: Set(info.entitlements.active.keys),
                         purchasedProductIDs: info.allPurchasedProductIdentifiers.subtracting(PurchaseConfig.tipProductIDs))
    }

    private static func outcome(of result: PurchaseResultData) -> PurchaseOutcome {
        result.userCancelled ? .cancelled : .completed(snapshot(result.customerInfo))
    }

    /// RevenueCat's errors, in the words the App Store sheet would use. The
    /// buyer is never told they were charged when they weren't.
    private static func outcome(of error: any Error) -> PurchaseOutcome {
        guard let code = error as? RevenueCat.ErrorCode else {
            Analytics.error(.purchase, error)
            return .failed(.storeError, message: "The purchase didn’t go through. You haven’t been charged.")
        }
        switch code {
        case .purchaseCancelledError:
            return .cancelled
        case .paymentPendingError:
            return .pending
        case .networkError, .offlineConnectionError:
            return .failed(.storeError, message: "Couldn’t reach the App Store. Check your connection and try again. You haven’t been charged.")
        case .purchaseNotAllowedError:
            return .failed(.notAllowed, message: "Purchases aren’t allowed on this device. Check Screen Time in Settings.")
        case .productNotAvailableForPurchaseError:
            return unavailable
        case .invalidReceiptError, .missingReceiptFileError:
            Analytics.error(.purchase, error)
            return .failed(.unverified, message: "The App Store couldn’t confirm this purchase. Try Restore purchases in a moment.")
        default:
            Analytics.error(.purchase, error)
            return .failed(.storeError, message: "The purchase didn’t go through. You haven’t been charged.")
        }
    }
}

// MARK: - Preview

#if DEBUG
/// Fixed prices (Products.storekit's, in rand) and purchases that pretend to
/// go through. Never in a Release build.
@MainActor
final class PreviewPurchasesClient: PurchasesClient {
    static let proPrice = "R199.99"
    static let tipPrices = ["ap_tip_amen": "R19.99", "ap_tip_hallelujah": "R49.99", "ap_tip_hosanna": "R99.99"]

    private var current = CustomerSnapshot()
    private var continuations: [UUID: AsyncStream<CustomerSnapshot>.Continuation] = [:]

    var isConfigured: Bool { true }

    func configure() {}

    func customerUpdates() -> AsyncStream<CustomerSnapshot> {
        let (stream, continuation) = AsyncStream.makeStream(of: CustomerSnapshot.self)
        continuation.yield(current)
        continuations[UUID()] = continuation
        return stream
    }

    func customer() async throws -> CustomerSnapshot { current }

    func offering(id: String?) async throws -> OfferingSnapshot? {
        OfferingSnapshot(id: "default", packages: [
            OfferingPackage(id: "$rc_lifetime", productID: PurchaseConfig.proProductID, price: Self.proPrice),
        ])
    }

    func prices(of productIDs: [String]) async -> [String: String] {
        Self.tipPrices.filter { productIDs.contains($0.key) }
    }

    func purchase(package: OfferingPackage) async -> PurchaseOutcome {
        try? await Task.sleep(for: .milliseconds(600))
        current.activeEntitlements.insert(PurchaseConfig.proEntitlement)
        current.purchasedProductIDs.insert(package.productID)
        continuations.values.forEach { $0.yield(current) }
        return .completed(current)
    }

    func purchase(productID: String) async -> PurchaseOutcome {
        try? await Task.sleep(for: .milliseconds(600))
        return .completed(current)
    }

    func restore() async -> RestoreOutcome { .restored(current) }
}
#endif
