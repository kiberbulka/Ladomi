//
//  DataManager.swift
//  Tracker
//
//  Created by User on 07.04.2025.
//

import Foundation

final class DataManager {
    
    static let shared = DataManager()
    
    var categories: [TrackerCategory] = [
    ]
    
    private init(){}
    
    func add(tracker: Tracker, to categoryTitle: String) {
        if let index = categories.firstIndex(where: { $0.title == categoryTitle }) {
            let existingCategory = categories[index]
            let updatedCategory = TrackerCategory(title: existingCategory.title, trackers: existingCategory.trackers + [tracker])
            categories[index] = updatedCategory
        } else {
            let newCategory = TrackerCategory(title: categoryTitle, trackers: [tracker])
            categories.append(newCategory)
        }
    }

}
