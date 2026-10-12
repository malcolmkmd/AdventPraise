//
//  AppearanceControls.swift
//  Advent Praise 7 — Vesper design system
//
//  Typography and reading-surface controls. Presented in AdventDrawer at about
//  60 % height over a light dim, so every change previews live on the lyrics
//  above it. Order: size → print scale → spacing → alignment → font →
//  surface (most-used first).
//

import SwiftUI

struct AppearanceControls: View {
    @Binding var style: DSReadingStyle
    @Binding var surface: DSSurface
    var onDone: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Doesn't scroll by itself; the drawer (or a preview) supplies the ScrollView.
    var body: some View {
        VStack(spacing: DS.Space.panel) {
            header
            sizeSection
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
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { fontCards }
                VStack(spacing: DS.Space.s) { fontCards }
            }
            surfaceSection
        }
        .padding(.horizontal, DS.Space.l)
        .padding(.top, DS.Space.m)
        .padding(.bottom, DS.Space.l + DS.Space.xxs)
        .environment(\.dsSurface, surface)
        .environment(\.colorScheme, surface.colorScheme)
        .tint(surface.tint)
        .haptic(.selection, trigger: style)
        .haptic(.selection, trigger: surface)
    }

    // MARK: Sections

    private var header: some View {
        HStack {
            Text("Appearance").font(DS.Typeface.sheetTitle).accessibilityAddTraits(.isHeader)
            Spacer()
            if let onDone {
                GlassButton(title: "Done", kind: .secondary, action: onDone)
            }
        }
        .frame(minHeight: DS.Size.hitTarget)
    }

    private var sizeSection: some View {
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

    @ViewBuilder private var fontCards: some View {
        ForEach(DS.ReadingFont.allCases) { font in
            FontCard(font: font, isSelected: style.font == font) { style.font = font }
        }
    }

    private var surfaceSection: some View {
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

    // MARK: Helpers

    private var printScale: Binding<DS.LyricScale> {
        Binding(get: { style.scale == .largePrint ? .largePrint : .standard },
                set: { newScale in
                    // Keep the relative position on the slider when switching scale.
                    style.scale = newScale
                    style.step = min(style.step, newScale.steps.count - 1)
                })
    }

    private func step(_ delta: Int) {
        style.step = min(max(style.step + delta, 0), style.scale.steps.count - 1)
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

// MARK: - Presentation

extension View {
    /// Presents AppearanceControls in the live-preview drawer: a light dim so the
    /// lyrics above stay readable, Done pinned at the bottom once you scroll.
    func appearanceDrawer(isPresented: Binding<Bool>, style: Binding<DSReadingStyle>,
                          surface: Binding<DSSurface>, onDismiss: (() -> Void)? = nil) -> some View {
        adventDrawer("Appearance", isPresented: isPresented,
                     style: AdventDrawerStyle(detents: [.fraction(0.6), .large], dimming: 0.12),
                     onDismiss: onDismiss) {
            AppearanceControls(style: style, surface: surface)
                .analyticsScreen(.appearance)
        } actions: {
            GlassButton(title: "Done", fullWidth: true) { isPresented.wrappedValue = false }
                .padding(.horizontal, DS.Space.l)
                .padding(.top, DS.Space.m)
        }
    }
}

#Preview("AppearanceControls") {
    @Previewable @State var style = DSReadingStyle()
    @Previewable @State var surface = DSSurface.paper
    VStack(alignment: .leading) {
        ChapterVerseBlock(number: 1, lines: ["Blessed assurance, Jesus is mine!",
                                              "Oh, what a foretaste of glory divine!"], style: style)
            .padding(DS.Space.gutter)
        Spacer()
    }
    .dsSurface(surface)
    .appearanceDrawer(isPresented: .constant(true), style: $style, surface: $surface)
}

#Preview("AppearanceControls · Muted, AX2") {
    @Previewable @State var style = DSReadingStyle(scale: .largePrint)
    @Previewable @State var surface = DSSurface.muted
    ScrollView { AppearanceControls(style: $style, surface: $surface) {} }
        .background(surface.background)
        .environment(\.dynamicTypeSize, .accessibility2)
}
