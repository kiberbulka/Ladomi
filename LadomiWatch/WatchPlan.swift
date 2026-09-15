import Foundation
import SwiftUI

struct WatchPlan: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let emoji: String
    let colorHex: String
    let isHabit: Bool
    let repetitionsPerDay: Int
    var completedRepetitions: Int

    var isCompleted: Bool { completedRepetitions >= repetitionsPerDay }
    var hasMultipleRepetitions: Bool { isHabit && repetitionsPerDay > 1 }

    private enum CodingKeys: String, CodingKey {
        case id, title, emoji, colorHex, isHabit, repetitionsPerDay, completedRepetitions, isCompleted
    }

    init?(dictionary: [String: Any]) {
        guard
            let idString = dictionary["id"] as? String,
            let id = UUID(uuidString: idString),
            let title = dictionary["title"] as? String,
            let emoji = dictionary["emoji"] as? String,
            let colorHex = dictionary["color"] as? String
        else {
            return nil
        }

        self.id = id
        self.title = title
        self.emoji = emoji
        self.colorHex = colorHex
        self.isHabit = dictionary["isHabit"] as? Bool ?? false
        self.repetitionsPerDay = max(1, dictionary["repetitionsPerDay"] as? Int ?? 1)
        let legacyCount = (dictionary["isCompleted"] as? Bool ?? false) ? repetitionsPerDay : 0
        self.completedRepetitions = min(
            repetitionsPerDay,
            max(0, dictionary["completedRepetitions"] as? Int ?? legacyCount)
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        emoji = try container.decode(String.self, forKey: .emoji)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        isHabit = try container.decodeIfPresent(Bool.self, forKey: .isHabit) ?? false
        repetitionsPerDay = max(1, try container.decodeIfPresent(Int.self, forKey: .repetitionsPerDay) ?? 1)
        let legacyCount = (try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false)
            ? repetitionsPerDay : 0
        completedRepetitions = min(
            repetitionsPerDay,
            max(0, try container.decodeIfPresent(Int.self, forKey: .completedRepetitions) ?? legacyCount)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(emoji, forKey: .emoji)
        try container.encode(colorHex, forKey: .colorHex)
        try container.encode(isHabit, forKey: .isHabit)
        try container.encode(repetitionsPerDay, forKey: .repetitionsPerDay)
        try container.encode(completedRepetitions, forKey: .completedRepetitions)
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
