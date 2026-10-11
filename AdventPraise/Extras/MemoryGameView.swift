//
//  MemoryGameView.swift
//  Advent Praise
//
//  Learn a verse by heart: words disappear a few more at a time, and the
//  singer recalls them. Tap a blank to peek at its word. Five levels, from
//  the full text to every word hidden.
//

import SwiftUI

struct MemoryGameView: View {
    let hymnal: Hymnal
    let hymn: Hymn

    @State private var blockIndex = 0
    @State private var level = 1
    /// Word positions in hiding order; the first `hiddenCount` are blank.
    @State private var order: [Int] = []
    @State private var revealed: Set<Int> = []
    @State private var firstLetters = true

    private static let levels: [(name: String, fraction: Double)] = [
        ("Read", 0), ("A few", 0.25), ("Half", 0.5), ("Most", 0.75), ("All", 1),
    ]

    private var block: Hymn.Block? { hymn.blocks.indices.contains(blockIndex) ? hymn.blocks[blockIndex] : nil }

    /// Each line as tokens; `index` counts across the whole block.
    private var lines: [[Token]] {
        var next = 0
        return (block?.lines ?? []).map { line in
            line.split(separator: " ").map { word in
                defer { next += 1 }
                return Token(index: next, text: String(word))
            }
        }
    }

    private var hideable: [Int] { lines.flatMap { $0 }.filter(\.hasLetters).map(\.index) }
    private var hiddenCount: Int { Int((Double(hideable.count) * Self.levels[level].fraction).rounded(.up)) }
    private var hidden: Set<Int> { Set(order.prefix(hiddenCount)).subtracting(revealed) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                blockPicker
                levelPicker
                text
                progress
            }
            .padding(20)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) { controls }
        .navigationTitle("Memorise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Toggle(isOn: $firstLetters) { Label("First letters", systemImage: "character") }
                    .toggleStyle(.button)
                    .accessibilityHint("Shows the first letter of each hidden word")
            }
        }
        .onAppear(perform: shuffle)
        .onChange(of: blockIndex) { _, _ in shuffle() }
    }

    // MARK: Pieces

    private var blockPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Array(hymn.blocks.enumerated()), id: \.offset) { i, block in
                    let title: String = switch block {
                    case let .verse(number, _): "Verse \(number)"
                    case .chorus: hymnal.chorusLabel
                    }
                    Button(title) { blockIndex = i; Haptics.selection() }
                        .scaledFont(size: 14, weight: .semibold)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(i == blockIndex ? DS.Palette.evergreen : Color.primary.opacity(0.06)))
                        .foregroundStyle(i == blockIndex ? .white : .primary)
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(i == blockIndex ? .isSelected : [])
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var levelPicker: some View {
        Picker("Words hidden", selection: Binding(get: { level }, set: { level = $0; revealed = [] })) {
            ForEach(Self.levels.indices, id: \.self) { i in Text(Self.levels[i].name).tag(i) }
        }
        .pickerStyle(.segmented)
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(line) { token in word(token) }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: hidden)
    }

    @ViewBuilder
    private func word(_ token: Token) -> some View {
        if hidden.contains(token.index) {
            Button {
                revealed.insert(token.index)
                Haptics.light()
            } label: {
                Text(blank(for: token.text))
                    .scaledFont(size: 21, design: .serif)
                    .foregroundStyle(DS.Palette.evergreen)
                    .padding(.horizontal, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(DS.Palette.evergreen.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(firstLetters ? "Hidden word starting with \(token.text.first.map(String.init) ?? "")" : "Hidden word")
            .accessibilityHint("Reveals the word")
        } else {
            Text(token.text)
                .scaledFont(size: 21, design: .serif)
                .foregroundStyle(revealed.contains(token.index) ? DS.Palette.brass : .primary)
        }
    }

    private var progress: some View {
        let total = min(hiddenCount, hideable.count)
        let peeked = revealed.intersection(order.prefix(hiddenCount)).count
        return Text(total == 0 ? "Read it through, then hide some words." : "\(total) hidden · \(peeked) peeked")
            .scaledFont(size: 13, weight: .semibold)
            .foregroundStyle(.secondary)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                shuffle()
                Haptics.soft()
            } label: {
                Label("New blanks", systemImage: "shuffle").frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            Button {
                if level < Self.levels.count - 1 { level += 1 }
                revealed = []
                Haptics.rigid()
            } label: {
                Label(level < Self.levels.count - 1 ? "Hide more" : "Try again", systemImage: "eye.slash")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.Palette.evergreen)
        }
        .scaledFont(size: 15, weight: .semibold)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: Logic

    private func shuffle() {
        order = hideable.shuffled()
        revealed = []
    }

    /// "Lord," → "L___," with first letters on, "____," without.
    private func blank(for word: String) -> String {
        var out = ""
        var shownFirst = false
        for c in word {
            if c.isLetter || c.isNumber {
                if firstLetters && !shownFirst { out.append(c); shownFirst = true } else { out.append("_") }
            } else {
                out.append(c)
            }
        }
        return out
    }

    private struct Token: Identifiable {
        let index: Int
        let text: String
        var id: Int { index }
        var hasLetters: Bool { text.contains { $0.isLetter } }
    }
}

/// Lays children out left to right, wrapping onto new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for i in row.indices {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for (i, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let needed = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if needed > width, !row.indices.isEmpty {
                rows.append(row)
                row = Row()
            }
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(i)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}
