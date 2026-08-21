//
//  Weekdays.swift
//  Tracker
//
//  Created by User on 31.03.2025.
//

import Foundation

enum Weekday: String, CaseIterable, Codable {
    case Monday
    case Tuesday
    case Wednesday
    case Thursday
    case Friday
    case Saturday
    case Sunday
    
    var localizedName: String {
        switch self {
        case .Monday: return NSLocalizedString("Monday", comment: "Monday")
        case .Tuesday: return NSLocalizedString("Tuesday", comment: "Tuesday")
        case .Wednesday: return NSLocalizedString("Wednesday", comment: "Wednesday")
        case .Thursday: return NSLocalizedString("Thursday", comment: "Thursday")
        case .Friday: return NSLocalizedString("Friday", comment: "Friday")
        case .Saturday: return NSLocalizedString("Saturday", comment: "Saturday")
        case .Sunday: return NSLocalizedString("Sunday", comment: "Sunday")
        }
    }

    var shortName: String {
        switch self {
        case .Monday: return NSLocalizedString("Monday_short", comment: "Monday short")
        case .Tuesday: return NSLocalizedString("Tuesday_short", comment: "Tuesday short")
        case .Wednesday: return NSLocalizedString("Wednesday_short", comment: "Wednesday short")
        case .Thursday: return NSLocalizedString("Thursday_short", comment: "Thursday short")
        case .Friday: return NSLocalizedString("Friday_short", comment: "Friday short")
        case .Saturday: return NSLocalizedString("Saturday_short", comment: "Saturday short")
        case .Sunday: return NSLocalizedString("Sunday_short", comment: "Sunday short")
        }
    }

    var numberValue: Int {
        switch self {
        case .Monday: return 1
        case .Tuesday: return 2
        case .Wednesday: return 3
        case .Thursday: return 4
        case .Friday: return 5
        case .Saturday: return 6
        case .Sunday: return 7
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        
        if let weekday = Weekday(rawValue: value) {
            self = weekday
            return
        }
        
        let mapping: [String: Weekday] = [
            "Понедельник": .Monday,
            "Вторник": .Tuesday,
            "Среда": .Wednesday,
            "Четверг": .Thursday,
            "Пятница": .Friday,
            "Суббота": .Saturday,
            "Воскресенье": .Sunday
        ]
        
        if let mapped = mapping[value] {
            self = mapped
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid weekday value: \(value)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }

    static func encodeSchedule(_ schedule: [Weekday]) -> String? {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(schedule)
            return String(data: data, encoding: .utf8)
        } catch {
            print("Ошибка кодирования расписания: \(error)")
            return nil
        }
    }

    static func decodeSchedule(from string: String) -> [Weekday]? {
        let decoder = JSONDecoder()
        guard let data = string.data(using: .utf8) else {
            print("Ошибка преобразования строки в данные")
            return nil
        }
        do {
            let schedule = try decoder.decode([Weekday].self, from: data)
            return schedule
        } catch {
            print("Ошибка декодирования расписания: \(error)")
            return nil
        }
    }
}
