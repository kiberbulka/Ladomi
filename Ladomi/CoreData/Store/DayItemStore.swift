import UIKit
import CoreData

protocol DayItemStoreDelegate: AnyObject {
    func didUpdate(_ update: DayItemStoreUpdate)
}

struct DayItemStoreUpdate {
    let insertedIndexes: IndexSet
    let deletedIndexes: IndexSet
}

final class DayItemStore: NSObject {
    
    // MARK: - Private properties
    
    private var insertedIndexes: IndexSet = []
    private var deletedIndexes: IndexSet = []
    
    private let context = CoreDataManager.shared.viewContext
    private var fetchedResultsController: NSFetchedResultsController<DayItemCoreData>
    
    // MARK: - Public properties
    
    weak var delegate: DayItemStoreDelegate?
    
    // MARK: - Initializers
    
    override init() {
        let fetchRequest: NSFetchRequest<DayItemCoreData> = DayItemCoreData.fetchRequest()
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
            print("Failed to fetch dayItems: \(error)")
        }
    }
    
    // MARK: - Public Methods
    
    func numberOfSections() -> Int {
        fetchedResultsController.sections?.count ?? 0
    }
    
    func numberOfItems(in section: Int) -> Int {
        fetchedResultsController.sections?[section].numberOfObjects ?? 0
    }
    
    func addDayItem(dayItem: DayItem, category: DayItemCategory?) {
        let dayItemCoreData = DayItemCoreData(context: context)
        
        if let category = category {
            let request = NSFetchRequest<DayItemCategoryCoreData>(entityName: "DayItemCategoryCoreData")
            request.predicate = NSPredicate(format: "%K == %@", #keyPath(DayItemCategoryCoreData.title), category.title)
            
            do {
                let results = try context.fetch(request)
                if let existingCategory = results.first {
                    dayItemCoreData.dayItemCategory = existingCategory
                } else {
                    let dayItemCategoryCoreData = DayItemCategoryCoreData(context: context)
                    dayItemCategoryCoreData.title = category.title
                    dayItemCoreData.dayItemCategory = dayItemCategoryCoreData
                    CoreDataManager.shared.saveContext()
                }
            } catch {
                print("Error fetching or creating category: \(error)")
            }
        }

        dayItemCoreData.name = dayItem.name
        dayItemCoreData.id = dayItem.id
        dayItemCoreData.emoji = dayItem.emoji
        dayItemCoreData.reminderTime = dayItem.reminderTime
        dayItemCoreData.eventDate = dayItem.eventDate
        dayItemCoreData.createdDate = dayItem.createdDate
        dayItemCoreData.archivedDate = dayItem.archivedDate
        dayItemCoreData.isArchived = dayItem.isArchived
        dayItemCoreData.isStopList = dayItem.isStopList
        
        if let colorString = dayItem.color.toHexString() {
            dayItemCoreData.color = colorString
        } else {
            print("Ошибка преобразования цвета в строку")
            dayItemCoreData.color = ""
        }
        
        dayItemCoreData.isHabit = dayItem.isHabit
        
        if let scheduleString = Weekday.encodeSchedule(dayItem.schedule) {
            dayItemCoreData.schedule = scheduleString
        } else {
            print("Ошибка кодирования расписания")
            dayItemCoreData.schedule = ""
        }
        
        CoreDataManager.shared.saveContext()
    }
    
    func dayItem(with id: UUID) -> DayItem? {
        return fetchDayItems().first { $0.id == id }
    }
    
    func fetchDayItems() -> [DayItem] {
        guard let objects = fetchedResultsController.fetchedObjects else { return [] }
        return objects.map { coreDataDayItem in
            let scheduleString = coreDataDayItem.schedule ?? ""
            let schedule: [Weekday] = Weekday.decodeSchedule(from: scheduleString) ?? []
            
            return DayItem(
                id: coreDataDayItem.id ?? UUID(),
                name: coreDataDayItem.name ?? "",
                color: UIColor(hex: coreDataDayItem.color ?? "#FFFFFF") ?? .gray,
                emoji: coreDataDayItem.emoji ?? "",
                schedule: schedule,
                isHabit: coreDataDayItem.isHabit,
                reminderTime: coreDataDayItem.reminderTime,
                eventDate: coreDataDayItem.eventDate,
                createdDate: coreDataDayItem.createdDate ?? Date(),
                archivedDate: coreDataDayItem.archivedDate,
                isArchived: coreDataDayItem.isArchived,
                isStopList: coreDataDayItem.isStopList
            )
        }
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension DayItemStore: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
        insertedIndexes.removeAll()
        deletedIndexes.removeAll()
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
        delegate?.didUpdate(
            DayItemStoreUpdate(
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

extension DayItemStore {
    func updateDayItem(original: DayItem, with updated: DayItem, category: DayItemCategory?) {
        let request: NSFetchRequest<DayItemCoreData> = DayItemCoreData.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", original.id as CVarArg)
        
        do {
            guard let dayItemCoreData = try context.fetch(request).first else {
                print("Не удалось найти ритм для обновления")
                return
            }
            dayItemCoreData.name = updated.name
            dayItemCoreData.emoji = updated.emoji
            dayItemCoreData.isHabit = updated.isHabit
            dayItemCoreData.reminderTime = updated.reminderTime
            dayItemCoreData.eventDate = updated.eventDate
            dayItemCoreData.createdDate = updated.createdDate
            dayItemCoreData.archivedDate = updated.archivedDate
            dayItemCoreData.isArchived = updated.isArchived
            dayItemCoreData.isStopList = updated.isStopList
            
            if let colorString = updated.color.toHexString() {
                dayItemCoreData.color = colorString
            } else {
                print("Ошибка преобразования цвета в строку")
                dayItemCoreData.color = ""
            }
            
            if let scheduleString = Weekday.encodeSchedule(updated.schedule) {
                dayItemCoreData.schedule = scheduleString
            } else {
                print("Ошибка кодирования расписания")
                dayItemCoreData.schedule = ""
            }
            if let category = category {
                let categoryRequest = NSFetchRequest<DayItemCategoryCoreData>(entityName: "DayItemCategoryCoreData")
                categoryRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(DayItemCategoryCoreData.title), category.title)
                
                let results = try context.fetch(categoryRequest)
                let categoryCoreData: DayItemCategoryCoreData
                
                if let existingCategory = results.first {
                    categoryCoreData = existingCategory
                } else {
                    categoryCoreData = DayItemCategoryCoreData(context: context)
                    categoryCoreData.title = category.title
                }
                
                dayItemCoreData.dayItemCategory = categoryCoreData
            } else {
                dayItemCoreData.dayItemCategory = nil
            }
            
            CoreDataManager.shared.saveContext()
            
        } catch {
            print("Ошибка при обновлении ритма: \(error)")
        }
    }
    
    func deleteDayItem(_ dayItem: DayItem) {
        let dayItemRequest: NSFetchRequest<DayItemCoreData> = DayItemCoreData.fetchRequest()
        dayItemRequest.predicate = NSPredicate(format: "id == %@", dayItem.id as CVarArg)
        
        do {
            if let dayItemCoreData = try context.fetch(dayItemRequest).first {
                ReminderNotificationService.shared.removeReminder(for: dayItem.id)
                let recordRequest: NSFetchRequest<DayItemRecordCoreData> = DayItemRecordCoreData.fetchRequest()
                recordRequest.predicate = NSPredicate(format: "id == %@", dayItem.id as CVarArg)
                
                let relatedRecords = try context.fetch(recordRequest)
                for record in relatedRecords {
                    context.delete(record)
                }

                context.delete(dayItemCoreData)
                
                try context.save()
                context.processPendingChanges()
            } else {
                print("Ритм для удаления не найден")
            }
        } catch {
            print("Ошибка при удалении ритма: \(error)")
        }
    }

    func setArchived(_ isArchived: Bool, dayItem: DayItem, archivedDate: Date = Date()) {
        let request: NSFetchRequest<DayItemCoreData> = DayItemCoreData.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", dayItem.id as CVarArg)

        do {
            guard let dayItemCoreData = try context.fetch(request).first else {
                print("Ритм для архивации не найден")
                return
            }

            dayItemCoreData.isArchived = isArchived
            dayItemCoreData.archivedDate = isArchived ? archivedDate : nil
            if dayItemCoreData.createdDate == nil {
                dayItemCoreData.createdDate = earliestRecordDate(for: dayItem.id) ?? archivedDate
            }

            if isArchived {
                ReminderNotificationService.shared.removeReminder(for: dayItem.id)
            }

            CoreDataManager.shared.saveContext()
            try? fetchedResultsController.performFetch()

            if !isArchived, let updatedDayItem = self.dayItem(with: dayItem.id) {
                ReminderNotificationService.shared.scheduleReminder(
                    for: updatedDayItem,
                    completedRecords: DayItemRecordStore().fetch()
                )
            }
        } catch {
            print("Ошибка при изменении архива ритма: \(error)")
        }
    }

    private func earliestRecordDate(for dayItemID: UUID) -> Date? {
        let request: NSFetchRequest<DayItemRecordCoreData> = DayItemRecordCoreData.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", dayItemID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        request.fetchLimit = 1

        return try? context.fetch(request).first?.date
    }

}
