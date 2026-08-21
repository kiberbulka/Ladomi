//
//  CategoryViewModel.swift
//  Tracker
//
//  Created by Olya on 05.05.2025.
//

import Foundation

class CategoryViewModel{
    
    private var categories: [TrackerCategory] = [] {
        didSet {
            self.reloadData?()
        }
    }
    
    var reloadData: (() -> Void)?
    var onCategorySelected: ((TrackerCategory) -> Void)?
    
    private let trackerCategoryStore = TrackerCategoryStore()
    
    init() {
        trackerCategoryStore.delegate = self
        fetchCategories()
    }
    
    func isEmpty() -> Bool {
        return categories.isEmpty
    }
    
    func categoryIndex(for category: TrackerCategory) -> Int? {
        return categories.firstIndex { $0.title == category.title }
    }
    
    func category(at index: Int) -> TrackerCategory? {
        guard index >= 0 && index < categories.count else { return nil }
        return categories[index]
    }
    
    func selectCategory(at index: Int) -> TrackerCategory? {
        guard index >= 0 && index < categories.count else { return nil }
        let category = categories[index]
        onCategorySelected?(category)
        return category
    }
    
    
    func numberOfCategories() -> Int {
        return categories.count
    }
    
    func fetchCategories(){
        categories = trackerCategoryStore.fetchCategories()
    }
    
    func addCategory(_ category: TrackerCategory) {
        trackerCategoryStore.addCategory(category)
        fetchCategories()
    }
    
    func deleteCategory(_ category: TrackerCategory) {
        trackerCategoryStore.deleteCategory(category)
        fetchCategories()
        
    }
    
    func deleteCategory(at index: Int) {
        guard categories.indices.contains(index) else { return }
        let category = categories[index]
        deleteCategory(category)
    }
    
    func editCategory(at indexPath: IndexPath, newTitle: String) {
        trackerCategoryStore.updateCategory(at: indexPath, with: newTitle)
        fetchCategories()
    }
}

extension CategoryViewModel: TrackerCategoryStoreDelegate {
    func didUpdateCategories(_ update: TrackerCategoryStoreUpdate) {
        fetchCategories()
    }
    
}
