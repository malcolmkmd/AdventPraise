//
//  ChurchModeView.swift
//  Advent Praise
//
//  Worship-in-church mode: one verse (or chorus) at a time, as large as the
//  screen allows, white on black. The screen stays awake, the status bar and
//  every other control disappear, and the whole screen is a next/previous
//  button: tap the right side (or the big arrow) for the next verse, the left
//  side to go back. The chorus follows each verse, as it is sung.
//

import SwiftUI
import UIKit

struct ChurchModeView: View {
    @Bindable var model: ReaderModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var maxLyricSize: CGFloat = 64
    @State private var index = 0

    private var sequence: [Hymn.Block] { model.hymn.sungSequence }
    private var block: Hymn.Block? { sequence.indices.contains(index) ? sequence[index] : nil }
    private var isLast: Bool { index >= sequence.count - 1 }
    private static let gold = Vesper.brassOnDark

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                    lyric(in: geo.size)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .gesture(
                            SpatialTapGesture().onEnded { value in
                                value.location.x < geo.size.width * 0.33 ? previous() : next()
                            }
                        )
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 30).onEnded { value in
                                if value.translation.width < -50 { next() }
                                if value.translation.width > 50 { previous() }
                            }
                        )
                    controls
                }
                .padding(.horizontal, 20)
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            index = 0
            Analytics.track(.churchModeStarted(hymnal: model.hymnal.id))
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: model.hymn.id) { _, _ in index = 0 }
        .accessibilityAction(named: "Next verse") { next() }
        .accessibilityAction(named: "Previous verse") { previous() }
        .accessibilityAction(.escape) { dismiss() }
    }

    // MARK: Pieces

    private var topBar: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(model.hymn.id) · \(model.hymn.title)")
                    .scaledFont(size: 15, weight: .semibold, relativeTo: .subheadline)
                    .lineLimit(1)
                Text(position)
                    .scaledFont(size: 13, weight: .medium, relativeTo: .caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .accessibilityElement(children: .combine)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 48, height: 48)
                    .churchGlass(in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close church mode")
        }
        .padding(.top, 8)
    }

    private var position: String {
        switch block {
        case let .verse(number, _)?: "Verse \(number) of \(model.hymn.verseCount)"
        case .chorus?: model.hymnal.chorusLabel
        case nil: ""
        }
    }

    @ViewBuilder
    private func lyric(in size: CGSize) -> some View {
        if let block {
            let isChorus: Bool = { if case .chorus = block { true } else { false } }()
            VStack(alignment: .leading, spacing: 16) {
                if isChorus {
                    Text(model.hymnal.chorusLabel)
                        .scaledFont(size: 16, weight: .bold, relativeTo: .headline)
                        .tracking(2).textCase(.uppercase)
                        .foregroundStyle(Self.gold)
                }
                Text(block.lines.joined(separator: "\n"))
                    .font(.system(size: maxLyricSize, weight: .semibold, design: .serif))
                    .italic(isChorus)
                    .lineSpacing(6)
                    .minimumScaleFactor(0.25)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .padding(.vertical, 12)
            .id(index)
            .transition(reduceMotion ? .opacity : .asymmetric(insertion: .opacity.combined(with: .offset(x: 24)),
                                                              removal: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(position). \(block.lines.joined(separator: " "))")
            .accessibilityAddTraits(.updatesFrequently)
        } else {
            Text("This hymn has no text yet.")
                .scaledFont(size: 22, design: .serif, italic: true)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Button(action: previous) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 26, weight: .bold))
                    .frame(width: 88, height: 72)
                    .churchGlass(in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(index == 0)
            .opacity(index == 0 ? 0.35 : 1)
            .accessibilityLabel("Previous verse")

            Button {
                if isLast { nextHymn() } else { next() }
            } label: {
                HStack(spacing: 10) {
                    Text(nextTitle)
                        .scaledFont(size: 20, weight: .bold, relativeTo: .title3)
                    Image(systemName: isLast ? "forward.end.fill" : "chevron.right")
                        .font(.system(size: 22, weight: .bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 72)
                .background(Capsule().fill(Self.gold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(nextAccessibilityLabel)
        }
        .padding(.bottom, 12)
    }

    private var nextTitle: String {
        guard isLast else { return "Next" }
        if let hymn = model.nextHymn { return "Hymn \(hymn.id)" }
        return "Done"
    }

    private var nextAccessibilityLabel: String {
        guard isLast else { return "Next verse" }
        if let hymn = model.nextHymn { return "Next hymn, \(hymn.id), \(hymn.title)" }
        return "Done"
    }

    // MARK: Navigation

    private func next() {
        guard !isLast else { return }
        withAnimation(.easeOut(duration: 0.22)) { index += 1 }
        Haptics.light()
    }

    private func previous() {
        guard index > 0 else { return }
        withAnimation(.easeOut(duration: 0.22)) { index -= 1 }
        Haptics.light()
    }

    private func nextHymn() {
        if model.goToNextHymn() != nil {
            index = 0
            Haptics.rigid()
        } else {
            dismiss()
        }
    }
}

private extension View {
    /// Liquid Glass on iOS 26, a dark material elsewhere.
    @ViewBuilder
    func churchGlass<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular.interactive(), in: shape)
        } else {
            background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(.white.opacity(0.15), lineWidth: 1))
        }
    }
}
