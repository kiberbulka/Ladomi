import Foundation
import SwiftUI

struct WatchPlan: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let emoji: String
    let colorHex: String
    var isCompleted: Bool

    init?(dictionary: [String: Any]) {
        guard
            let idString = dictionary["id"] as? String,
            let id = UUID(uuidString: idString),
            let title = dictionary["title"] as? String,
            let emoji = dictionary["emoji"] as? String,
            let colorHex = dictionary["color"] as? String,
            let isCompleted = dictionary["isCompleted"] as? Bool
        else {
            return nil
        }

        self.id = id
        self.title = title
        self.emoji = emoji
        self.colorHex = colorHex
        self.isCompleted = isCompleted
    }

    var color: Color {
        Color(hex: colorHex)
    }
}

extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)

        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
