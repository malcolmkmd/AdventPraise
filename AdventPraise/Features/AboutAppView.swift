//
//  AboutAppView.swift
//  Advent Praise
//
//  More → About → About Advent Praise: the church logo in a little of the
//  paywall's light, a short note from Malcolm, who makes the app, and the
//  version and build. The Privacy Policy and the Terms of Use are one tap
//  further, in the same stack.
//
//  Keep the note humble and true: who makes the app, why, and thanks to
//  the people who bought translations in earlier versions, which made
//  every translation free in 7.0. Nothing more is claimed.
//

import SwiftUI

struct AboutAppView: View {
    @Environment(\.dsSurface) private var surface

    private var palette: PaywallPalette { PaywallPalette(surface: surface) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.l) {
                header
                letter
                details
            }
            .padding(.horizontal, DS.Space.l + DS.Space.xxs)
            .padding(.bottom, DS.Space.l * 2)
            .frame(maxWidth: DS.Space.readingMeasure, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .analyticsScreen(.aboutApp)
    }

    private var header: some View {
        VStack(spacing: DS.Space.s) {
            PaywallLogo(palette: palette, width: 56)
                .padding(.top, DS.Space.m)
                .padding(.bottom, DS.Space.xs)
            Text(verbatim: "Advent Praise")
                .font(DS.Typeface.display)
                .accessibilityAddTraits(.isHeader)
            Text("Hymns of the Seventh-day Adventist Church in the languages of Southern Africa")
                .font(DS.Typeface.rowBody)
                .foregroundStyle(surface.secondary)
                .multilineTextAlignment(.center)
                .dsBalancedWrap()
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, DS.Space.l)
        .background(alignment: .bottom) {
            PaywallLight(palette: palette, intensity: 0.5)
                .frame(height: 260)
                // A glow that fades out on every side, rather than a box of light.
                .mask {
                    EllipticalGradient(stops: [.init(color: .black, location: 0.2), .init(color: .clear, location: 1)],
                                       center: UnitPoint(x: 0.5, y: 0.62))
                }
                .mask {
                    LinearGradient(stops: [.init(color: .black, location: 0.5), .init(color: .clear, location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                }
        }
    }

    // MARK: Letter

    private var letter: some View {
        VStack(alignment: .leading, spacing: DS.Space.m + DS.Space.xxs) {
            Text("A note from Malcolm").dsEyebrow(tracking: 1.4).foregroundStyle(palette.brass)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(AboutCopy.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(DS.Typeface.rowBody)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: DS.Space.hair) {
                Text("With thanks,")
                    .font(DS.Typeface.rowBody)
                Text(verbatim: "Malcolm Kumwenda")
                    .font(.system(.title2, design: .serif, weight: .regular).italic())
                    .foregroundStyle(palette.brass)
                    .padding(.top, DS.Space.xxs)
                Text("Independent developer, South Africa")
                    .font(DS.Typeface.caption)
                    .foregroundStyle(surface.secondary)
            }
            .padding(.top, DS.Space.xxs)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Details

    private var details: some View {
        VStack(spacing: 0) {
            AboutDetailRow(title: "Version", value: AppInfo.version)
            AboutDetailRow(title: "Build", value: AppInfo.build)
            linkRow("Privacy Policy") { PrivacyPolicyView() }
                .overlay(alignment: .bottom) { Divider().padding(.leading, DS.Space.m) }
            linkRow("Terms of Use") { TermsOfUseView() }
        }
        .background(RoundedRectangle.ds(DS.Radius.tile).fill(.primary.opacity(DS.Fill.row)))
        .clipShape(RoundedRectangle.ds(DS.Radius.tile))
        .padding(.top, DS.Space.s)
    }

    private func linkRow(_ title: LocalizedStringKey, @ViewBuilder destination: () -> some View) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: DS.Space.m) {
                Text(title).font(DS.Typeface.label)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(surface.secondary)
            }
            .padding(.horizontal, DS.Space.m)
            .frame(minHeight: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct AboutDetailRow: View {
    let title: LocalizedStringKey
    let value: String
    @Environment(\.dsSurface) private var surface

    var body: some View {
        HStack {
            Text(title).font(DS.Typeface.label)
            Spacer(minLength: DS.Space.s)
            Text(verbatim: value)
                .font(DS.Typeface.label.monospacedDigit())
                .foregroundStyle(surface.secondary)
                .textSelection(.enabled)
        }
        .padding(.horizontal, DS.Space.m)
        .frame(minHeight: 46)
        .overlay(alignment: .bottom) { Divider().padding(.leading, DS.Space.m) }
        .accessibilityElement(children: .combine)
    }
}

@MainActor
private enum AboutCopy {
    static let paragraphs: [LocalizedStringKey] = [
        "I’m Malcolm Kumwenda, an independent developer from South Africa, and I make Advent Praise on my own.",
        "I built it to carry the hymns of the Seventh-day Adventist Church in the languages of Southern Africa, so that the songs we sing together are close at hand, in church and wherever else you sing them.",
        "To everyone who bought a translation in an earlier version of Advent Praise: thank you. Your support is greatly appreciated.",
        "If these hymns are a blessing to you, I’m grateful to have had a small part in it.",
    ]
}

// MARK: - Previews

#Preview("About · paper") {
    NavigationStack { AboutAppView() }
        .dsSurface(.paper)
}

#Preview("About · black") {
    NavigationStack { AboutAppView() }
        .dsSurface(.black)
}
