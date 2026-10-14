//
//  MoreDrawer.swift
//  Advent Praise
//
//  More, in AdventDrawer: the Pro card on top, then reading switches (and
//  Haptics), tools, the feature board, support and about (with the Share
//  anonymous usage switch). Opened from the More tile in the Lectern's
//  hymn tray. Every screen More leads to is a page inside the drawer: the
//  Tools (and their own pages: a passage, a collection, a service plan),
//  Vote on features (only when the app has a Features.Vote board), Support
//  Advent Praise, About Advent Praise, the Privacy Policy and the Terms of
//  Use. They push over More, and back returns to it, where the user left
//  off. Church mode, a hymn opened from a page and the Pro paywall close the
//  drawer and move on. There is no email: the app has no contact address.
//  Translation, theme and text are in the reader menu; About this hymn there
//  too, Memorise in the tray.
//

import SwiftUI

/// The pages More pushes inside its drawer.
enum MorePage: AdventDrawerPage {
    case scripture, passage(Passage)
    case collections, collection(HymnCollection)
    case planner, plan(UUID), planPitch(Int)
    case pitch
    case featureBoard
    case support, aboutApp, privacy, terms

    /// The page for a More row.
    init(_ sheet: ExtraSheet) {
        switch sheet {
        case .scripture: self = .scripture
        case .collections: self = .collections
        case .planner: self = .planner
        case .support: self = .support
        case .aboutApp: self = .aboutApp
        case .privacy: self = .privacy
        case .terms: self = .terms
        case .pitch, .about, .memory: self = .pitch
        }
    }

    var drawerTitle: Text {
        switch self {
        case .scripture: Text(ExtraSheet.scripture.title)
        case .passage(let passage): Text(verbatim: passage.reference)
        case .collections: Text(ExtraSheet.collections.title)
        case .collection(let collection): Text(verbatim: collection.title)
        case .planner: Text(ExtraSheet.planner.title)
        case .plan: Text("Service plan")
        case .pitch, .planPitch: Text(ExtraSheet.pitch.title)
        case .featureBoard: Text("Vote on features")
        case .support: Text("Support")
        case .aboutApp: Text("About")
        case .privacy: Text("Privacy")
        case .terms: Text("Terms")
        }
    }

    /// The board scrolls itself.
    var fillsDrawer: Bool { self == .featureBoard }
}

extension View {
    func moreDrawer(model: ReaderModel) -> some View {
        modifier(MoreDrawerPresenter(model: model))
    }
}

private struct MoreDrawerPresenter: ViewModifier {
    @Bindable var model: ReaderModel

    func body(content: Content) -> some View {
        content.adventDrawer("More", isPresented: $model.showMore, path: $model.morePath) {
            MoreDrawerContent(model: model)
        } destination: { page in
            destination(for: page)
        }
        // More stays mounted under its pages, so coming back counts as a visit here.
        .onChange(of: model.morePath.isEmpty) { _, isRoot in
            if isRoot, model.showMore { Analytics.screen(.more) }
        }
        // Over the drawer, which stays open under it.
        .supportSheet(isPresented: $model.showSupport)
    }

    @ViewBuilder
    private func destination(for page: MorePage) -> some View {
        switch page {
        case .scripture: ScriptureIndexPage(model: model) { push(.passage($0)) }
        case .passage(let passage): PassageHymnsPage(model: model, passage: passage)
        case .collections: CollectionsPage(model: model) { push(.collection($0)) }
        case .collection(let collection):
            CollectionHymnsPage(model: model, collection: collection) { push(.plan($0)) }
        case .planner: ServicePlansPage(model: model) { push(.plan($0)) }
        case .plan(let id): ServicePlanPage(model: model, planID: id) { push(.planPitch($0)) }
        case .planPitch(let number):
            PitchPipeView(hymnal: model.hymnal, hymn: model.hymnal.hymn(number: number) ?? model.hymn)
        case .pitch: PitchPipeView(hymnal: model.hymnal, hymn: model.hymn)
        case .featureBoard: FeatureBoardPage()
        // Support is a sheet over More (supportSheet), not a page.
        case .support: EmptyView()
        case .aboutApp: AboutAppView { push($0 == .privacy ? .privacy : .terms) }
        case .privacy: PrivacyPolicyView()
        case .terms: TermsOfUseView()
        }
    }

    private func push(_ page: MorePage) { model.morePath.append(page) }
}

private struct MoreDrawerContent: View {
    @Bindable var model: ReaderModel
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
                        model.morePath.append(MorePage(tool))
                    }
                }
            }
            // No email: requests and corrections go to the board, when there is one.
            if FeatureBoardConfig.isEnabled {
                DSInsetGroup(title: "Help us improve") {
                    MoreRow(title: "Vote on features", detail: String(localized: "Or request one"), isLast: true) {
                        Image(systemName: "lightbulb")
                    } action: {
                        guard FeatureBoard.prepare(for: settings.surface) else { return }
                        model.morePath.append(.featureBoard)
                    }
                    .accessibilityHint("Opens the feature board. Requests and votes leave this phone.")
                }
            }
            DSInsetGroup(title: "Support") {
                // The tips, for everyone: the one row that opens a sheet, like
                // the paywall. Closing it comes back here.
                MoreRow(title: ExtraSheet.support.title, detail: ExtraSheet.support.detail(for: model)) {
                    Image(systemName: ExtraSheet.support.systemImage)
                } action: {
                    model.showSupport = true
                }
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
            model.morePath.append(MorePage(sheet))
        }
    }
}

// MARK: - Rows

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
