import Foundation

enum LadomiWidgetShared {
    static let appGroupIdentifier = "group.com.olyasmirnova.Ladomi"
    static let todaySnapshotKey = "todayWidgetSnapshot"

    static var storage: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }
}

struct LadomiWidgetItem: Codable, Hashable {
    let emoji: String
    let title: String
    let timeText: String?
    let isCompleted: Bool
}

struct LadomiTodayWidgetSnapshot: Codable, Hashable {
    let date: Date
    let completedCount: Int
    let totalCount: Int
    let items: [LadomiWidgetItem]

    var progress: Double {
        guard totalCount > 0 else {
            return 0
        }

        return Double(completedCount) / Double(totalCount)
    }

    var hasDayItems: Bool {
        totalCount > 0
    }

    static let empty = LadomiTodayWidgetSnapshot(
        date: Date(),
        completedCount: 0,
        totalCount: 0,
        items: []
    )

    static let preview = LadomiTodayWidgetSnapshot(
        date: Date(),
        completedCount: 2,
        totalCount: 5,
        items: [
            LadomiWidgetItem(emoji: "💧", title: NSLocalizedString("widget.preview.water", comment: "Widget preview item"), timeText: "09:00", isCompleted: true),
            LadomiWidgetItem(emoji: "📖", title: NSLocalizedString("widget.preview.reading", comment: "Widget preview item"), timeText: "18:30", isCompleted: true),
            LadomiWidgetItem(emoji: "🧘", title: NSLocalizedString("widget.preview.meditation", comment: "Widget preview item"), timeText: "21:00", isCompleted: false),
            LadomiWidgetItem(emoji: "💊", title: NSLocalizedString("widget.preview.vitamins", comment: "Widget preview item"), timeText: nil, isCompleted: false),
            LadomiWidgetItem(emoji: "📦", title: NSLocalizedString("widget.preview.order", comment: "Widget preview item"), timeText: "22:00", isCompleted: false)
        ]
    )
}
