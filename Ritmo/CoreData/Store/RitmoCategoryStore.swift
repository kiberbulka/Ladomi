//
//  RitmoCategoryStore.swift
//  Ritmo
//
//  Created by Olya on 19.04.2025.
//

import CoreData
import UIKit

struct RitmoCategoryStoreUpdate {
    let insertedIndexes: IndexSet
    let deletedIndexes: IndexSet
    let updatedIndexes: IndexSet
}

protocol RitmoCategoryStoreDelegate: AnyObject {
    func didUpdateCategories(_ update: RitmoCategoryStoreUpdate)
}

final class RitmoCategoryStore: NSObject {
    weak var delegate: RitmoCategoryStoreDelegate?
    
    private let context = CoreDataManager.shared.viewContext
    private var fetchedResultsController: NSFetchedResultsController<RitmoCategoryCoreData>
    private var insertedIndexes: IndexSet?
    private var deletedIndexes: IndexSet?
    private var updatedIndexes: IndexSet?
    
    var numberOfSection: Int {
        fetchedResultsController.sections?.count ?? 0
    }
    
    override init() {
        let fetchRequest: NSFetchRequest<RitmoCategoryCoreData> = RitmoCategoryCoreData.fetchRequest()
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
    
    func create(_ category: RitmoCategory) throws {
        let ritmoCategoryCoreData = RitmoCategoryCoreData(context: context)
        ritmoCategoryCoreData.title = category.title
        ritmoCategoryCoreData.ritmos = []
        CoreDataManager.shared.saveContext()
    }
    
    func addCategory(_ category: RitmoCategory) {
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
    
    func loadCategories() -> [RitmoCategory] {
        return fetchCategories()
    }
    
    func deleteCategory(_ category: RitmoCategory) {
        let request: NSFetchRequest<RitmoCategoryCoreData> = RitmoCategoryCoreData.fetchRequest()
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
    
    func category(for ritmo: Ritmo) -> RitmoCategory? {
        let categories = fetchCategories()
        for category in categories {
            if category.ritmos.contains(where: { $0.id == ritmo.id }) {
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
    
    func fetchCategories() -> [RitmoCategory] {
        let request = NSFetchRequest<RitmoCategoryCoreData>(entityName: "RitmoCategoryCoreData")
        
        do {
            let ritmoCategories = try context.fetch(request)
            
            return ritmoCategories.map { categoryCoreData in
                let title = categoryCoreData.title ?? ""
                let ritmos = categoryCoreData.ritmos?.allObjects as? [RitmoCoreData] ?? []
                let sortedRitmos = ritmos.sorted { ($0.name ?? "") < ($1.name ?? "") }
                let ritmoObjects = sortedRitmos.compactMap { ritmoCoreData in
                    
                    let scheduleString = ritmoCoreData.schedule ?? ""
                    let schedule = scheduleString.isEmpty ? [] : Weekday.decodeSchedule(from: scheduleString) ?? []
                    
                    return Ritmo(
                        id: ritmoCoreData.id ?? UUID(),
                        name: ritmoCoreData.name ?? "",
                        color: UIColor(hex: ritmoCoreData.color ?? "") ?? .colorSection1,
                        emoji: ritmoCoreData.emoji ?? "",
                        schedule: schedule,
                        isHabit: ritmoCoreData.isHabit,
                        reminderTime: ritmoCoreData.reminderTime,
                        eventDate: ritmoCoreData.eventDate,
                        createdDate: ritmoCoreData.createdDate ?? Date(),
                        archivedDate: ritmoCoreData.archivedDate,
                        isArchived: ritmoCoreData.isArchived
                    )
                }
                return RitmoCategory(title: title, ritmos: ritmoObjects)
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
extension RitmoCategoryStore: NSFetchedResultsControllerDelegate {
    
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

