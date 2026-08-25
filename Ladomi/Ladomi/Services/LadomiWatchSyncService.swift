import Foundation
import WatchConnectivity

final class LadomiWatchSyncService: NSObject {
    static let shared = LadomiWatchSyncService()
    static let recordsDidChangeNotification = Notification.Name("LadomiWatchRecordsDidChange")

    private let dayItemStore = DayItemStore()
    private let dayItemRecordStore = DayItemRecordStore()
    private let postponedDayItemsKey = "postponedDayItemsByDate"
    private var session: WCSession?

    private lazy var storageDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        self.session = session
        session.delegate = self
        session.activate()
    }

    func publishTodayPlans() {
        guard let session, session.activationState == .activated else { return }
        do {
            try session.updateApplicationContext(todayPayload())
        } catch {
            print("Failed to update Apple Watch plans: \(error)")
        }
    }

    private func todayPayload() -> [String: Any] {
        let today = Date()
        let records = dayItemRecordStore.fetch()
        let plans = dayItemStore.fetchDayItems()
            .filter { isVisibleToday($0, records: records, today: today) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { item -> [String: Any] in
                [
                    "id": item.id.uuidString,
                    "title": item.name,
                    "emoji": item.emoji,
                    "color": item.color.toHexString() ?? "#D9D9D9",
                    "isCompleted": records.contains {
                        $0.dayItemID == item.id && Calendar.current.isDate($0.date, inSameDayAs: today)
                    }
                ]
            }

        return ["plans": plans, "updatedAt": today.timeIntervalSince1970]
    }

    private func isVisibleToday(_ item: DayItem, records: [DayItemRecord], today: Date) -> Bool {
        guard !item.isArchived, !item.isStopList else { return false }

        let calendar = Calendar.current
        if isPostponedFrom(item.id, on: today) {
            return false
        }
        if isPostponedTo(item.id, on: today) {
            return true
        }

        if item.isHabit {
            let weekday = calendar.component(.weekday, from: today)
            let mondayBasedWeekday = weekday == 1 ? 7 : weekday - 1
            return item.schedule.contains { $0.numberValue == mondayBasedWeekday }
        }

        if let completedRecord = records.first(where: { $0.dayItemID == item.id }) {
            return calendar.isDate(completedRecord.date, inSameDayAs: today)
        }

        let eventDate = calendar.startOfDay(for: item.eventDate ?? today)
        return eventDate <= calendar.startOfDay(for: today)
    }

    private func isPostponedFrom(_ id: UUID, on date: Date) -> Bool {
        postponements()["\(id.uuidString)_\(dateKey(date))"] != nil
    }

    private func isPostponedTo(_ id: UUID, on date: Date) -> Bool {
        let targetDate = dateKey(date)
        let itemPrefix = "\(id.uuidString)_"
        return postponements().contains { key, value in
            key.hasPrefix(itemPrefix) && value == targetDate
        }
    }

    private func postponements() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: postponedDayItemsKey) as? [String: String] ?? [:]
    }

    private func dateKey(_ date: Date) -> String {
        storageDateFormatter.string(from: Calendar.current.startOfDay(for: date))
    }

    private func setCompleted(_ isCompleted: Bool, id: UUID) {
        let records = dayItemRecordStore.fetch()
        let todayRecord = records.first {
            $0.dayItemID == id && Calendar.current.isDateInToday($0.date)
        }

        do {
            if isCompleted, todayRecord == nil {
                try dayItemRecordStore.add(dayItemRecord: DayItemRecord(dayItemID: id, date: Date()))
            } else if !isCompleted, let todayRecord {
                try dayItemRecordStore.delete(dayItemRecord: todayRecord)
            }

            NotificationCenter.default.post(name: Self.recordsDidChangeNotification, object: nil)
            publishTodayPlans()
        } catch {
            print("Failed to apply Apple Watch completion: \(error)")
        }
    }

    private func handle(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)? = nil) {
        switch message["action"] as? String {
        case "setCompleted":
            guard
                let idString = message["id"] as? String,
                let id = UUID(uuidString: idString),
                let isCompleted = message["isCompleted"] as? Bool
            else {
                replyHandler?(todayPayload())
                return
            }
            setCompleted(isCompleted, id: id)
            replyHandler?(todayPayload())
        case "requestPlans":
            replyHandler?(todayPayload())
        default:
            break
        }
    }
}

extension LadomiWatchSyncService: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        DispatchQueue.main.async { [weak self] in self?.publishTodayPlans() }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.handle(message, replyHandler: replyHandler)
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        DispatchQueue.main.async { [weak self] in self?.handle(userInfo) }
    }
}
