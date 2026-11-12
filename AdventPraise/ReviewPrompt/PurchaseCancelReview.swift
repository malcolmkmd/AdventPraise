//
//  PurchaseCancelReview.swift
//  Advent Praise
//
//  After someone closes the App Store sheet on Pro (not on a tip), a short
//  ask for a review. Once per install, never for someone who has Pro, and
//  never when the gentle rating prompt has already asked or is waiting, so
//  the two don't both appear. The sheet uses the same opaque reading-surface
//  ground as the gentle rating prompt, so the words stay readable over a hymn.
//

import StoreKit
import SwiftUI

/// Whether the sheet may appear. Pure, so the once-per-install rules can be
/// tested without a view or RevenueCat.
enum PurchaseCancelReviewDecision {
    static func show(isPro: Bool, alreadyShown: Bool, gentleAsked: Bool, gentlePending: Bool) -> Bool {
        !isPro && !alreadyShown && !gentleAsked && !gentlePending
    }
}

/// How the sheet ended.
enum PurchaseCancelReviewOutcome: String, Sendable {
    /// "Leave a review".
    case review
    case notNow = "not_now"
    /// Swiped away.
    case dismissed
}

@MainActor @Observable
final class PurchaseCancelReviewCenter {
    static let shared = PurchaseCancelReviewCenter()

    /// The sheet is up while this is set.
    var isPresented = false

    @ObservationIgnored private var didLogShow = false

    /// Called when a Pro purchase comes back cancelled. Tips never call this.
    func consider(isPro: Bool, prompt: ReviewPrompt = .shared) {
        guard PurchaseCancelReviewDecision.show(
            isPro: isPro,
            alreadyShown: prompt.purchaseCancelReviewShown,
            gentleAsked: prompt.hasAskedGently,
            gentlePending: prompt.isGentlePending) else { return }
        // Marked now, so a second cancel can't stack a second sheet, and the
        // gentle prompt won't ask as well.
        prompt.notePurchaseCancelReviewShown()
        didLogShow = false
        isPresented = true
    }

    func shown() {
        guard isPresented, !didLogShow else { return }
        didLogShow = true
        Analytics.track(.purchaseCancelReviewShown)
    }

    func answered(_ outcome: PurchaseCancelReviewOutcome) {
        guard isPresented else { return }
        isPresented = false
        Analytics.track(.purchaseCancelReviewAnswered(outcome))
    }
}

extension View {
    /// The review ask after a cancelled Pro purchase, over the paywall.
    func purchaseCancelReviewSheet() -> some View {
        sheet(isPresented: Binding(get: { PurchaseCancelReviewCenter.shared.isPresented },
                                   // A swipe is recorded by the sheet's onDisappear.
                                   set: { _ in })) {
            PurchaseCancelReviewSheet { outcome in
                PurchaseCancelReviewCenter.shared.answered(outcome)
            }
            .onAppear { PurchaseCancelReviewCenter.shared.shown() }
        }
    }
}

// MARK: - Asking iOS

@MainActor
enum AppReviewRequest {
    /// Asks for the in-app review prompt. False when there is no window scene
    /// to present it in, which is when the write-review page should open.
    /// `requestReview` is rate-limited and may still show nothing.
    @discardableResult
    static func requestInScene() -> Bool {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            return false
        }
        if #available(iOS 18, *) {
            AppStore.requestReview(in: scene)
        } else {
            SKStoreReviewController.requestReview(in: scene)
        }
        return true
    }
}

// MARK: - Sheet

struct PurchaseCancelReviewSheet: View {
    let onAnswer: (PurchaseCancelReviewOutcome) -> Void
    var startsOpen = false

    @Environment(\.dsSurface) private var surface
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var opened: Bool
    @State private var answered = false

    init(onAnswer: @escaping (PurchaseCancelReviewOutcome) -> Void, startsOpen: Bool = false) {
        self.onAnswer = onAnswer
        self.startsOpen = startsOpen
        _opened = State(initialValue: startsOpen)
    }

    var body: some View {
        let ink = ReviewAskInk(surface: surface)
        VStack(spacing: DS.Space.m) {
            Text("No worries")
                .font(DS.Typeface.display)
                .foregroundStyle(ink.title)
                .dsBalancedWrap()
                .accessibilityAddTraits(.isHeader)
            Text("Advent Praise is free for everyone. If it’s been a blessing, a quick review helps more people find it.")
                .font(DS.Typeface.rowBody)
                .foregroundStyle(ink.body)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: DS.Space.l)
            ReviewAskButtons(primary: "Leave a review", primaryID: "purchaseCancelReview.leaveReview",
                             secondaryID: "purchaseCancelReview.notNow", onPrimary: leaveReview, onSecondary: { finish(.notNow) })
        }
        .padding(.horizontal, DS.Space.l + DS.Space.xxs)
        .padding(.top, DS.Space.l + DS.Space.m)
        .padding(.bottom, DS.Space.l)
        .modifier(PaywallRise(opened: opened, reduceMotion: reduceMotion))
        .reviewAskChrome()
        .onAppear {
            withAnimation(reduceMotion ? .easeInOut(duration: 0.5) : .spring(duration: 0.8, bounce: 0).delay(0.1)) {
                opened = true
            }
        }
        .onDisappear { finish(.dismissed) }
        .accessibilityAction(.escape) { finish(.notNow) }
    }

    private func leaveReview() {
        finish(.review)
        // After the sheet has gone, so the system prompt isn't lost under it.
        // No scene to present in: the write-review page (app id 1015021132).
        let open = openURL
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            if !AppReviewRequest.requestInScene() {
                open(AppInfo.writeReviewURL)
            }
        }
    }

    private func finish(_ outcome: PurchaseCancelReviewOutcome) {
        guard !answered else { return }
        answered = true
        onAnswer(outcome)
    }
}

#Preview("No worries · dark, over a hymn") {
    HymnBackedSheetPreview(surface: .black) {
        PurchaseCancelReviewSheet(onAnswer: { _ in }, startsOpen: true)
    }
}

#Preview("No worries · paper, over a hymn") {
    HymnBackedSheetPreview(surface: .paper) {
        PurchaseCancelReviewSheet(onAnswer: { _ in }, startsOpen: true)
    }
}
