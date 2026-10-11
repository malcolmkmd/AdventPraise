//
//  WhatsNewSheet.swift
//  Advent Praise
//
//  "Welcome to Advent Praise 7" — shown once after updating to (or installing)
//  7.x. A dark glass sheet: big title, four short feature blocks, a primary
//  action and Continue.
//

import SwiftUI

enum WhatsNew {
    static let version = "7.0"
    private static let key = "whatsNew.lastSeenVersion"

    static var shouldShow: Bool {
        (UserDefaults.standard.string(forKey: key) ?? "0").compare(version, options: .numeric) == .orderedAscending
    }

    static func markSeen() { UserDefaults.standard.set(version, forKey: key) }
}

struct WhatsNewSheet: View {
    var onTryChurchMode: () -> Void
    @Environment(\.dismiss) private var dismiss

    private struct Feature: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let detail: String
    }

    private let features: [Feature] = [
        Feature(symbol: "rectangle.on.rectangle", title: "Church mode",
                detail: "One verse at a time in large, bright text. The screen stays awake; tap to move on."),
        Feature(symbol: "globe", title: "Every hymnal, every language",
                detail: "Christ In Song, the SDA Hymnal and 22 more, with your purchases restored."),
        Feature(symbol: "textformat.size", title: "Large print & reading themes",
                detail: "Paper, parchment, sepia or black, in the size that suits your eyes."),
        Feature(symbol: "mic", title: "Siri & Shortcuts",
                detail: "“Open hymn in Advent Praise” — then say the number."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Welcome to")
                        .scaledFont(size: 20, weight: .semibold, design: .serif, relativeTo: .title3)
                        .foregroundStyle(Vesper.brassOnDark)
                    Text("Advent Praise 7")
                        .scaledFont(size: 40, weight: .bold, design: .serif, relativeTo: .largeTitle)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 36)

                VStack(spacing: 12) {
                    ForEach(features) { feature in
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: feature.symbol)
                                .scaledFont(size: 22, weight: .semibold)
                                .foregroundStyle(Vesper.evergreenOnDark)
                                .frame(width: 32)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(feature.title).scaledFont(size: 17, weight: .semibold)
                                Text(feature.detail).scaledFont(size: 14).foregroundStyle(.white.opacity(0.7))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(16)
                        .whatsNewGlass()
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                Button {
                    WhatsNew.markSeen()
                    Analytics.track(.whatsNewContinued(action: "church_mode"))
                    dismiss()
                    onTryChurchMode()
                } label: {
                    Text("Try Church Mode")
                        .scaledFont(size: 17, weight: .bold)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .whatsNewPrimaryButton()

                Button {
                    WhatsNew.markSeen()
                    Analytics.track(.whatsNewContinued(action: "continue"))
                    dismiss()
                } label: {
                    Text("Continue")
                        .scaledFont(size: 17, weight: .semibold)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .frame(maxWidth: 560)
        }
        .foregroundStyle(.white)
        .background(
            LinearGradient(colors: [Color(hex: 0x0E1615), Color(hex: 0x14221F), .black],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .presentationBackground(.black)
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(false)
        .onDisappear { WhatsNew.markSeen() }
    }
}

private extension View {
    @ViewBuilder
    func whatsNewGlass() -> some View {
        let shape = RoundedRectangle(cornerRadius: Vesper.Radius.card, style: .continuous)
        if #available(iOS 26, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.12), lineWidth: 1))
        }
    }

    @ViewBuilder
    func whatsNewPrimaryButton() -> some View {
        if #available(iOS 26, *) {
            buttonStyle(.glassProminent).tint(Vesper.evergreen)
        } else {
            buttonStyle(.borderedProminent).buttonBorderShape(.capsule).tint(Vesper.evergreen)
        }
    }
}
