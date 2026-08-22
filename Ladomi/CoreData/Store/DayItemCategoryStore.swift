import CoreData
import UIKit

struct DayItemCategoryStoreUpdate {
    let insertedIndexes: IndexSet
    let deletedIndexes: IndexSet
    let updatedIndexes: IndexSet
}

protocol DayItemCategoryStoreDelegate: AnyObject {
    func didUpdateCategories(_ update: DayItemCategoryStoreUpdate)
}

final class DayItemCategoryStore: NSObject {
    weak var delegate: DayItemCategoryStoreDelegate?
    
    private let context = CoreDataManager.shared.viewContext
    private var fetchedResultsController: NSFetchedResultsController<DayItemCategoryCoreData>
    private var insertedIndexes: IndexSet?
    private var deletedIndexes: IndexSet?
    private var updatedIndexes: IndexSet?
    
    var numberOfSection: Int {
        fetchedResultsController.sections?.count ?? 0
    }
    
    override init() {
        let fetchRequest: NSFetchRequest<DayItemCategoryCoreData> = DayItemCategoryCoreData.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        
        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: CoreDataManager.shared.viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        super.init()
        
        fetchedResultsController.delegate = self
        
        do {
            try fetchedResultsController.performFetch()
        } catch {
            print("Failed to fetch categories: \(error)")
        }
    }
    
    func create(_ category: DayItemCategory) throws {
        let dayItemCategoryCoreData = DayItemCategoryCoreData(context: context)
        dayItemCategoryCoreData.title = category.title
        dayItemCategoryCoreData.dayItems = []
        CoreDataManager.shared.saveContext()
    }
    
    func addCategory(_ category: DayItemCategory) {
        do {
            try create(category)
            delegate?.didUpdateCategories(
                .init(insertedIndexes: IndexSet([fetchedResultsController.fetchedObjects?.count ?? 0]),
                      deletedIndexes: IndexSet(),
                      updatedIndexes: IndexSet())
            )
        } catch {
            print("Error adding category: \(error)")
        }
    }
    
    func loadCategories() -> [DayItemCategory] {
        return fetchCategories()
    }
    
    func deleteCategory(_ category: DayItemCategory) {
        let request: NSFetchRequest<DayItemCategoryCoreData> = DayItemCategoryCoreData.fetchRequest()
        request.predicate = NSPredicate(format: "title == %@", category.title)
        
        do {
            let categories = try context.fetch(request)
            if let categoryToDelete = categories.first {
                context.delete(categoryToDelete)
                CoreDataManager.shared.saveContext()
            }
        } catch {
            print("Ошибка при удалении категории: \(error)")
        }
    }
    
    func category(for dayItem: DayItem) -> DayItemCategory? {
        let categories = fetchCategories()
        for category in categories {
            if category.dayItems.contains(where: { $0.id == dayItem.id }) {
                return category
            }
        }
        return nil
    }

    
    
    func updateCategory(at indexPath: IndexPath, with title: String) {
        let category = fetchedResultsController.object(at: indexPath)
        category.title = title
        CoreDataManager.shared.saveContext()
    }
    
    func fetchCategories() -> [DayItemCategory] {
        let request = NSFetchRequest<DayItemCategoryCoreData>(entityName: "DayItemCategoryCoreData")
        
        do {
            let dayItemCategories = try context.fetch(request)
            
            return dayItemCategories.map { categoryCoreData in
                let title = categoryCoreData.title ?? ""
                let dayItems = categoryCoreData.dayItems?.allObjects as? [DayItemCoreData] ?? []
                let sortedDayItems = dayItems.sorted { ($0.name ?? "") < ($1.name ?? "") }
                let dayItemObjects = sortedDayItems.compactMap { dayItemCoreData in
                    
                    let scheduleString = dayItemCoreData.schedule ?? ""
                    let schedule = scheduleString.isEmpty ? [] : Weekday.decodeSchedule(from: scheduleString) ?? []
                    
                    return DayItem(
                        id: dayItemCoreData.id ?? UUID(),
                        name: dayItemCoreData.name ?? "",
                        color: UIColor(hex: dayItemCoreData.color ?? "") ?? .colorSection1,
                        emoji: dayItemCoreData.emoji ?? "",
                        schedule: schedule,
                        isHabit: dayItemCoreData.isHabit,
                        reminderTime: dayItemCoreData.reminderTime,
                        eventDate: dayItemCoreData.eventDate,
                        createdDate: dayItemCoreData.createdDate ?? Date(),
                        archivedDate: dayItemCoreData.archivedDate,
                        isArchived: dayItemCoreData.isArchived,
                        isStopList: dayItemCoreData.isStopList
                    )
                }
                return DayItemCategory(title: title, dayItems: dayItemObjects)
            }
        } catch {
            print("Failed to fetch categories: \(error)")
            return []
        }
    }
    
    func numberOfRowsInSection(_ section: Int) -> Int {
        fetchedResultsController.sections?[section].numberOfObjects ?? 0
    }
    
}
extension DayItemCategoryStore: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
        insertedIndexes = IndexSet()
        deletedIndexes = IndexSet()
        updatedIndexes = IndexSet()
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        guard
            let insertedIndexes = insertedIndexes,
            let deletedIndexes = deletedIndexes,
            let updatedIndexes = updatedIndexes else { return }
        delegate?.didUpdateCategories(
            .init(
                insertedIndexes: insertedIndexes,
                deletedIndexes: deletedIndexes,
                updatedIndexes: updatedIndexes
            )
        )
        self.insertedIndexes = nil
        self.deletedIndexes = nil
        self.updatedIndexes = nil
    }
    
    func controller(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>,
        didChange anObject: Any,
        at indexPath: IndexPath?,
        for type: NSFetchedResultsChangeType,
        newIndexPath: IndexPath?) {
            switch type {
            case .delete:
                if let indexPath = indexPath {
                    deletedIndexes?.insert(indexPath.row)
                }
            case .insert:
                if let newIndexPath = newIndexPath {
                    insertedIndexes?.insert(newIndexPath.row)
                }
            case .update:
                if let indexPath = indexPath {
                    updatedIndexes?.insert(indexPath.row)
                }
            default:
                break
            }
        }
}
