//
//  HymnNumberPad.swift
//  Advent Praise 7 — Vesper design system
//
//  The "Go" flow: type a number, watch the title resolve, press Go.
//  Keys are opaque (they sit inside glass); only the pad as a whole floats.
//  Supports a hardware keyboard on iPad: digits, ⌫ and ↩.
//

import SwiftUI

struct HymnNumberPad: View {
    @Binding var digits: String
    /// Resolves a number to a title; nil = no such hymn in this hymnal.
    let title: (Int) -> String?
    var recents: [DSHymnSummary] = []
    var maxDigits = 4
    /// true = draws its own glass (iPad popover, standalone). false = embedded in the Lectern.
    var isStandalone = true
    var onSearchInstead: (() -> Void)? = nil
    let onGo: (Int) -> Void

    @Environment(\.dsSurface) private var surface
    @FocusState private var keyboardFocus: Bool
    @ScaledMetric(relativeTo: .title2) private var keyHeight: CGFloat = DS.Size.padKey

    private var number: Int? { Int(digits) }
    private var resolvedTitle: String? { number.flatMap(title) }

    var body: some View {
        Group {
            if isStandalone {
                // One glass panel; the Go key inside it is bordered, not glass.
                pad.dsGlass(RoundedRectangle.ds(DS.Radius.panel), depth: .capsule)
            } else {
                pad
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        .sensoryFeedback(trigger: digits) { old, new in
            guard new.count > old.count else { return .impact(weight: .light) }
            return resolvedTitle != nil ? .impact(flexibility: .rigid) : .impact(weight: .light)
        }
        .onChange(of: resolvedTitle) { _, newTitle in
            if let newTitle, let number {
                AccessibilityNotification.Announcement("\(number), \(newTitle)").post()
            }
        }
    }

    private var pad: some View {
        VStack(spacing: DS.Space.m) {
            readout
            preview
            if !recents.isEmpty { recentRow }
            keys
        }
        .padding(DS.Space.panel)
        .focusable()
        .focused($keyboardFocus)
        .focusEffectDisabled()
        .onKeyPress(characters: .decimalDigits) { press in
            push(press.characters); return .handled
        }
        .onKeyPress(.delete) { backspace(); return .handled }
        .onKeyPress(.return) { go(); return .handled }
        .onAppear { keyboardFocus = true }
    }

    // MARK: Readout

    private var readout: some View {
        HStack(spacing: DS.Space.s) {
            HStack {
                if digits.isEmpty {
                    Text("Hymn number").font(DS.Typeface.label.weight(.regular)).foregroundStyle(surface.secondary)
                } else {
                    Text(digits)
                        .font(DS.Typeface.padReadout).monospacedDigit()
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DS.Space.panel)
            .frame(maxWidth: .infinity, minHeight: DS.Size.hitTarget)
            .background(RoundedRectangle.ds(DS.Radius.tile).fill(.primary.opacity(DS.Fill.inset)))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Hymn number")
            .accessibilityValue(digits.isEmpty ? Text("empty") : Text(digits))

            if let onSearchInstead {
                Button("Abc", action: onSearchInstead)
                    .font(DS.Typeface.button)
                    .padding(.horizontal, DS.Space.m)
                    .frame(minHeight: DS.Size.hitTarget)
                    .background(RoundedRectangle.ds(DS.Radius.tile).fill(.primary.opacity(DS.Fill.inset)))
                    .foregroundStyle(.primary)
                    .accessibilityLabel("Search by words instead")
            }
        }
    }

    // MARK: Preview line

    private var preview: some View {
        VStack(alignment: .leading, spacing: DS.Space.hair) {
            if let resolvedTitle, let number {
                Text(resolvedTitle).font(DS.Typeface.panelTitle).lineLimit(2)
                Text("Hymn \(number)").dsEyebrow(tracking: 0.7).foregroundStyle(surface.brass)
            } else if digits.isEmpty {
                Text("The title appears as you type.").font(DS.Typeface.detail).foregroundStyle(surface.secondary)
            } else {
                Text("No hymn with that number").font(DS.Typeface.rowBody.italic()).foregroundStyle(surface.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
        .padding(.horizontal, DS.Space.xxs)
        .animation(DS.Motion.quick, value: resolvedTitle)
        .accessibilityElement(children: .combine)
    }

    // MARK: Recents

    private var recentRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: DS.Space.xs) {
                Text("Recent").dsEyebrow().foregroundStyle(surface.secondary)
                ForEach(recents.prefix(3)) { hymn in
                    Button { digits = String(hymn.number) } label: {
                        HStack(spacing: DS.Space.xxs) {
                            Text(String(hymn.number)).foregroundStyle(surface.brass)
                            Text(hymn.title).lineLimit(1)
                        }
                        .font(DS.Typeface.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .frame(minHeight: 32)
                        .frame(maxWidth: 140)
                        .overlay(Capsule().strokeBorder(.primary.opacity(DS.Fill.stroke)))
                        // 32 pt chip, 44 pt tall hit area.
                        .frame(minHeight: DS.Size.hitTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Recent: \(hymn.number), \(hymn.title)")
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Keys

    private var keys: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Space.s), count: 3),
                  spacing: DS.Space.s) {
            ForEach(1...9, id: \.self) { n in
                PadKey(label: String(n), height: keyHeight) { push(String(n)) }
            }
            Button(action: backspace) {
                Image(systemName: "delete.left").font(.system(.title3))
                    .frame(maxWidth: .infinity, minHeight: keyHeight)
                    .contentShape(Rectangle())
            }
            .buttonRepeatBehavior(.enabled)
            .foregroundStyle(surface.secondary)
            .disabled(digits.isEmpty)
            .accessibilityLabel("Delete last digit")

            PadKey(label: "0", height: keyHeight) { push("0") }

            // The pad's one primary action. The pad always sits on glass, so this
            // is the bordered-prominent form (solid Evergreen key on iOS 17–25).
            GlassButton(title: "Go", systemImage: "arrow.right", fullWidth: true, action: go)
                .disabled(resolvedTitle == nil)
                .accessibilityLabel("Go to hymn")
                .accessibilityHint(resolvedTitle.map { Text($0) } ?? Text("Enter a hymn number first"))
        }
    }

    // MARK: Intents

    private func push(_ digit: String) {
        guard digits.count < maxDigits else { return }
        digits = digits == "0" ? digit : digits + digit
    }

    private func backspace() { digits = String(digits.dropLast()) }

    private func go() {
        guard let number, resolvedTitle != nil else { return }
        onGo(number)
    }
}

private struct PadKey: View {
    let label: String
    let height: CGFloat
    let action: () -> Void
    @Environment(\.dsSurface) private var surface

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(DS.Typeface.padDigit)
                .frame(maxWidth: .infinity, minHeight: height)
                .background(RoundedRectangle.ds(DS.Radius.key).fill(surface.elevated.opacity(0.85)))
                .overlay(RoundedRectangle.ds(DS.Radius.key).strokeBorder(.primary.opacity(DS.Fill.hairline)))
        }
        .buttonStyle(DSPressStyle())
        .foregroundStyle(.primary)
        .accessibilityLabel(label)
    }
}

#Preview("HymnNumberPad") {
    @Previewable @State var digits = "30"
    ZStack(alignment: .bottom) {
        DSPreviewBackdrop()
        HymnNumberPad(digits: $digits, title: DSPreview.title(for:),
                      recents: Array(DSPreview.hymns.prefix(3)),
                      onSearchInstead: {}) { _ in }
            .padding(DS.Space.l)
    }
    .dsSurface(.paper)
}

#Preview("HymnNumberPad · Black, empty") {
    @Previewable @State var digits = ""
    ZStack(alignment: .bottom) {
        DSPreviewBackdrop()
        HymnNumberPad(digits: $digits, title: DSPreview.title(for:)) { _ in }
            .padding(DS.Space.l)
    }
    .dsSurface(.black)
}
