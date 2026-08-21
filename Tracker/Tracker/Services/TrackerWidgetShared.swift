//
//  TrackerWidgetShared.swift
//  Tracker
//
//  Created by Codex on 09.08.2026.
//

import Foundation

enum TrackerWidgetShared {
    static let appGroupIdentifier = "group.com.olyasmirnova.Tracker.Tracker"
    static let todaySnapshotKey = "todayWidgetSnapshot"

    static var storage: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }
}

struct TrackerWidgetItem: Codable, Hashable {
    let emoji: String
    let title: String
    let timeText: String?
    let isCompleted: Bool
}

struct TrackerTodayWidgetSnapshot: Codable, Hashable {
    let date: Date
    let completedCount: Int
    let totalCount: Int
    let items: [TrackerWidgetItem]

    var progress: Double {
        guard totalCount > 0 else {
            return 0
        }

        return Double(completedCount) / Double(totalCount)
    }

    var hasTrackers: Bool {
        totalCount > 0
    }

    static let empty = TrackerTodayWidgetSnapshot(
        date: Date(),
        completedCount: 0,
        totalCount: 0,
        items: []
    )

    static let preview = TrackerTodayWidgetSnapshot(
        date: Date(),
        completedCount: 2,
        totalCount: 5,
        items: [
            TrackerWidgetItem(emoji: "💧", title: "Вода", timeText: "09:00", isCompleted: true),
            TrackerWidgetItem(emoji: "📖", title: "Чтение", timeText: "18:30", isCompleted: true),
            TrackerWidgetItem(emoji: "🧘", title: "Медитация", timeText: "21:00", isCompleted: false),
            TrackerWidgetItem(emoji: "💊", title: "Купить витамины", timeText: nil, isCompleted: false),
            TrackerWidgetItem(emoji: "📦", title: "Забрать заказ", timeText: "22:00", isCompleted: false)
        ]
    )
}
