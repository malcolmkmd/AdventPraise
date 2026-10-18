//
//  MoreSheet.swift
//  Advent Praise
//
//  More, a sheet with its own navigation stack: the Pro card on top, the
//  MIDI Piano card under it, then reading switches (and Haptics, church mode and Replay tour), tools, the
//  feature board, support and
//  about (with the Share anonymous usage switch). Opened from the More tile
//  in the Lectern's hymn tray. The Tools (and their own pages: a passage, a
//  collection, a service plan), About Advent Praise, the Privacy Policy and
//  the Terms of Use push in the stack under a standard navigation bar: Back
//  pops, Done closes More from any depth, and the next opening starts at
//  the root. Support Advent Praise (paywall chrome), Vote on features (the
//  board has its own navigation) and Recommend open as sheets over More.
//  Church mode and the Pro paywall close More first and open once it has
//  gone; a hymn opened from a page closes it. There is no email: the app
//  has no contact address. Translation, theme and text are in the reader
//  menu; About this hymn there too (in its drawer), Memorise in the tray.
//

import SwiftUI

/// The pages More pushes in its navigation stack.
enum MorePage: Hashable {
    case scripture, passage(Passage)
    case collections, collection(HymnCollection)
    case planner, plan(UUID), planPitch(Int)
    case pitch
    case aboutApp, privacy, terms

    /// The page for a More row. Nil for the screens that aren't pages:
    /// About this hymn, Memorise, Sheet music, Support.
    init?(_ sheet: ExtraSheet) {
        switch sheet {
        case .scripture: self = .scripture
        case .collections: self = .collections
        case .planner: self = .planner
        case .pitch: self = .pitch
        case .aboutApp: self = .aboutApp
        case .privacy: self = .privacy
        case .terms: self = .terms
        case .about, .memory, .sheetMusic, .support: return nil
        }
    }

    var title: Text {
        switch self {
        case .scripture: Text(ExtraSheet.scripture.title)
        case .passage(let passage): Text(verbatim: passage.reference)
        case .collections: Text(ExtraSheet.collections.title)
        case .collection(let collection): Text(verbatim: collection.title)
        case .planner: Text(ExtraSheet.planner.title)
        case .plan: Text("Service plan")
        case .pitch, .planPitch: Text(ExtraSheet.pitch.title)
        case .aboutApp: Text("About")
        case .privacy: Text("Privacy")
        case .terms: Text("Terms")
        }
    }
}

extension View {
    func moreSheet(model: ReaderModel) -> some View {
        modifier(MoreSheetPresenter(model: model))
    }
}

private struct MoreSheetPresenter: ViewModifier {
    @Bindable var model: ReaderModel
    @Environment(ReadingSettings.self) private var settings
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content.sheet(isPresented: $model.showMore, onDismiss: { model.moreDidDismiss() }) {
            NavigationStack(path: $model.morePath) {
                MoreContent(model: model)
                    .navigationTitle("More")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationDestination(for: MorePage.self) { page in
                        destination(for: page)
                            .navigationTitle(page.title)
                            .navigationBarTitleDisplayMode(.inline)
                    }
                    .toolbar { doneButton }
            }
            .modifier(ToolSheetChrome(surface: settings.surface))
            .presentationDragIndicator(.visible)
            // Over More, which stays open under them.
            .supportSheet(isPresented: $model.showSupport)
            .sheet(isPresented: $model.showFeatureBoard) {
                FeatureBoardView()
                    .modifier(ToolSheetChrome(surface: settings.surface))
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $model.showShare) {
                ShareSheet(items: [AppInfo.shareText, AppInfo.appStoreURL]).presentationDetents([.medium, .large])
                    .analyticsScreen(.share)
            }
        }
    }

    /// Closes More from any page; the next opening starts at the root.
    private var doneButton: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Done") { model.showMore = false }
                .fontWeight(.semibold)
        }
    }

    @ViewBuilder
    private func destination(for page: MorePage) -> some View {
        Group {
            switch page {
            case .scripture: MorePageScroll { ScriptureIndexPage(model: model) { push(.passage($0)) } }
            case .passage(let passage): MorePageScroll { PassageHymnsPage(model: model, passage: passage) }
            case .collections: MorePageScroll { CollectionsPage(model: model) { push(.collection($0)) } }
            case .collection(let collection):
                MorePageScroll { CollectionHymnsPage(model: model, collection: collection) { push(.plan($0)) } }
            case .planner: MorePageScroll { ServicePlansPage(model: model) { push(.plan($0)) } }
            case .plan(let id): MorePageScroll { ServicePlanPage(model: model, planID: id) { push(.planPitch($0)) } }
            case .planPitch(let number):
                PitchPipeView(hymnal: model.hymnal, hymn: model.hymnal.hymn(number: number) ?? model.hymn)
            case .pitch: PitchPipeView(hymnal: model.hymnal, hymn: model.hymn)
            case .aboutApp: AboutAppView { push($0 == .privacy ? .privacy : .terms) }
            case .privacy: PrivacyPolicyView()
            case .terms: TermsOfUseView()
            }
        }
        // A pushed page is opaque system background otherwise; match More's.
        .background((contrast == .increased ? settings.surface.highContrastBackground : settings.surface.background).ignoresSafeArea())
        .toolbar { doneButton }
    }

    private func push(_ page: MorePage) { model.morePath.append(page) }
}

/// A page built for a scroller (DrawerPageLayout), in the stack's own ScrollView.
private struct MorePageScroll<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            content.padding(.vertical, DS.Space.m)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

private struct MoreContent: View {
    @Bindable var model: ReaderModel
    @Environment(ReadingSettings.self) private var settings
    @Environment(TourModel.self) private var tour
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var settings = settings
        @Bindable var haptics = Haptics.shared
        @Bindable var analytics = Analytics.shared
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.m) {
                Text("Advent Praise \(AppInfo.version)")
                    .dsEyebrow(tracking: 0.9)
                    .foregroundStyle(settings.surface.secondary)
                    .padding(.horizontal, DS.Space.xxs)

                // Pro first: one row, the free plays left or thanks; opens the paywall.
                ProMoreCard {
                    model.leaveMore { model.paywall = .support }
                }
                .tourAnchor(.proCard)
                // The MIDI piano alone, under Pro; Owned once it (or Pro) is bought.
                MIDIMoreCard {
                    model.leaveMore { model.paywall = .midi }
                }

                // Translation, theme and text are in the reader menu (the globe).
                DSInsetGroup(title: "Reading") {
                    MoreToggleRow(title: "Chorus after every verse", isOn: $settings.repeatChorus) {
                        Image(systemName: "repeat")
                    }
                    MoreToggleRow(title: "Haptics", isOn: $haptics.isEnabled) {
                        Image(systemName: "hand.tap")
                    }
                    MoreRow(title: "Church mode", detail: "One verse at a time") {
                        Image(systemName: "rectangle.on.rectangle")
                    } action: {
                        model.leaveMore { model.enterChurchMode(from: .more) }
                    }
                    // The onboarding tour again, over the reader once More has gone.
                    MoreRow(title: "Replay tour", detail: String(localized: "8 short steps"), isLast: true) {
                        Image(systemName: "sparkles")
                    } action: {
                        model.leaveMore { tour.start(from: .more) }
                    }
                    .accessibilityHint("Walks through the number pad, the tray, the piano, church mode and more")
                }
                DSInsetGroup(title: "Tools") {
                    ForEach(ExtraSheet.toolsOrder) { tool in
                        MoreRow(title: tool.title, detail: tool.detail(for: model),
                                isLast: tool == ExtraSheet.toolsOrder.last) {
                            Image(systemName: tool.systemImage)
                        } action: {
                            Analytics.track(.toolOpened(tool, source: .more))
                            pageRow(tool)
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
                            model.showFeatureBoard = true
                        }
                        .accessibilityHint("Opens the feature board. Requests and votes leave this phone.")
                    }
                }
                DSInsetGroup(title: "Support") {
                    // The tips, for everyone, in a sheet like the paywall's.
                    // Closing it comes back here.
                    MoreRow(title: ExtraSheet.support.title, detail: ExtraSheet.support.detail(for: model)) {
                        Image(systemName: ExtraSheet.support.systemImage)
                    } action: {
                        model.showSupport = true
                    }
                    .tourAnchor(.supportRow)
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
            .padding(.vertical, DS.Space.m)
        }
        // The tour's last step points at the Pro card and the Support row.
        .tourHost(.more)
        // Also on the way back from a page: the root is visited again.
        .analyticsScreen(.more)
    }

    /// A screen that isn't a tool; Back comes here.
    private func sheetRow(_ sheet: ExtraSheet) -> some View {
        MoreRow(title: sheet.title, detail: sheet.detail(for: model)) {
            Image(systemName: sheet.systemImage)
        } action: {
            pageRow(sheet)
        }
    }

    private func pageRow(_ sheet: ExtraSheet) {
        if let page = MorePage(sheet) { model.morePath.append(page) }
    }
}

// MARK: - Rows

/// A row that leads somewhere: More's, and About this hymn's in its drawer.
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
