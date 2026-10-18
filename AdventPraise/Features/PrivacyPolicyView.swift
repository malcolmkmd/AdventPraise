//
//  PrivacyPolicyView.swift
//  Advent Praise
//
//  The privacy policy, in the app: what Advent Praise keeps on the phone,
//  the anonymous usage it can send (PostHog, EU; no IDFA, no App Tracking
//  Transparency), purchases through Apple, the content it includes (with a
//  small credit for the accompaniment's MIDI files and the sheet music's scores) and the feature board
//  when the app has one. Opened from More → About and from the paywall's
//  Privacy Policy link. The Terms of Use share its section style.
//
//  Keep it true to the code. If analytics, purchases or the board change,
//  change this screen and docs/appstore/privacy-label.md together.
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dsSurface) private var surface

    var body: some View {
        ScrollViewReader { proxy in
            DrawerAwareScrollView {
                page
            }
            #if DEBUG
            .onAppear { if DebugLaunch.showsCredits { proxy.scrollTo(PrivacyPolicy.contentID, anchor: .top) } }
            #endif
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .analyticsScreen(.privacy)
    }

    private var page: some View {
        VStack(alignment: .leading, spacing: DS.Space.l + DS.Space.xs) {
            header
            summary
            ForEach(PrivacyPolicy.sections) { section in
                PolicySection(section: section).id(section.id)
            }
        }
        .padding(.horizontal, DS.Space.l + DS.Space.xxs)
        .padding(.top, DS.Space.m)
        .padding(.bottom, DS.Space.l * 2)
        .frame(maxWidth: DS.Space.readingMeasure, alignment: .leading)
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        PolicyHeader(title: "Privacy Policy")
    }

    /// The short version, before the detail.
    private var summary: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Text("In short").dsEyebrow().foregroundStyle(surface.brass)
            ForEach(Array(PrivacyPolicy.inShort.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .firstTextBaseline, spacing: DS.Space.s) {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(surface.tint)
                        .accessibilityHidden(true)
                    Text(line)
                        .font(DS.Typeface.rowBody)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(DS.Space.m + DS.Space.xxs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle.ds(DS.Radius.tile).fill(surface.tint.opacity(DS.Fill.tintActive)))
        .accessibilityElement(children: .combine)
    }
}

/// The paywall's Privacy Policy link: the same screen in a sheet of its own.
struct PrivacyPolicySheet: View {
    let surface: DSSurface
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            PrivacyPolicyView()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done", action: onDone).fontWeight(.semibold)
                    }
                }
        }
        .modifier(ToolSheetChrome(surface: surface))
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Copy

struct PolicySectionCopy: Identifiable {
    let id: String
    let title: LocalizedStringKey
    let paragraphs: [LocalizedStringKey]
    /// One quiet line after the paragraphs, in small secondary text.
    var note: LocalizedStringKey? = nil
}

@MainActor
private enum PrivacyPolicy {

    static let contentID = "content"

    static let inShort: [LocalizedStringKey] = [
        "No account, no sign-in and no advertising.",
        "Your favourites, playlists and settings stay on your phone.",
        "Anonymous usage counts help improve the app, and you can switch them off.",
        "Purchases are made with Apple. We never see your payment details.",
    ]

    static var sections: [PolicySectionCopy] {
        var sections = [
            PolicySectionCopy(id: "who", title: "Who makes Advent Praise", paragraphs: [
                "Advent Praise is made by Malcolm Kumwenda, an independent developer in South Africa. This policy explains what the app does with information, in plain words.",
            ]),
            PolicySectionCopy(id: "device", title: "On your phone", paragraphs: [
                "There are no accounts. Advent Praise never asks for your name, email address or phone number.",
                "Your favourites, playlists, service plans, recent hymns, pitch notes and settings are stored only on your device. The hymns and their piano accompaniment come inside the app, so reading and singing work without the internet.",
                "The number of free plays of the piano you have used is also kept in your device’s Keychain, so that it isn’t reset by reinstalling the app.",
            ]),
            PolicySectionCopy(id: "usage", title: "Anonymous usage", paragraphs: [
                "To learn which features are used and what to improve, the app can send anonymous usage counts to PostHog, an analytics service, on servers in the European Union.",
                "These say what happened in the app: for example, that a hymn was opened (its hymnal and number), that church mode started, or how many results a search found. They include the app and iOS versions, the device model, language, time zone and screen size.",
                "They never include your name, the words you search for, the names of your playlists or the text of hymns. Your location isn’t looked up from your IP address. There are no crash reports and no recordings of the screen.",
                "Each install has a random ID that isn’t tied to you, your Apple Account or your device. **You can switch usage off in More → Share anonymous usage.** Switching it off stops sending and deletes that ID.",
            ]),
            PolicySectionCopy(id: "tracking", title: "No tracking or advertising", paragraphs: [
                "Advent Praise has no ads. It doesn’t use the advertising identifier, doesn’t track you across other apps and websites, and doesn’t sell or share information with data brokers. That is why it never asks for permission to track.",
            ]),
            PolicySectionCopy(id: "purchases", title: "Purchases", paragraphs: [
                "Advent Praise Pro and tips are bought through Apple’s App Store. Apple handles the payment, and the app only learns from Apple, on your device, whether Pro is yours. We never see your card or Apple Account details.",
                "Usage counts can record that a purchase was started or completed, with the product’s name, but never the price or any receipt.",
            ]),
            PolicySectionCopy(id: contentID, title: "Content we include", paragraphs: [
                "The hymns, their accompaniment and the scripture references come inside the app. Christ In Song and its translations come from the texts of earlier versions of Advent Praise.",
                "Scripture references come from the hymns’ own words, the texts printed in Christ in Song (1908) and the Hymnary.org scripture index. Collections follow the topical sections of the Seventh-day Adventist Hymnal (1985), as listed on Hymnary.org.",
            ], note: "The piano accompaniment uses MIDI files, and the sheet music is engraved from scores, from The Cyber Hymnal (hymntime.com)."),
        ]
        if FeatureBoardConfig.isEnabled {
            sections.append(PolicySectionCopy(id: "board", title: "Feature requests", paragraphs: [
                "Vote on features opens a board run by Features.Vote. Your requests, comments and votes are sent there with a random ID for this phone, and others can read what you post. Your name and email aren’t sent, so please don’t type them in.",
            ]))
        }
        sections.append(contentsOf: [
            PolicySectionCopy(id: "links", title: "Links to other sites", paragraphs: [
                "Some links leave the app, such as scripture passages on Bible.com. Those sites have their own privacy policies.",
            ]),
            PolicySectionCopy(id: "children", title: "Children", paragraphs: [
                "Advent Praise is for everyone who sings. It doesn’t collect personal information from anyone, children included.",
            ]),
            PolicySectionCopy(id: "changes", title: "Changes", paragraphs: [
                "If what the app does with information changes, this policy changes with it, in the same update. The version and date above show which one you are reading.",
            ]),
        ])
        return sections
    }
}

// MARK: - Shared with the Terms of Use

/// The title, then the app version and the date it was last changed.
struct PolicyHeader: View {
    let title: LocalizedStringKey
    @Environment(\.dsSurface) private var surface

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text(title)
                .font(DS.Typeface.display)
                .accessibilityAddTraits(.isHeader)
            Text("Advent Praise \(AppInfo.version) · Updated October 2026")
                .font(DS.Typeface.detail)
                .foregroundStyle(surface.secondary)
        }
    }
}

struct PolicySection: View {
    let section: PolicySectionCopy
    @Environment(\.dsSurface) private var surface

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s + DS.Space.xxs) {
            Text(section.title)
                .font(DS.Typeface.panelTitle)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(section.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(DS.Typeface.rowBody)
                    .lineSpacing(5)
                    .foregroundStyle(surface.foreground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let note = section.note {
                Text(note)
                    .font(DS.Typeface.detail)
                    .foregroundStyle(surface.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Previews

#Preview("Privacy · paper") {
    NavigationStack { PrivacyPolicyView() }
        .dsSurface(.paper)
}

#Preview("Privacy · black") {
    NavigationStack { PrivacyPolicyView() }
        .dsSurface(.black)
}
