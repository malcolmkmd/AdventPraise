//
//  AdventPraiseWidgets.swift
//  AdventPraiseWidgets
//
//  Church mode's Live Activity (Lock Screen + Dynamic Island) and a small
//  Home Screen widget that opens the hymnal.
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct AdventPraiseWidgets: WidgetBundle {
    var body: some Widget {
        ChurchLiveActivityWidget()
        OpenHymnalWidget()
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

// MARK: - Home Screen

struct OpenHymnalEntry: TimelineEntry { let date: Date }

struct OpenHymnalProvider: TimelineProvider {
    func placeholder(in context: Context) -> OpenHymnalEntry { .init(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (OpenHymnalEntry) -> Void) { completion(.init(date: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<OpenHymnalEntry>) -> Void) {
        completion(Timeline(entries: [.init(date: .now)], policy: .never))
    }
}

struct OpenHymnalWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "OpenHymnal", provider: OpenHymnalProvider()) { _ in
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "music.note.list").font(.title2).foregroundStyle(brass)
                Spacer(minLength: 0)
                Text("Advent Praise").font(.system(.headline, design: .serif))
                Text("Open the hymnal").font(.caption).foregroundStyle(.white.opacity(0.75))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .containerBackground(evergreen, for: .widget)
        }
        .configurationDisplayName("Advent Praise")
        .description("Opens the hymnal.")
        .supportedFamilies([.systemSmall])
    }
}
