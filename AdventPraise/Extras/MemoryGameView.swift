//
//  MemoryGameView.swift
//  Advent Praise
//
//  Learn a verse by heart, as a game. Some words are hidden (A few, Half,
//  Most or All, one round each); the singer fills them in order by tapping
//  the next word from four chips that could all fit. Blanks give nothing
//  away. A right word drops into place with a haptic and builds a streak;
//  every third in a row earns a hint. A wrong one shakes and is ruled out.
//  A finished stanza earns stars; finished with every word hidden, it is
//  learned by heart and the verse tab says so. Rules and scoring:
//  MemoryRound.
//

import SwiftUI

struct MemoryGameView: View {
    let hymnal: Hymnal
    let hymn: Hymn

    @State private var blockIndex = 0
    @State private var level = MemoryRound.Level.few
    @State private var round = MemoryRound.empty
    /// The word that just dropped in, glowing for a moment.
    @State private var justFilled: Int?
    /// Shakes per chip for the current blank, counted up on each wrong pick.
    @State private var shakes: [String: Int] = [:]
    /// A short line under the scoreboard: a streak milestone, a free letter.
    @State private var note: Note?
    /// Stars revealed so far on the completion card.
    @State private var starsShown = 0
    /// The round's stars beat the stanza's best.
    @State private var isNewBest = false
    @Environment(\.dsSurface) private var surface
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Note: Equatable {
        let text: String
        let symbol: String
        /// The blank the note is about; it goes when that blank is filled.
        var blank: Int? = nil
        let id = UUID()
    }

    private var block: Hymn.Block? { hymn.blocks.indices.contains(blockIndex) ? hymn.blocks[blockIndex] : nil }
    private var blockName: String { block.map(name(of:)) ?? "" }
    private var progress: MemoryProgress { MemoryProgress(hymnal: hymnal.id, hymn: hymn.id) }

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
                    let learned = progress.isLearned(block: i)
                    Button { blockIndex = i; Haptics.play(.selection) } label: {
                        HStack(spacing: DS.Space.xxs) {
                            Text(name(of: block))
                            if learned {
                                Image(systemName: "checkmark.circle.fill").imageScale(.small)
                            }
                        }
                    }
                    .buttonStyle(ToolChipStyle(isSelected: i == blockIndex))
                    .accessibilityLabel(learned ? "\(name(of: block)), learned by heart" : name(of: block))
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
                        let best = progress.stars(block: blockIndex, level: option)
                        Button { level = option; Haptics.play(.selection) } label: {
                            HStack(spacing: DS.Space.xxs) {
                                Text(option.name)
                                if best > 0 {
                                    StarRow(count: best, shown: best, size: 9,
                                            color: option == level ? surface.onTint : surface.brass)
                                }
                            }
                        }
                        .buttonStyle(ToolChipStyle(isSelected: option == level))
                        .accessibilityLabel(best > 0
                            ? Text(AttributedString(localized: "\(option.name) hidden, best ^[\(best) star](inflect: true)"))
                            : Text("\(option.name) hidden"))
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
            HStack(alignment: .firstTextBaseline, spacing: DS.Space.m) {
                stat(value: round.score, label: "Score")
                HStack(alignment: .firstTextBaseline, spacing: DS.Space.xxs) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(round.streak >= MemoryRound.streakPerHint ? surface.brass : surface.secondary)
                        .symbolEffect(.bounce, value: reduceMotion ? 0 : round.streak)
                    stat(value: round.streak, label: "Streak")
                }
                HStack(alignment: .firstTextBaseline, spacing: DS.Space.xxs) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(round.hints > 0 ? surface.tint : surface.secondary)
                        .symbolEffect(.bounce, value: reduceMotion ? 0 : round.hintsEarned)
                    stat(value: round.hints, label: "Hints")
                }
                Spacer(minLength: 0)
                Text("\(round.filled.count) of \(round.targets.count)")
                    .font(DS.Typeface.label).monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(surface.secondary)
                    .contentTransition(.numericText())
            }
            ProgressBar(value: round.progress)
            noteLine
        }
        .animation(DS.Motion.adaptive(DS.Motion.quick, reduceMotion: reduceMotion), value: round.score)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score \(round.score), streak \(round.streak), \(round.hints) hints, \(round.filled.count) of \(round.targets.count) words found")
    }

    private func stat(value: Int, label: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Space.xxs) {
            Text(value, format: .number)
                .font(DS.Typeface.panelTitle).monospacedDigit()
                .contentTransition(.numericText(value: Double(value)))
            // One line, whatever the score's width: "Streak", never "Strea / k".
            Text(label).dsEyebrow().foregroundStyle(surface.secondary)
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    /// A line that stays the height of one caption so nothing below jumps.
    private var noteLine: some View {
        ZStack(alignment: .leading) {
            Text(" ").font(DS.Typeface.detail)
            if let note {
                Label(note.text, systemImage: note.symbol)
                    .font(DS.Typeface.detail.weight(.semibold))
                    .foregroundStyle(surface.brass)
                    .id(note.id)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .clipped()
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
            let shown = round.shownPrefix(token.index)
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
                Button { hint() } label: {
                    Label {
                        Text("Hint")
                    } icon: {
                        Image(systemName: "lightbulb")
                            .overlay(alignment: .topTrailing) {
                                Text(round.hints, format: .number)
                                    .font(DS.Typeface.caption.weight(.bold)).monospacedDigit()
                                    .foregroundStyle(surface.onTint)
                                    .padding(.horizontal, 4)
                                    .frame(minWidth: 16, minHeight: 16)
                                    .background(Capsule().fill(round.hints > 0 ? surface.tint : surface.secondary))
                                    .offset(x: 10, y: -9)
                                    .contentTransition(.numericText())
                            }
                    }
                }
                .font(DS.Typeface.button)
                .foregroundStyle(surface.tint)
                .frame(minHeight: DS.Size.hitTarget)
                .disabled(!round.canHint)
                .animation(DS.Motion.adaptive(DS.Motion.quick, reduceMotion: reduceMotion), value: round.hints)
                .accessibilityLabel("Hint")
                .accessibilityValue(round.hints == 1 ? "1 left" : "\(round.hints) left")
                .accessibilityHint(round.hints > 0 ? "Shows the next letter and rules out words that can't fit. Keeps your streak; the word scores less."
                                                   : "Three right in a row earns a hint.")
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: DS.Space.s), GridItem(.flexible(), spacing: DS.Space.s)],
                      spacing: DS.Space.s) {
                ForEach(round.choices, id: \.self) { choice in
                    let out = round.isRuledOut(choice)
                    Button { pick(choice) } label: { Text(choice) }
                        .buttonStyle(WordChipStyle(isRuledOut: out))
                        .disabled(out)
                        .modifier(Shake(amount: reduceMotion ? 0 : 9, shakes: CGFloat(shakes[choice, default: 0])))
                        .accessibilityValue(out ? "ruled out" : "")
                        .accessibilityHint(out ? "" : "Fills the next blank")
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
        let learned = level == .all
        let next = level.harder
        let nextBlock = blockIndex + 1 < hymn.blocks.count ? blockIndex + 1 : nil
        return VStack(spacing: DS.Space.m) {
            Image(systemName: learned ? "laurel.leading" : "checkmark.seal.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(surface.brass)
                .symbolEffect(.bounce, value: reduceMotion ? 0 : starsShown)
                .accessibilityHidden(true)
            Text(learned ? "\(blockName) learned by heart" : "\(blockName), round \(level.round) of 4")
                .font(DS.Typeface.sheetTitle)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            StarRow(count: 3, shown: starsShown, size: 28)
                .accessibilityLabel(round.stars == 1 ? "1 star" : "\(round.stars) stars")
            Text(verdict)
                .font(DS.Typeface.detail)
                .foregroundStyle(surface.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: DS.Space.l) {
                summary("\(round.score)", "Score")
                summary("\(round.bestStreak)", "Best streak")
                summary(round.accuracy.formatted(.percent.precision(.fractionLength(0))), "First try")
            }
            VStack(spacing: DS.Space.s) {
                if let next {
                    Button("Next round: \(next.name.lowercased()) hidden") { replay(.nextLevel) }
                        .buttonStyle(ToolButtonStyle(prominent: true))
                } else if let nextBlock {
                    Button("Next: \(name(of: hymn.blocks[nextBlock]))") { replay(.nextBlock) }
                        .buttonStyle(ToolButtonStyle(prominent: true))
                }
                Button("Play again") { replay(.again) }
                    .buttonStyle(ToolButtonStyle(prominent: next == nil && nextBlock == nil))
                if learned, level != .few {
                    Button("Start over from a few") { replay(.startOver) }
                        .buttonStyle(ToolButtonStyle())
                }
            }
        }
        .padding(DS.Space.l)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle.ds(DS.Radius.card).fill(surface.elevated))
        .overlay(RoundedRectangle.ds(DS.Radius.card).strokeBorder(surface.controlBorder.opacity(0.5)))
        .transition(reduceMotion ? .opacity : .scale(scale: 0.92).combined(with: .opacity))
    }

    /// A line under the stars: what they mean, and whether they're a best.
    private var verdict: String {
        let line: String = switch round.stars {
        case 3: String(localized: "Word perfect, or near enough.")
        case 2: String(localized: "Well remembered. Three stars for nine in ten first time.")
        default: String(localized: "Finished. Play again for more first-time words.")
        }
        return isNewBest ? line + " " + String(localized: "A new best.") : line
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
            // Fresh blanks every start: Play again never deals the same
            // hidden words twice running. Another verse just starts clean.
            let sameVerse = round.lines.map { $0.map(\.text).joined(separator: " ") } == lines
            round = MemoryRound(lines: lines, level: level, hymnWords: words,
                                avoiding: sameVerse ? round.targets : [])
            shakes = [:]
            justFilled = nil
            note = nil
            starsShown = 0
            isNewBest = false
        }
        if !round.targets.isEmpty {
            Analytics.track(.memoryGameStarted(part: part, level: level, wordCount: round.targets.count))
        }
    }

    private func replay(_ reason: MemoryReplay) {
        Haptics.play(.selection)
        switch reason {
        case .again:
            Analytics.track(.memoryRoundReplayed(part: part, level: level, reason: reason))
            newRound()
        case .nextLevel:
            guard let next = level.harder else { return }
            Analytics.track(.memoryRoundReplayed(part: part, level: next, reason: reason))
            level = next
        case .nextBlock:
            Analytics.track(.memoryRoundReplayed(part: part, level: level, reason: reason))
            blockIndex += 1
        case .startOver:
            Analytics.track(.memoryRoundReplayed(part: part, level: .few, reason: reason))
            level = .few
        }
    }

    private var part: MemoryPart {
        if case .chorus? = block { return .chorus }
        return .verse
    }

    private func pick(_ choice: String) {
        guard let current = round.current else { return }
        var next = round
        switch next.choose(choice) {
        case let .right(milestone, earnedHint):
            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.4, bounce: 0.45)) {
                round = next
                shakes = [:]
                justFilled = current
                if milestone {
                    note = Note(text: earnedHint ? String(localized: "\(round.streak) in a row, +1 hint")
                                                 : String(localized: "\(round.streak) in a row"),
                                symbol: earnedHint ? "lightbulb.fill" : "flame.fill")
                } else if note?.blank == current {
                    note = nil
                }
            }
            if milestone { Analytics.track(.memoryStreakReached(part: part, level: level, streak: round.streak)) }
            // A tap per word, a firmer one for a milestone; success is kept for the stanza.
            if round.isComplete {
                finish()
            } else {
                Haptics.play(milestone ? .thresholdCrossed : .lightImpact)
                let streakPhrase = String(localized: "\(choice). Streak \(round.streak).")
                announce(earnedHint ? streakPhrase + " " + String(localized: "Hint earned.") : streakPhrase)
            }
            let shownNote = note?.id
            Task {
                try? await Task.sleep(for: .milliseconds(650))
                if justFilled == current {
                    withAnimation(DS.Motion.adaptive(.easeOut(duration: 0.4), reduceMotion: reduceMotion)) { justFilled = nil }
                }
                try? await Task.sleep(for: .milliseconds(1_600))
                if milestone, note?.id == shownNote {
                    withAnimation(DS.Motion.adaptive(DS.Motion.quick, reduceMotion: reduceMotion)) { note = nil }
                }
            }
        case let .wrong(revealed):
            withAnimation(.linear(duration: 0.4)) { shakes[choice, default: 0] += 1 }
            withAnimation(DS.Motion.adaptive(DS.Motion.quick, reduceMotion: reduceMotion)) {
                round = next
                if revealed { note = Note(text: String(localized: "First letter shown"), symbol: "character", blank: current) }
            }
            Haptics.play(.error)
            announce(revealed ? String(localized: "Not \(choice). \(hintPhrase(for: current))")
                              : String(localized: "Not \(choice)."))
        }
    }

    private func hint() {
        guard let current = round.current else { return }
        var next = round
        guard next.hint() else { return }
        withAnimation(DS.Motion.adaptive(DS.Motion.quick, reduceMotion: reduceMotion)) { round = next }
        Haptics.play(.softImpact)
        Analytics.track(.memoryHintUsed(part: part, level: level, hintsLeft: round.hints))
        let left = round.choices.filter { !round.isRuledOut($0) }.count
        announce(hintPhrase(for: current) + " " + String(localized: "\(left) words left to choose from."))
    }

    /// The stanza is done: stars one by one, the best kept, learned noted.
    private func finish() {
        let stars = round.stars
        isNewBest = progress.record(stars: stars, block: blockIndex, level: level)
        let firstTry = Int((round.accuracy * 100).rounded())
        Analytics.track(.memoryGameCompleted(part: part, level: level, score: round.score, bestStreak: round.bestStreak,
                                             firstTryPercent: firstTry, hintsUsed: round.hintsUsed, stars: stars))
        if level == .all { Analytics.track(.memoryVerseLearned(part: part, stars: stars)) }
        Haptics.play(.success)
        let headline = level == .all ? String(localized: "\(blockName) learned by heart.")
                                     : String(localized: "\(blockName) finished, round \(level.round) of 4.")
        announce(headline + " " + (stars == 1 ? String(localized: "1 star.") : String(localized: "\(stars) stars."))
                 + " " + String(localized: "Score \(round.score)."))
        if reduceMotion {
            starsShown = stars
            return
        }
        Task {
            for shown in 1...stars {
                try? await Task.sleep(for: .milliseconds(shown == 1 ? 500 : 320))
                guard round.isComplete else { return }
                withAnimation(.spring(duration: 0.35, bounce: 0.4)) { starsShown = shown }
                Haptics.play(.lightImpact)
            }
        }
    }

    private func hintPhrase(for index: Int) -> String {
        let shown = round.shownPrefix(index)
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

    /// A hidden word. Nothing shown: a fixed-width blank, so its length
    /// gives nothing away. Letters revealed: "Lo__," at the word's true length.
    private func blank(for token: MemoryRound.Token) -> String {
        var remaining = round.shownLetters(token.index)
        guard remaining > 0 else {
            let trailing = token.text.reversed().prefix { !$0.isLetter && !$0.isNumber }
            return "_____" + String(trailing.reversed())
        }
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

/// Up to three stars, `shown` of them lit (brass unless `color` says
/// otherwise), the rest outlined.
private struct StarRow: View {
    let count: Int
    let shown: Int
    let size: CGFloat
    var color: Color?
    @Environment(\.dsSurface) private var surface
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: size / 5) {
            ForEach(0..<count, id: \.self) { i in
                let lit = i < shown
                Image(systemName: lit ? "star.fill" : "star")
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(lit ? (color ?? surface.brass) : surface.secondary)
                    .scaleEffect(lit || reduceMotion ? 1 : 0.85)
                    .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.4), value: lit)
            }
        }
        .accessibilityElement(children: .ignore)
    }
}

/// A word chip in the choice panel: the reading ground on the elevated panel,
/// with an outline. Ruled out after a wrong pick or a hint (struck through, dimmed).
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
            .animation(DS.Motion.quick, value: isRuledOut)
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
