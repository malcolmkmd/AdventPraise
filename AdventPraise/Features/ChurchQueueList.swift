//
//  ChurchQueueList.swift
//  Advent Praise
//
//  The running playlist or service plan, above church mode's number pad.
//  The hymn Next goes to is highlighted and scrolled into view; the open
//  one is marked Now. Tap any hymn to jump there and follow the list on
//  from it. Hymns this hymnal lacks are shown muted and can't be chosen.
//

import SwiftUI

struct ChurchQueueList: View {
    let queue: RunningQueue
    let title: (Int) -> String?
    let onSelect: (Int) -> Void
    @Environment(\.dsSurface) private var surface

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            HStack(spacing: DS.Space.xs) {
                Image(systemName: "music.note.list")
                Text(queue.name).lineLimit(1)
                Spacer(minLength: 0)
                Text(progress).monospacedDigit()
            }
            .dsEyebrow(tracking: 0.9)
            .foregroundStyle(surface.secondary)
            .padding(.horizontal, DS.Space.xxs)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            ScrollViewReader { proxy in
                DSFittingScroll(maxHeight: 208) {
                    VStack(spacing: DS.Space.xxs) {
                        ForEach(Array(queue.numbers.enumerated()), id: \.offset) { index, number in
                            row(index: index, number: number).id(index)
                        }
                    }
                }
                .onAppear {
                    // The next hymn, or the open one at the end of the list.
                    if let target = queue.next ?? queue.current { proxy.scrollTo(target, anchor: .center) }
                }
            }
        }
    }

    private var progress: String {
        guard let current = queue.current else { return "\(queue.numbers.count)" }
        return "\(current + 1) of \(queue.numbers.count)"
    }

    private func row(index: Int, number: Int) -> some View {
        let name = title(number)
        let isNext = index == queue.next
        let isCurrent = index == queue.current
        return Button { onSelect(index) } label: {
            HStack(spacing: DS.Space.s) {
                Text(String(number))
                    .font(DS.Typeface.label).monospacedDigit()
                    .foregroundStyle(isNext ? surface.onTint : surface.brass)
                    .frame(minWidth: 40, alignment: .trailing)
                Text(name ?? String(localized: "Not in this hymnal"))
                    .font(DS.Typeface.label)
                    .foregroundStyle(isNext ? surface.onTint : name == nil ? surface.secondary : .primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isNext || isCurrent {
                    Text(isNext ? LocalizedStringKey("Next") : "Now")
                        .dsEyebrow(tracking: 0.9)
                        .foregroundStyle(isNext ? surface.onTint : surface.tint)
                }
            }
            .padding(.horizontal, DS.Space.s)
            .frame(maxWidth: .infinity, minHeight: DS.Size.hitTarget)
            .background(RoundedRectangle.ds(DS.Radius.tile).fill(fill(isNext: isNext, isCurrent: isCurrent)))
            .contentShape(RoundedRectangle.ds(DS.Radius.tile))
        }
        .buttonStyle(DSPressStyle())
        .disabled(name == nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Hymn \(number), \(name ?? String(localized: "not in this hymnal"))"))
        .accessibilityValue(isNext ? Text("Next") : isCurrent ? Text("Now showing") : Text(""))
        .accessibilityHint("Shows this hymn and follows the list from here.")
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
    }

    private func fill(isNext: Bool, isCurrent: Bool) -> Color {
        if isNext { return surface.tint }
        if isCurrent { return surface.tint.opacity(DS.Fill.tintSelected) }
        return Color.primary.opacity(DS.Fill.inset)
    }
}
