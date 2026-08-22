import Foundation

final class DataManager {
    
    static let shared = DataManager()
    
    var categories: [DayItemCategory] = [
    ]
    
    private init(){}
    
    func add(dayItem: DayItem, to categoryTitle: String) {
        if let index = categories.firstIndex(where: { $0.title == categoryTitle }) {
            let existingCategory = categories[index]
            let updatedCategory = DayItemCategory(title: existingCategory.title, dayItems: existingCategory.dayItems + [dayItem])
            categories[index] = updatedCategory
        } else {
            let newCategory = DayItemCategory(title: categoryTitle, dayItems: [dayItem])
            categories.append(newCategory)
        }
    }

}
