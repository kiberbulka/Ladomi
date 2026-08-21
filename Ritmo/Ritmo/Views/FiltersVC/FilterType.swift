import Foundation

enum FilterType: String, CaseIterable {
    case all
    case habits
    case events
    case notCompleted
    
    var title: String {
        switch self {
        case .all: 
            return NSLocalizedString("allRitmos", comment: "ячейка все ритмы")
        case .habits:
            return NSLocalizedString("habitsFilter", comment: "")
        case .events:
            return NSLocalizedString("eventsFilter", comment: "")
        case .notCompleted:
            return NSLocalizedString("uncompletedRitmos", comment: "")
        }
    }
    
    var isDefault: Bool {
        return self == .all
    }
}
