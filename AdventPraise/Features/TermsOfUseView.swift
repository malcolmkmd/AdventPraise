//
//  TermsOfUseView.swift
//  Advent Praise
//
//  The terms of use, in the app, in the Privacy Policy's style: who makes
//  Advent Praise, what the hymn texts are for, who owns the hymns (the same
//  text as legal/hymn-content-terms.md, shared with Android), Pro and tips (through Apple,
//  refunds through Apple), no warranty, the limit of liability, South
//  African law and changes. Opened from More → About and from About
//  Advent Praise. The one email address is the rights holders' contact in
//  "Hymn content and ownership".
//
//  Keep it true to the store. If Pro or the tips change, change this too.
//  Pro: the annual subscription (ap_pro_annual, 3-day trial); earlier
//  one-time buyers keep Pro for life.
//

import SwiftUI

struct TermsOfUseView: View {
    var body: some View {
        DrawerAwareScrollView {
            VStack(alignment: .leading, spacing: DS.Space.l + DS.Space.xs) {
                PolicyHeader(title: "Terms of Use")
                ForEach(TermsOfUse.sections) { section in
                    PolicySection(section: section)
                }
            }
            .padding(.horizontal, DS.Space.l + DS.Space.xxs)
            .padding(.top, DS.Space.m)
            .padding(.bottom, DS.Space.l * 2)
            .frame(maxWidth: DS.Space.readingMeasure, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Terms")
        .navigationBarTitleDisplayMode(.inline)
        .analyticsScreen(.terms)
    }
}

// MARK: - Copy

@MainActor
private enum TermsOfUse {
    static let sections: [PolicySectionCopy] = [
        PolicySectionCopy(id: "who", title: "Who makes Advent Praise", paragraphs: [
            "Advent Praise is made by Malcolm Kumwenda and published by MDEVSA (PTY) LTD, a company in South Africa. By using the app you agree to these terms.",
        ]),
        PolicySectionCopy(id: "hymns", title: "The hymns", paragraphs: [
            "The hymn texts are provided for personal devotion and for congregational worship: reading, singing and showing them in church. Please don’t sell them, or copy them out of the app to publish elsewhere.",
        ]),
        // Word for word legal/hymn-content-terms.md: change both together.
        PolicySectionCopy(id: "ownership", title: "Hymn content and ownership", paragraphs: [
            "Advent Praise does not own the hymns it displays. Most hymn texts, tunes and sheet music in the app are in the public domain. Some hymn texts, translations and arrangements remain the property of their respective authors, composers and publishers, including the Seventh-day Adventist Hymnal (1985). They are credited where known and included for personal and congregational worship.",
            "Advent Praise Pro is a subscription to the app's features and services, such as the MIDI player, sheet music viewer, church mode, AirPlay casting and future updates. It is not a purchase of, licence to, or transfer of ownership in any hymn, text, tune, recording or score.",
            "If you are a rights holder and believe content in the app should be credited differently or removed, contact us at hi@malcolmk.com and we will respond promptly.",
        ]),
        PolicySectionCopy(id: "pro", title: "Advent Praise Pro", paragraphs: [
            "Pro is an annual auto-renewing subscription with a 3-day free trial. It is sold and charged by Apple through the App Store, under Apple’s terms.",
            "Payment is charged to your Apple Account at confirmation of purchase or, if you start with the free trial, at the end of the trial. The subscription renews automatically each year unless it is cancelled at least 24 hours before the end of the current period.",
            "You can manage or cancel the subscription in your App Store account settings. Any unused part of a free trial is forfeited when you buy a subscription.",
            "If you bought Pro (or the MIDI Piano) as a one-time purchase, you keep Pro for life.",
            "Refunds are handled by Apple. To ask for one, use Report a Problem on Apple’s website or in your App Store purchase history.",
        ]),
        PolicySectionCopy(id: "tips", title: "Tips", paragraphs: [
            "Tips are a voluntary thank you, also paid through Apple. They unlock nothing and don’t change how the app works.",
        ]),
        PolicySectionCopy(id: "warranty", title: "No warranty", paragraphs: [
            "Advent Praise is provided “as is”. Care has gone into the hymns, translations, scripture references and accompaniment, but they may contain mistakes, and the app may not always be available or free of faults.",
        ]),
        PolicySectionCopy(id: "liability", title: "Limitation of liability", paragraphs: [
            "As far as the law allows, Malcolm Kumwenda and MDEVSA (PTY) LTD are not liable for any indirect or consequential loss from using the app, and their total liability is limited to the amount you paid for it. Nothing here limits rights you have under consumer law that can’t be excluded.",
        ]),
        PolicySectionCopy(id: "law", title: "Governing law", paragraphs: [
            "These terms are governed by the laws of the Republic of South Africa.",
        ]),
        PolicySectionCopy(id: "changes", title: "Changes", paragraphs: [
            "These terms may change as the app does. Changes come in an app update, and the version and date above show which terms you are reading. Using the app after an update means you accept them.",
        ]),
    ]
}

// MARK: - Previews

#Preview("Terms · paper") {
    NavigationStack { TermsOfUseView() }
        .dsSurface(.paper)
}

#Preview("Terms · black") {
    NavigationStack { TermsOfUseView() }
        .dsSurface(.black)
}
