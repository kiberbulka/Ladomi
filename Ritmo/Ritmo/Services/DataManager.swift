import Foundation

final class DataManager {
    
    static let shared = DataManager()
    
    var categories: [RitmoCategory] = [
    ]
    
    private init(){}
    
    func add(ritmo: Ritmo, to categoryTitle: String) {
        if let index = categories.firstIndex(where: { $0.title == categoryTitle }) {
            let existingCategory = categories[index]
            let updatedCategory = RitmoCategory(title: existingCategory.title, ritmos: existingCategory.ritmos + [ritmo])
            categories[index] = updatedCategory
        } else {
            let newCategory = RitmoCategory(title: categoryTitle, ritmos: [ritmo])
            categories.append(newCategory)
        }
    }

}
