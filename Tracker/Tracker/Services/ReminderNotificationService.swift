//
//  ReminderNotificationService.swift
//  Tracker
//
//  Created by Codex on 06.08.2026.
//

import Foundation
import UserNotifications

final class ReminderNotificationService {
    static let shared = ReminderNotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let identifierPrefix = "tracker-reminder"
    private let softReminderSuffix = "soft"
    private let softReminderHour = 20
    private let softReminderMinute = 0
    private let habitReminderPrefix = "habit"
    private let eventReminderPrefix = "event"
    private let habitPlanningWindowDays = 60
    private let maxHabitRemindersPerTracker = 8
    private let skippedReminderQueue = DispatchQueue(label: "tracker.reminders.skipped")
    private var skippedHabitReminderKeys: Set<String> = []

    private init() {}

    func scheduleReminder(for tracker: Tracker, completedRecords: [TrackerRecord] = []) {
        guard !tracker.isArchived, tracker.reminderTime != nil else {
            removeReminder(for: tracker.id)
            return
        }

        removeRegularReminders(for: tracker.id)
        syncSkippedReminders(for: tracker, completedRecords: completedRecords)

        notificationCenter.getNotificationSettings { [weak self] settings in
            guard let self = self else { return }

            switch settings.authorizationStatus {
            case .authorized, .provisional:
                self.addNotificationRequests(for: tracker, completedRecords: completedRecords)
            case .notDetermined:
                self.notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if let error = error {
                        print("Failed to request notification authorization: \(error)")
                    }

                    guard granted else { return }
                    self.addNotificationRequests(for: tracker, completedRecords: completedRecords)
                }
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }

    func removeReminder(for trackerID: UUID) {
        removeRegularReminders(for: trackerID)
        removeNotifications(matching: notificationIdentifierPrefix(for: trackerID))
    }

    func removeReminder(for trackerID: UUID, on date: Date) {
        skipReminder(for: trackerID, on: date)

        let identifiers = [
            habitReminderIdentifier(for: trackerID, date: date),
            notificationIdentifier(for: trackerID, suffix: "\(appWeekdayNumber(for: date))"),
            softReminderIdentifier(for: trackerID, date: date)
        ]

        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func scheduleSoftReminderIfNeeded(for tracker: Tracker, completedRecords: [TrackerRecord], date: Date = Date()) {
        removeSoftReminder(for: tracker.id, date: date)

        guard shouldScheduleSoftReminder(for: tracker, completedRecords: completedRecords, date: date),
              let triggerDate = softReminderDate(for: date) else {
            return
        }

        notificationCenter.getNotificationSettings { [weak self] settings in
            guard let self = self else { return }

            switch settings.authorizationStatus {
            case .authorized, .provisional:
                self.addSoftReminderRequest(for: tracker, triggerDate: triggerDate)
            case .notDetermined:
                self.notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if let error = error {
                        print("Failed to request notification authorization: \(error)")
                    }

                    guard granted else { return }
                    self.addSoftReminderRequest(for: tracker, triggerDate: triggerDate)
                }
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }

    func removeSoftReminder(for trackerID: UUID, date: Date = Date()) {
        let identifier = softReminderIdentifier(for: trackerID, date: date)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    private func addNotificationRequests(for tracker: Tracker, completedRecords: [TrackerRecord]) {
        guard let reminderTime = tracker.reminderTime else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("reminder.notification.title", comment: "Notification title")
        content.body = tracker.name
        content.sound = .default

        if tracker.isHabit {
            habitReminderDates(for: tracker, reminderTime: reminderTime, completedRecords: completedRecords).forEach { date in
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents(from: date), repeats: false)
                let request = UNNotificationRequest(
                    identifier: habitReminderIdentifier(for: tracker.id, date: date),
                    content: content,
                    trigger: trigger
                )
                notificationCenter.add(request) { error in
                    if let error = error {
                        print("Failed to schedule habit reminder: \(error)")
                    }
                }
            }
        } else if let date = eventReminderDate(for: tracker, reminderTime: reminderTime, completedRecords: completedRecords) {
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents(from: date), repeats: false)
            let request = UNNotificationRequest(
                identifier: eventReminderIdentifier(for: tracker.id, date: date),
                content: content,
                trigger: trigger
            )
            notificationCenter.add(request) { error in
                if let error = error {
                    print("Failed to schedule event reminder: \(error)")
                }
            }
        }
    }

    private func habitReminderDates(
        for tracker: Tracker,
        reminderTime: Date,
        completedRecords: [TrackerRecord]
    ) -> [Date] {
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.startOfDay(for: now)

        return (0..<habitPlanningWindowDays).compactMap { dayOffset -> Date? in
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate),
                  isHabit(tracker, activeOn: date),
                  !isTrackerCompleted(tracker.id, on: date, completedRecords: completedRecords),
                  !isReminderSkipped(for: tracker.id, on: date),
                  let reminderDate = reminderDate(from: reminderTime, on: date),
                  reminderDate > now else {
                return nil
            }

            return reminderDate
        }
        .prefix(maxHabitRemindersPerTracker)
        .map { $0 }
    }

    private func eventReminderDate(
        for tracker: Tracker,
        reminderTime: Date,
        completedRecords: [TrackerRecord]
    ) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let eventDate = calendar.startOfDay(for: tracker.eventDate ?? today)
        let effectiveDate = eventDate < today ? today : eventDate

        guard !completedRecords.contains(where: { $0.trackerID == tracker.id }),
              let reminderDate = reminderDate(from: reminderTime, on: effectiveDate),
              reminderDate > now else {
            return nil
        }

        return reminderDate
    }

    private func addSoftReminderRequest(for tracker: Tracker, triggerDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("softReminder.notification.title", comment: "Soft reminder notification title")
        content.body = tracker.name
        content.sound = .default

        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: softReminderIdentifier(for: tracker.id, date: triggerDate),
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to schedule soft reminder: \(error)")
            }
        }
    }

    private func shouldScheduleSoftReminder(for tracker: Tracker, completedRecords: [TrackerRecord], date: Date) -> Bool {
        guard tracker.isHabit,
              let reminderTime = tracker.reminderTime,
              isHabit(tracker, activeOn: date),
              !isTrackerCompleted(tracker.id, on: date, completedRecords: completedRecords),
              let regularReminderDate = reminderDate(from: reminderTime, on: date),
              let softReminderDate = softReminderDate(for: date) else {
            return false
        }

        return date < softReminderDate && regularReminderDate < softReminderDate
    }

    private func softReminderDate(for date: Date) -> Date? {
        Calendar.current.date(
            bySettingHour: softReminderHour,
            minute: softReminderMinute,
            second: 0,
            of: date
        )
    }

    private func reminderDate(from reminderTime: Date, on date: Date) -> Date? {
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        return Calendar.current.date(
            bySettingHour: timeComponents.hour ?? 0,
            minute: timeComponents.minute ?? 0,
            second: 0,
            of: date
        )
    }

    private func isTrackerCompleted(_ trackerID: UUID, on date: Date, completedRecords: [TrackerRecord]) -> Bool {
        completedRecords.contains {
            $0.trackerID == trackerID && Calendar.current.isDate($0.date, inSameDayAs: date)
        }
    }

    private func isHabit(_ tracker: Tracker, activeOn date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
        return tracker.schedule.contains { $0.numberValue == adjustedWeekday }
    }

    private func dateComponents(from date: Date) -> DateComponents {
        var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        components.calendar = Calendar.current
        components.timeZone = .current
        return components
    }

    private func notificationIdentifiers(for trackerID: UUID) -> [String] {
        let weekdayIdentifiers = (1...7).map { notificationIdentifier(for: trackerID, suffix: "\($0)") }
        let rollingIdentifiers = plannedDateOffsets().flatMap { date -> [String] in
            [
                habitReminderIdentifier(for: trackerID, date: date),
                eventReminderIdentifier(for: trackerID, date: date)
            ]
        }
        return weekdayIdentifiers + [notificationIdentifier(for: trackerID, suffix: "event")] + rollingIdentifiers
    }

    private func removeRegularReminders(for trackerID: UUID) {
        let identifiers = notificationIdentifiers(for: trackerID)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func plannedDateOffsets() -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<habitPlanningWindowDays).compactMap {
            calendar.date(byAdding: .day, value: $0, to: today)
        }
    }

    private func habitReminderIdentifier(for trackerID: UUID, date: Date) -> String {
        notificationIdentifier(for: trackerID, suffix: "\(habitReminderPrefix)-\(dateString(from: date))")
    }

    private func eventReminderIdentifier(for trackerID: UUID, date: Date) -> String {
        notificationIdentifier(for: trackerID, suffix: "\(eventReminderPrefix)-\(dateString(from: date))")
    }

    private func softReminderIdentifier(for trackerID: UUID, date: Date) -> String {
        notificationIdentifier(for: trackerID, suffix: "\(softReminderSuffix)-\(dateString(from: date))")
    }

    private func dateString(from date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    private func appWeekdayNumber(for date: Date) -> Int {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 ? 7 : weekday - 1
    }

    private func syncSkippedReminders(for tracker: Tracker, completedRecords: [TrackerRecord]) {
        guard tracker.isHabit else {
            return
        }

        let calendar = Calendar.current
        let completedDateStrings = Set(completedRecords
            .filter { $0.trackerID == tracker.id }
            .map { dateString(from: calendar.startOfDay(for: $0.date)) })

        skippedReminderQueue.sync {
            plannedDateOffsets().forEach { date in
                let key = reminderKey(for: tracker.id, date: date)
                if completedDateStrings.contains(dateString(from: date)) {
                    skippedHabitReminderKeys.insert(key)
                } else {
                    skippedHabitReminderKeys.remove(key)
                }
            }
        }
    }

    private func skipReminder(for trackerID: UUID, on date: Date) {
        skippedReminderQueue.sync {
            skippedHabitReminderKeys.insert(reminderKey(for: trackerID, date: date))
        }
    }

    private func isReminderSkipped(for trackerID: UUID, on date: Date) -> Bool {
        skippedReminderQueue.sync {
            skippedHabitReminderKeys.contains(reminderKey(for: trackerID, date: date))
        }
    }

    private func reminderKey(for trackerID: UUID, date: Date) -> String {
        "\(trackerID.uuidString)-\(dateString(from: date))"
    }

    private func notificationIdentifier(for trackerID: UUID, suffix: String) -> String {
        "\(identifierPrefix)-\(trackerID.uuidString)-\(suffix)"
    }

    private func notificationIdentifierPrefix(for trackerID: UUID) -> String {
        "\(identifierPrefix)-\(trackerID.uuidString)"
    }

    private func removeNotifications(matching prefix: String) {
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            let identifiers = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix(prefix) }
            self?.notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        }

        notificationCenter.getDeliveredNotifications { [weak self] notifications in
            let identifiers = notifications
                .map { $0.request.identifier }
                .filter { $0.hasPrefix(prefix) }
            self?.notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
        }
    }
}
