//
//  MemoryGameView.swift
//  Advent Praise
//
//  Learn a verse by heart, as a game. Some words are hidden (A few, Half,
//  Most or All); the singer fills them in order by tapping the next word
//  from a row of chips. A right word drops into place with a haptic and
//  builds a streak; a wrong one shakes and the blank shows one more letter.
//  Rules and scoring: MemoryRound.
//

import SwiftUI

struct MemoryGameView: View {
    let hymnal: Hymnal
    let hymn: Hymn

    @State private var blockIndex = 0
    @State private var level = MemoryRound.Level.few
    @State private var round = MemoryRound.empty
    @State private var firstLetters = true
    /// The word that just dropped in, glowing for a moment.
    @State private var justFilled: Int?
    /// Wrong picks for the current blank: shaken, then set aside.
    @State private var wrongPicks: [String: Int] = [:]
    @Environment(\.dsSurface) private var surface
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var block: Hymn.Block? { hymn.blocks.indices.contains(blockIndex) ? hymn.blocks[blockIndex] : nil }
    private var blockName: String { block.map(name(of:)) ?? "" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.l) {
                blockPicker
                levelPicker
                scoreboard
                verse
                if round.isComplete { completion }
            }
            .padding(DS.Space.l)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !round.isComplete { choicePanel }
        }
        .navigationTitle("Memorise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Toggle(isOn: $firstLetters) { Label("First letters", systemImage: "character") }
                    .toggleStyle(.button)
                    .accessibilityHint("Shows the first letter of each hidden word")
            }
        }
        .onAppear(perform: newRound)
        .analyticsScreen(.memoryGame)
        #if DEBUG
        .task {
            try? await Task.sleep(for: .milliseconds(400))
            for _ in 0..<DebugLaunch.memoryMoves {
                guard let current = round.current, let answer = round.token(current)?.answer else { break }
                pick(answer)
            }
            if DebugLaunch.memoryMoves > 0, let wrong = round.choices.first(where: {
                MemoryRound.key($0) != MemoryRound.key(round.current.flatMap(round.token)?.answer ?? "")
            }) { pick(wrong) }
        }
        #endif
        .onChange(of: blockIndex) { _, _ in newRound() }
        .onChange(of: level) { _, _ in newRound() }
    }

    // MARK: Pickers

    private var blockPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: DS.Space.s) {
                ForEach(Array(hymn.blocks.enumerated()), id: \.offset) { i, block in
                    Button(name(of: block)) { blockIndex = i; Haptics.play(.selection) }
                        .buttonStyle(ToolChipStyle(isSelected: i == blockIndex))
                        .accessibilityAddTraits(i == blockIndex ? .isSelected : [])
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var levelPicker: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text("Words hidden").dsEyebrow().foregroundStyle(surface.secondary)
                .accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal) {
                HStack(spacing: DS.Space.s) {
                    ForEach(MemoryRound.Level.allCases) { option in
                        Button(option.name) { level = option; Haptics.play(.selection) }
                            .buttonStyle(ToolChipStyle(isSelected: option == level))
                            .accessibilityLabel("\(option.name) hidden")
                            .accessibilityAddTraits(option == level ? .isSelected : [])
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: Score

    private var scoreboard: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Space.l) {
                stat(value: round.score, label: "Score")
                HStack(alignment: .firstTextBaseline, spacing: DS.Space.xxs) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(round.streak > 0 ? surface.brass : surface.secondary)
                        .symbolEffect(.bounce, value: reduceMotion ? 0 : round.streak)
                    stat(value: round.streak, label: "Streak")
                }
                Spacer(minLength: 0)
                Text("\(round.filled.count) of \(round.targets.count)")
                    .font(DS.Typeface.label).monospacedDigit()
                    .foregroundStyle(surface.secondary)
                    .contentTransition(.numericText())
            }
            ProgressBar(value: round.progress)
        }
        .animation(DS.Motion.adaptive(DS.Motion.quick, reduceMotion: reduceMotion), value: round.score)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score \(round.score), streak \(round.streak), \(round.filled.count) of \(round.targets.count) words found")
    }

    private func stat(value: Int, label: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Space.xxs) {
            Text(value, format: .number)
                .font(DS.Typeface.panelTitle).monospacedDigit()
                .contentTransition(.numericText(value: Double(value)))
            Text(label).dsEyebrow().foregroundStyle(surface.secondary)
        }
    }

    // MARK: Verse

    private var verse: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            ForEach(Array(round.lines.enumerated()), id: \.offset) { _, line in
                FlowLayout(spacing: DS.Space.xs, lineSpacing: DS.Space.xs) {
                    ForEach(line) { token in word(token) }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(blockName): \(spokenVerse)")
    }

    @ViewBuilder
    private func word(_ token: MemoryRound.Token) -> some View {
        if round.isHidden(token.index) {
            BlankWord(text: blank(for: token), isCurrent: token.index == round.current)
                .transition(reduceMotion ? .opacity : .scale(scale: 0.6).combined(with: .opacity))
        } else {
            Text(token.text)
                .scaledFont(size: 21, design: .serif)
                .background {
                    if justFilled == token.index {
                        RoundedRectangle.ds(6).fill(surface.brass.opacity(DS.Fill.highlight))
                            .padding(.horizontal, -DS.Space.xxs)
                    }
                }
                .scaleEffect(justFilled == token.index && !reduceMotion ? 1.12 : 1)
                .transition(reduceMotion ? .opacity : .scale(scale: 1.4).combined(with: .opacity))
        }
    }

    /// What VoiceOver reads: the verse, with "blank" for each hidden word.
    private var spokenVerse: String {
        round.lines.flatMap { $0 }.map { token in
            guard round.isHidden(token.index) else { return token.text }
            let shown = String(token.answer.prefix(round.shownLetters(token.index, firstLetters: firstLetters)))
            let blank = token.index == round.current ? String(localized: "next blank") : String(localized: "blank")
            return shown.isEmpty ? blank : String(localized: "\(blank) starting \(shown)")
        }
        .joined(separator: " ")
    }

    // MARK: Choices

    private var choicePanel: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            HStack {
                Text("Which word comes next?").font(DS.Typeface.label)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: DS.Space.s)
                Button("Hint", systemImage: "lightbulb") { hint() }
                    .font(DS.Typeface.button)
                    .foregroundStyle(surface.tint)
                    .frame(minHeight: DS.Size.hitTarget)
                    .disabled(round.current == nil)
                    .accessibilityHint("Shows one more letter. Ends your streak.")
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: DS.Space.s), GridItem(.flexible(), spacing: DS.Space.s)],
                      spacing: DS.Space.s) {
                ForEach(round.choices, id: \.self) { choice in
                    let misses = wrongPicks[choice, default: 0]
                    Button { pick(choice) } label: { Text(choice) }
                        .buttonStyle(WordChipStyle(isRuledOut: misses > 0))
                        .disabled(misses > 0)
                        .modifier(Shake(amount: reduceMotion ? 0 : 9, shakes: CGFloat(misses)))
                        .accessibilityHint("Fills the next blank")
                }
            }
            .id(round.current) // fresh chips for each blank
            .transition(.opacity)
        }
        .padding(.horizontal, DS.Space.l)
        .padding(.vertical, DS.Space.m)
        .frame(maxWidth: .infinity)
        .background(surface.elevated.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(surface.controlBorder.opacity(0.4)).frame(height: 1) }
    }

    // MARK: Completion

    private var completion: some View {
        let accuracy = round.targets.isEmpty ? 0 : Double(round.firstTry) / Double(round.targets.count)
        let next = level.harder
        let nextBlock = blockIndex + 1 < hymn.blocks.count ? blockIndex + 1 : nil
        return VStack(spacing: DS.Space.m) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(surface.brass)
                .accessibilityHidden(true)
            Text("\(blockName) learned").font(DS.Typeface.sheetTitle)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: DS.Space.l) {
                summary("\(round.score)", "Score")
                summary("\(round.bestStreak)", "Best streak")
                summary(accuracy.formatted(.percent.precision(.fractionLength(0))), "First try")
            }
            VStack(spacing: DS.Space.s) {
                if let next {
                    Button("Hide more words") { level = next }
                        .buttonStyle(ToolButtonStyle(prominent: true))
                } else if let nextBlock {
                    Button("Next: \(name(of: hymn.blocks[nextBlock]))") { blockIndex = nextBlock }
                        .buttonStyle(ToolButtonStyle(prominent: true))
                }
                Button("Play again") { newRound() }
                    .buttonStyle(ToolButtonStyle(prominent: next == nil && nextBlock == nil))
            }
        }
        .padding(DS.Space.l)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle.ds(DS.Radius.card).fill(surface.elevated))
        .overlay(RoundedRectangle.ds(DS.Radius.card).strokeBorder(surface.controlBorder.opacity(0.5)))
        .transition(reduceMotion ? .opacity : .scale(scale: 0.92).combined(with: .opacity))
    }

    private func summary(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(spacing: DS.Space.hair) {
            Text(value).font(DS.Typeface.panelTitle).monospacedDigit()
            Text(label).dsEyebrow(tracking: 0.6).foregroundStyle(surface.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Actions

    private func newRound() {
        let lines = block?.lines ?? []
        let words = hymn.blocks.flatMap(\.lines).flatMap { $0.split(separator: " ").map(String.init) }
        withAnimation(DS.Motion.adaptive(DS.Motion.quick, reduceMotion: reduceMotion)) {
            round = MemoryRound(lines: lines, level: level, hymnWords: words)
            wrongPicks = [:]
            justFilled = nil
        }
        if !round.targets.isEmpty {
            Analytics.track(.memoryGameStarted(part: part, level: level, wordCount: round.targets.count))
        }
    }

    private var part: MemoryPart {
        if case .chorus? = block { return .chorus }
        return .verse
    }

    private func trackCompletion() {
        let firstTry = round.targets.isEmpty ? 0 : round.firstTry * 100 / round.targets.count
        Analytics.track(.memoryGameCompleted(part: part, level: level, score: round.score, bestStreak: round.bestStreak,
                                             firstTryPercent: firstTry, hintsUsed: round.hintsUsed))
    }

    private func pick(_ choice: String) {
        guard let current = round.current else { return }
        var next = round
        if next.choose(choice) {
            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.4, bounce: 0.45)) {
                round = next
                wrongPicks = [:]
                justFilled = current
            }
            // A tap per word; success is kept for finishing the verse.
            Haptics.play(round.isComplete ? .success : .lightImpact)
            if round.isComplete { trackCompletion() }
            announce(round.isComplete ? String(localized: "\(choice). \(blockName) learned. Score \(round.score).")
                                      : String(localized: "\(choice). Streak \(round.streak)."))
            Task {
                try? await Task.sleep(for: .milliseconds(650))
                if justFilled == current {
                    withAnimation(DS.Motion.adaptive(.easeOut(duration: 0.4), reduceMotion: reduceMotion)) { justFilled = nil }
                }
            }
        } else {
            withAnimation(.linear(duration: 0.4)) { wrongPicks[choice, default: 0] += 1 }
            withAnimation(DS.Motion.adaptive(DS.Motion.quick, reduceMotion: reduceMotion)) { round = next }
            Haptics.play(.error)
            announce(String(localized: "Not \(choice). \(hintPhrase(for: current))"))
        }
    }

    private func hint() {
        guard let current = round.current else { return }
        withAnimation(DS.Motion.adaptive(DS.Motion.quick, reduceMotion: reduceMotion)) { round.hint() }
        Haptics.play(.softImpact)
        announce(hintPhrase(for: current))
    }

    private func hintPhrase(for index: Int) -> String {
        let shown = round.token(index).map { String($0.answer.prefix(round.shownLetters(index, firstLetters: firstLetters))) } ?? ""
        return shown.isEmpty ? "" : String(localized: "It starts \(shown).")
    }

    private func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }

    // MARK: Text

    private func name(of block: Hymn.Block) -> String {
        switch block {
        case let .verse(number, _): String(localized: "Verse \(number)")
        case .chorus: hymnal.chorusLabel
        }
    }

    /// "Lord," → "L___," (first letter on, plus any hints), "____," with none.
    private func blank(for token: MemoryRound.Token) -> String {
        var remaining = round.shownLetters(token.index, firstLetters: firstLetters)
        var out = ""
        for c in token.text {
            if c.isLetter || c.isNumber {
                if remaining > 0 { out.append(c); remaining -= 1 } else { out.append("_") }
            } else {
                out.append(c)
            }
        }
        return out
    }
}

// MARK: - Pieces

/// A hidden word. The one to fill next sits in a tint wash with a firm tint
/// outline; later ones are dashed outlines. Text is full foreground on both.
private struct BlankWord: View {
    let text: String
    let isCurrent: Bool
    @Environment(\.dsSurface) private var surface

    var body: some View {
        let shape = RoundedRectangle.ds(6)
        Text(text)
            .scaledFont(size: 21, design: .serif)
            .padding(.horizontal, DS.Space.xxs)
            .background(shape.fill(isCurrent ? surface.tint.opacity(DS.Fill.tintOn) : .clear))
            .overlay {
                if isCurrent {
                    shape.strokeBorder(surface.tint, lineWidth: 2)
                } else {
                    shape.strokeBorder(surface.controlBorder, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
            }
            .contentTransition(.interpolate)
    }
}

/// A word chip in the choice panel: the reading ground on the elevated panel,
/// with an outline. Ruled out after a wrong pick (struck through, dimmed).
private struct WordChipStyle: ButtonStyle {
    var isRuledOut: Bool
    @Environment(\.dsSurface) private var surface
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle.ds(DS.Radius.key)
        configuration.label
            .scaledFont(size: 19, weight: .semibold, design: .serif)
            .strikethrough(isRuledOut)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, DS.Space.m)
            .frame(maxWidth: .infinity, minHeight: DS.Size.row)
            .background(shape.fill(configuration.isPressed ? surface.tint.opacity(DS.Fill.tintOn) : surface.background))
            .overlay(shape.strokeBorder(configuration.isPressed ? surface.tint : surface.controlBorder,
                                        lineWidth: configuration.isPressed ? 2 : 1))
            .contentShape(shape)
            .opacity(isRuledOut ? DS.Fill.disabled : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(DS.Motion.press, value: configuration.isPressed)
    }
}

/// A thin tint bar for the share of blanks filled.
private struct ProgressBar: View {
    let value: Double
    @Environment(\.dsSurface) private var surface

    var body: some View {
        Capsule().fill(surface.controlBorder.opacity(0.35))
            .frame(height: 6)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule().fill(surface.tint).frame(width: proxy.size.width * min(max(value, 0), 1))
                }
            }
            .accessibilityHidden(true)
    }
}

/// Side-to-side shake; `shakes` counts up once per wrong pick.
private struct Shake: GeometryEffect {
    var amount: CGFloat
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(shakes * .pi * 4), y: 0))
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
