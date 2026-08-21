import CoreData

struct RitmoRecordStoreUpdate {
    let insertedIndexes: IndexSet
    let deletedIndexes: IndexSet
    let updatedIndexes: IndexSet
}

protocol RitmoRecordStoreDelegate: AnyObject {
    func didUpdateRecords(_ update: RitmoCategoryStoreUpdate)
}

final class RitmoRecordStore: NSObject {
    weak var delegate: RitmoRecordStoreDelegate?
    
    private let context = CoreDataManager.shared.viewContext
    private var fetchedResultsController: NSFetchedResultsController<RitmoRecordCoreData>
    
    private var insertedIndexes: IndexSet?
    private var deletedIndexes: IndexSet?
    private var updatedIndexes: IndexSet?
    
    
    override init() {
        let fetchRequest: NSFetchRequest<RitmoRecordCoreData> = RitmoRecordCoreData.fetchRequest()
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
            print("Failed to fetch ritmo records: \(error)")
        }
    }
    
    func add(ritmoRecord: RitmoRecord) throws {
        let ritmoRecordCD = RitmoRecordCoreData(context: context)
        
        ritmoRecordCD.id = ritmoRecord.ritmoID
        ritmoRecordCD.date = ritmoRecord.date
        
        CoreDataManager.shared.saveContext()
        try? fetchedResultsController.performFetch()
    }
    
    func fetch() -> [RitmoRecord] {
        let request = NSFetchRequest<RitmoRecordCoreData>(entityName: "RitmoRecordCoreData")
        
        do {
            let results = try context.fetch(request)
            return results.map { ritmoRecord in
                RitmoRecord(
                    ritmoID: ritmoRecord.id ?? UUID(),
                    date: ritmoRecord.date ?? Date()
                )
            }
        } catch {
            print("Failed to fetch ritmoRecords: \(error)")
            return []
        }
    }
    
    func delete(ritmoRecord: RitmoRecord) throws {
        let request = NSFetchRequest<RitmoRecordCoreData>(entityName: "RitmoRecordCoreData")
        request.predicate = NSPredicate(
            format: "id == %@ AND date == %@",
            ritmoRecord.ritmoID as CVarArg,
            ritmoRecord.date as CVarArg
        )
        
        if let ritmoRecordCoreData = try context.fetch(request).first {
            context.delete(ritmoRecordCoreData)
        }
        
        CoreDataManager.shared.saveContext()
        try? fetchedResultsController.performFetch()
    }
}

extension RitmoRecordStore : NSFetchedResultsControllerDelegate {
    
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

