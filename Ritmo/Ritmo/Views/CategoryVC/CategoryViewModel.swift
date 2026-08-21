import Foundation

class CategoryViewModel{
    
    private var categories: [RitmoCategory] = [] {
        didSet {
            self.reloadData?()
        }
    }
    
    var reloadData: (() -> Void)?
    var onCategorySelected: ((RitmoCategory) -> Void)?
    
    private let ritmoCategoryStore = RitmoCategoryStore()
    
    init() {
        ritmoCategoryStore.delegate = self
        fetchCategories()
    }
    
    func isEmpty() -> Bool {
        return categories.isEmpty
    }
    
    func categoryIndex(for category: RitmoCategory) -> Int? {
        return categories.firstIndex { $0.title == category.title }
    }
    
    func category(at index: Int) -> RitmoCategory? {
        guard index >= 0 && index < categories.count else { return nil }
        return categories[index]
    }
    
    func selectCategory(at index: Int) -> RitmoCategory? {
        guard index >= 0 && index < categories.count else { return nil }
        let category = categories[index]
        onCategorySelected?(category)
        return category
    }
    
    
    func numberOfCategories() -> Int {
        return categories.count
    }
    
    func fetchCategories(){
        categories = ritmoCategoryStore.fetchCategories()
    }
    
    func addCategory(_ category: RitmoCategory) {
        ritmoCategoryStore.addCategory(category)
        fetchCategories()
    }
    
    func deleteCategory(_ category: RitmoCategory) {
        ritmoCategoryStore.deleteCategory(category)
        fetchCategories()
        
    }
    
    func deleteCategory(at index: Int) {
        guard categories.indices.contains(index) else { return }
        let category = categories[index]
        deleteCategory(category)
    }
    
    func editCategory(at indexPath: IndexPath, newTitle: String) {
        ritmoCategoryStore.updateCategory(at: indexPath, with: newTitle)
        fetchCategories()
    }
}

extension CategoryViewModel: RitmoCategoryStoreDelegate {
    func didUpdateCategories(_ update: RitmoCategoryStoreUpdate) {
        fetchCategories()
    }
    
}
