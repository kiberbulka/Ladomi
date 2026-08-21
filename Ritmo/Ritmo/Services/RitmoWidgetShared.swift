//
//  RitmoWidgetShared.swift
//  Ritmo
//
//  Created by Codex on 09.08.2026.
//

import Foundation

enum RitmoWidgetShared {
    static let appGroupIdentifier = "group.com.olyasmirnova.Ritmo.Ritmo"
    static let todaySnapshotKey = "todayWidgetSnapshot"

    static var storage: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }
}

struct RitmoWidgetItem: Codable, Hashable {
    let emoji: String
    let title: String
    let timeText: String?
    let isCompleted: Bool
}

struct RitmoTodayWidgetSnapshot: Codable, Hashable {
    let date: Date
    let completedCount: Int
    let totalCount: Int
    let items: [RitmoWidgetItem]

    var progress: Double {
        guard totalCount > 0 else {
            return 0
        }

        return Double(completedCount) / Double(totalCount)
    }

    var hasRitmos: Bool {
        totalCount > 0
    }

    static let empty = RitmoTodayWidgetSnapshot(
        date: Date(),
        completedCount: 0,
        totalCount: 0,
        items: []
    )

    static let preview = RitmoTodayWidgetSnapshot(
        date: Date(),
        completedCount: 2,
        totalCount: 5,
        items: [
            RitmoWidgetItem(emoji: "💧", title: "Вода", timeText: "09:00", isCompleted: true),
            RitmoWidgetItem(emoji: "📖", title: "Чтение", timeText: "18:30", isCompleted: true),
            RitmoWidgetItem(emoji: "🧘", title: "Медитация", timeText: "21:00", isCompleted: false),
            RitmoWidgetItem(emoji: "💊", title: "Купить витамины", timeText: nil, isCompleted: false),
            RitmoWidgetItem(emoji: "📦", title: "Забрать заказ", timeText: "22:00", isCompleted: false)
        ]
    )
}
