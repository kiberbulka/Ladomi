import UIKit
import CoreData

protocol RitmoStoreDelegate: AnyObject {
    func didUpdate(_ update: RitmoStoreUpdate)
}

struct RitmoStoreUpdate {
    let insertedIndexes: IndexSet
    let deletedIndexes: IndexSet
}

final class RitmoStore: NSObject {
    
    // MARK: - Private properties
    
    private var insertedIndexes: IndexSet = []
    private var deletedIndexes: IndexSet = []
    
    private let context = CoreDataManager.shared.viewContext
    private var fetchedResultsController: NSFetchedResultsController<RitmoCoreData>
    
    // MARK: - Public properties
    
    weak var delegate: RitmoStoreDelegate?
    
    // MARK: - Initializers
    
    override init() {
        let fetchRequest: NSFetchRequest<RitmoCoreData> = RitmoCoreData.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
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
            print("Failed to fetch ritmos: \(error)")
        }
    }
    
    // MARK: - Public Methods
    
    func numberOfSections() -> Int {
        fetchedResultsController.sections?.count ?? 0
    }
    
    func numberOfItems(in section: Int) -> Int {
        fetchedResultsController.sections?[section].numberOfObjects ?? 0
    }
    
    func addRitmo(ritmo: Ritmo, category: RitmoCategory) {
        let ritmoCoreData = RitmoCoreData(context: context)
        
        let request = NSFetchRequest<RitmoCategoryCoreData>(entityName: "RitmoCategoryCoreData")
        request.predicate = NSPredicate(format: "%K == %@", #keyPath(RitmoCategoryCoreData.title), category.title)
        
        var ritmoCategoryCoreData: RitmoCategoryCoreData?
        
        do {
            let results = try context.fetch(request)
            if let existingCategory = results.first {
                ritmoCategoryCoreData = existingCategory
            } else {
                ritmoCategoryCoreData = RitmoCategoryCoreData(context: context)
                ritmoCategoryCoreData?.title = category.title
                CoreDataManager.shared.saveContext()
            }
        } catch {
            print("Error fetching or creating category: \(error)")
        }
        ritmoCoreData.ritmoCategory = ritmoCategoryCoreData
        ritmoCoreData.name = ritmo.name
        ritmoCoreData.id = ritmo.id
        ritmoCoreData.emoji = ritmo.emoji
        ritmoCoreData.reminderTime = ritmo.reminderTime
        ritmoCoreData.eventDate = ritmo.eventDate
        ritmoCoreData.createdDate = ritmo.createdDate
        ritmoCoreData.archivedDate = ritmo.archivedDate
        ritmoCoreData.isArchived = ritmo.isArchived
        
        if let colorString = ritmo.color.toHexString() {
            ritmoCoreData.color = colorString
        } else {
            print("Ошибка преобразования цвета в строку")
            ritmoCoreData.color = ""
        }
        
        ritmoCoreData.isHabit = ritmo.isHabit
        
        if let scheduleString = Weekday.encodeSchedule(ritmo.schedule) {
            ritmoCoreData.schedule = scheduleString
        } else {
            print("Ошибка кодирования расписания")
            ritmoCoreData.schedule = ""
        }
        
        CoreDataManager.shared.saveContext()
    }
    
    func ritmo(with id: UUID) -> Ritmo? {
        return fetchRitmos().first { $0.id == id }
    }
    
    func fetchRitmos() -> [Ritmo] {
        guard let objects = fetchedResultsController.fetchedObjects else { return [] }
        return objects.map { coreDataRitmo in
            let scheduleString = coreDataRitmo.schedule ?? ""
            let schedule: [Weekday] = Weekday.decodeSchedule(from: scheduleString) ?? []
            
            return Ritmo(
                id: coreDataRitmo.id ?? UUID(),
                name: coreDataRitmo.name ?? "",
                color: UIColor(hex: coreDataRitmo.color ?? "#FFFFFF") ?? .gray,
                emoji: coreDataRitmo.emoji ?? "",
                schedule: schedule,
                isHabit: coreDataRitmo.isHabit,
                reminderTime: coreDataRitmo.reminderTime,
                eventDate: coreDataRitmo.eventDate,
                createdDate: coreDataRitmo.createdDate ?? Date(),
                archivedDate: coreDataRitmo.archivedDate,
                isArchived: coreDataRitmo.isArchived
            )
        }
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension RitmoStore: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
        insertedIndexes.removeAll()
        deletedIndexes.removeAll()
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
        delegate?.didUpdate(
            RitmoStoreUpdate(
                insertedIndexes: insertedIndexes,
                deletedIndexes: deletedIndexes
            )
        )
    }
    
    func controller(
        _ controller: NSFetchedResultsController<any NSFetchRequestResult>,
        didChange anObject: Any,
        at indexPath: IndexPath?,
        for type: NSFetchedResultsChangeType,
        newIndexPath: IndexPath?
    ) {
        switch type {
        case .insert:
            if let newIndexPath = newIndexPath {
                insertedIndexes.insert(newIndexPath.item)
            }
        case .delete:
            if let indexPath = indexPath {
                deletedIndexes.insert(indexPath.item)
            }
        default:
            break
        }
    }
}

// MARK: - Extensions

extension RitmoStore {
    func updateRitmo(original: Ritmo, with updated: Ritmo, category: RitmoCategory) {
        let request: NSFetchRequest<RitmoCoreData> = RitmoCoreData.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", original.id as CVarArg)
        
        do {
            guard let ritmoCoreData = try context.fetch(request).first else {
                print("Не удалось найти трекер для обновления")
                return
            }
            ritmoCoreData.name = updated.name
            ritmoCoreData.emoji = updated.emoji
            ritmoCoreData.isHabit = updated.isHabit
            ritmoCoreData.reminderTime = updated.reminderTime
            ritmoCoreData.eventDate = updated.eventDate
            ritmoCoreData.createdDate = updated.createdDate
            ritmoCoreData.archivedDate = updated.archivedDate
            ritmoCoreData.isArchived = updated.isArchived
            
            if let colorString = updated.color.toHexString() {
                ritmoCoreData.color = colorString
            } else {
                print("Ошибка преобразования цвета в строку")
                ritmoCoreData.color = ""
            }
            
            if let scheduleString = Weekday.encodeSchedule(updated.schedule) {
                ritmoCoreData.schedule = scheduleString
            } else {
                print("Ошибка кодирования расписания")
                ritmoCoreData.schedule = ""
            }
            let categoryRequest = NSFetchRequest<RitmoCategoryCoreData>(entityName: "RitmoCategoryCoreData")
            categoryRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(RitmoCategoryCoreData.title), category.title)
            
            let results = try context.fetch(categoryRequest)
            let categoryCoreData: RitmoCategoryCoreData
            
            if let existingCategory = results.first {
                categoryCoreData = existingCategory
            } else {
                categoryCoreData = RitmoCategoryCoreData(context: context)
                categoryCoreData.title = category.title
            }
            
            ritmoCoreData.ritmoCategory = categoryCoreData
            
            CoreDataManager.shared.saveContext()
            
        } catch {
            print("Ошибка при обновлении трекера: \(error)")
        }
    }
    
    func deleteRitmo(_ ritmo: Ritmo) {
        let ritmoRequest: NSFetchRequest<RitmoCoreData> = RitmoCoreData.fetchRequest()
        ritmoRequest.predicate = NSPredicate(format: "id == %@", ritmo.id as CVarArg)
        
        do {
            if let ritmoCoreData = try context.fetch(ritmoRequest).first {
                ReminderNotificationService.shared.removeReminder(for: ritmo.id)
                let recordRequest: NSFetchRequest<RitmoRecordCoreData> = RitmoRecordCoreData.fetchRequest()
                recordRequest.predicate = NSPredicate(format: "id == %@", ritmo.id as CVarArg)
                
                let relatedRecords = try context.fetch(recordRequest)
                for record in relatedRecords {
                    context.delete(record)
                }

                context.delete(ritmoCoreData)
                
                try context.save()
                context.processPendingChanges()
            } else {
                print("Трекер для удаления не найден")
            }
        } catch {
            print("Ошибка при удалении трекера: \(error)")
        }
    }

    func setArchived(_ isArchived: Bool, ritmo: Ritmo, archivedDate: Date = Date()) {
        let request: NSFetchRequest<RitmoCoreData> = RitmoCoreData.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", ritmo.id as CVarArg)

        do {
            guard let ritmoCoreData = try context.fetch(request).first else {
                print("Трекер для архивации не найден")
                return
            }

            ritmoCoreData.isArchived = isArchived
            ritmoCoreData.archivedDate = isArchived ? archivedDate : nil
            if ritmoCoreData.createdDate == nil {
                ritmoCoreData.createdDate = earliestRecordDate(for: ritmo.id) ?? archivedDate
            }

            if isArchived {
                ReminderNotificationService.shared.removeReminder(for: ritmo.id)
            }

            CoreDataManager.shared.saveContext()
            try? fetchedResultsController.performFetch()

            if !isArchived, let updatedRitmo = self.ritmo(with: ritmo.id) {
                ReminderNotificationService.shared.scheduleReminder(
                    for: updatedRitmo,
                    completedRecords: RitmoRecordStore().fetch()
                )
            }
        } catch {
            print("Ошибка при изменении архива трекера: \(error)")
        }
    }

    private func earliestRecordDate(for ritmoID: UUID) -> Date? {
        let request: NSFetchRequest<RitmoRecordCoreData> = RitmoRecordCoreData.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", ritmoID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        request.fetchLimit = 1

        return try? context.fetch(request).first?.date
    }

}
