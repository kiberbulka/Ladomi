import Foundation

#if canImport(WidgetKit)
import WidgetKit
#endif

final class LadomiWidgetSnapshotService {
    static let shared = LadomiWidgetSnapshotService()

    private let postponedDayItemsKey = "postponedDayItemsByDate"
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

    func saveTodaySnapshot(dayItems: [DayItem], completedRecords: [DayItemRecord], date: Date = Date()) {
        let activeDayItems = dayItems.filter { !$0.isArchived && !$0.isStopList }

        let todayHabits = sortedForWidget(
            activeDayItems.filter { $0.isHabit && isDayItemActiveForWidget($0, on: date, completedRecords: completedRecords) }
        )
        let todayEvents = sortedForWidget(
            activeDayItems.filter { !$0.isHabit && isDayItemActiveForWidget($0, on: date, completedRecords: completedRecords) }
        )
        let todayDayItems = todayHabits + todayEvents

        let completedDayItemIDs = Set(completedRecords
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .map(\.dayItemID))

        let items = todayDayItems
            .prefix(5)
            .map {
                LadomiWidgetItem(
                    emoji: $0.emoji,
                    title: $0.name,
                    timeText: $0.reminderTime.map { timeFormatter.string(from: $0) },
                    isCompleted: completedDayItemIDs.contains($0.id)
                )
            }

        let snapshot = LadomiTodayWidgetSnapshot(
            date: date,
            completedCount: completedDayItemIDs.intersection(Set(todayDayItems.map(\.id))).count,
            totalCount: todayDayItems.count,
            items: items
        )

        save(snapshot)
    }

    private func save(_ snapshot: LadomiTodayWidgetSnapshot) {
        do {
            let data = try JSONEncoder().encode(snapshot)
            LadomiWidgetShared.storage.set(data, forKey: LadomiWidgetShared.todaySnapshotKey)

            #if canImport(WidgetKit)
            if #available(iOS 14.0, *) {
                WidgetCenter.shared.reloadTimelines(ofKind: "TodayProgressWidget")
            }
            #endif
        } catch {
            print("Failed to save widget snapshot: \(error)")
        }
    }

    private func isDayItemActiveForWidget(_ dayItem: DayItem, on date: Date, completedRecords: [DayItemRecord]) -> Bool {
        if isDayItemPostponedFrom(dayItem, on: date) {
            return false
        }

        if isDayItemPostponedTo(dayItem, on: date) {
            return true
        }

        if dayItem.isHabit {
            return isHabit(dayItem, activeOn: date)
        }

        return isEvent(dayItem, activeOn: date, completedRecords: completedRecords)
    }

    private func isHabit(_ dayItem: DayItem, activeOn date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
        return dayItem.schedule.contains { $0.numberValue == adjustedWeekday }
    }

    private func isEvent(_ dayItem: DayItem, activeOn date: Date, completedRecords: [DayItemRecord]) -> Bool {
        let selectedDate = calendar.startOfDay(for: date)

        if let record = completedRecords.first(where: { $0.dayItemID == dayItem.id }) {
            return calendar.isDate(record.date, inSameDayAs: selectedDate)
        }

        return calendar.isDate(effectiveDateForIncompleteEvent(dayItem, relativeTo: selectedDate), inSameDayAs: selectedDate)
    }

    private func effectiveDateForIncompleteEvent(_ dayItem: DayItem, relativeTo date: Date) -> Date {
        let today = calendar.startOfDay(for: date)
        let eventDate = calendar.startOfDay(for: dayItem.eventDate ?? today)

        return eventDate < today ? today : eventDate
    }

    private func sortedForWidget(_ dayItems: [DayItem]) -> [DayItem] {
        dayItems.sorted { lhs, rhs in
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

    private func isDayItemPostponedFrom(_ dayItem: DayItem, on date: Date) -> Bool {
        loadPostponements()[postponementKey(for: dayItem.id, date: date)] != nil
    }

    private func isDayItemPostponedTo(_ dayItem: DayItem, on date: Date) -> Bool {
        let targetDateKey = dateKey(for: date)
        let dayItemPrefix = "\(dayItem.id.uuidString)_"
        return loadPostponements().contains { key, value in
            key.hasPrefix(dayItemPrefix) && value == targetDateKey
        }
    }

    private func loadPostponements() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: postponedDayItemsKey) as? [String: String] ?? [:]
    }

    private func postponementKey(for dayItemID: UUID, date: Date) -> String {
        "\(dayItemID.uuidString)_\(dateKey(for: date))"
    }

    private func dateKey(for date: Date) -> String {
        postponementDateFormatter.string(from: calendar.startOfDay(for: date))
    }
}
