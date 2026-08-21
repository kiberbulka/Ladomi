//
//  TrackerStore.swift
//  Tracker
//
//  Created by Olya on 19.04.2025.
//

import UIKit
import CoreData

protocol TrackerStoreDelegate: AnyObject {
    func didUpdate(_ update: TrackerStoreUpdate)
}

struct TrackerStoreUpdate {
    let insertedIndexes: IndexSet
    let deletedIndexes: IndexSet
}

final class TrackerStore: NSObject {
    
    // MARK: - Private properties
    
    private var insertedIndexes: IndexSet = []
    private var deletedIndexes: IndexSet = []
    
    private let context = CoreDataManager.shared.viewContext
    private var fetchedResultsController: NSFetchedResultsController<TrackerCoreData>
    
    // MARK: - Public properties
    
    weak var delegate: TrackerStoreDelegate?
    
    // MARK: - Initializers
    
    override init() {
        let fetchRequest: NSFetchRequest<TrackerCoreData> = TrackerCoreData.fetchRequest()
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
            print("Failed to fetch trackers: \(error)")
        }
    }
    
    // MARK: - Public Methods
    
    func numberOfSections() -> Int {
        fetchedResultsController.sections?.count ?? 0
    }
    
    func numberOfItems(in section: Int) -> Int {
        fetchedResultsController.sections?[section].numberOfObjects ?? 0
    }
    
    func addTracker(tracker: Tracker, category: TrackerCategory) {
        let trackerCoreData = TrackerCoreData(context: context)
        
        let request = NSFetchRequest<TrackerCategoryCoreData>(entityName: "TrackerCategoryCoreData")
        request.predicate = NSPredicate(format: "%K == %@", #keyPath(TrackerCategoryCoreData.title), category.title)
        
        var trackerCategoryCoreData: TrackerCategoryCoreData?
        
        do {
            let results = try context.fetch(request)
            if let existingCategory = results.first {
                trackerCategoryCoreData = existingCategory
            } else {
                trackerCategoryCoreData = TrackerCategoryCoreData(context: context)
                trackerCategoryCoreData?.title = category.title
                CoreDataManager.shared.saveContext()
            }
        } catch {
            print("Error fetching or creating category: \(error)")
        }
        trackerCoreData.trackerCategory = trackerCategoryCoreData
        trackerCoreData.name = tracker.name
        trackerCoreData.id = tracker.id
        trackerCoreData.emoji = tracker.emoji
        trackerCoreData.reminderTime = tracker.reminderTime
        trackerCoreData.eventDate = tracker.eventDate
        trackerCoreData.createdDate = tracker.createdDate
        trackerCoreData.archivedDate = tracker.archivedDate
        trackerCoreData.isArchived = tracker.isArchived
        
        if let colorString = tracker.color.toHexString() {
            trackerCoreData.color = colorString
        } else {
            print("Ошибка преобразования цвета в строку")
            trackerCoreData.color = ""
        }
        
        trackerCoreData.isHabit = tracker.isHabit
        
        if let scheduleString = Weekday.encodeSchedule(tracker.schedule) {
            trackerCoreData.schedule = scheduleString
        } else {
            print("Ошибка кодирования расписания")
            trackerCoreData.schedule = ""
        }
        
        CoreDataManager.shared.saveContext()
    }
    
    func tracker(with id: UUID) -> Tracker? {
        return fetchTrackers().first { $0.id == id }
    }
    
    func fetchTrackers() -> [Tracker] {
        guard let objects = fetchedResultsController.fetchedObjects else { return [] }
        return objects.map { coreDataTracker in
            let scheduleString = coreDataTracker.schedule ?? ""
            let schedule: [Weekday] = Weekday.decodeSchedule(from: scheduleString) ?? []
            
            return Tracker(
                id: coreDataTracker.id ?? UUID(),
                name: coreDataTracker.name ?? "",
                color: UIColor(hex: coreDataTracker.color ?? "#FFFFFF") ?? .gray,
                emoji: coreDataTracker.emoji ?? "",
                schedule: schedule,
                isHabit: coreDataTracker.isHabit,
                reminderTime: coreDataTracker.reminderTime,
                eventDate: coreDataTracker.eventDate,
                createdDate: coreDataTracker.createdDate ?? Date(),
                archivedDate: coreDataTracker.archivedDate,
                isArchived: coreDataTracker.isArchived
            )
        }
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension TrackerStore: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
        insertedIndexes.removeAll()
        deletedIndexes.removeAll()
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
        delegate?.didUpdate(
            TrackerStoreUpdate(
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

extension TrackerStore {
    func updateTracker(original: Tracker, with updated: Tracker, category: TrackerCategory) {
        let request: NSFetchRequest<TrackerCoreData> = TrackerCoreData.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", original.id as CVarArg)
        
        do {
            guard let trackerCoreData = try context.fetch(request).first else {
                print("Не удалось найти трекер для обновления")
                return
            }
            trackerCoreData.name = updated.name
            trackerCoreData.emoji = updated.emoji
            trackerCoreData.isHabit = updated.isHabit
            trackerCoreData.reminderTime = updated.reminderTime
            trackerCoreData.eventDate = updated.eventDate
            trackerCoreData.createdDate = updated.createdDate
            trackerCoreData.archivedDate = updated.archivedDate
            trackerCoreData.isArchived = updated.isArchived
            
            if let colorString = updated.color.toHexString() {
                trackerCoreData.color = colorString
            } else {
                print("Ошибка преобразования цвета в строку")
                trackerCoreData.color = ""
            }
            
            if let scheduleString = Weekday.encodeSchedule(updated.schedule) {
                trackerCoreData.schedule = scheduleString
            } else {
                print("Ошибка кодирования расписания")
                trackerCoreData.schedule = ""
            }
            let categoryRequest = NSFetchRequest<TrackerCategoryCoreData>(entityName: "TrackerCategoryCoreData")
            categoryRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(TrackerCategoryCoreData.title), category.title)
            
            let results = try context.fetch(categoryRequest)
            let categoryCoreData: TrackerCategoryCoreData
            
            if let existingCategory = results.first {
                categoryCoreData = existingCategory
            } else {
                categoryCoreData = TrackerCategoryCoreData(context: context)
                categoryCoreData.title = category.title
            }
            
            trackerCoreData.trackerCategory = categoryCoreData
            
            CoreDataManager.shared.saveContext()
            
        } catch {
            print("Ошибка при обновлении трекера: \(error)")
        }
    }
    
    func deleteTracker(_ tracker: Tracker) {
        let trackerRequest: NSFetchRequest<TrackerCoreData> = TrackerCoreData.fetchRequest()
        trackerRequest.predicate = NSPredicate(format: "id == %@", tracker.id as CVarArg)
        
        do {
            if let trackerCoreData = try context.fetch(trackerRequest).first {
                ReminderNotificationService.shared.removeReminder(for: tracker.id)
                let recordRequest: NSFetchRequest<TrackerRecordCoreData> = TrackerRecordCoreData.fetchRequest()
                recordRequest.predicate = NSPredicate(format: "id == %@", tracker.id as CVarArg)
                
                let relatedRecords = try context.fetch(recordRequest)
                for record in relatedRecords {
                    context.delete(record)
                }

                context.delete(trackerCoreData)
                
                try context.save()
                context.processPendingChanges()
            } else {
                print("Трекер для удаления не найден")
            }
        } catch {
            print("Ошибка при удалении трекера: \(error)")
        }
    }

    func setArchived(_ isArchived: Bool, tracker: Tracker, archivedDate: Date = Date()) {
        let request: NSFetchRequest<TrackerCoreData> = TrackerCoreData.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", tracker.id as CVarArg)

        do {
            guard let trackerCoreData = try context.fetch(request).first else {
                print("Трекер для архивации не найден")
                return
            }

            trackerCoreData.isArchived = isArchived
            trackerCoreData.archivedDate = isArchived ? archivedDate : nil
            if trackerCoreData.createdDate == nil {
                trackerCoreData.createdDate = earliestRecordDate(for: tracker.id) ?? archivedDate
            }

            if isArchived {
                ReminderNotificationService.shared.removeReminder(for: tracker.id)
            }

            CoreDataManager.shared.saveContext()
            try? fetchedResultsController.performFetch()

            if !isArchived, let updatedTracker = self.tracker(with: tracker.id) {
                ReminderNotificationService.shared.scheduleReminder(
                    for: updatedTracker,
                    completedRecords: TrackerRecordStore().fetch()
                )
            }
        } catch {
            print("Ошибка при изменении архива трекера: \(error)")
        }
    }

    private func earliestRecordDate(for trackerID: UUID) -> Date? {
        let request: NSFetchRequest<TrackerRecordCoreData> = TrackerRecordCoreData.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", trackerID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        request.fetchLimit = 1

        return try? context.fetch(request).first?.date
    }

}
