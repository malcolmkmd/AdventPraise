//
//  MoreDrawer.swift
//  Advent Praise
//
//  More, in AdventDrawer: the Pro card on top, then reading switches (and
//  Haptics), tools, the feature board, support and about (with the Share
//  anonymous usage switch). Opened from the More tile in the Lectern's
//  hymn tray. Support Advent Praise, About Advent Praise, the Privacy
//  Policy, the Terms of Use and the pitch pipe are pages inside the drawer:
//  they push over More, and back returns to it, where the user left off.
//  The other Tools and Vote on features (only when the app has a
//  Features.Vote board) are full screens, so they close the drawer and stand
//  in for More one level down: closing them (Done, a swipe) reopens More at
//  the row they came from. Church mode and the Pro paywall move on for
//  good. There is no email: the app has no contact address. Translation,
//  theme and text are in the reader menu; About this hymn there too,
//  Memorise in the tray.
//

import SwiftUI

extension View {
    func moreDrawer(model: ReaderModel) -> some View {
        modifier(MoreDrawerPresenter(model: model))
    }
}

private struct MoreDrawerPresenter: ViewModifier {
    @Bindable var model: ReaderModel
    /// More's pages, pushed inside the drawer. Empty: More itself.
    @State private var path: [ExtraSheet] = []

    func body(content: Content) -> some View {
        content.adventDrawer("More", isPresented: $model.showMore, path: $path) {
            ScrollViewReader { proxy in
                MoreDrawerContent(model: model, path: $path)
                    // Back from one of its screens: where the user left off.
                    .onAppear {
                        guard let row = model.takeMoreScrollAnchor() else { return }
                        proxy.scrollTo(row, anchor: .center)
                    }
            }
        } destination: { page in
            switch page {
            case .aboutApp: AboutAppView { path.append($0 == .privacy ? .privacy : .terms) }
            case .privacy: PrivacyPolicyView()
            case .terms: TermsOfUseView()
            case .support: SupportView()
            case .pitch: PitchPipeView(hymnal: model.hymnal, hymn: model.hymn)
            case .about, .scripture, .collections, .memory, .planner: EmptyView()
            }
        }
        // More stays mounted under its pages, so coming back counts as a visit here.
        .onChange(of: path.isEmpty) { _, isRoot in
            if isRoot, model.showMore { Analytics.screen(.more) }
        }
    }
}

extension ExtraSheet {
    /// The screens that open as pages inside the More drawer rather than in a sheet.
    fileprivate var isMorePage: Bool {
        switch self {
        case .support, .aboutApp, .privacy, .terms, .pitch: true
        case .about, .scripture, .collections, .memory, .planner: false
        }
    }
}

private struct MoreDrawerContent: View {
    @Bindable var model: ReaderModel
    @Binding var path: [ExtraSheet]
    @Environment(ReadingSettings.self) private var settings
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var settings = settings
        @Bindable var haptics = Haptics.shared
        @Bindable var analytics = Analytics.shared
        VStack(alignment: .leading, spacing: DS.Space.m) {
            VStack(alignment: .leading, spacing: DS.Space.hair) {
                Text("More").font(DS.Typeface.sheetTitle).accessibilityAddTraits(.isHeader)
                Text("Advent Praise \(AppInfo.version)")
                    .dsEyebrow(tracking: 0.9)
                    .foregroundStyle(settings.surface.secondary)
            }
            // Clear of the close button.
            .padding(.trailing, DS.Size.hitTarget + DS.Space.m)
            .frame(minHeight: DS.Size.hitTarget, alignment: .leading)
            .padding(.bottom, DS.Space.xs)

            // Pro first: one row, the free plays left or thanks; opens the paywall.
            ProMoreCard {
                model.showMore = false
                model.paywall = .support
            }

            // Translation, theme and text are in the reader menu (the globe).
            DSInsetGroup(title: "Reading") {
                MoreToggleRow(title: "Chorus after every verse", isOn: $settings.repeatChorus) {
                    Image(systemName: "repeat")
                }
                MoreToggleRow(title: "Haptics", isOn: $haptics.isEnabled) {
                    Image(systemName: "hand.tap")
                }
                MoreRow(title: "Church mode", detail: "One verse at a time", isLast: true) {
                    Image(systemName: "rectangle.on.rectangle")
                } action: {
                    model.showMore = false
                    model.enterChurchMode(from: .more)
                }
            }
            DSInsetGroup(title: "Tools") {
                ForEach(ExtraSheet.toolsOrder) { tool in
                    MoreRow(title: tool.title, detail: tool.detail(for: model),
                            isLast: tool == ExtraSheet.toolsOrder.last) {
                        Image(systemName: tool.systemImage)
                    } action: {
                        Analytics.track(.toolOpened(tool, source: .more))
                        open(tool, row: MoreRowID.tool(tool))
                    }
                    .id(MoreRowID.tool(tool))
                }
            }
            // No email: requests and corrections go to the board, when there is one.
            if FeatureBoardConfig.isEnabled {
                DSInsetGroup(title: "Help us improve") {
                    MoreRow(title: "Vote on features", detail: String(localized: "Or request one"), isLast: true) {
                        Image(systemName: "lightbulb")
                    } action: {
                        guard FeatureBoard.prepare(for: settings.surface) else { return }
                        Haptics.play(.softImpact)
                        model.leaveMore(for: MoreRowID.featureBoard) { model.showFeatureBoard = true }
                    }
                    .id(MoreRowID.featureBoard)
                    .accessibilityHint("Opens the feature board. Requests and votes leave this phone.")
                }
            }
            DSInsetGroup(title: "Support") {
                // The tips, for everyone; back comes here.
                sheetRow(.support)
                MoreRow(title: "Recommend Advent Praise") {
                    Image(systemName: "paperplane")
                } action: {
                    Analytics.track(.shareOpened)
                    model.showShare = true
                }
                MoreRow(title: "Rate on the App Store", isLast: true) {
                    Image(systemName: "star")
                } action: {
                    Analytics.track(.externalLinkOpened(.rateApp))
                    openURL(AppInfo.writeReviewURL)
                }
            }
            DSInsetGroup(title: "About") {
                sheetRow(.aboutApp)
                // The policy (the MIDI files' credit is in it), then the terms.
                sheetRow(.privacy)
                sheetRow(.terms)
                MoreToggleRow(title: "Share anonymous usage", isOn: $analytics.isEnabled, isLast: true) {
                    Image(systemName: "chart.bar")
                }
            }
            Text("Anonymous usage is a count of which features are used, so we know what to improve. It never includes your name, the words of hymns or what you search for.")
                .font(DS.Typeface.caption)
                .foregroundStyle(settings.surface.secondary)
                .padding(.horizontal, DS.Space.xxs)
                .padding(.top, -DS.Space.xs)
        }
        .padding(.horizontal, DS.Space.l)
        .padding(.top, DS.Space.m)
        .analyticsScreen(.more)
    }

    /// A screen that isn't a tool; back comes here.
    private func sheetRow(_ sheet: ExtraSheet) -> some View {
        MoreRow(title: sheet.title, detail: sheet.detail(for: model)) {
            Image(systemName: sheet.systemImage)
        } action: {
            open(sheet, row: MoreRowID.sheet(sheet))
        }
        .id(MoreRowID.sheet(sheet))
    }

    /// A page pushes inside the drawer; a full screen closes it and comes back to `row`.
    private func open(_ sheet: ExtraSheet, row: String) {
        if sheet.isMorePage {
            path.append(sheet)
        } else {
            model.leaveMore(for: row) { Extras.shared.sheet = sheet }
        }
    }
}

// MARK: - Rows

/// Scroll targets for the rows whose screens come back to More.
private enum MoreRowID {
    static let featureBoard = "featureBoard"
    static func tool(_ tool: ExtraSheet) -> String { "tool.\(tool.rawValue)" }
    static func sheet(_ sheet: ExtraSheet) -> String { "sheet.\(sheet.rawValue)" }
}

/// A drawer row that leads somewhere. Also About this hymn's.
struct MoreRow<Icon: View>: View {
    let title: LocalizedStringKey
    var detail: String? = nil
    var isLast = false
    @ViewBuilder let icon: Icon
    let action: () -> Void
    @Environment(\.dsSurface) private var surface

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Space.m) {
                icon.font(.system(size: 18)).foregroundStyle(surface.tint).frame(width: 28)
                Text(title).font(DS.Typeface.label)
                Spacer(minLength: 0)
                if let detail {
                    Text(detail).font(DS.Typeface.caption).foregroundStyle(surface.secondary).lineLimit(1)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(surface.secondary)
            }
            .padding(.horizontal, DS.Space.m)
            .frame(minHeight: 46)
            .overlay(alignment: .bottom) { if !isLast { Divider().padding(.leading, 52) } }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct MoreToggleRow<Icon: View>: View {
    let title: LocalizedStringKey
    @Binding var isOn: Bool
    var isLast = false
    @ViewBuilder let icon: Icon
    @Environment(\.dsSurface) private var surface

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: DS.Space.m) {
                icon.font(.system(size: 18)).foregroundStyle(surface.tint).frame(width: 28)
                Text(title).font(DS.Typeface.label)
            }
        }
        .tint(surface.tint)
        .padding(.horizontal, DS.Space.m)
        .frame(minHeight: 46)
        .overlay(alignment: .bottom) { if !isLast { Divider().padding(.leading, 52) } }
    }
}
