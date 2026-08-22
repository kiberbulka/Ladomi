import CoreData

struct DayItemRecordStoreUpdate {
    let insertedIndexes: IndexSet
    let deletedIndexes: IndexSet
    let updatedIndexes: IndexSet
}

protocol DayItemRecordStoreDelegate: AnyObject {
    func didUpdateRecords(_ update: DayItemCategoryStoreUpdate)
}

final class DayItemRecordStore: NSObject {
    weak var delegate: DayItemRecordStoreDelegate?
    
    private let context = CoreDataManager.shared.viewContext
    private var fetchedResultsController: NSFetchedResultsController<DayItemRecordCoreData>
    
    private var insertedIndexes: IndexSet?
    private var deletedIndexes: IndexSet?
    private var updatedIndexes: IndexSet?
    
    
    override init() {
        let fetchRequest: NSFetchRequest<DayItemRecordCoreData> = DayItemRecordCoreData.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
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
            print("Failed to fetch dayItem records: \(error)")
        }
    }
    
    func add(dayItemRecord: DayItemRecord) throws {
        let dayItemRecordCD = DayItemRecordCoreData(context: context)
        
        dayItemRecordCD.id = dayItemRecord.dayItemID
        dayItemRecordCD.date = dayItemRecord.date
        
        CoreDataManager.shared.saveContext()
        try? fetchedResultsController.performFetch()
    }
    
    func fetch() -> [DayItemRecord] {
        let request = NSFetchRequest<DayItemRecordCoreData>(entityName: "DayItemRecordCoreData")
        
        do {
            let results = try context.fetch(request)
            return results.map { dayItemRecord in
                DayItemRecord(
                    dayItemID: dayItemRecord.id ?? UUID(),
                    date: dayItemRecord.date ?? Date()
                )
            }
        } catch {
            print("Failed to fetch dayItemRecords: \(error)")
            return []
        }
    }
    
    func delete(dayItemRecord: DayItemRecord) throws {
        let request = NSFetchRequest<DayItemRecordCoreData>(entityName: "DayItemRecordCoreData")
        request.predicate = NSPredicate(
            format: "id == %@ AND date == %@",
            dayItemRecord.dayItemID as CVarArg,
            dayItemRecord.date as CVarArg
        )
        
        if let dayItemRecordCoreData = try context.fetch(request).first {
            context.delete(dayItemRecordCoreData)
        }
        
        CoreDataManager.shared.saveContext()
        try? fetchedResultsController.performFetch()
    }
}

extension DayItemRecordStore : NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        insertedIndexes = IndexSet()
        deletedIndexes = IndexSet()
        updatedIndexes = IndexSet()
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        guard let insertedIndexes = insertedIndexes,
              let deletedIndexes = deletedIndexes,
              let updatedIndexes = updatedIndexes
        else {
            return
        }
        delegate?.didUpdateRecords(.init(insertedIndexes: insertedIndexes, deletedIndexes: deletedIndexes, updatedIndexes: updatedIndexes ))
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

