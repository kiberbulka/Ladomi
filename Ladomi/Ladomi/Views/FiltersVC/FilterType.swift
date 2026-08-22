import Foundation

enum FilterType: String, CaseIterable {
    case all
    case habits
    case events
    case notCompleted
    
    var title: String {
        switch self {
        case .all: 
            return NSLocalizedString("allDayItems", comment: "ячейка все ритмы")
        case .habits:
            return NSLocalizedString("habitsFilter", comment: "")
        case .events:
            return NSLocalizedString("eventsFilter", comment: "")
        case .notCompleted:
            return NSLocalizedString("uncompletedDayItems", comment: "")
        }
    }
    
    var isDefault: Bool {
        return self == .all
    }
}
