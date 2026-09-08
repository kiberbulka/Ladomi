import Foundation
import UserNotifications

final class ReminderNotificationService {
    private struct InactivityReminderCandidate {
        let identifier: String
        let dayItem: DayItem
        let missedDays: Int
        let triggerDate: Date
    }

    static let shared = ReminderNotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let identifierPrefix = "dayItem-reminder"
    private let softReminderSuffix = "soft"
    private let softReminderHour = 20
    private let softReminderMinute = 0
    private let habitReminderPrefix = "habit"
    private let eventReminderPrefix = "event"
    private let inactivityReminderPrefix = "inactivity"
    private let inactivityThreshold = 3
    private let inactivityReminderHour = 10
    private let scheduledInactivityReminderIDsKey = "scheduledInactivityReminderIDs"
    private let postponedDayItemsKey = "postponedDayItemsByDate"
    private let habitPlanningWindowDays = 60
    private let maxHabitRemindersPerDayItem = 8
    private let skippedReminderQueue = DispatchQueue(label: "dayItem.reminders.skipped")
    private let inactivityReminderStateQueue = DispatchQueue(label: "dayItem.reminders.inactivityState")
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
        removeSavedInactivityReminderIdentifiers(for: dayItemID)
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

    func scheduleInactivityReminders(
        for dayItems: [DayItem],
        completedRecords: [DayItemRecord],
        date: Date = Date()
    ) {
        let postponements = loadPostponements()
        let candidates = dayItems.compactMap {
            inactivityReminderCandidate(
                for: $0,
                completedRecords: completedRecords,
                postponements: postponements,
                date: date
            )
        }
        let desiredIdentifiers = Set(candidates.map { $0.identifier })
        let savedIdentifiers = savedInactivityReminderIdentifiers()
            .intersection(desiredIdentifiers)
        saveInactivityReminderIdentifiers(savedIdentifiers)

        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }

            let inactivityRequests = requests.filter {
                self.isInactivityReminderIdentifier($0.identifier)
            }
            let stalePendingIdentifiers = inactivityRequests
                .map { $0.identifier }
                .filter { !desiredIdentifiers.contains($0) }
            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: stalePendingIdentifiers)

            self.notificationCenter.getDeliveredNotifications { [weak self] notifications in
                guard let self else { return }

                let inactivityNotifications = notifications.filter {
                    self.isInactivityReminderIdentifier($0.request.identifier)
                }
                let staleDeliveredIdentifiers = inactivityNotifications
                    .map { $0.request.identifier }
                    .filter { !desiredIdentifiers.contains($0) }
                self.notificationCenter.removeDeliveredNotifications(withIdentifiers: staleDeliveredIdentifiers)

                let existingIdentifiers = Set(
                    inactivityRequests.map { $0.identifier }
                    + inactivityNotifications.map { $0.request.identifier }
                ).union(savedIdentifiers)
                let candidatesToAdd = candidates.filter {
                    !existingIdentifiers.contains($0.identifier)
                }

                self.addInactivityReminderRequests(candidatesToAdd, now: date)
            }
        }
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
        let postponements = loadPostponements()

        return (0..<habitPlanningWindowDays).compactMap { dayOffset -> Date? in
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate),
                  isHabit(dayItem, activeOn: date, postponements: postponements),
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
        let eventDate = DayItemInactivityCalculator.effectiveEventDate(
            for: dayItem,
            postponements: loadPostponements(),
            calendar: calendar
        )
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

    private func addInactivityReminderRequests(
        _ candidates: [InactivityReminderCandidate],
        now: Date
    ) {
        guard !candidates.isEmpty else {
            return
        }

        notificationCenter.getNotificationSettings { [weak self] settings in
            guard let self else { return }

            switch settings.authorizationStatus {
            case .authorized, .provisional:
                candidates.forEach { self.addInactivityReminderRequest($0, now: now) }
            case .notDetermined:
                self.notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if let error {
                        print("Failed to request notification authorization: \(error)")
                    }

                    guard granted else { return }
                    candidates.forEach { self.addInactivityReminderRequest($0, now: now) }
                }
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }

    private func addInactivityReminderRequest(
        _ candidate: InactivityReminderCandidate,
        now: Date
    ) {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString(
            "inactivity.notification.title",
            comment: "Inactive day item notification title"
        )
        content.body = inactivityNotificationBody(
            for: candidate.dayItem,
            missedDays: candidate.missedDays
        )
        content.sound = .default

        let trigger: UNNotificationTrigger
        if candidate.triggerDate <= now {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        } else {
            trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents(from: candidate.triggerDate),
                repeats: false
            )
        }

        let request = UNNotificationRequest(
            identifier: candidate.identifier,
            content: content,
            trigger: trigger
        )
        notificationCenter.add(request) { error in
            if let error {
                print("Failed to schedule inactivity reminder: \(error)")
            } else {
                self.saveInactivityReminderIdentifier(candidate.identifier)
            }
        }
    }

    private func inactivityReminderCandidate(
        for dayItem: DayItem,
        completedRecords: [DayItemRecord],
        postponements: [String: String],
        date: Date
    ) -> InactivityReminderCandidate? {
        guard !dayItem.isArchived, !dayItem.isStopList else {
            return nil
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        let itemRecords = completedRecords.filter { $0.dayItemID == dayItem.id }

        if !dayItem.isHabit {
            guard itemRecords.isEmpty else {
                return nil
            }

            let eventDate = DayItemInactivityCalculator.effectiveEventDate(
                for: dayItem,
                postponements: postponements,
                calendar: calendar
            )
            guard let thresholdDate = calendar.date(
                byAdding: .day,
                value: inactivityThreshold,
                to: eventDate
            ) else {
                return nil
            }
            let triggerDate = reminderDate(
                hour: inactivityReminderHour,
                on: thresholdDate,
                calendar: calendar
            )
            let missedDays = max(
                inactivityThreshold,
                calendar.dateComponents([.day], from: eventDate, to: today).day ?? 0
            )

            return InactivityReminderCandidate(
                identifier: inactivityReminderIdentifier(
                    for: dayItem.id,
                    episodeStartDate: eventDate
                ),
                dayItem: dayItem,
                missedDays: missedDays,
                triggerDate: triggerDate
            )
        }

        guard !dayItem.schedule.isEmpty else {
            return nil
        }

        let status = DayItemInactivityCalculator.status(
            for: dayItem,
            records: completedRecords,
            postponements: postponements,
            through: today,
            calendar: calendar
        )
        var missedDays = status?.missedDays ?? 0
        var episodeStartDate = status?.firstMissedDate
        let completedDates = Set(itemRecords.map { calendar.startOfDay(for: $0.date) })

        if missedDays >= inactivityThreshold,
           let episodeStartDate,
           let thirdMissedDate = missedHabitThresholdDate(
               for: dayItem,
               episodeStartDate: episodeStartDate,
               postponements: postponements,
               calendar: calendar
           ),
           let notificationDay = calendar.date(byAdding: .day, value: 1, to: thirdMissedDate) {
            return InactivityReminderCandidate(
                identifier: inactivityReminderIdentifier(
                    for: dayItem.id,
                    episodeStartDate: episodeStartDate
                ),
                dayItem: dayItem,
                missedDays: missedDays,
                triggerDate: reminderDate(
                    hour: inactivityReminderHour,
                    on: notificationDay,
                    calendar: calendar
                )
            )
        }

        var projectedDate = today
        for _ in 0..<366 {
            if DayItemInactivityCalculator.isHabitExpected(
                dayItem,
                on: projectedDate,
                postponements: postponements,
                calendar: calendar
            ) {
                if completedDates.contains(projectedDate) {
                    missedDays = 0
                    episodeStartDate = nil
                } else {
                    missedDays += 1
                    if episodeStartDate == nil {
                        episodeStartDate = projectedDate
                    }

                    if missedDays >= inactivityThreshold,
                       let episodeStartDate,
                       let notificationDay = calendar.date(byAdding: .day, value: 1, to: projectedDate) {
                        return InactivityReminderCandidate(
                            identifier: inactivityReminderIdentifier(
                                for: dayItem.id,
                                episodeStartDate: episodeStartDate
                            ),
                            dayItem: dayItem,
                            missedDays: inactivityThreshold,
                            triggerDate: reminderDate(
                                hour: inactivityReminderHour,
                                on: notificationDay,
                                calendar: calendar
                            )
                        )
                    }
                }
            }

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: projectedDate) else {
                break
            }
            projectedDate = nextDate
        }

        return nil
    }

    private func missedHabitThresholdDate(
        for dayItem: DayItem,
        episodeStartDate: Date,
        postponements: [String: String],
        calendar: Calendar
    ) -> Date? {
        var missedDays = 0
        var date = episodeStartDate

        for _ in 0..<366 {
            if DayItemInactivityCalculator.isHabitExpected(
                dayItem,
                on: date,
                postponements: postponements,
                calendar: calendar
            ) {
                missedDays += 1
                if missedDays == inactivityThreshold {
                    return date
                }
            }

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else {
                return nil
            }
            date = nextDate
        }

        return nil
    }

    private func inactivityNotificationBody(for dayItem: DayItem, missedDays: Int) -> String {
        let remainder10 = missedDays % 10
        let remainder100 = missedDays % 100
        let type = dayItem.isHabit ? "habit" : "event"
        let form: String

        if remainder10 == 1 && remainder100 != 11 {
            form = "one"
        } else if remainder10 >= 2 && remainder10 <= 4 && (remainder100 < 10 || remainder100 >= 20) {
            form = "few"
        } else {
            form = "many"
        }

        let key = "inactivity.notification.\(type).body.\(form)"
        return String(
            format: NSLocalizedString(key, comment: "Inactive day item notification body"),
            dayItem.name,
            missedDays
        )
    }

    private func reminderDate(hour: Int, on date: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
    }

    private func shouldScheduleSoftReminder(for dayItem: DayItem, completedRecords: [DayItemRecord], date: Date) -> Bool {
        let postponements = loadPostponements()

        guard dayItem.isHabit,
              let reminderTime = dayItem.reminderTime,
              isHabit(dayItem, activeOn: date, postponements: postponements),
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

    private func isHabit(
        _ dayItem: DayItem,
        activeOn date: Date,
        postponements: [String: String]
    ) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
        let isScheduled = dayItem.schedule.contains { $0.numberValue == adjustedWeekday }
        let dateKey = postponementDateKey(for: date)
        let itemPrefix = "\(dayItem.id.uuidString)_"
        let isPostponedFromDate = postponements["\(itemPrefix)\(dateKey)"] != nil
        let isPostponedToDate = postponements.contains { key, value in
            key.hasPrefix(itemPrefix) && value == dateKey
        }

        return (isScheduled || isPostponedToDate) && !isPostponedFromDate
    }

    private func loadPostponements() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: postponedDayItemsKey) as? [String: String] ?? [:]
    }

    private func postponementDateKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
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

    private func inactivityReminderIdentifier(for dayItemID: UUID, episodeStartDate: Date) -> String {
        notificationIdentifier(
            for: dayItemID,
            suffix: "\(inactivityReminderPrefix)-\(dateString(from: episodeStartDate))"
        )
    }

    private func isInactivityReminderIdentifier(_ identifier: String) -> Bool {
        identifier.hasPrefix("\(identifierPrefix)-")
            && identifier.contains("-\(inactivityReminderPrefix)-")
    }

    private func savedInactivityReminderIdentifiers() -> Set<String> {
        inactivityReminderStateQueue.sync {
            Set(UserDefaults.standard.stringArray(forKey: scheduledInactivityReminderIDsKey) ?? [])
        }
    }

    private func saveInactivityReminderIdentifiers(_ identifiers: Set<String>) {
        inactivityReminderStateQueue.sync {
            UserDefaults.standard.set(Array(identifiers), forKey: scheduledInactivityReminderIDsKey)
        }
    }

    private func saveInactivityReminderIdentifier(_ identifier: String) {
        inactivityReminderStateQueue.sync {
            var identifiers = Set(
                UserDefaults.standard.stringArray(forKey: scheduledInactivityReminderIDsKey) ?? []
            )
            identifiers.insert(identifier)
            UserDefaults.standard.set(Array(identifiers), forKey: scheduledInactivityReminderIDsKey)
        }
    }

    private func removeSavedInactivityReminderIdentifiers(for dayItemID: UUID) {
        let prefix = "\(notificationIdentifierPrefix(for: dayItemID))-\(inactivityReminderPrefix)-"
        inactivityReminderStateQueue.sync {
            let identifiers = Set(
                UserDefaults.standard.stringArray(forKey: scheduledInactivityReminderIDsKey) ?? []
            ).filter {
                !$0.hasPrefix(prefix)
            }
            UserDefaults.standard.set(Array(identifiers), forKey: scheduledInactivityReminderIDsKey)
        }
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
