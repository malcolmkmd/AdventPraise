//
//  AppearanceSheet.swift
//  Advent Praise
//
//  Typography and reading-environment controls. Presented as a medium-detent
//  sheet over the reader with background interaction enabled, so every change
//  previews live on the lyrics behind it.
//

import SwiftUI

struct AppearanceSheet: View {
    @Environment(ReadingSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    private var env: ReadingEnvironment { settings.environment }

    var body: some View {
        @Bindable var settings = settings

        ScrollView {
        VStack(spacing: 14) {
            HStack {
                Text("Appearance").scaledFont(size: 22, weight: .semibold, design: .serif)
                Spacer()
                Button("Done") { dismiss() }
                    .scaledFont(size: 14, weight: .bold)
                    .padding(.horizontal, 14).frame(height: 36)
                    .background(Capsule().fill(env.tint.opacity(0.12)))
                    .foregroundStyle(env.tint)
            }
            .frame(height: 44)

            // Text size
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    SectionLabel("Text size")
                    Spacer()
                    Text("\(Int(settings.pointSize)) pt").scaledFont(size: 13).monospacedDigit()
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                HStack(spacing: 10) {
                    SizeStepButton(size: 15, label: "Smaller text") { settings.stepSize(by: -1); Haptics.light() }
                    Slider(value: Binding(get: { Double(settings.sizeIndex) },
                                          set: { settings.sizeIndex = Int($0.rounded()) }),
                           in: 0...Double(ReadingSettings.sizeSteps.count - 1), step: 1)
                        .tint(env.tint)
                        .accessibilityLabel("Text size")
                        .accessibilityValue("\(Int(settings.pointSize)) points")
                    SizeStepButton(size: 24, label: "Larger text") { settings.stepSize(by: 1); Haptics.light() }
                }
            }

            // Large print and chorus repetition
            VStack(spacing: 6) {
                Toggle(isOn: Binding(get: { settings.largePrint },
                                     set: { settings.largePrint = $0; Analytics.track(.largePrintChanged(on: $0)) })) {
                    Text("Large print").scaledFont(size: 15, weight: .semibold)
                }
                Toggle(isOn: $settings.repeatChorus) {
                    Text("Chorus after every verse").scaledFont(size: 15, weight: .semibold)
                }
            }
            .tint(env.tint)

            // Line spacing
            HStack(spacing: 12) {
                SectionLabel("Spacing")
                Spacer()
                Picker("Line spacing", selection: $settings.lineSpacing) {
                    ForEach(LineSpacingOption.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260)
            }

            // Alignment
            HStack(spacing: 12) {
                SectionLabel("Alignment")
                Spacer()
                Picker("Text alignment", selection: $settings.alignment) {
                    Image(systemName: "text.alignleft").tag(TextAlignment.leading).accessibilityLabel("Align left")
                    Image(systemName: "text.aligncenter").tag(TextAlignment.center).accessibilityLabel("Align center")
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }

            // Font
            HStack(spacing: 10) {
                ForEach(ReadingFont.allCases) { font in
                    FontCard(font: font, isSelected: settings.font == font, tint: env.tint) {
                        settings.font = font; Haptics.selection()
                    }
                }
            }

            // Environment
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Reading environment")
                HStack(spacing: 8) {
                    ForEach(ReadingEnvironment.allCases) { candidate in
                        EnvironmentSwatch(environment: candidate,
                                          isSelected: settings.environment == candidate,
                                          tint: env.tint) {
                            withAnimation(.easeInOut(duration: 0.3)) { settings.environment = candidate }
                            Haptics.selection()
                        }
                    }
                }
            }

        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .preferredColorScheme(env.colorScheme)
    }
}

// MARK: - Pieces

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).scaledFont(size: 11, weight: .bold).tracking(1.3).textCase(.uppercase)
            .foregroundStyle(.secondary)
    }
}

private struct SizeStepButton: View {
    let size: CGFloat
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text("A").scaledFont(size: size, weight: .semibold, design: .serif)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: Vesper.Radius.chip, style: .continuous).fill(.primary.opacity(0.06)))
        }
        .buttonRepeatBehavior(.enabled)
        .foregroundStyle(.primary)
        .accessibilityLabel(label)
    }
}

private struct FontCard: View {
    let font: ReadingFont
    let isSelected: Bool
    let tint: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text("Aa").scaledFont(size: 26, weight: .medium, design: font.design)
                VStack(alignment: .leading, spacing: 2) {
                    Text(font.name).scaledFont(size: 14, weight: .bold)
                    Text(font.detail).scaledFont(size: 11).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(RoundedRectangle(cornerRadius: Vesper.Radius.card, style: .continuous)
                .fill(isSelected ? tint.opacity(0.12) : .primary.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: Vesper.Radius.card, style: .continuous)
                .strokeBorder(isSelected ? tint : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(font.name) font")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.spring(duration: 0.3, bounce: 0.2), value: isSelected)
    }
}

private struct EnvironmentSwatch: View {
    let environment: ReadingEnvironment
    let isSelected: Bool
    let tint: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text("Aa").scaledFont(size: 22, weight: .medium, design: .serif)
                Text(environment.name).scaledFont(size: 10, weight: .semibold).tracking(0.4)
            }
            .foregroundStyle(environment.foreground)
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(environment.background))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isSelected ? tint : .primary.opacity(0.12), lineWidth: isSelected ? 2 : 1))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(tint.opacity(isSelected ? 0.18 : 0), lineWidth: 5).padding(-3))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(environment.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.spring(duration: 0.3, bounce: 0.2), value: isSelected)
    }
}
