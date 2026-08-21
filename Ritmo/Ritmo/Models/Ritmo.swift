import UIKit

struct Ritmo {
    let id: UUID
    let name: String
    let color: UIColor
    let emoji: String
    let schedule: [Weekday]
    let isHabit: Bool
    let reminderTime: Date?
    let eventDate: Date?
    let createdDate: Date
    let archivedDate: Date?
    let isArchived: Bool

    init(
        id: UUID,
        name: String,
        color: UIColor,
        emoji: String,
        schedule: [Weekday],
        isHabit: Bool,
        reminderTime: Date? = nil,
        eventDate: Date? = nil,
        createdDate: Date = Date(),
        archivedDate: Date? = nil,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.emoji = emoji
        self.schedule = schedule
        self.isHabit = isHabit
        self.reminderTime = reminderTime
        self.eventDate = eventDate
        self.createdDate = createdDate
        self.archivedDate = archivedDate
        self.isArchived = isArchived
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
