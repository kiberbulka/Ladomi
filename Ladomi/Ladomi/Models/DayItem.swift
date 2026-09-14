import UIKit

struct DayItem {
    let id: UUID
    let name: String
    let color: UIColor
    let emoji: String
    let schedule: [Weekday]
    let isHabit: Bool
    let repetitionsPerDay: Int
    let reminderTimes: [Date]
    var reminderTime: Date? { reminderTimes.first }
    let eventDate: Date?
    let createdDate: Date
    let archivedDate: Date?
    let isArchived: Bool
    let isStopList: Bool

    init(
        id: UUID,
        name: String,
        color: UIColor,
        emoji: String,
        schedule: [Weekday],
        isHabit: Bool,
        repetitionsPerDay: Int = 1,
        reminderTime: Date? = nil,
        reminderTimes: [Date]? = nil,
        eventDate: Date? = nil,
        createdDate: Date = Date(),
        archivedDate: Date? = nil,
        isArchived: Bool = false,
        isStopList: Bool = false
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.emoji = emoji
        self.schedule = schedule
        self.isHabit = isHabit
        let normalizedRepetitionsPerDay = max(1, repetitionsPerDay)
        let normalizedReminderTimes = Self.normalizedReminderTimes(
            reminderTimes ?? reminderTime.map { [$0] } ?? []
        )
        self.repetitionsPerDay = normalizedRepetitionsPerDay
        self.reminderTimes = isHabit
            ? Array(normalizedReminderTimes.prefix(normalizedRepetitionsPerDay))
            : normalizedReminderTimes
        self.eventDate = eventDate
        self.createdDate = createdDate
        self.archivedDate = archivedDate
        self.isArchived = isArchived
        self.isStopList = isStopList
    }

    private static func normalizedReminderTimes(_ dates: [Date]) -> [Date] {
        let calendar = Calendar.current
        var seenMinutes: Set<Int> = []

        return dates
            .sorted {
                let first = calendar.dateComponents([.hour, .minute], from: $0)
                let second = calendar.dateComponents([.hour, .minute], from: $1)
                return (first.hour ?? 0, first.minute ?? 0) < (second.hour ?? 0, second.minute ?? 0)
            }
            .filter { date in
                let components = calendar.dateComponents([.hour, .minute], from: date)
                let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
                return seenMinutes.insert(minutes).inserted
            }
    }
}

enum DayItemReminderTimesCoder {
    static func encode(_ reminderTimes: [Date]) -> String? {
        guard !reminderTimes.isEmpty,
              let data = try? JSONEncoder().encode(reminderTimes.map(\.timeIntervalSinceReferenceDate)) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func decode(_ value: String?) -> [Date]? {
        guard let value,
              let data = value.data(using: .utf8),
              let intervals = try? JSONDecoder().decode([TimeInterval].self, from: data) else {
            return nil
        }
        return intervals.map(Date.init(timeIntervalSinceReferenceDate:))
    }
}

// MARK: - UIColor extension
extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexSanitized.hasPrefix("#") {
            hexSanitized.remove(at: hexSanitized.startIndex)
        }
        guard hexSanitized.count == 6 else { return nil }
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0
        
        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
    
    func toHexString() -> String? {
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0

            if self.getRed(&r, green: &g, blue: &b, alpha: &a) {
                let red = Int(r * 255)
                let green = Int(g * 255)
                let blue = Int(b * 255)
                return String(format: "#%02X%02X%02X", red, green, blue)
            } else {
                return nil
            }
        }
}
