import SwiftUI
import WidgetKit

struct TodayProgressEntry: TimelineEntry {
    let date: Date
    let snapshot: RitmoTodayWidgetSnapshot
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

    private func loadSnapshot() -> RitmoTodayWidgetSnapshot {
        guard let data = RitmoWidgetShared.storage.data(forKey: RitmoWidgetShared.todaySnapshotKey),
              let snapshot = try? JSONDecoder().decode(RitmoTodayWidgetSnapshot.self, from: data),
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
        .ritmoWidgetBackground()
    }
}

private struct SmallTodayWidget: View {
    let snapshot: RitmoTodayWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Сегодня")
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            if snapshot.hasRitmos {
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
                Text("Нет привычек")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Открой трекер")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var statusText: String {
        snapshot.completedCount == snapshot.totalCount ? "День закрыт" : "Осталось \(snapshot.totalCount - snapshot.completedCount)"
    }
}

private struct MediumTodayWidget: View {
    let snapshot: RitmoTodayWidgetSnapshot

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Сегодня")
                    .font(.headline)

                Text(snapshot.hasRitmos ? "\(snapshot.completedCount)/\(snapshot.totalCount)" : "0/0")
                    .font(.system(size: 32, weight: .bold))

                ProgressView(value: snapshot.progress)
                    .tint(.blue)

                Text(snapshot.completedCount == snapshot.totalCount && snapshot.hasRitmos ? "День закрыт" : "План на день")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                if snapshot.items.isEmpty {
                    Text("Открой приложение, чтобы обновить виджет")
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
    let item: RitmoWidgetItem
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
    let snapshot: RitmoTodayWidgetSnapshot

    var body: some View {
        Gauge(value: snapshot.progress) {
            Text("Сегодня")
        } currentValueLabel: {
            Text(snapshot.hasRitmos ? "\(snapshot.completedCount)/\(snapshot.totalCount)" : "0")
                .font(.caption2.weight(.bold))
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }
}

private struct RectangularTodayWidget: View {
    let snapshot: RitmoTodayWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Сегодня")
                .font(.caption.weight(.semibold))

            Text(titleText)
                .font(.headline)

            Text(subtitleText)
                .font(.caption2)
        }
    }

    private var titleText: String {
        snapshot.hasRitmos ? "\(snapshot.completedCount) из \(snapshot.totalCount)" : "Нет привычек"
    }

    private var subtitleText: String {
        guard snapshot.hasRitmos else {
            return "Открой приложение"
        }

        return snapshot.completedCount == snapshot.totalCount ? "День закрыт" : "Осталось \(snapshot.totalCount - snapshot.completedCount)"
    }
}

private struct InlineTodayWidget: View {
    let snapshot: RitmoTodayWidgetSnapshot

    var body: some View {
        Text(snapshot.hasRitmos ? "Сегодня \(snapshot.completedCount)/\(snapshot.totalCount)" : "Сегодня нет привычек")
    }
}

@main
struct TodayProgressWidget: Widget {
    let kind = "TodayProgressWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProgressProvider()) { entry in
            TodayProgressWidgetView(entry: entry)
        }
        .configurationDisplayName("Сегодня")
        .description("Прогресс привычек на сегодня.")
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
    func ritmoWidgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) {
                Color(.systemBackground)
            }
        } else {
            background(Color(.systemBackground))
        }
    }
}
