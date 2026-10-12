//
//  MoreDrawer.swift
//  Advent Praise
//
//  More: reading options (and the Haptics switch), feedback and about (with
//  the Share anonymous usage switch), in AdventDrawer. Opened from
//  the More tile in the Lectern's hymn tray. Rows that lead somewhere else
//  close the drawer first. Appearance, the Tools and Mail stand in for More
//  one level down: closing them (Done, Cancel, a swipe) reopens More at the
//  row they came from. Church mode and the hymnal picker move on for good.
//

import SwiftUI

extension View {
    func moreDrawer(model: ReaderModel) -> some View {
        modifier(MoreDrawerPresenter(model: model))
    }
}

private struct MoreDrawerPresenter: ViewModifier {
    @Bindable var model: ReaderModel

    func body(content: Content) -> some View {
        content.adventDrawer("More", isPresented: $model.showMore) {
            ScrollViewReader { proxy in
                MoreDrawerContent(model: model)
                    // Back from one of its screens: where the user left off.
                    .onAppear {
                        guard let row = model.takeMoreScrollAnchor() else { return }
                        proxy.scrollTo(row, anchor: .center)
                    }
            }
        }
    }
}

private struct MoreDrawerContent: View {
    @Bindable var model: ReaderModel
    @Environment(ReadingSettings.self) private var settings
    @Environment(PurchaseStore.self) private var store
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

            DSInsetGroup(title: "Reading") {
                MoreRow(title: "Appearance", detail: appearanceSummary) {
                    Text("Aa").font(DS.Typeface.label)
                } action: {
                    model.leaveMore(for: MoreRowID.appearance) { model.showAppearance = true }
                }
                .id(MoreRowID.appearance)
                MoreToggleRow(title: "Large print", isOn: $settings.largePrint) {
                    Image(systemName: "textformat.size")
                }
                MoreToggleRow(title: "Chorus after every verse", isOn: $settings.repeatChorus) {
                    Image(systemName: "repeat")
                }
                MoreToggleRow(title: "Haptics", isOn: $haptics.isEnabled) {
                    Image(systemName: "hand.tap")
                }
                MoreRow(title: "Church mode", detail: "One verse at a time") {
                    Image(systemName: "rectangle.on.rectangle")
                } action: {
                    model.showMore = false
                    model.enterChurchMode(from: .more)
                }
                MoreRow(title: "Hymnals", detail: "\(model.hymnal.name) · \(HymnalInfo.catalogue.count)", isLast: true) {
                    Image(systemName: "globe")
                } action: {
                    model.showMore = false
                    model.openLectern(.hymnals)
                }
            }
            DSInsetGroup(title: "Tools") {
                ForEach(ExtraSheet.toolsOrder) { tool in
                    MoreRow(title: tool.title, detail: tool.detail(for: model),
                            isLast: tool == ExtraSheet.toolsOrder.last) {
                        Image(systemName: tool.systemImage)
                    } action: {
                        model.leaveMore(for: MoreRowID.tool(tool)) { Extras.shared.sheet = tool }
                    }
                    .id(MoreRowID.tool(tool))
                }
            }
            DSInsetGroup(title: "Help us improve") {
                MoreRow(title: "Send a correction", detail: "Hymn \(model.hymn.id)") {
                    Image(systemName: "pencil.and.list.clipboard")
                } action: {
                    model.leaveMore(for: MoreRowID.correction) { model.mail = MailRequest(kind: .correction) }
                }
                .id(MoreRowID.correction)
                MoreRow(title: "Request a hymnal or feature", isLast: true) {
                    Image(systemName: "envelope")
                } action: {
                    model.leaveMore(for: MoreRowID.request) { model.mail = MailRequest(kind: .request) }
                }
                .id(MoreRowID.request)
            }
            DSInsetGroup(title: "About") {
                MoreRow(title: "Restore purchases") {
                    Image(systemName: "arrow.clockwise")
                } action: { Task { await store.restore(source: .more) } }
                MoreRow(title: "Recommend Advent Praise") {
                    Image(systemName: "paperplane")
                } action: {
                    Analytics.track(.shareOpened)
                    model.showShare = true
                }
                MoreRow(title: "Rate on the App Store") {
                    Image(systemName: "star")
                } action: { open(AppInfo.writeReviewURL, .rateApp) }
                MoreToggleRow(title: "Share anonymous usage", isOn: $analytics.isEnabled) {
                    Image(systemName: "chart.bar")
                }
                MoreRow(title: "Privacy policy") {
                    Image(systemName: "hand.raised")
                } action: { open(AppInfo.privacyPolicyURL, .privacyPolicy) }
                MoreRow(title: "MIDI files from The Cyber Hymnal (hymntime.com)", isLast: true) {
                    Image(systemName: "music.note")
                } action: { open(AppInfo.cyberHymnalURL, .cyberHymnal) }
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

    private func open(_ url: URL, _ link: ExternalLink) {
        Analytics.track(.externalLinkOpened(link))
        openURL(url)
    }

    private var appearanceSummary: String {
        let face = settings.style.font == .serif ? "Serif" : "Sans"
        return "\(settings.surface.rawValue.capitalized) · \(face) · \(Int(settings.style.basePointSize)) pt"
    }
}

// MARK: - Rows

/// Scroll targets for the rows whose screens come back to More.
private enum MoreRowID {
    static let appearance = "appearance"
    static let correction = "correction"
    static let request = "request"
    static func tool(_ tool: ExtraSheet) -> String { "tool.\(tool.rawValue)" }
}

private struct MoreRow<Icon: View>: View {
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
        .overlay(alignment: .bottom) { Divider().padding(.leading, 52) }
    }
}
