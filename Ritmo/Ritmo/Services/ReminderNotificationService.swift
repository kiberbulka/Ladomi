//
//  ReminderNotificationService.swift
//  Ritmo
//
//  Created by Codex on 06.08.2026.
//

import Foundation
import UserNotifications

final class ReminderNotificationService {
    static let shared = ReminderNotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let identifierPrefix = "ritmo-reminder"
    private let softReminderSuffix = "soft"
    private let softReminderHour = 20
    private let softReminderMinute = 0
    private let habitReminderPrefix = "habit"
    private let eventReminderPrefix = "event"
    private let habitPlanningWindowDays = 60
    private let maxHabitRemindersPerRitmo = 8
    private let skippedReminderQueue = DispatchQueue(label: "ritmo.reminders.skipped")
    private var skippedHabitReminderKeys: Set<String> = []

    private init() {}

    func scheduleReminder(for ritmo: Ritmo, completedRecords: [RitmoRecord] = []) {
        guard !ritmo.isArchived, ritmo.reminderTime != nil else {
            removeReminder(for: ritmo.id)
            return
        }

        removeRegularReminders(for: ritmo.id)
        syncSkippedReminders(for: ritmo, completedRecords: completedRecords)

        notificationCenter.getNotificationSettings { [weak self] settings in
            guard let self = self else { return }

            switch settings.authorizationStatus {
            case .authorized, .provisional:
                self.addNotificationRequests(for: ritmo, completedRecords: completedRecords)
            case .notDetermined:
                self.notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if let error = error {
                        print("Failed to request notification authorization: \(error)")
                    }

                    guard granted else { return }
                    self.addNotificationRequests(for: ritmo, completedRecords: completedRecords)
                }
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }

    func removeReminder(for ritmoID: UUID) {
        removeRegularReminders(for: ritmoID)
        removeNotifications(matching: notificationIdentifierPrefix(for: ritmoID))
    }

    func removeReminder(for ritmoID: UUID, on date: Date) {
        skipReminder(for: ritmoID, on: date)

        let identifiers = [
            habitReminderIdentifier(for: ritmoID, date: date),
            notificationIdentifier(for: ritmoID, suffix: "\(appWeekdayNumber(for: date))"),
            softReminderIdentifier(for: ritmoID, date: date)
        ]

        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func scheduleSoftReminderIfNeeded(for ritmo: Ritmo, completedRecords: [RitmoRecord], date: Date = Date()) {
        removeSoftReminder(for: ritmo.id, date: date)

        guard shouldScheduleSoftReminder(for: ritmo, completedRecords: completedRecords, date: date),
              let triggerDate = softReminderDate(for: date) else {
            return
        }

        notificationCenter.getNotificationSettings { [weak self] settings in
            guard let self = self else { return }

            switch settings.authorizationStatus {
            case .authorized, .provisional:
                self.addSoftReminderRequest(for: ritmo, triggerDate: triggerDate)
            case .notDetermined:
                self.notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if let error = error {
                        print("Failed to request notification authorization: \(error)")
                    }

                    guard granted else { return }
                    self.addSoftReminderRequest(for: ritmo, triggerDate: triggerDate)
                }
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }

    func removeSoftReminder(for ritmoID: UUID, date: Date = Date()) {
        let identifier = softReminderIdentifier(for: ritmoID, date: date)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    private func addNotificationRequests(for ritmo: Ritmo, completedRecords: [RitmoRecord]) {
        guard let reminderTime = ritmo.reminderTime else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("reminder.notification.title", comment: "Notification title")
        content.body = ritmo.name
        content.sound = .default

        if ritmo.isHabit {
            habitReminderDates(for: ritmo, reminderTime: reminderTime, completedRecords: completedRecords).forEach { date in
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents(from: date), repeats: false)
                let request = UNNotificationRequest(
                    identifier: habitReminderIdentifier(for: ritmo.id, date: date),
                    content: content,
                    trigger: trigger
                )
                notificationCenter.add(request) { error in
                    if let error = error {
                        print("Failed to schedule habit reminder: \(error)")
                    }
                }
            }
        } else if let date = eventReminderDate(for: ritmo, reminderTime: reminderTime, completedRecords: completedRecords) {
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents(from: date), repeats: false)
            let request = UNNotificationRequest(
                identifier: eventReminderIdentifier(for: ritmo.id, date: date),
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
        for ritmo: Ritmo,
        reminderTime: Date,
        completedRecords: [RitmoRecord]
    ) -> [Date] {
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.startOfDay(for: now)

        return (0..<habitPlanningWindowDays).compactMap { dayOffset -> Date? in
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate),
                  isHabit(ritmo, activeOn: date),
                  !isRitmoCompleted(ritmo.id, on: date, completedRecords: completedRecords),
                  !isReminderSkipped(for: ritmo.id, on: date),
                  let reminderDate = reminderDate(from: reminderTime, on: date),
                  reminderDate > now else {
                return nil
            }

            return reminderDate
        }
        .prefix(maxHabitRemindersPerRitmo)
        .map { $0 }
    }

    private func eventReminderDate(
        for ritmo: Ritmo,
        reminderTime: Date,
        completedRecords: [RitmoRecord]
    ) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let eventDate = calendar.startOfDay(for: ritmo.eventDate ?? today)
        let effectiveDate = eventDate < today ? today : eventDate

        guard !completedRecords.contains(where: { $0.ritmoID == ritmo.id }),
              let reminderDate = reminderDate(from: reminderTime, on: effectiveDate),
              reminderDate > now else {
            return nil
        }

        return reminderDate
    }

    private func addSoftReminderRequest(for ritmo: Ritmo, triggerDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("softReminder.notification.title", comment: "Soft reminder notification title")
        content.body = ritmo.name
        content.sound = .default

        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: softReminderIdentifier(for: ritmo.id, date: triggerDate),
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to schedule soft reminder: \(error)")
            }
        }
    }

    private func shouldScheduleSoftReminder(for ritmo: Ritmo, completedRecords: [RitmoRecord], date: Date) -> Bool {
        guard ritmo.isHabit,
              let reminderTime = ritmo.reminderTime,
              isHabit(ritmo, activeOn: date),
              !isRitmoCompleted(ritmo.id, on: date, completedRecords: completedRecords),
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

    private func isRitmoCompleted(_ ritmoID: UUID, on date: Date, completedRecords: [RitmoRecord]) -> Bool {
        completedRecords.contains {
            $0.ritmoID == ritmoID && Calendar.current.isDate($0.date, inSameDayAs: date)
        }
    }

    private func isHabit(_ ritmo: Ritmo, activeOn date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
        return ritmo.schedule.contains { $0.numberValue == adjustedWeekday }
    }

    private func dateComponents(from date: Date) -> DateComponents {
        var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        components.calendar = Calendar.current
        components.timeZone = .current
        return components
    }

    private func notificationIdentifiers(for ritmoID: UUID) -> [String] {
        let weekdayIdentifiers = (1...7).map { notificationIdentifier(for: ritmoID, suffix: "\($0)") }
        let rollingIdentifiers = plannedDateOffsets().flatMap { date -> [String] in
            [
                habitReminderIdentifier(for: ritmoID, date: date),
                eventReminderIdentifier(for: ritmoID, date: date)
            ]
        }
        return weekdayIdentifiers + [notificationIdentifier(for: ritmoID, suffix: "event")] + rollingIdentifiers
    }

    private func removeRegularReminders(for ritmoID: UUID) {
        let identifiers = notificationIdentifiers(for: ritmoID)
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

    private func habitReminderIdentifier(for ritmoID: UUID, date: Date) -> String {
        notificationIdentifier(for: ritmoID, suffix: "\(habitReminderPrefix)-\(dateString(from: date))")
    }

    private func eventReminderIdentifier(for ritmoID: UUID, date: Date) -> String {
        notificationIdentifier(for: ritmoID, suffix: "\(eventReminderPrefix)-\(dateString(from: date))")
    }

    private func softReminderIdentifier(for ritmoID: UUID, date: Date) -> String {
        notificationIdentifier(for: ritmoID, suffix: "\(softReminderSuffix)-\(dateString(from: date))")
    }

    private func dateString(from date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    private func appWeekdayNumber(for date: Date) -> Int {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 ? 7 : weekday - 1
    }

    private func syncSkippedReminders(for ritmo: Ritmo, completedRecords: [RitmoRecord]) {
        guard ritmo.isHabit else {
            return
        }

        let calendar = Calendar.current
        let completedDateStrings = Set(completedRecords
            .filter { $0.ritmoID == ritmo.id }
            .map { dateString(from: calendar.startOfDay(for: $0.date)) })

        skippedReminderQueue.sync {
            plannedDateOffsets().forEach { date in
                let key = reminderKey(for: ritmo.id, date: date)
                if completedDateStrings.contains(dateString(from: date)) {
                    skippedHabitReminderKeys.insert(key)
                } else {
                    skippedHabitReminderKeys.remove(key)
                }
            }
        }
    }

    private func skipReminder(for ritmoID: UUID, on date: Date) {
        skippedReminderQueue.sync {
            skippedHabitReminderKeys.insert(reminderKey(for: ritmoID, date: date))
        }
    }

    private func isReminderSkipped(for ritmoID: UUID, on date: Date) -> Bool {
        skippedReminderQueue.sync {
            skippedHabitReminderKeys.contains(reminderKey(for: ritmoID, date: date))
        }
    }

    private func reminderKey(for ritmoID: UUID, date: Date) -> String {
        "\(ritmoID.uuidString)-\(dateString(from: date))"
    }

    private func notificationIdentifier(for ritmoID: UUID, suffix: String) -> String {
        "\(identifierPrefix)-\(ritmoID.uuidString)-\(suffix)"
    }

    private func notificationIdentifierPrefix(for ritmoID: UUID) -> String {
        "\(identifierPrefix)-\(ritmoID.uuidString)"
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
