//
//  StatisticsService.swift
//  Tracker
//
//  Created by Olya on 17.05.2025.
//
import CoreData
import Foundation

struct StatisticsData {
    let longestStreak: Int
    let currentStreak: Int
    let perfectDays: Int
    let completedCount: Int
    let completedToday: Int
    let completedThisWeek: Int
    let completedThisMonth: Int
    let averagePerDay: Int
    let completionRate: Int
    let activeTrackersCount: Int
}

struct AnalyticsInsight {
    let title: String
    let value: String
    let detail: String
}

struct AnalyticsData {
    let analyzedDays: Int
    let moodDays: Int
    let averageCompletionRate: Int
    let insights: [AnalyticsInsight]
}

final class StatisticsService {
    private struct DayMetric {
        let date: Date
        let plannedCount: Int
        let completedCount: Int
        let mood: Mood?

        var completionRate: Double {
            guard plannedCount > 0 else {
                return 0
            }

            return Double(completedCount) / Double(plannedCount)
        }

        var weekdayIndex: Int {
            let weekday = Calendar.current.component(.weekday, from: date)
            return weekday == 1 ? 7 : weekday - 1
        }
    }

    private enum Mood: String, Hashable {
        case great
        case good
        case calm
        case tired
        case bad

        var score: Int {
            switch self {
            case .great: return 5
            case .good: return 4
            case .calm: return 3
            case .tired: return 2
            case .bad: return 1
            }
        }

        var emoji: String {
            switch self {
            case .great: return "🤩"
            case .good: return "🙂"
            case .calm: return "😌"
            case .tired: return "🥱"
            case .bad: return "😞"
            }
        }
    }
    
    // MARK: - Private Properties
    
    private let trackerStore: TrackerStore
    private let trackerRecordStore: TrackerRecordStore
    private let calendar = Calendar.current
    private let moodStorageKey = "tracker.dayMoodByDate"

    private lazy var moodDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    // MARK: - Initializers
    
    init(trackerStore: TrackerStore, trackerRecordStore: TrackerRecordStore) {
        self.trackerStore = trackerStore
        self.trackerRecordStore = trackerRecordStore
    }
    
    convenience init() {
        self.init(trackerStore: TrackerStore(), trackerRecordStore: TrackerRecordStore())
    }
    
    // MARK: - Public Methods
    
    func fetchStatistics() -> StatisticsData {
        let trackers = trackerStore.fetchTrackers().filter { !$0.isArchived }
        let trackerIDs = Set(trackers.map { $0.id })
        
        let records = trackerRecordStore.fetch().filter { trackerIDs.contains($0.trackerID) }
        
        let groupedByDate = Dictionary(grouping: records) { calendar.startOfDay(for: $0.date) }
        
        let completedCount = records.count
        let today = calendar.startOfDay(for: Date())
        let completedToday = records.filter { calendar.isDate($0.date, inSameDayAs: today) }.count
        let completedThisWeek = recordsCount(in: calendar.dateInterval(of: .weekOfYear, for: today), records: records)
        let completedThisMonth = recordsCount(in: calendar.dateInterval(of: .month, for: today), records: records)
        
        let uniqueDaysCount = groupedByDate.keys.count
        let averagePerDay = uniqueDaysCount == 0 ? 0 : Int(round(Double(completedCount) / Double(uniqueDaysCount)))

        let eventCompletionDates = makeEventCompletionDates(trackers: trackers, records: records)
        let periodStart = statisticsPeriodStart(trackers: trackers, records: records, today: today)
        let periodDates = dates(from: periodStart, through: today)
        let perfectDays = periodDates.filter {
            isPerfectDay($0, trackers: trackers, recordsByDate: groupedByDate, eventCompletionDates: eventCompletionDates, today: today)
        }.count
        let longestStreak = longestPerfectDaysStreak(
            dates: periodDates,
            trackers: trackers,
            recordsByDate: groupedByDate,
            eventCompletionDates: eventCompletionDates,
            today: today
        )
        let currentStreak = currentPerfectDaysStreak(
            dates: periodDates.reversed(),
            trackers: trackers,
            recordsByDate: groupedByDate,
            eventCompletionDates: eventCompletionDates,
            today: today
        )
        let plannedCompletions = periodDates.reduce(0) { result, date in
            result + activeTrackerIDs(on: date, trackers: trackers, eventCompletionDates: eventCompletionDates, today: today).count
        }
        let completionRate = plannedCompletions == 0 ? 0 : Int(round(Double(completedCount) / Double(plannedCompletions) * 100))
        
        return StatisticsData(
            longestStreak: longestStreak,
            currentStreak: currentStreak,
            perfectDays: perfectDays,
            completedCount: completedCount,
            completedToday: completedToday,
            completedThisWeek: completedThisWeek,
            completedThisMonth: completedThisMonth,
            averagePerDay: averagePerDay,
            completionRate: completionRate,
            activeTrackersCount: trackers.count
        )
    }

    func fetchAnalytics() -> AnalyticsData {
        let trackers = trackerStore.fetchTrackers()
        let trackerIDs = Set(trackers.map { $0.id })
        let records = trackerRecordStore.fetch().filter { trackerIDs.contains($0.trackerID) }
        let today = calendar.startOfDay(for: Date())
        let periodStart = statisticsPeriodStart(trackers: trackers, records: records, today: today)
        let periodDates = dates(from: periodStart, through: today)
        let recordsByDate = Dictionary(grouping: records) { calendar.startOfDay(for: $0.date) }
        let eventCompletionDates = makeEventCompletionDates(trackers: trackers, records: records)
        let trackerStartDates = makeTrackerStartDates(trackers: trackers, records: records)
        let moodsByDate = fetchMoodsByDate()

        let metrics = periodDates.map { date in
            let plannedIDs = plannedTrackerIDs(
                on: date,
                trackers: trackers,
                eventCompletionDates: eventCompletionDates,
                trackerStartDates: trackerStartDates,
                today: today
            )
            let completedIDs = Set(recordsByDate[date, default: []].map { $0.trackerID })
            let completedPlannedCount = completedIDs.intersection(plannedIDs).count

            return DayMetric(
                date: date,
                plannedCount: plannedIDs.count,
                completedCount: completedPlannedCount,
                mood: moodsByDate[moodKey(for: date)]
            )
        }

        let plannedMetrics = metrics.filter { $0.plannedCount > 0 }
        let moodMetrics = plannedMetrics.filter { $0.mood != nil }
        let averageCompletionRate = percentage(averageRate(for: plannedMetrics))

        return AnalyticsData(
            analyzedDays: plannedMetrics.count,
            moodDays: moodMetrics.count,
            averageCompletionRate: averageCompletionRate,
            insights: makeInsights(metrics: plannedMetrics, moodMetrics: moodMetrics)
        )
    }

    private func recordsCount(in interval: DateInterval?, records: [TrackerRecord]) -> Int {
        guard let interval = interval else {
            return 0
        }

        return records.filter { interval.contains($0.date) }.count
    }

    private func statisticsPeriodStart(trackers: [Tracker], records: [TrackerRecord], today: Date) -> Date {
        let recordDates = records.map { calendar.startOfDay(for: $0.date) }
        let eventDates = trackers.compactMap { tracker -> Date? in
            guard !tracker.isHabit, let eventDate = tracker.eventDate else {
                return nil
            }

            return calendar.startOfDay(for: eventDate)
        }

        return (recordDates + eventDates).min() ?? today
    }

    private func dates(from startDate: Date, through endDate: Date) -> [Date] {
        var dates: [Date] = []
        var date = calendar.startOfDay(for: startDate)
        let endDate = calendar.startOfDay(for: endDate)

        while date <= endDate {
            dates.append(date)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else {
                break
            }
            date = nextDate
        }

        return dates
    }

    private func makeEventCompletionDates(trackers: [Tracker], records: [TrackerRecord]) -> [UUID: Date] {
        let eventIDs = Set(trackers.filter { !$0.isHabit }.map { $0.id })
        let eventRecords = records.filter { eventIDs.contains($0.trackerID) }

        return Dictionary(grouping: eventRecords, by: { $0.trackerID }).compactMapValues { records in
            records
                .map { calendar.startOfDay(for: $0.date) }
                .sorted()
                .first
        }
    }

    private func isPerfectDay(
        _ date: Date,
        trackers: [Tracker],
        recordsByDate: [Date: [TrackerRecord]],
        eventCompletionDates: [UUID: Date],
        today: Date
    ) -> Bool {
        let activeIDs = activeTrackerIDs(on: date, trackers: trackers, eventCompletionDates: eventCompletionDates, today: today)
        guard !activeIDs.isEmpty else {
            return false
        }

        let completedIDs = Set(recordsByDate[calendar.startOfDay(for: date), default: []].map { $0.trackerID })
        return activeIDs.isSubset(of: completedIDs)
    }

    private func longestPerfectDaysStreak(
        dates: [Date],
        trackers: [Tracker],
        recordsByDate: [Date: [TrackerRecord]],
        eventCompletionDates: [UUID: Date],
        today: Date
    ) -> Int {
        var currentStreak = 0
        var longestStreak = 0

        for date in dates {
            if isPerfectDay(date, trackers: trackers, recordsByDate: recordsByDate, eventCompletionDates: eventCompletionDates, today: today) {
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)
            } else {
                currentStreak = 0
            }
        }

        return longestStreak
    }

    private func currentPerfectDaysStreak(
        dates: ReversedCollection<[Date]>,
        trackers: [Tracker],
        recordsByDate: [Date: [TrackerRecord]],
        eventCompletionDates: [UUID: Date],
        today: Date
    ) -> Int {
        var currentStreak = 0

        for date in dates {
            guard isPerfectDay(date, trackers: trackers, recordsByDate: recordsByDate, eventCompletionDates: eventCompletionDates, today: today) else {
                break
            }
            currentStreak += 1
        }

        return currentStreak
    }

    private func activeTrackerIDs(
        on date: Date,
        trackers: [Tracker],
        eventCompletionDates: [UUID: Date],
        today: Date
    ) -> Set<UUID> {
        let startOfDay = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: today)
        let activeIDs = trackers.compactMap { tracker -> UUID? in
            if tracker.isHabit {
                return isHabit(tracker, activeOn: startOfDay) ? tracker.id : nil
            }

            return isEvent(tracker, activeOn: startOfDay, eventCompletionDates: eventCompletionDates, today: today) ? tracker.id : nil
        }

        return Set(activeIDs)
    }

    private func plannedTrackerIDs(
        on date: Date,
        trackers: [Tracker],
        eventCompletionDates: [UUID: Date],
        trackerStartDates: [UUID: Date],
        today: Date
    ) -> Set<UUID> {
        let startOfDay = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: today)
        let plannedIDs = trackers.compactMap { tracker -> UUID? in
            guard isTrackerAvailable(tracker, on: startOfDay, trackerStartDates: trackerStartDates) else {
                return nil
            }

            if tracker.isHabit {
                return isHabit(tracker, activeOn: startOfDay) ? tracker.id : nil
            }

            return isEventPlanned(tracker, on: startOfDay, eventCompletionDates: eventCompletionDates, today: today) ? tracker.id : nil
        }

        return Set(plannedIDs)
    }

    private func isTrackerAvailable(_ tracker: Tracker, on date: Date, trackerStartDates: [UUID: Date]) -> Bool {
        let startOfDay = calendar.startOfDay(for: date)
        let createdDate = calendar.startOfDay(for: trackerStartDates[tracker.id] ?? tracker.createdDate)

        if startOfDay < createdDate {
            return false
        }

        guard let archivedDate = tracker.archivedDate else {
            return true
        }

        return startOfDay <= calendar.startOfDay(for: archivedDate)
    }

    private func makeTrackerStartDates(trackers: [Tracker], records: [TrackerRecord]) -> [UUID: Date] {
        let recordsByTracker = Dictionary(grouping: records) { $0.trackerID }

        return Dictionary(uniqueKeysWithValues: trackers.map { tracker in
            let recordDates = recordsByTracker[tracker.id, default: []].map { calendar.startOfDay(for: $0.date) }
            let createdDate = calendar.startOfDay(for: tracker.createdDate)
            var candidateDates = [createdDate]
            if let eventDate = tracker.eventDate {
                candidateDates.append(calendar.startOfDay(for: eventDate))
            }
            candidateDates.append(contentsOf: recordDates)
            let startDate = candidateDates.min() ?? createdDate
            return (tracker.id, startDate)
        })
    }

    private func isHabit(_ tracker: Tracker, activeOn date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
        return tracker.schedule.contains { $0.numberValue == adjustedWeekday }
    }

    private func isEvent(_ tracker: Tracker, activeOn date: Date, eventCompletionDates: [UUID: Date], today: Date) -> Bool {
        if let completionDate = eventCompletionDates[tracker.id] {
            return calendar.isDate(completionDate, inSameDayAs: date)
        }

        let eventDate = calendar.startOfDay(for: tracker.eventDate ?? today)
        let activeDate = eventDate < today ? today : eventDate
        return calendar.isDate(activeDate, inSameDayAs: date)
    }

    private func isEventPlanned(_ tracker: Tracker, on date: Date, eventCompletionDates: [UUID: Date], today: Date) -> Bool {
        let startOfDay = calendar.startOfDay(for: date)
        let eventDate = calendar.startOfDay(for: tracker.eventDate ?? today)

        guard eventDate <= startOfDay else {
            return false
        }

        if let completionDate = eventCompletionDates[tracker.id] {
            return startOfDay <= calendar.startOfDay(for: completionDate)
        }

        return startOfDay <= today
    }

    private func fetchMoodsByDate() -> [String: Mood] {
        let rawMoods = UserDefaults.standard.dictionary(forKey: moodStorageKey) as? [String: String] ?? [:]
        return rawMoods.compactMapValues { Mood(rawValue: $0) }
    }

    private func moodKey(for date: Date) -> String {
        moodDateFormatter.string(from: date)
    }

    private func makeInsights(metrics: [DayMetric], moodMetrics: [DayMetric]) -> [AnalyticsInsight] {
        guard !metrics.isEmpty else {
            return []
        }

        var insights: [AnalyticsInsight] = [
            makeOverviewInsight(metrics: metrics)
        ]

        if let moodInsight = makeMoodInsight(metrics: moodMetrics) {
            insights.append(moodInsight)
        } else {
            insights.append(
                AnalyticsInsight(
                    title: NSLocalizedString("analytics.noMood.title", comment: "No mood data title"),
                    value: NSLocalizedString("analytics.noMood.value", comment: "No mood data value"),
                    detail: NSLocalizedString("analytics.noMood.detail", comment: "No mood data detail")
                )
            )
        }

        if let loadInsight = makeLoadInsight(metrics: metrics) {
            insights.append(loadInsight)
        }

        if let weekdayInsight = makeWeekdayInsight(metrics: metrics) {
            insights.append(weekdayInsight)
        }

        insights.append(makeAdviceInsight(metrics: metrics, moodMetrics: moodMetrics))
        return insights
    }

    private func makeOverviewInsight(metrics: [DayMetric]) -> AnalyticsInsight {
        let plannedTotal = metrics.reduce(0) { $0 + $1.plannedCount }
        let completedTotal = metrics.reduce(0) { $0 + $1.completedCount }
        let averageRate = percentage(Double(completedTotal) / Double(max(plannedTotal, 1)))
        let format = NSLocalizedString("analytics.overview.detail", comment: "Analytics overview detail")

        return AnalyticsInsight(
            title: NSLocalizedString("analytics.overview.title", comment: "Analytics overview title"),
            value: "\(averageRate)%",
            detail: String(format: format, metrics.count, completedTotal, plannedTotal)
        )
    }

    private func makeMoodInsight(metrics: [DayMetric]) -> AnalyticsInsight? {
        let grouped = Dictionary(grouping: metrics) { $0.mood }
        let groups = grouped.compactMap { mood, metrics -> (mood: Mood, rate: Double, count: Int)? in
            guard let mood = mood, metrics.count >= 2 else {
                return nil
            }

            return (mood, averageRate(for: metrics), metrics.count)
        }

        guard let best = groups.max(by: { $0.rate < $1.rate }) else {
            return nil
        }

        let worst = groups.min(by: { $0.rate < $1.rate })
        let value = "\(best.mood.emoji) \(percentage(best.rate))%"

        if let worst = worst, worst.mood != best.mood {
            let format = NSLocalizedString("analytics.mood.detailWithWorst", comment: "Mood analytics detail with worst mood")
            return AnalyticsInsight(
                title: NSLocalizedString("analytics.mood.title", comment: "Mood analytics title"),
                value: value,
                detail: String(format: format, best.mood.emoji, percentage(best.rate), worst.mood.emoji, percentage(worst.rate))
            )
        }

        let format = NSLocalizedString("analytics.mood.detail", comment: "Mood analytics detail")
        return AnalyticsInsight(
            title: NSLocalizedString("analytics.mood.title", comment: "Mood analytics title"),
            value: value,
            detail: String(format: format, best.mood.emoji, percentage(best.rate))
        )
    }

    private func makeLoadInsight(metrics: [DayMetric]) -> AnalyticsInsight? {
        guard metrics.count >= 4 else {
            return nil
        }

        let averagePlan = Double(metrics.reduce(0) { $0 + $1.plannedCount }) / Double(metrics.count)
        let heavyDays = metrics.filter { Double($0.plannedCount) > averagePlan }
        let lightDays = metrics.filter { Double($0.plannedCount) <= averagePlan }

        guard !heavyDays.isEmpty, !lightDays.isEmpty else {
            return nil
        }

        let heavyRate = averageRate(for: heavyDays)
        let lightRate = averageRate(for: lightDays)
        let difference = percentage(abs(lightRate - heavyRate))
        let value = heavyRate < lightRate ? "-\(difference)%" : "+\(difference)%"
        let format = heavyRate < lightRate
            ? NSLocalizedString("analytics.load.detailHeavy", comment: "Heavy load analytics detail")
            : NSLocalizedString("analytics.load.detailStable", comment: "Stable load analytics detail")

        return AnalyticsInsight(
            title: NSLocalizedString("analytics.load.title", comment: "Load analytics title"),
            value: value,
            detail: String(format: format, Int(ceil(averagePlan)), percentage(heavyRate), percentage(lightRate))
        )
    }

    private func makeWeekdayInsight(metrics: [DayMetric]) -> AnalyticsInsight? {
        let grouped = Dictionary(grouping: metrics) { $0.weekdayIndex }
        let groups = grouped.compactMap { weekday, metrics -> (weekday: Int, rate: Double, count: Int)? in
            guard metrics.count >= 2 else {
                return nil
            }

            return (weekday, averageRate(for: metrics), metrics.count)
        }

        guard let best = groups.max(by: { $0.rate < $1.rate }) else {
            return nil
        }

        let format = NSLocalizedString("analytics.weekday.detail", comment: "Weekday analytics detail")
        return AnalyticsInsight(
            title: NSLocalizedString("analytics.weekday.title", comment: "Weekday analytics title"),
            value: weekdayName(for: best.weekday),
            detail: String(format: format, weekdayName(for: best.weekday), percentage(best.rate))
        )
    }

    private func makeAdviceInsight(metrics: [DayMetric], moodMetrics: [DayMetric]) -> AnalyticsInsight {
        let tiredMetrics = moodMetrics.filter { ($0.mood?.score ?? 0) <= 2 }
        if tiredMetrics.count >= 2, averageRate(for: tiredMetrics) < averageRate(for: metrics) {
            return AnalyticsInsight(
                title: NSLocalizedString("analytics.advice.title", comment: "Advice analytics title"),
                value: NSLocalizedString("analytics.advice.tired.value", comment: "Tired advice value"),
                detail: NSLocalizedString("analytics.advice.tired.detail", comment: "Tired advice detail")
            )
        }

        let averagePlan = Double(metrics.reduce(0) { $0 + $1.plannedCount }) / Double(metrics.count)
        let heavyDays = metrics.filter { Double($0.plannedCount) > averagePlan }
        if !heavyDays.isEmpty, averageRate(for: heavyDays) < averageRate(for: metrics) {
            return AnalyticsInsight(
                title: NSLocalizedString("analytics.advice.title", comment: "Advice analytics title"),
                value: NSLocalizedString("analytics.advice.load.value", comment: "Load advice value"),
                detail: NSLocalizedString("analytics.advice.load.detail", comment: "Load advice detail")
            )
        }

        return AnalyticsInsight(
            title: NSLocalizedString("analytics.advice.title", comment: "Advice analytics title"),
            value: NSLocalizedString("analytics.advice.stable.value", comment: "Stable advice value"),
            detail: NSLocalizedString("analytics.advice.stable.detail", comment: "Stable advice detail")
        )
    }

    private func averageRate(for metrics: [DayMetric]) -> Double {
        guard !metrics.isEmpty else {
            return 0
        }

        let totalPlanned = metrics.reduce(0) { $0 + $1.plannedCount }
        let totalCompleted = metrics.reduce(0) { $0 + $1.completedCount }
        guard totalPlanned > 0 else {
            return 0
        }

        return Double(totalCompleted) / Double(totalPlanned)
    }

    private func percentage(_ value: Double) -> Int {
        Int(round(value * 100))
    }

    private func weekdayName(for weekday: Int) -> String {
        let weekdays = [
            NSLocalizedString("Monday", comment: "Monday"),
            NSLocalizedString("Tuesday", comment: "Tuesday"),
            NSLocalizedString("Wednesday", comment: "Wednesday"),
            NSLocalizedString("Thursday", comment: "Thursday"),
            NSLocalizedString("Friday", comment: "Friday"),
            NSLocalizedString("Saturday", comment: "Saturday"),
            NSLocalizedString("Sunday", comment: "Sunday")
        ]

        guard weekdays.indices.contains(weekday - 1) else {
            return ""
        }

        return weekdays[weekday - 1]
    }
}
