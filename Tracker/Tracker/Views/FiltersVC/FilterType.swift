//
//  FilterType.swift
//  Tracker
//
//  Created by Olya on 20.05.2025.
//

import Foundation

enum FilterType: String, CaseIterable {
    case all
    case habits
    case events
    case notCompleted
    
    var title: String {
        switch self {
        case .all: 
            return NSLocalizedString("allTrackers", comment: "ячейка все трекеры")
        case .habits:
            return NSLocalizedString("habitsFilter", comment: "")
        case .events:
            return NSLocalizedString("eventsFilter", comment: "")
        case .notCompleted:
            return NSLocalizedString("uncompletedTrackers", comment: "")
        }
    }
    
    var isDefault: Bool {
        return self == .all
    }
}
