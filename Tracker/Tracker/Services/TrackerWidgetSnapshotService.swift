//
//  TrackerWidgetSnapshotService.swift
//  Tracker
//
//  Created by Codex on 09.08.2026.
//

import Foundation

#if canImport(WidgetKit)
import WidgetKit
#endif

final class TrackerWidgetSnapshotService {
    static let shared = TrackerWidgetSnapshotService()

    private let postponedTrackersKey = "postponedTrackersByDate"
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

    func saveTodaySnapshot(trackers: [Tracker], completedRecords: [TrackerRecord], date: Date = Date()) {
        let activeTrackers = trackers.filter { !$0.isArchived }

        let todayHabits = sortedForWidget(
            activeTrackers.filter { $0.isHabit && isTrackerActiveForWidget($0, on: date, completedRecords: completedRecords) }
        )
        let todayEvents = sortedForWidget(
            activeTrackers.filter { !$0.isHabit && isTrackerActiveForWidget($0, on: date, completedRecords: completedRecords) }
        )
        let todayTrackers = todayHabits + todayEvents

        let completedTrackerIDs = Set(completedRecords
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .map(\.trackerID))

        let items = todayTrackers
            .prefix(5)
            .map {
                TrackerWidgetItem(
                    emoji: $0.emoji,
                    title: $0.name,
                    timeText: $0.reminderTime.map { timeFormatter.string(from: $0) },
                    isCompleted: completedTrackerIDs.contains($0.id)
                )
            }

        let snapshot = TrackerTodayWidgetSnapshot(
            date: date,
            completedCount: completedTrackerIDs.intersection(Set(todayTrackers.map(\.id))).count,
            totalCount: todayTrackers.count,
            items: items
        )

        save(snapshot)
    }

    private func save(_ snapshot: TrackerTodayWidgetSnapshot) {
        do {
            let data = try JSONEncoder().encode(snapshot)
            TrackerWidgetShared.storage.set(data, forKey: TrackerWidgetShared.todaySnapshotKey)

            #if canImport(WidgetKit)
            if #available(iOS 14.0, *) {
                WidgetCenter.shared.reloadTimelines(ofKind: "TodayProgressWidget")
            }
            #endif
        } catch {
            print("Failed to save widget snapshot: \(error)")
        }
    }

    private func isTrackerActiveForWidget(_ tracker: Tracker, on date: Date, completedRecords: [TrackerRecord]) -> Bool {
        if isTrackerPostponedFrom(tracker, on: date) {
            return false
        }

        if isTrackerPostponedTo(tracker, on: date) {
            return true
        }

        if tracker.isHabit {
            return isHabit(tracker, activeOn: date)
        }

        return isEvent(tracker, activeOn: date, completedRecords: completedRecords)
    }

    private func isHabit(_ tracker: Tracker, activeOn date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
        return tracker.schedule.contains { $0.numberValue == adjustedWeekday }
    }

    private func isEvent(_ tracker: Tracker, activeOn date: Date, completedRecords: [TrackerRecord]) -> Bool {
        let selectedDate = calendar.startOfDay(for: date)

        if let record = completedRecords.first(where: { $0.trackerID == tracker.id }) {
            return calendar.isDate(record.date, inSameDayAs: selectedDate)
        }

        return calendar.isDate(effectiveDateForIncompleteEvent(tracker, relativeTo: selectedDate), inSameDayAs: selectedDate)
    }

    private func effectiveDateForIncompleteEvent(_ tracker: Tracker, relativeTo date: Date) -> Date {
        let today = calendar.startOfDay(for: date)
        let eventDate = calendar.startOfDay(for: tracker.eventDate ?? today)

        return eventDate < today ? today : eventDate
    }

    private func sortedForWidget(_ trackers: [Tracker]) -> [Tracker] {
        trackers.sorted { lhs, rhs in
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

    private func isTrackerPostponedFrom(_ tracker: Tracker, on date: Date) -> Bool {
        loadPostponements()[postponementKey(for: tracker.id, date: date)] != nil
    }

    private func isTrackerPostponedTo(_ tracker: Tracker, on date: Date) -> Bool {
        let targetDateKey = dateKey(for: date)
        let trackerPrefix = "\(tracker.id.uuidString)_"
        return loadPostponements().contains { key, value in
            key.hasPrefix(trackerPrefix) && value == targetDateKey
        }
    }

    private func loadPostponements() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: postponedTrackersKey) as? [String: String] ?? [:]
    }

    private func postponementKey(for trackerID: UUID, date: Date) -> String {
        "\(trackerID.uuidString)_\(dateKey(for: date))"
    }

    private func dateKey(for date: Date) -> String {
        postponementDateFormatter.string(from: calendar.startOfDay(for: date))
    }
}
