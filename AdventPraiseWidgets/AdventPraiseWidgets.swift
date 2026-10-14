//
//  AdventPraiseWidgets.swift
//  AdventPraiseWidgets
//
//  Church mode's Live Activity (Lock Screen + Dynamic Island) and the
//  church remote widget (Home Screen and Lock Screen).
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct AdventPraiseWidgets: WidgetBundle {
    var body: some Widget {
        ChurchLiveActivityWidget()
        ChurchRemoteWidget()
        HymnOfTheDayWidget()
    }
}

private let evergreen = Color(red: 0.07, green: 0.20, blue: 0.16)
private let brass = Color(red: 0.84, green: 0.68, blue: 0.38)

// MARK: - Live Activity

struct ChurchLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ChurchActivityAttributes.self) { context in
            LockScreenView(state: context.state, hymnal: context.attributes.hymnal)
                .activityBackgroundTint(evergreen)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("\(state.hymnNumber)")
                        .font(.system(.title, design: .serif).weight(.semibold))
                        .foregroundStyle(brass)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if state.isOnTV {
                        Image(systemName: "tv").foregroundStyle(brass).padding(.trailing, 4)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(state.title).font(.system(.headline, design: .serif)).lineLimit(1)
                        Text(state.position).font(.caption).foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    RemoteButtons(state: state)
                }
            } compactLeading: {
                Text("\(state.hymnNumber)")
                    .font(.system(.body, design: .serif).weight(.semibold))
                    .foregroundStyle(brass)
            } compactTrailing: {
                Text("\(state.step)/\(state.stepCount)").font(.caption.monospacedDigit())
            } minimal: {
                Text("\(state.hymnNumber)").font(.caption2.weight(.semibold)).foregroundStyle(brass)
            }
        }
    }
}

private struct LockScreenView: View {
    let state: ChurchActivityAttributes.ContentState
    let hymnal: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(state.hymnNumber)")
                    .font(.system(.title, design: .serif).weight(.semibold))
                    .foregroundStyle(brass)
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.title).font(.system(.headline, design: .serif)).lineLimit(1)
                    Text(state.isOnTV ? "\(state.position) · On TV" : state.position)
                        .font(.caption).foregroundStyle(.white.opacity(0.75))
                }
                Spacer(minLength: 0)
            }
            RemoteButtons(state: state)
        }
        .foregroundStyle(.white)
        .padding(14)
    }
}

private struct RemoteButtons: View {
    let state: ChurchActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 10) {
            Button(intent: ChurchPreviousVerseIntent()) {
                Label("Previous", systemImage: "chevron.left").frame(maxWidth: .infinity)
            }
            .disabled(!state.canGoBack)
            Button(intent: ChurchNextVerseIntent()) {
                Label("Next", systemImage: "chevron.right").frame(maxWidth: .infinity)
            }
            .tint(brass)
            Button(intent: ChurchEndIntent()) {
                Label("End", systemImage: "xmark")
            }
            .tint(.white.opacity(0.35))
        }
        .buttonStyle(.borderedProminent)
        .labelStyle(.titleAndIcon)
        .font(.subheadline.weight(.semibold))
    }
}

// MARK: - Church remote widget

struct ChurchRemoteEntry: TimelineEntry {
    let date: Date
    let state: ChurchWidgetState
}

struct ChurchRemoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> ChurchRemoteEntry { .init(date: .now, state: .placeholder) }
    func getSnapshot(in context: Context, completion: @escaping (ChurchRemoteEntry) -> Void) {
        completion(.init(date: .now, state: context.isPreview ? .placeholder : .load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ChurchRemoteEntry>) -> Void) {
        // The app reloads this on every change; nothing to schedule.
        completion(Timeline(entries: [.init(date: .now, state: .load())], policy: .never))
    }
}

struct ChurchRemoteWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: ChurchWidgetState.widgetKind, provider: ChurchRemoteProvider()) { entry in
            ChurchRemoteView(state: entry.state)
        }
        .configurationDisplayName("Church Remote")
        .description("The hymn you're on, with verse buttons while presenting.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

private struct ChurchRemoteView: View {
    let state: ChurchWidgetState
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Text(state.isPresenting ? "\(state.hymnNumber) · \(state.position)" : "Hymn \(state.hymnNumber)")
            case .accessoryCircular:
                VStack(spacing: 0) {
                    Text("\(state.hymnNumber)").font(.system(.title3, design: .serif).weight(.semibold))
                    if state.isPresenting { Image(systemName: state.isOnTV ? "tv" : "music.note") .font(.caption2) }
                }
                .containerBackground(.fill.tertiary, for: .widget)
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(state.hymnNumber) · \(state.title)").font(.headline).lineLimit(1)
                    Text(state.isPresenting ? state.position : state.hymnal).font(.caption).lineLimit(1)
                    if state.isOnTV { Label("On TV", systemImage: "tv").font(.caption2) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .containerBackground(.fill.tertiary, for: .widget)
            default:
                home.containerBackground(evergreen, for: .widget)
            }
        }
        .widgetURL(state.isPro ? (state.isPresenting ? WidgetLink.present.url : nil) : nil)
    }

    private var isLarge: Bool { family == .systemLarge }
    private var isSmall: Bool { family == .systemSmall }

    private var home: some View {
        VStack(alignment: .leading, spacing: isSmall ? 6 : 10) {
            header
            Spacer(minLength: 0)
            if state.isPresenting {
                verseRow
                if !isSmall { presentingExtras }
            } else {
                action(.present, "Present", "play.rectangle.fill", prominent: true)
                if !isSmall { idleExtras }
            }
            if isLarge { libraryRow }
        }
        .foregroundStyle(.white)
        .buttonStyle(.borderedProminent)
        .font(.footnote.weight(.semibold))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(state.hymnNumber)")
                    .font(.system(isSmall ? .title2 : .title, design: .serif).weight(.semibold))
                    .foregroundStyle(brass)
                if state.isOnTV {
                    Label("On TV", systemImage: "tv").font(.caption2.weight(.semibold)).foregroundStyle(brass)
                }
            }
            Text(state.title).font(.system(isSmall ? .subheadline : .headline, design: .serif))
                .lineLimit(isLarge ? 3 : 2)
            Text(state.isPresenting ? state.position : state.hymnal)
                .font(.caption).foregroundStyle(.white.opacity(0.75)).lineLimit(1)
        }
    }

    /// Previous / Next verse: intents while Pro, otherwise the paywall.
    private var verseRow: some View {
        HStack(spacing: 8) {
            remote(ChurchPreviousVerseIntent(), "Previous", "chevron.left", enabled: state.canGoBack)
            remote(ChurchNextVerseIntent(), "Next", "chevron.right", prominent: true)
        }
    }

    private var presentingExtras: some View {
        HStack(spacing: 8) {
            remote(ChurchBlankIntent(), state.isBlanked ? "Show" : "Blank",
                   state.isBlanked ? "eye" : "eye.slash")
            remote(ChurchNextHymnIntent(), "Next hymn", "forward.end.fill", enabled: state.hasNextHymn)
        }
    }

    private var idleExtras: some View {
        HStack(spacing: 8) {
            action(.numberPad, "Number", "number")
            action(.favourites, "Favourites", "heart")
        }
    }

    private var libraryRow: some View {
        HStack(spacing: 8) {
            if state.isPresenting { action(.numberPad, "Number", "number") }
            action(.hymnOfTheDay, "Hymn of the day", "sparkles")
            if state.isPresenting { action(.favourites, "Favourites", "heart") }
        }
    }

    @ViewBuilder
    private func remote<I: AppIntent>(_ intent: I, _ title: LocalizedStringKey, _ image: String,
                                      enabled: Bool = true, prominent: Bool = false) -> some View {
        if state.isPro {
            Button(intent: intent) { label(title, image) }
                .tint(prominent ? brass : .white.opacity(0.22))
                .disabled(!enabled)
        } else {
            Link(destination: WidgetLink.paywall.url) { pill(title, image, prominent: prominent) }
        }
    }

    /// Opens the app (Present is Pro: the paywall otherwise).
    private func action(_ link: WidgetLink, _ title: LocalizedStringKey, _ image: String,
                        prominent: Bool = false) -> some View {
        let target = (link == .present && !state.isPro) ? WidgetLink.paywall : link
        return Link(destination: target.url) { pill(title, image, prominent: prominent) }
    }

    private func label(_ title: LocalizedStringKey, _ image: String) -> some View {
        Label(title, systemImage: image)
            .labelStyle(.titleAndIcon)
            .lineLimit(1).minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
    }

    private func pill(_ title: LocalizedStringKey, _ image: String, prominent: Bool) -> some View {
        label(title, image)
            .padding(.vertical, 7)
            .background(Capsule().fill(prominent ? brass : .white.opacity(0.22)))
            .foregroundStyle(prominent ? evergreen : .white)
    }
}

// MARK: - Hymn of the Day (free)

struct HymnOfTheDayEntry: TimelineEntry {
    let date: Date
    let hymn: HymnOfTheDay
}

struct HymnOfTheDayProvider: TimelineProvider {
    func placeholder(in context: Context) -> HymnOfTheDayEntry { .init(date: .now, hymn: .placeholder) }
    func getSnapshot(in context: Context, completion: @escaping (HymnOfTheDayEntry) -> Void) {
        completion(.init(date: .now, hymn: Self.days().first ?? .placeholder))
    }
    /// One entry per day the app has written, each from its midnight; then
    /// reload at the midnight after the last.
    func getTimeline(in context: Context, completion: @escaping (Timeline<HymnOfTheDayEntry>) -> Void) {
        let days = Self.days()
        guard !days.isEmpty else {
            completion(Timeline(entries: [.init(date: .now, hymn: .placeholder)], policy: .after(Self.nextMidnight())))
            return
        }
        let entries = days.enumerated().map { offset, hymn in
            HymnOfTheDayEntry(date: offset == 0 ? .now : hymn.date, hymn: hymn)
        }
        let end = Calendar.current.date(byAdding: .day, value: 1, to: days.last!.date) ?? Self.nextMidnight()
        completion(Timeline(entries: entries, policy: .after(end)))
    }

    /// Today's onwards.
    private static func days() -> [HymnOfTheDay] {
        let today = Calendar.current.startOfDay(for: .now)
        let all = HymnOfTheDay.loadAll()
        let upcoming = all.filter { $0.date >= today }
        return upcoming.isEmpty ? Array(all.suffix(1)) : upcoming
    }

    private static func nextMidnight() -> Date {
        Calendar.current.nextDate(after: .now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime)
            ?? .now.addingTimeInterval(86_400)
    }
}

struct HymnOfTheDayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: HymnOfTheDay.widgetKind, provider: HymnOfTheDayProvider()) { entry in
            HymnOfTheDayView(hymn: entry.hymn)
        }
        .configurationDisplayName("Hymn of the Day")
        .description("A new hymn every day, with its first verse.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

private struct HymnOfTheDayView: View {
    let hymn: HymnOfTheDay
    @Environment(\.widgetFamily) private var family

    private var lineCount: Int {
        switch family {
        case .systemSmall: 2
        case .systemMedium: 3
        case .systemLarge: 8
        default: 1
        }
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Text("Hymn \(hymn.number) · \(hymn.title)")
            case .accessoryCircular:
                VStack(spacing: 0) {
                    Image(systemName: "sparkles").font(.caption2)
                    Text("\(hymn.number)").font(.system(.title3, design: .serif).weight(.semibold))
                }
                .containerBackground(.fill.tertiary, for: .widget)
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(hymn.number) · \(hymn.title)").font(.headline).lineLimit(1)
                    Text(hymn.lines.first ?? "").font(.caption).lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .containerBackground(.fill.tertiary, for: .widget)
            default:
                home.containerBackground(evergreen, for: .widget)
            }
        }
        .widgetURL(hymn.url)
    }

    private var home: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 4 : 8) {
            Text("HYMN OF THE DAY").font(.caption2.weight(.bold)).foregroundStyle(brass)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(hymn.number)")
                    .font(.system(family == .systemSmall ? .title2 : .title, design: .serif).weight(.semibold))
                    .foregroundStyle(brass)
                Text(hymn.title).font(.system(.headline, design: .serif)).lineLimit(2)
            }
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(hymn.lines.prefix(lineCount).enumerated()), id: \.offset) { _, line in
                    Text(line).font(.system(family == .systemLarge ? .body : .caption, design: .serif))
                        .lineLimit(family == .systemLarge ? 2 : 1)
                }
            }
            .foregroundStyle(.white.opacity(0.85))
            Spacer(minLength: 0)
            if family == .systemLarge {
                Text(hymn.hymnal).font(.caption).foregroundStyle(.white.opacity(0.6))
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
