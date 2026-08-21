import Foundation

#if canImport(WidgetKit)
import WidgetKit
#endif

final class RitmoWidgetSnapshotService {
    static let shared = RitmoWidgetSnapshotService()

    private let postponedRitmosKey = "postponedRitmosByDate"
    private let calendar = Calendar.current

    private lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private lazy var postponementDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private init() {}

    func saveTodaySnapshot(ritmos: [Ritmo], completedRecords: [RitmoRecord], date: Date = Date()) {
        let activeRitmos = ritmos.filter { !$0.isArchived && !$0.isStopList }

        let todayHabits = sortedForWidget(
            activeRitmos.filter { $0.isHabit && isRitmoActiveForWidget($0, on: date, completedRecords: completedRecords) }
        )
        let todayEvents = sortedForWidget(
            activeRitmos.filter { !$0.isHabit && isRitmoActiveForWidget($0, on: date, completedRecords: completedRecords) }
        )
        let todayRitmos = todayHabits + todayEvents

        let completedRitmoIDs = Set(completedRecords
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .map(\.ritmoID))

        let items = todayRitmos
            .prefix(5)
            .map {
                RitmoWidgetItem(
                    emoji: $0.emoji,
                    title: $0.name,
                    timeText: $0.reminderTime.map { timeFormatter.string(from: $0) },
                    isCompleted: completedRitmoIDs.contains($0.id)
                )
            }

        let snapshot = RitmoTodayWidgetSnapshot(
            date: date,
            completedCount: completedRitmoIDs.intersection(Set(todayRitmos.map(\.id))).count,
            totalCount: todayRitmos.count,
            items: items
        )

        save(snapshot)
    }

    private func save(_ snapshot: RitmoTodayWidgetSnapshot) {
        do {
            let data = try JSONEncoder().encode(snapshot)
            RitmoWidgetShared.storage.set(data, forKey: RitmoWidgetShared.todaySnapshotKey)

            #if canImport(WidgetKit)
            if #available(iOS 14.0, *) {
                WidgetCenter.shared.reloadTimelines(ofKind: "TodayProgressWidget")
            }
            #endif
        } catch {
            print("Failed to save widget snapshot: \(error)")
        }
    }

    private func isRitmoActiveForWidget(_ ritmo: Ritmo, on date: Date, completedRecords: [RitmoRecord]) -> Bool {
        if isRitmoPostponedFrom(ritmo, on: date) {
            return false
        }

        if isRitmoPostponedTo(ritmo, on: date) {
            return true
        }

        if ritmo.isHabit {
            return isHabit(ritmo, activeOn: date)
        }

        return isEvent(ritmo, activeOn: date, completedRecords: completedRecords)
    }

    private func isHabit(_ ritmo: Ritmo, activeOn date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
        return ritmo.schedule.contains { $0.numberValue == adjustedWeekday }
    }

    private func isEvent(_ ritmo: Ritmo, activeOn date: Date, completedRecords: [RitmoRecord]) -> Bool {
        let selectedDate = calendar.startOfDay(for: date)

        if let record = completedRecords.first(where: { $0.ritmoID == ritmo.id }) {
            return calendar.isDate(record.date, inSameDayAs: selectedDate)
        }

        return calendar.isDate(effectiveDateForIncompleteEvent(ritmo, relativeTo: selectedDate), inSameDayAs: selectedDate)
    }

    private func effectiveDateForIncompleteEvent(_ ritmo: Ritmo, relativeTo date: Date) -> Date {
        let today = calendar.startOfDay(for: date)
        let eventDate = calendar.startOfDay(for: ritmo.eventDate ?? today)

        return eventDate < today ? today : eventDate
    }

    private func sortedForWidget(_ ritmos: [Ritmo]) -> [Ritmo] {
        ritmos.sorted { lhs, rhs in
            switch (lhs.reminderTime, rhs.reminderTime) {
            case let (lhsTime?, rhsTime?):
                return timeMinutes(from: lhsTime) < timeMinutes(from: rhsTime)
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
    }

    private func timeMinutes(from date: Date) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func isRitmoPostponedFrom(_ ritmo: Ritmo, on date: Date) -> Bool {
        loadPostponements()[postponementKey(for: ritmo.id, date: date)] != nil
    }

    private func isRitmoPostponedTo(_ ritmo: Ritmo, on date: Date) -> Bool {
        let targetDateKey = dateKey(for: date)
        let ritmoPrefix = "\(ritmo.id.uuidString)_"
        return loadPostponements().contains { key, value in
            key.hasPrefix(ritmoPrefix) && value == targetDateKey
        }
    }

    private func loadPostponements() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: postponedRitmosKey) as? [String: String] ?? [:]
    }

    private func postponementKey(for ritmoID: UUID, date: Date) -> String {
        "\(ritmoID.uuidString)_\(dateKey(for: date))"
    }

    private func dateKey(for date: Date) -> String {
        postponementDateFormatter.string(from: calendar.startOfDay(for: date))
    }
}
