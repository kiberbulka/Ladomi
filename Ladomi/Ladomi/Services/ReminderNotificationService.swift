import Foundation
import UserNotifications

final class ReminderNotificationService {
    static let shared = ReminderNotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let identifierPrefix = "dayItem-reminder"
    private let softReminderSuffix = "soft"
    private let softReminderHour = 20
    private let softReminderMinute = 0
    private let habitReminderPrefix = "habit"
    private let eventReminderPrefix = "event"
    private let habitPlanningWindowDays = 60
    private let maxHabitRemindersPerDayItem = 8
    private let skippedReminderQueue = DispatchQueue(label: "dayItem.reminders.skipped")
    private var skippedHabitReminderKeys: Set<String> = []

    private init() {}

    func scheduleReminder(for dayItem: DayItem, completedRecords: [DayItemRecord] = []) {
        guard !dayItem.isArchived, !dayItem.isStopList, dayItem.reminderTime != nil else {
            removeReminder(for: dayItem.id)
            return
        }

        removeRegularReminders(for: dayItem.id)
        syncSkippedReminders(for: dayItem, completedRecords: completedRecords)

        notificationCenter.getNotificationSettings { [weak self] settings in
            guard let self = self else { return }

            switch settings.authorizationStatus {
            case .authorized, .provisional:
                self.addNotificationRequests(for: dayItem, completedRecords: completedRecords)
            case .notDetermined:
                self.notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if let error = error {
                        print("Failed to request notification authorization: \(error)")
                    }

                    guard granted else { return }
                    self.addNotificationRequests(for: dayItem, completedRecords: completedRecords)
                }
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }

    func removeReminder(for dayItemID: UUID) {
        removeRegularReminders(for: dayItemID)
        removeNotifications(matching: notificationIdentifierPrefix(for: dayItemID))
    }

    func removeReminder(for dayItemID: UUID, on date: Date) {
        skipReminder(for: dayItemID, on: date)

        let identifiers = [
            habitReminderIdentifier(for: dayItemID, date: date),
            notificationIdentifier(for: dayItemID, suffix: "\(appWeekdayNumber(for: date))"),
            softReminderIdentifier(for: dayItemID, date: date)
        ]

        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func scheduleSoftReminderIfNeeded(for dayItem: DayItem, completedRecords: [DayItemRecord], date: Date = Date()) {
        removeSoftReminder(for: dayItem.id, date: date)

        guard !dayItem.isStopList else {
            return
        }

        guard shouldScheduleSoftReminder(for: dayItem, completedRecords: completedRecords, date: date),
              let triggerDate = softReminderDate(for: date) else {
            return
        }

        notificationCenter.getNotificationSettings { [weak self] settings in
            guard let self = self else { return }

            switch settings.authorizationStatus {
            case .authorized, .provisional:
                self.addSoftReminderRequest(for: dayItem, triggerDate: triggerDate)
            case .notDetermined:
                self.notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if let error = error {
                        print("Failed to request notification authorization: \(error)")
                    }

                    guard granted else { return }
                    self.addSoftReminderRequest(for: dayItem, triggerDate: triggerDate)
                }
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }

    func removeSoftReminder(for dayItemID: UUID, date: Date = Date()) {
        let identifier = softReminderIdentifier(for: dayItemID, date: date)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    private func addNotificationRequests(for dayItem: DayItem, completedRecords: [DayItemRecord]) {
        guard let reminderTime = dayItem.reminderTime else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("reminder.notification.title", comment: "Notification title")
        content.body = dayItem.name
        content.sound = .default

        if dayItem.isHabit {
            habitReminderDates(for: dayItem, reminderTime: reminderTime, completedRecords: completedRecords).forEach { date in
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents(from: date), repeats: false)
                let request = UNNotificationRequest(
                    identifier: habitReminderIdentifier(for: dayItem.id, date: date),
                    content: content,
                    trigger: trigger
                )
                notificationCenter.add(request) { error in
                    if let error = error {
                        print("Failed to schedule habit reminder: \(error)")
                    }
                }
            }
        } else if let date = eventReminderDate(for: dayItem, reminderTime: reminderTime, completedRecords: completedRecords) {
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents(from: date), repeats: false)
            let request = UNNotificationRequest(
                identifier: eventReminderIdentifier(for: dayItem.id, date: date),
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
        for dayItem: DayItem,
        reminderTime: Date,
        completedRecords: [DayItemRecord]
    ) -> [Date] {
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.startOfDay(for: now)

        return (0..<habitPlanningWindowDays).compactMap { dayOffset -> Date? in
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate),
                  isHabit(dayItem, activeOn: date),
                  !isDayItemCompleted(dayItem.id, on: date, completedRecords: completedRecords),
                  !isReminderSkipped(for: dayItem.id, on: date),
                  let reminderDate = reminderDate(from: reminderTime, on: date),
                  reminderDate > now else {
                return nil
            }

            return reminderDate
        }
        .prefix(maxHabitRemindersPerDayItem)
        .map { $0 }
    }

    private func eventReminderDate(
        for dayItem: DayItem,
        reminderTime: Date,
        completedRecords: [DayItemRecord]
    ) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let eventDate = calendar.startOfDay(for: dayItem.eventDate ?? today)
        let effectiveDate = eventDate < today ? today : eventDate

        guard !completedRecords.contains(where: { $0.dayItemID == dayItem.id }),
              let reminderDate = reminderDate(from: reminderTime, on: effectiveDate),
              reminderDate > now else {
            return nil
        }

        return reminderDate
    }

    private func addSoftReminderRequest(for dayItem: DayItem, triggerDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("softReminder.notification.title", comment: "Soft reminder notification title")
        content.body = dayItem.name
        content.sound = .default

        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: softReminderIdentifier(for: dayItem.id, date: triggerDate),
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to schedule soft reminder: \(error)")
            }
        }
    }

    private func shouldScheduleSoftReminder(for dayItem: DayItem, completedRecords: [DayItemRecord], date: Date) -> Bool {
        guard dayItem.isHabit,
              let reminderTime = dayItem.reminderTime,
              isHabit(dayItem, activeOn: date),
              !isDayItemCompleted(dayItem.id, on: date, completedRecords: completedRecords),
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

    private func isDayItemCompleted(_ dayItemID: UUID, on date: Date, completedRecords: [DayItemRecord]) -> Bool {
        completedRecords.contains {
            $0.dayItemID == dayItemID && Calendar.current.isDate($0.date, inSameDayAs: date)
        }
    }

    private func isHabit(_ dayItem: DayItem, activeOn date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
        return dayItem.schedule.contains { $0.numberValue == adjustedWeekday }
    }

    private func dateComponents(from date: Date) -> DateComponents {
        var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        components.calendar = Calendar.current
        components.timeZone = .current
        return components
    }

    private func notificationIdentifiers(for dayItemID: UUID) -> [String] {
        let weekdayIdentifiers = (1...7).map { notificationIdentifier(for: dayItemID, suffix: "\($0)") }
        let rollingIdentifiers = plannedDateOffsets().flatMap { date -> [String] in
            [
                habitReminderIdentifier(for: dayItemID, date: date),
                eventReminderIdentifier(for: dayItemID, date: date)
            ]
        }
        return weekdayIdentifiers + [notificationIdentifier(for: dayItemID, suffix: "event")] + rollingIdentifiers
    }

    private func removeRegularReminders(for dayItemID: UUID) {
        let identifiers = notificationIdentifiers(for: dayItemID)
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

    private func habitReminderIdentifier(for dayItemID: UUID, date: Date) -> String {
        notificationIdentifier(for: dayItemID, suffix: "\(habitReminderPrefix)-\(dateString(from: date))")
    }

    private func eventReminderIdentifier(for dayItemID: UUID, date: Date) -> String {
        notificationIdentifier(for: dayItemID, suffix: "\(eventReminderPrefix)-\(dateString(from: date))")
    }

    private func softReminderIdentifier(for dayItemID: UUID, date: Date) -> String {
        notificationIdentifier(for: dayItemID, suffix: "\(softReminderSuffix)-\(dateString(from: date))")
    }

    private func dateString(from date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    private func appWeekdayNumber(for date: Date) -> Int {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 ? 7 : weekday - 1
    }

    private func syncSkippedReminders(for dayItem: DayItem, completedRecords: [DayItemRecord]) {
        guard dayItem.isHabit else {
            return
        }

        let calendar = Calendar.current
        let completedDateStrings = Set(completedRecords
            .filter { $0.dayItemID == dayItem.id }
            .map { dateString(from: calendar.startOfDay(for: $0.date)) })

        skippedReminderQueue.sync {
            plannedDateOffsets().forEach { date in
                let key = reminderKey(for: dayItem.id, date: date)
                if completedDateStrings.contains(dateString(from: date)) {
                    skippedHabitReminderKeys.insert(key)
                } else {
                    skippedHabitReminderKeys.remove(key)
                }
            }
        }
    }

    private func skipReminder(for dayItemID: UUID, on date: Date) {
        skippedReminderQueue.sync {
            skippedHabitReminderKeys.insert(reminderKey(for: dayItemID, date: date))
        }
    }

    private func isReminderSkipped(for dayItemID: UUID, on date: Date) -> Bool {
        skippedReminderQueue.sync {
            skippedHabitReminderKeys.contains(reminderKey(for: dayItemID, date: date))
        }
    }

    private func reminderKey(for dayItemID: UUID, date: Date) -> String {
        "\(dayItemID.uuidString)-\(dateString(from: date))"
    }

    private func notificationIdentifier(for dayItemID: UUID, suffix: String) -> String {
        "\(identifierPrefix)-\(dayItemID.uuidString)-\(suffix)"
    }

    private func notificationIdentifierPrefix(for dayItemID: UUID) -> String {
        "\(identifierPrefix)-\(dayItemID.uuidString)"
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
