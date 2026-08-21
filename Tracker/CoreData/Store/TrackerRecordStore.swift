//
//  TrackerRecordStore.swift
//  Tracker
//
//  Created by Olya on 19.04.2025.
//

import CoreData

struct TrackerRecordStoreUpdate {
    let insertedIndexes: IndexSet
    let deletedIndexes: IndexSet
    let updatedIndexes: IndexSet
}

protocol TrackerRecordStoreDelegate: AnyObject {
    func didUpdateRecords(_ update: TrackerCategoryStoreUpdate)
}

final class TrackerRecordStore: NSObject {
    weak var delegate: TrackerRecordStoreDelegate?
    
    private let context = CoreDataManager.shared.viewContext
    private var fetchedResultsController: NSFetchedResultsController<TrackerRecordCoreData>
    
    private var insertedIndexes: IndexSet?
    private var deletedIndexes: IndexSet?
    private var updatedIndexes: IndexSet?
    
    
    override init() {
        let fetchRequest: NSFetchRequest<TrackerRecordCoreData> = TrackerRecordCoreData.fetchRequest()
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
            print("Failed to fetch tracker records: \(error)")
        }
    }
    
    func add(trackerRecord: TrackerRecord) throws {
        let trackerRecordCD = TrackerRecordCoreData(context: context)
        
        trackerRecordCD.id = trackerRecord.trackerID
        trackerRecordCD.date = trackerRecord.date
        
        CoreDataManager.shared.saveContext()
        try? fetchedResultsController.performFetch()
    }
    
    func fetch() -> [TrackerRecord] {
        let request = NSFetchRequest<TrackerRecordCoreData>(entityName: "TrackerRecordCoreData")
        
        do {
            let results = try context.fetch(request)
            return results.map { trackerRecord in
                TrackerRecord(
                    trackerID: trackerRecord.id ?? UUID(),
                    date: trackerRecord.date ?? Date()
                )
            }
        } catch {
            print("Failed to fetch trackerRecords: \(error)")
            return []
        }
    }
    
    func delete(trackerRecord: TrackerRecord) throws {
        let request = NSFetchRequest<TrackerRecordCoreData>(entityName: "TrackerRecordCoreData")
        request.predicate = NSPredicate(
            format: "id == %@ AND date == %@",
            trackerRecord.trackerID as CVarArg,
            trackerRecord.date as CVarArg
        )
        
        if let trackerRecordCoreData = try context.fetch(request).first {
            context.delete(trackerRecordCoreData)
        }
        
        CoreDataManager.shared.saveContext()
        try? fetchedResultsController.performFetch()
    }
}

extension TrackerRecordStore : NSFetchedResultsControllerDelegate {
    
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

