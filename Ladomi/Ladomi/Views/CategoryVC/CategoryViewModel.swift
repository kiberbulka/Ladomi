import Foundation

class CategoryViewModel{
    
    private var categories: [DayItemCategory] = [] {
        didSet {
            self.reloadData?()
        }
    }
    
    var reloadData: (() -> Void)?
    var onCategorySelected: ((DayItemCategory) -> Void)?
    
    private let dayItemCategoryStore = DayItemCategoryStore()
    
    init() {
        dayItemCategoryStore.delegate = self
        fetchCategories()
    }
    
    func isEmpty() -> Bool {
        return categories.isEmpty
    }
    
    func categoryIndex(for category: DayItemCategory) -> Int? {
        return categories.firstIndex { $0.title == category.title }
    }
    
    func category(at index: Int) -> DayItemCategory? {
        guard index >= 0 && index < categories.count else { return nil }
        return categories[index]
    }
    
    func selectCategory(at index: Int) -> DayItemCategory? {
        guard index >= 0 && index < categories.count else { return nil }
        let category = categories[index]
        onCategorySelected?(category)
        return category
    }
    
    
    func numberOfCategories() -> Int {
        return categories.count
    }
    
    func fetchCategories(){
        categories = dayItemCategoryStore.fetchCategories()
    }
    
    func addCategory(_ category: DayItemCategory) {
        dayItemCategoryStore.addCategory(category)
        fetchCategories()
    }
    
    func deleteCategory(_ category: DayItemCategory) {
        dayItemCategoryStore.deleteCategory(category)
        fetchCategories()
        
    }
    
    func deleteCategory(at index: Int) {
        guard categories.indices.contains(index) else { return }
        let category = categories[index]
        deleteCategory(category)
    }
    
    func editCategory(at indexPath: IndexPath, newTitle: String) {
        dayItemCategoryStore.updateCategory(at: indexPath, with: newTitle)
        fetchCategories()
    }
}

extension CategoryViewModel: DayItemCategoryStoreDelegate {
    func didUpdateCategories(_ update: DayItemCategoryStoreUpdate) {
        fetchCategories()
    }
    
}
