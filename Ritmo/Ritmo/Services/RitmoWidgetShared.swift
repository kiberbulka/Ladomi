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
            RitmoWidgetItem(emoji: "💧", title: NSLocalizedString("widget.preview.water", comment: "Widget preview item"), timeText: "09:00", isCompleted: true),
            RitmoWidgetItem(emoji: "📖", title: NSLocalizedString("widget.preview.reading", comment: "Widget preview item"), timeText: "18:30", isCompleted: true),
            RitmoWidgetItem(emoji: "🧘", title: NSLocalizedString("widget.preview.meditation", comment: "Widget preview item"), timeText: "21:00", isCompleted: false),
            RitmoWidgetItem(emoji: "💊", title: NSLocalizedString("widget.preview.vitamins", comment: "Widget preview item"), timeText: nil, isCompleted: false),
            RitmoWidgetItem(emoji: "📦", title: NSLocalizedString("widget.preview.order", comment: "Widget preview item"), timeText: "22:00", isCompleted: false)
        ]
    )
}
