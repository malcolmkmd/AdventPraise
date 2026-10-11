//
//  MoreDrawer.swift
//  Advent Praise
//
//  More: reading options, feedback and about, in AdventDrawer. Opened from
//  the More tile in the Lectern's hymn tray. Rows that lead somewhere else
//  (church mode, Mail, the hymnal picker, Appearance) close the drawer first.
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
            MoreDrawerContent(model: model)
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
                    model.showMore = false
                    model.showAppearance = true
                }
                MoreToggleRow(title: "Large print", isOn: $settings.largePrint) {
                    Image(systemName: "textformat.size")
                }
                MoreToggleRow(title: "Chorus after every verse", isOn: $settings.repeatChorus) {
                    Image(systemName: "repeat")
                }
                MoreRow(title: "Church mode", detail: "One verse at a time") {
                    Image(systemName: "rectangle.on.rectangle")
                } action: {
                    model.showMore = false
                    model.showChurchMode = true
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
                        model.showMore = false
                        Extras.shared.sheet = tool
                    }
                }
            }
            DSInsetGroup(title: "Help us improve") {
                MoreRow(title: "Send a correction", detail: "Hymn \(model.hymn.id)") {
                    Image(systemName: "pencil.and.list.clipboard")
                } action: {
                    model.showMore = false
                    model.mail = MailRequest(kind: .correction)
                }
                MoreRow(title: "Request a hymnal or feature", isLast: true) {
                    Image(systemName: "envelope")
                } action: {
                    model.showMore = false
                    model.mail = MailRequest(kind: .request)
                }
            }
            DSInsetGroup(title: "About") {
                MoreRow(title: "Restore purchases") {
                    Image(systemName: "arrow.clockwise")
                } action: { Task { await store.restore() } }
                MoreRow(title: "Recommend Advent Praise") {
                    Image(systemName: "paperplane")
                } action: { model.showShare = true }
                MoreRow(title: "Rate on the App Store") {
                    Image(systemName: "star")
                } action: { openURL(AppInfo.writeReviewURL) }
                MoreRow(title: "Privacy policy") {
                    Image(systemName: "hand.raised")
                } action: { openURL(AppInfo.privacyPolicyURL) }
                MoreRow(title: "MIDI files from The Cyber Hymnal (hymntime.com)", isLast: true) {
                    Image(systemName: "music.note")
                } action: { openURL(AppInfo.cyberHymnalURL) }
            }
        }
        .padding(.horizontal, DS.Space.l)
        .padding(.top, DS.Space.m)
    }

    private var appearanceSummary: String {
        let face = settings.style.font == .serif ? "Serif" : "Sans"
        return "\(settings.surface.rawValue.capitalized) · \(face) · \(Int(settings.style.basePointSize)) pt"
    }
}

// MARK: - Rows

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
