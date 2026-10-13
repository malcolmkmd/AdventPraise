//
//  AppearanceControls.swift
//  Advent Praise 7 — Vesper design system
//
//  Typography and reading-surface controls, as sections the reader menu's
//  Theme and Text panels lay out (ReaderMenuPanels.swift). They hang over
//  the lyrics, so every change previews live on the page below. Each reads
//  `\.dsSurface` and draws no glass of its own.
//

import SwiftUI

/// Text size: a slider between smaller and larger "A" buttons, in points.
struct ReadingSizeControl: View {
    @Binding var style: DSReadingStyle
    @Environment(\.dsSurface) private var surface

    var body: some View {
        VStack(spacing: DS.Space.s) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("Text size")
                Spacer()
                Text("\(Int(style.basePointSize)) pt").font(DS.Typeface.detail).monospacedDigit()
                    .foregroundStyle(surface.secondary)
                    .contentTransition(.numericText())
            }
            HStack(spacing: 10) {
                SizeStepButton(glyphSize: 15, label: "Smaller text") { step(-1) }
                    .disabled(style.step == 0)
                Slider(value: Binding(get: { Double(style.step) }, set: { style.step = Int($0.rounded()) }),
                       in: 0...Double(style.scale.steps.count - 1), step: 1)
                    .accessibilityLabel("Text size")
                    .accessibilityValue("\(Int(style.basePointSize)) points")
                SizeStepButton(glyphSize: 24, label: "Larger text") { step(1) }
                    .disabled(style.step == style.scale.steps.count - 1)
            }
            Text("Also follows your iPhone’s text size setting.")
                .font(DS.Typeface.caption).foregroundStyle(surface.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func step(_ delta: Int) {
        style.step = min(max(style.step + delta, 0), style.scale.steps.count - 1)
    }
}

/// Print size, line spacing and alignment: a segmented row each.
struct ReadingLayoutControls: View {
    @Binding var style: DSReadingStyle

    var body: some View {
        VStack(spacing: DS.Space.m) {
            HStack(spacing: DS.Space.m) {
                SectionLabel("Print")
                Spacer()
                Picker("Print size", selection: printScale) {
                    Text("Standard").tag(DS.LyricScale.standard)
                    Text("Large print").tag(DS.LyricScale.largePrint)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260)
            }
            HStack(spacing: DS.Space.m) {
                SectionLabel("Spacing")
                Spacer()
                Picker("Line spacing", selection: $style.lineSpacing) {
                    ForEach(DS.LineSpacing.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260)
            }
            HStack(spacing: DS.Space.m) {
                SectionLabel("Alignment")
                Spacer()
                Picker("Text alignment", selection: $style.centered) {
                    Image(systemName: "text.alignleft").tag(false).accessibilityLabel("Align left")
                    Image(systemName: "text.aligncenter").tag(true).accessibilityLabel("Align centre")
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
        }
    }

    private var printScale: Binding<DS.LyricScale> {
        Binding(get: { style.scale == .largePrint ? .largePrint : .standard },
                set: { newScale in
                    // Keep the relative position on the slider when switching scale.
                    style.scale = newScale
                    style.step = min(style.step, newScale.steps.count - 1)
                })
    }
}

/// Serif or sans: side by side, stacked when they don't fit.
struct ReadingFontPicker: View {
    @Binding var style: DSReadingStyle

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { cards }
            VStack(spacing: DS.Space.s) { cards }
        }
    }

    @ViewBuilder private var cards: some View {
        ForEach(DS.ReadingFont.allCases) { font in
            FontCard(font: font, isSelected: style.font == font) { style.font = font }
        }
    }
}

/// The reading surfaces as swatches, each drawn in its own ground and ink.
struct ReadingSurfacePicker: View {
    @Binding var surface: DSSurface
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            SectionLabel("Reading surface")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: DS.Space.s)], spacing: DS.Space.s) {
                ForEach(DSSurface.allCases) { candidate in
                    SurfaceSwatch(candidate: candidate, isSelected: surface == candidate) {
                        withAnimation(DS.Motion.adaptive(DS.Motion.surface, reduceMotion: reduceMotion)) {
                            surface = candidate
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Pieces

private struct SectionLabel: View {
    let text: LocalizedStringKey
    @Environment(\.dsSurface) private var surface
    init(_ text: LocalizedStringKey) { self.text = text }
    var body: some View {
        Text(text).dsEyebrow().foregroundStyle(surface.secondary).accessibilityAddTraits(.isHeader)
    }
}

private struct SizeStepButton: View {
    let glyphSize: CGFloat
    let label: LocalizedStringKey
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text("A").font(.system(size: glyphSize, weight: .semibold, design: .serif))
                .frame(width: DS.Size.hitTarget, height: DS.Size.hitTarget)
                .background(RoundedRectangle.ds(DS.Radius.chip).fill(.primary.opacity(DS.Fill.inset)))
        }
        .buttonStyle(DSPressStyle())
        .buttonRepeatBehavior(.enabled)
        .foregroundStyle(.primary)
        .accessibilityLabel(label)
    }
}

private struct FontCard: View {
    let font: DS.ReadingFont
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.dsSurface) private var surface

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Space.m) {
                Text("Aa").font(.system(.title, design: font.design, weight: .medium))
                VStack(alignment: .leading, spacing: DS.Space.hair) {
                    Text(font.name).font(DS.Typeface.label.weight(.bold))
                    Text(font.detail).font(DS.Typeface.caption).foregroundStyle(surface.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DS.Space.panel)
            .padding(.vertical, DS.Space.s)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(RoundedRectangle.ds(DS.Radius.card)
                .fill(isSelected ? surface.tint.opacity(DS.Fill.tintSelected) : Color.primary.opacity(DS.Fill.inset)))
            .overlay(RoundedRectangle.ds(DS.Radius.card)
                .strokeBorder(isSelected ? surface.tint : .clear, lineWidth: 1.5))
            .contentShape(RoundedRectangle.ds(DS.Radius.card))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(font.name))
        .accessibilityHint(Text(font.detail))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .animation(DS.Motion.select, value: isSelected)
    }
}

/// A surface preview: its own ground and ink, so it reads true on any sheet.
private struct SurfaceSwatch: View {
    let candidate: DSSurface
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.dsSurface) private var current

    var body: some View {
        Button(action: action) {
            VStack(spacing: DS.Space.xs) {
                Text("Aa").font(.system(.title2, design: .serif, weight: .medium))
                Text(candidate.name).font(.caption2.weight(.semibold)).tracking(0.4).lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(candidate.foreground)
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(RoundedRectangle.ds(DS.Radius.tile).fill(candidate.background))
            .overlay(RoundedRectangle.ds(DS.Radius.tile)
                .strokeBorder(isSelected ? current.tint : Color.primary.opacity(DS.Fill.stroke),
                              lineWidth: isSelected ? 2 : 1))
            .overlay(RoundedRectangle.ds(DS.Radius.tile)
                .strokeBorder(current.tint.opacity(isSelected ? 0.18 : 0), lineWidth: 5).padding(-3))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(candidate.name))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .animation(DS.Motion.select, value: isSelected)
    }
}

#Preview("Reading controls") {
    @Previewable @State var style = DSReadingStyle()
    @Previewable @State var surface = DSSurface.paper
    ScrollView {
        VStack(spacing: DS.Space.panel) {
            ReadingSizeControl(style: $style)
            ReadingFontPicker(style: $style)
            ReadingLayoutControls(style: $style)
            ReadingSurfacePicker(surface: $surface)
        }
        .padding(DS.Space.l)
    }
    .dsSurface(surface)
}

#Preview("Reading controls · Muted, AX2") {
    @Previewable @State var style = DSReadingStyle(scale: .largePrint)
    @Previewable @State var surface = DSSurface.muted
    ScrollView {
        VStack(spacing: DS.Space.panel) {
            ReadingSizeControl(style: $style)
            ReadingFontPicker(style: $style)
        }
        .padding(DS.Space.l)
    }
    .dsSurface(surface)
    .environment(\.dynamicTypeSize, .accessibility2)
}
