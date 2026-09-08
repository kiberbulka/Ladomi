import Foundation

struct DayItemRecord {
    let dayItemID: UUID
    let date: Date
}

enum DayItemAttentionKind {
    case habit
    case event
}

struct DayItemInactivityStatus {
    let kind: DayItemAttentionKind
    let missedDays: Int
    let firstMissedDate: Date
}

enum DayItemInactivityCalculator {
    static func status(
        for dayItem: DayItem,
        records: [DayItemRecord],
        postponements: [String: String],
        through referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> DayItemInactivityStatus? {
        guard !dayItem.isArchived, !dayItem.isStopList else {
            return nil
        }

        let today = calendar.startOfDay(for: referenceDate)
        let completedDates = Set(
            records
                .filter { $0.dayItemID == dayItem.id }
                .map { calendar.startOfDay(for: $0.date) }
        )

        if dayItem.isHabit {
            if isHabitExpected(dayItem, on: today, postponements: postponements, calendar: calendar),
               completedDates.contains(today) {
                return nil
            }

            let createdDate = calendar.startOfDay(for: dayItem.createdDate)
            guard var date = calendar.date(byAdding: .day, value: -1, to: today) else {
                return nil
            }

            var missedDays = 0
            var firstMissedDate: Date?

            while date >= createdDate {
                if isHabitExpected(dayItem, on: date, postponements: postponements, calendar: calendar) {
                    if completedDates.contains(date) {
                        break
                    }
                    missedDays += 1
                    firstMissedDate = date
                }

                guard let previousDate = calendar.date(byAdding: .day, value: -1, to: date) else {
                    break
                }
                date = previousDate
            }

            guard missedDays > 0, let firstMissedDate else {
                return nil
            }

            return DayItemInactivityStatus(
                kind: .habit,
                missedDays: missedDays,
                firstMissedDate: firstMissedDate
            )
        }

        guard completedDates.isEmpty else {
            return nil
        }

        let eventDate = effectiveEventDate(
            for: dayItem,
            postponements: postponements,
            calendar: calendar
        )
        let overdueDays = calendar.dateComponents([.day], from: eventDate, to: today).day ?? 0

        guard overdueDays > 0 else {
            return nil
        }

        return DayItemInactivityStatus(
            kind: .event,
            missedDays: overdueDays,
            firstMissedDate: eventDate
        )
    }

    static func isHabitExpected(
        _ habit: DayItem,
        on date: Date,
        postponements: [String: String],
        calendar: Calendar = .current
    ) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
        let isScheduled = habit.schedule.contains { $0.numberValue == adjustedWeekday }
        let dateKey = storageDateKey(for: date, calendar: calendar)
        let itemPrefix = "\(habit.id.uuidString)_"
        let isPostponedFromDate = postponements["\(itemPrefix)\(dateKey)"] != nil
        let isPostponedToDate = postponements.contains { key, value in
            key.hasPrefix(itemPrefix) && value == dateKey
        }

        return (isScheduled || isPostponedToDate) && !isPostponedFromDate
    }

    static func effectiveEventDate(
        for event: DayItem,
        postponements: [String: String],
        calendar: Calendar = .current
    ) -> Date {
        let originalDate = calendar.startOfDay(for: event.eventDate ?? event.createdDate)
        let itemPrefix = "\(event.id.uuidString)_"
        let postponedDates = postponements.compactMap { key, value -> Date? in
            guard key.hasPrefix(itemPrefix) else {
                return nil
            }
            return date(from: value, calendar: calendar)
        }

        return postponedDates.max() ?? originalDate
    }

    static func storageDateKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private static func date(from storageDateKey: String, calendar: Calendar) -> Date? {
        let parts = storageDateKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else {
            return nil
        }

        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}
