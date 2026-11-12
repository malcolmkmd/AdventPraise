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
    /// Set when the purchase-cancel sheet is shown, for the rest of this install.
    @ObservationIgnored static let purchaseCancelReviewKey = "reviewPrompt.purchaseCancelReviewShown"
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

    /// The gentle prompt has been shown in some version of the app.
    var hasAskedGently: Bool { state.askedVersion != nil }

    /// A gentle ask is waiting for a free screen.
    var isGentlePending: Bool { pending != nil }

    /// The purchase-cancel sheet has been shown on this install.
    var purchaseCancelReviewShown: Bool { defaults.bool(forKey: Self.purchaseCancelReviewKey) }

    /// The purchase-cancel sheet is the ask for this install. Clears a
    /// waiting gentle prompt so the two aren't both on screen.
    func notePurchaseCancelReviewShown() {
        defaults.set(true, forKey: Self.purchaseCancelReviewKey)
        pending = nil
        save()
    }

    private func offer(_ trigger: ReviewTrigger?) {
        guard let trigger, pending == nil, !purchaseCancelReviewShown else { return }
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
/// The ground is the reading surface, opaque, so a glass sheet cannot wash
/// the words out over the hymn.
struct ReviewPromptSheet: View {
    let trigger: ReviewTrigger
    let onAnswer: (ReviewPromptOutcome) -> Void

    @Environment(\.requestReview) private var requestReview
    @Environment(\.dsSurface) private var surface
    @State private var answered = false

    var body: some View {
        let ink = ReviewAskInk(surface: surface)
        VStack(spacing: DS.Space.m) {
            Image(systemName: "star.bubble")
                .font(DS.Typeface.display)
                .foregroundStyle(surface.tint)
                .accessibilityHidden(true)
            Text("Help others find Advent Praise")
                .font(DS.Typeface.panelTitle)
                .foregroundStyle(ink.title)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text("A rating on the App Store helps other church members find the app, and your comments help decide what to improve next.")
                .font(DS.Typeface.rowBody)
                .foregroundStyle(ink.body)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: DS.Space.s)
            ReviewAskButtons(primary: "Rate Advent Praise", primaryID: "reviewPrompt.rate",
                             secondaryID: "reviewPrompt.notNow") {
                finish(.rate)
                // After the sheet has gone, so the system prompt isn't lost under it.
                let request = requestReview
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(600))
                    request()
                }
            } onSecondary: {
                finish(.notNow)
            }
        }
        .padding(DS.Space.l)
        .reviewAskChrome()
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

// MARK: - Readable sheet

/// Colours for the rating asks. Title and body sit on an opaque surface;
/// the primary button is white on a darker evergreen (about 7:1), on every theme.
struct ReviewAskInk {
    let surface: DSSurface
    var title: Color { surface.foreground }
    /// `secondary` is tuned to stay at least 4.5:1 on this surface.
    var body: Color { surface.secondary }
    var quietFill: Color { surface.background }
    var quietLabel: Color { surface.foreground }
    var quietBorder: Color { surface.controlBorder }
}

/// Opaque reading-surface ground. `elevated` is the solid stand-in for a
/// material: a material over the hymn is what washed these sheets out.
struct ReviewAskGround: View {
    @Environment(\.dsSurface) private var surface
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dsWorshipMode) private var worship

    var body: some View {
        let high = worship || contrast == .increased
        (high ? surface.highContrastBackground : surface.elevated)
            .accessibilityHidden(true)
    }
}

extension View {
    /// Medium sheet on the reading surface, not the system glass.
    func reviewAskChrome() -> some View {
        modifier(ReviewAskChrome())
    }
}

private struct ReviewAskChrome: ViewModifier {
    @Environment(\.dsSurface) private var surface

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background { ReviewAskGround() }
            .environment(\.colorScheme, surface.colorScheme)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground { ReviewAskGround() }
    }
}

/// White label on darker evergreen, and a solid "Not now" in the primary label colour.
struct ReviewAskButtons: View {
    let primary: LocalizedStringKey
    var primaryID: String = ""
    var secondaryID: String = ""
    let onPrimary: () -> Void
    let onSecondary: () -> Void

    @Environment(\.dsSurface) private var surface

    var body: some View {
        let ink = ReviewAskInk(surface: surface)
        VStack(spacing: DS.Space.s) {
            Button(action: onPrimary) {
                Text(primary)
                    .font(DS.Typeface.button)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, minHeight: DS.Size.row)
                    .background(RoundedRectangle.ds(DS.Radius.key).fill(DS.Palette.evergreenDeep))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(primaryID)
            Button(action: onSecondary) {
                Text("Not now")
                    .font(DS.Typeface.button)
                    .foregroundStyle(ink.quietLabel)
                    .frame(maxWidth: .infinity, minHeight: DS.Size.row)
                    .background(RoundedRectangle.ds(DS.Radius.key).fill(ink.quietFill))
                    .overlay(RoundedRectangle.ds(DS.Radius.key).strokeBorder(ink.quietBorder))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(secondaryID)
        }
        .frame(maxWidth: 400)
    }
}

/// The sheet over a hymn, so a preview shows the ground is opaque.
struct HymnBackedSheetPreview<Sheet: View>: View {
    let surface: DSSurface
    @ViewBuilder var sheet: () -> Sheet

    var body: some View {
        ZStack(alignment: .bottom) {
            DSPreviewBackdrop()
            sheet()
                .frame(maxHeight: 480)
        }
        .dsSurface(surface)
    }
}

#Preview("Help others · dark, over a hymn") {
    HymnBackedSheetPreview(surface: .black) {
        ReviewPromptSheet(trigger: .fifthSession) { _ in }
    }
}

#Preview("Help others · paper, over a hymn") {
    HymnBackedSheetPreview(surface: .paper) {
        ReviewPromptSheet(trigger: .fifthSession) { _ in }
    }
}
