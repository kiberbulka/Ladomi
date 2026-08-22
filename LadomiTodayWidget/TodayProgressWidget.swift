import SwiftUI
import WidgetKit

struct TodayProgressEntry: TimelineEntry {
    let date: Date
    let snapshot: LadomiTodayWidgetSnapshot
}

struct TodayProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayProgressEntry {
        TodayProgressEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayProgressEntry) -> Void) {
        let snapshot = context.isPreview ? .preview : loadSnapshot()
        completion(TodayProgressEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayProgressEntry>) -> Void) {
        let entry = TodayProgressEntry(date: Date(), snapshot: loadSnapshot())
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private func loadSnapshot() -> LadomiTodayWidgetSnapshot {
        guard let data = LadomiWidgetShared.storage.data(forKey: LadomiWidgetShared.todaySnapshotKey),
              let snapshot = try? JSONDecoder().decode(LadomiTodayWidgetSnapshot.self, from: data),
              Calendar.current.isDateInToday(snapshot.date) else {
            return .empty
        }

        return snapshot
    }
}

struct TodayProgressWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: TodayProgressEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                MediumTodayWidget(snapshot: entry.snapshot)
            case .accessoryCircular:
                CircularTodayWidget(snapshot: entry.snapshot)
            case .accessoryRectangular:
                RectangularTodayWidget(snapshot: entry.snapshot)
            case .accessoryInline:
                InlineTodayWidget(snapshot: entry.snapshot)
            default:
                SmallTodayWidget(snapshot: entry.snapshot)
            }
        }
        .ladomiWidgetBackground()
    }
}

private struct SmallTodayWidget: View {
    let snapshot: LadomiTodayWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("widget.today", comment: "Widget today title"))
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            if snapshot.hasDayItems {
                Text("\(snapshot.completedCount)/\(snapshot.totalCount)")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.primary)

                ProgressView(value: snapshot.progress)
                    .tint(.blue)

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text(NSLocalizedString("widget.noDayItems", comment: "No dayItems in widget"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(NSLocalizedString("widget.openTracker", comment: "Open app widget hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var statusText: String {
        if snapshot.completedCount == snapshot.totalCount {
            return NSLocalizedString("widget.dayClosed", comment: "All dayItems completed")
        }

        let format = NSLocalizedString("widget.remainingFormat", comment: "Remaining dayItems count")
        return String(format: format, snapshot.totalCount - snapshot.completedCount)
    }
}

private struct MediumTodayWidget: View {
    let snapshot: LadomiTodayWidgetSnapshot

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("widget.today", comment: "Widget today title"))
                    .font(.headline)

                Text(snapshot.hasDayItems ? "\(snapshot.completedCount)/\(snapshot.totalCount)" : "0/0")
                    .font(.system(size: 32, weight: .bold))

                ProgressView(value: snapshot.progress)
                    .tint(.blue)

                Text(snapshot.completedCount == snapshot.totalCount && snapshot.hasDayItems
                     ? NSLocalizedString("widget.dayClosed", comment: "All dayItems completed")
                     : NSLocalizedString("widget.dayPlan", comment: "Day plan widget status"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                if snapshot.items.isEmpty {
                    Text(NSLocalizedString("widget.openAppToUpdate", comment: "Open app to update widget"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                } else {
                    ForEach(snapshot.items, id: \.self) { item in
                        HabitRow(item: item, isCompact: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
    }
}

private struct HabitRow: View {
    let item: LadomiWidgetItem
    var isCompact = false

    var body: some View {
        HStack(spacing: isCompact ? 6 : 7) {
            Text(item.isCompleted ? "✓" : item.emoji)
                .font(.caption.weight(.bold))
                .frame(width: isCompact ? 18 : 22, height: isCompact ? 18 : 22)
                .background(item.isCompleted ? Color.green.opacity(0.18) : Color.blue.opacity(0.12))
                .clipShape(Circle())

            if isCompact {
                Text(item.title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)

                if let timeText = item.timeText {
                    Spacer(minLength: 4)

                    Text(timeText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)

                    if let timeText = item.timeText {
                        Text(timeText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}

private struct CircularTodayWidget: View {
    let snapshot: LadomiTodayWidgetSnapshot

    var body: some View {
        Gauge(value: snapshot.progress) {
            Text(NSLocalizedString("widget.today", comment: "Widget today title"))
        } currentValueLabel: {
            Text(snapshot.hasDayItems ? "\(snapshot.completedCount)/\(snapshot.totalCount)" : "0")
                .font(.caption2.weight(.bold))
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }
}

private struct RectangularTodayWidget: View {
    let snapshot: LadomiTodayWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(NSLocalizedString("widget.today", comment: "Widget today title"))
                .font(.caption.weight(.semibold))

            Text(titleText)
                .font(.headline)

            Text(subtitleText)
                .font(.caption2)
        }
    }

    private var titleText: String {
        guard snapshot.hasDayItems else {
            return NSLocalizedString("widget.noDayItems", comment: "No dayItems in widget")
        }

        let format = NSLocalizedString("widget.progressFormat", comment: "Completed out of total widget progress")
        return String(format: format, snapshot.completedCount, snapshot.totalCount)
    }

    private var subtitleText: String {
        guard snapshot.hasDayItems else {
            return NSLocalizedString("widget.openApp", comment: "Open app widget hint")
        }

        if snapshot.completedCount == snapshot.totalCount {
            return NSLocalizedString("widget.dayClosed", comment: "All dayItems completed")
        }

        let format = NSLocalizedString("widget.remainingFormat", comment: "Remaining dayItems count")
        return String(format: format, snapshot.totalCount - snapshot.completedCount)
    }
}

private struct InlineTodayWidget: View {
    let snapshot: LadomiTodayWidgetSnapshot

    var body: some View {
        Text(inlineText)
    }

    private var inlineText: String {
        if snapshot.hasDayItems {
            let format = NSLocalizedString("widget.inlineProgressFormat", comment: "Inline widget progress")
            return String(format: format, snapshot.completedCount, snapshot.totalCount)
        }

        return NSLocalizedString("widget.inlineEmpty", comment: "Inline widget empty state")
    }
}

@main
struct TodayProgressWidget: Widget {
    let kind = "TodayProgressWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProgressProvider()) { entry in
            TodayProgressWidgetView(entry: entry)
        }
        .configurationDisplayName(NSLocalizedString("widget.displayName", comment: "Widget display name"))
        .description(NSLocalizedString("widget.description", comment: "Widget description"))
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

private extension View {
    @ViewBuilder
    func ladomiWidgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) {
                Color(.systemBackground)
            }
        } else {
            background(Color(.systemBackground))
        }
    }
}
