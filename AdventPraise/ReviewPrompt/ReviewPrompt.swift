import StoreKit
import SwiftUI

/// Decides when to ask for a rating and holds the pending ask until the
/// screen is free. It listens to the analytics events the app already sends,
/// so the features themselves don't need to know about it.
@MainActor @Observable
final class ReviewPrompt {
    static let shared = ReviewPrompt()

    /// The ask waiting to show (the sheet presents while this is set).
    var pending: ReviewTrigger?

    /// How long the sheet music needs to stay open to count as finished.
    static let sheetMusicMinimum: TimeInterval = 60

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key = "reviewPrompt.eligibility"
    @ObservationIgnored private var state: ReviewEligibility
    @ObservationIgnored private var sheetMusicOpenedAt: Date?
    @ObservationIgnored private let version: String

    init(defaults: UserDefaults = .standard,
         version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0") {
        self.defaults = defaults
        self.version = version
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode(ReviewEligibility.self, from: data) {
            state = saved
        } else {
            state = ReviewEligibility()
        }
    }

    // MARK: Signals

    /// Fed every analytics event, sent or not (consent only governs sending).
    nonisolated static func observe(_ event: AnalyticsEvent) {
        Task { @MainActor in shared.handle(event) }
    }

    func handle(_ event: AnalyticsEvent, now: Date = .now) {
        switch event {
        case .appOpened:
            offer(state.recordSession(version: version, now: now))
        case let .favouriteToggled(_, isFavourite) where isFavourite:
            offer(state.recordFavouriteAdded(version: version, now: now))
        case .accompanimentCompleted:
            offer(state.finishedPlayback(.accompanimentFinished, version: version, now: now))
        case .sheetMusicOpened:
            sheetMusicOpenedAt = now
        case .paywallViewed, .paywallDismissed, .playLimitPaywallShown, .sheetMusicPaywallOpened,
             .purchaseStarted, .purchaseCompleted, .tipStarted, .tipCompleted:
            state.recordPaywallOrPurchase(now: now)
            pending = nil
        default:
            return
        }
        save()
    }

    /// The sheet music closed; long enough open counts as finishing it.
    func sheetMusicClosed(now: Date = .now) {
        guard let opened = sheetMusicOpenedAt else { return }
        sheetMusicOpenedAt = nil
        guard now.timeIntervalSince(opened) >= Self.sheetMusicMinimum else { return }
        offer(state.finishedPlayback(.sheetMusicFinished, version: version, now: now))
    }

    private func offer(_ trigger: ReviewTrigger?) {
        guard let trigger, pending == nil else { return }
        // Asked once per version, whatever the answer: mark it now so a
        // second trigger can't stack.
        state.markAsked(version: version)
        pending = trigger
        save()
    }

    // MARK: Answers

    func shown(_ trigger: ReviewTrigger) {
        Analytics.track(.reviewPromptShown(trigger: trigger))
    }

    func answered(_ trigger: ReviewTrigger, _ outcome: ReviewPromptOutcome) {
        Analytics.track(.reviewPromptAnswered(trigger: trigger, outcome: outcome))
        pending = nil
    }

    private func save() {
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: key) }
    }
}

// MARK: - Sheet

/// The neutral ask before the system prompt: one way to rate, one way out.
struct ReviewPromptSheet: View {
    let trigger: ReviewTrigger
    let onAnswer: (ReviewPromptOutcome) -> Void

    @Environment(\.requestReview) private var requestReview
    @State private var answered = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.bubble")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Help others find Advent Praise")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("A rating on the App Store helps other church members find the app, and your comments help decide what to improve next.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                finish(.rate)
                // After the sheet has gone, so the system prompt isn't lost under it.
                let request = requestReview
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(600))
                    request()
                }
            } label: {
                Text("Rate Advent Praise").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Button("Not now") { finish(.notNow) }
                .controlSize(.large)
        }
        .padding(24)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onDisappear { finish(.dismissed) }
    }

    private func finish(_ outcome: ReviewPromptOutcome) {
        guard !answered else { return }
        answered = true
        onAnswer(outcome)
    }
}

extension View {
    /// Presents the pending rating ask when nothing else is on screen.
    func reviewPromptSheet(_ prompt: ReviewPrompt, isEnabled: Bool) -> some View {
        sheet(item: Binding(get: { isEnabled ? prompt.pending.map(ReviewPromptItem.init) : nil },
                            // A swipe away is recorded by the sheet's own onDisappear.
                            set: { _ in })) { item in
            ReviewPromptSheet(trigger: item.trigger) { outcome in
                prompt.answered(item.trigger, outcome)
            }
            .onAppear { prompt.shown(item.trigger) }
        }
    }
}

private struct ReviewPromptItem: Identifiable {
    let trigger: ReviewTrigger
    var id: String { trigger.rawValue }
}
