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
    let activeDayItemsCount: Int
}

struct AnalyticsInsight {
    let title: String
    let value: String
    let detail: String
}

struct DayItemAttentionItem {
    let dayItemID: UUID
    let name: String
    let emoji: String
    let kind: DayItemAttentionKind
    let missedDays: Int
}

struct AnalyticsData {
    let analyzedDays: Int
    let moodDays: Int
    let averageCompletionRate: Int
    let attentionItems: [DayItemAttentionItem]
    let insights: [AnalyticsInsight]
}

final class StatisticsService {
    private struct DayMetric {
        let date: Date
        let habitPlannedCount: Int
        let habitCompletedCount: Int
        let eventPlannedCount: Int
        let eventCompletedCount: Int
        let mood: Mood?
        let sleepHours: Double?

        var plannedCount: Int {
            habitPlannedCount + eventPlannedCount
        }

        var completedCount: Int {
            habitCompletedCount + eventCompletedCount
        }

        var weekdayIndex: Int {
            let weekday = Calendar.current.component(.weekday, from: date)
            return weekday == 1 ? 7 : weekday - 1
        }
    }

    private struct ComfortLoadCandidate {
        let mood: Mood
        let comfortableLimit: Int
        let comfortableRate: Double
        let overloadedRate: Double

        var completionDrop: Double {
            comfortableRate - overloadedRate
        }
    }

    private struct SleepCandidate {
        let typicalHours: Double
        let shorterSleepRate: Double
        let longerSleepRate: Double

        var improvementAfterLongerSleep: Double {
            longerSleepRate - shorterSleepRate
        }
    }

    private enum Mood: String, Hashable {
        case great
        case good
        case calm
        case tired
        case bad

        var emoji: String {
            switch self {
            case .great: return "🤩"
            case .good: return "🙂"
            case .calm: return "😌"
            case .tired: return "🥱"
            case .bad: return "😞"
            }
        }

        var localizedName: String {
            NSLocalizedString("calendar.mood.\(rawValue)", comment: "Mood name in analytics")
        }
    }
    
    // MARK: - Private Properties
    
    private let dayItemStore: DayItemStore
    private let dayItemRecordStore: DayItemRecordStore
    private let calendar = Calendar.current
    private let moodStorageKey = "dayItem.dayMoodByDate"
    private let postponedDayItemsKey = "postponedDayItemsByDate"
    private let analyticsWindowDays = 28
    private let minimumMoodDays = 5
    private let minimumLoadGroupDays = 2
    private let minimumWeekdayDays = 3
    private let minimumSleepDays = 5
    private let minimumSleepGroupDays = 2
    private let smoothingPriorItems = 5.0
    private let recencyHalfLifeDays = 30.0

    private lazy var moodDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    // MARK: - Initializers
    
    init(dayItemStore: DayItemStore, dayItemRecordStore: DayItemRecordStore) {
        self.dayItemStore = dayItemStore
        self.dayItemRecordStore = dayItemRecordStore
    }
    
    convenience init() {
        self.init(dayItemStore: DayItemStore(), dayItemRecordStore: DayItemRecordStore())
    }
    
    // MARK: - Public Methods
    
    func fetchStatistics() -> StatisticsData {
        let dayItems = dayItemStore.fetchDayItems().filter { !$0.isArchived && !$0.isStopList }
        let dayItemIDs = Set(dayItems.map { $0.id })
        
        let records = dayItemRecordStore.fetch().filter { dayItemIDs.contains($0.dayItemID) }
        
        let groupedByDate = Dictionary(grouping: records) { calendar.startOfDay(for: $0.date) }
        
        let completedCount = records.count
        let today = calendar.startOfDay(for: Date())
        let completedToday = records.filter { calendar.isDate($0.date, inSameDayAs: today) }.count
        let completedThisWeek = recordsCount(in: calendar.dateInterval(of: .weekOfYear, for: today), records: records)
        let completedThisMonth = recordsCount(in: calendar.dateInterval(of: .month, for: today), records: records)
        
        let uniqueDaysCount = groupedByDate.keys.count
        let averagePerDay = uniqueDaysCount == 0 ? 0 : Int(round(Double(completedCount) / Double(uniqueDaysCount)))

        let eventCompletionDates = makeEventCompletionDates(dayItems: dayItems, records: records)
        let periodStart = statisticsPeriodStart(dayItems: dayItems, records: records, today: today)
        let periodDates = dates(from: periodStart, through: today)
        let perfectDays = periodDates.filter {
            isPerfectDay($0, dayItems: dayItems, recordsByDate: groupedByDate, eventCompletionDates: eventCompletionDates, today: today)
        }.count
        let longestStreak = longestPerfectDaysStreak(
            dates: periodDates,
            dayItems: dayItems,
            recordsByDate: groupedByDate,
            eventCompletionDates: eventCompletionDates,
            today: today
        )
        let currentStreak = currentPerfectDaysStreak(
            dates: periodDates.reversed(),
            dayItems: dayItems,
            recordsByDate: groupedByDate,
            eventCompletionDates: eventCompletionDates,
            today: today
        )
        let plannedCompletions = periodDates.reduce(0) { result, date in
            result + activeDayItemIDs(on: date, dayItems: dayItems, eventCompletionDates: eventCompletionDates, today: today).count
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
            activeDayItemsCount: dayItems.count
        )
    }

    func fetchAnalytics(
        sleepHoursByDate: [String: Double] = [:],
        sleepIntegrationEnabled: Bool = false
    ) -> AnalyticsData {
        let allDayItems = dayItemStore.fetchDayItems()
        let dayItems = allDayItems.filter { !$0.isStopList }
        let dayItemIDs = Set(dayItems.map { $0.id })
        let stopListIDs = Set(allDayItems.filter { $0.isStopList }.map { $0.id })
        let allRecords = dayItemRecordStore.fetch()
        let records = allRecords.filter { dayItemIDs.contains($0.dayItemID) }
        let today = calendar.startOfDay(for: Date())
        let postponements = UserDefaults.standard.dictionary(forKey: postponedDayItemsKey) as? [String: String] ?? [:]
        let periodStart = calendar.date(
            byAdding: .day,
            value: -(analyticsWindowDays - 1),
            to: today
        ) ?? today
        let periodDates = dates(from: periodStart, through: today)
        let recordsByDate = Dictionary(grouping: records) { calendar.startOfDay(for: $0.date) }
        let eventCompletionDates = makeEventCompletionDates(dayItems: dayItems, records: records)
        let dayItemStartDates = makeDayItemStartDates(dayItems: dayItems, records: records)
        let moodsByDate = fetchMoodsByDate()
        let stopListSlipCount = allRecords.filter { record in
            guard stopListIDs.contains(record.dayItemID) else {
                return false
            }

            let recordDate = calendar.startOfDay(for: record.date)
            return recordDate >= periodStart && recordDate <= today
        }.count

        let metrics = periodDates.map { date in
            let habitPlannedIDs = analyticsHabitIDs(
                on: date,
                dayItems: dayItems,
                dayItemStartDates: dayItemStartDates,
                postponements: postponements
            )
            let eventPlannedIDs = analyticsEventIDs(
                on: date,
                dayItems: dayItems,
                eventCompletionDates: eventCompletionDates,
                dayItemStartDates: dayItemStartDates,
                postponements: postponements,
                today: today
            )
            let completedIDs = Set(recordsByDate[date, default: []].map { $0.dayItemID })
            let completedHabitCount = completedIDs.intersection(habitPlannedIDs).count
            let completedEventCount = eventPlannedIDs.filter { eventCompletionDates[$0] != nil }.count

            return DayMetric(
                date: date,
                habitPlannedCount: habitPlannedIDs.count,
                habitCompletedCount: completedHabitCount,
                eventPlannedCount: eventPlannedIDs.count,
                eventCompletedCount: completedEventCount,
                mood: moodsByDate[moodKey(for: date)],
                sleepHours: sleepHoursByDate[moodKey(for: date)]
            )
        }

        let plannedMetrics = metrics.filter { metric in
            guard metric.plannedCount > 0 else {
                return false
            }

            return metric.date < today || metric.completedCount == metric.plannedCount
        }
        let moodMetrics = plannedMetrics.filter { $0.mood != nil }
        let averageCompletionRate = percentage(averageRate(for: plannedMetrics))

        return AnalyticsData(
            analyzedDays: plannedMetrics.count,
            moodDays: moodMetrics.count,
            averageCompletionRate: averageCompletionRate,
            attentionItems: makeAttentionItems(
                dayItems: allDayItems.filter { !$0.isArchived && !$0.isStopList },
                records: allRecords,
                postponements: postponements,
                today: today
            ),
            insights: makeInsights(
                metrics: plannedMetrics,
                moodMetrics: moodMetrics,
                stopListSlipCount: stopListSlipCount,
                sleepIntegrationEnabled: sleepIntegrationEnabled,
                referenceDate: today
            )
        )
    }

    private func makeAttentionItems(
        dayItems: [DayItem],
        records: [DayItemRecord],
        postponements: [String: String],
        today: Date
    ) -> [DayItemAttentionItem] {
        let items = dayItems.compactMap { dayItem -> DayItemAttentionItem? in
            guard let status = DayItemInactivityCalculator.status(
                for: dayItem,
                records: records,
                postponements: postponements,
                through: today,
                calendar: calendar
            ), status.missedDays >= 3 else {
                return nil
            }

            return DayItemAttentionItem(
                dayItemID: dayItem.id,
                name: dayItem.name,
                emoji: dayItem.emoji,
                kind: status.kind,
                missedDays: status.missedDays
            )
        }

        return items.sorted {
            if $0.missedDays == $1.missedDays {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return $0.missedDays > $1.missedDays
        }
    }

    private func recordsCount(in interval: DateInterval?, records: [DayItemRecord]) -> Int {
        guard let interval = interval else {
            return 0
        }

        return records.filter { interval.contains($0.date) }.count
    }

    private func statisticsPeriodStart(dayItems: [DayItem], records: [DayItemRecord], today: Date) -> Date {
        let recordDates = records.map { calendar.startOfDay(for: $0.date) }
        let eventDates = dayItems.compactMap { dayItem -> Date? in
            guard !dayItem.isHabit, let eventDate = dayItem.eventDate else {
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

    private func makeEventCompletionDates(dayItems: [DayItem], records: [DayItemRecord]) -> [UUID: Date] {
        let eventIDs = Set(dayItems.filter { !$0.isHabit }.map { $0.id })
        let eventRecords = records.filter { eventIDs.contains($0.dayItemID) }

        return Dictionary(grouping: eventRecords, by: { $0.dayItemID }).compactMapValues { records in
            records
                .map { calendar.startOfDay(for: $0.date) }
                .sorted()
                .first
        }
    }

    private func isPerfectDay(
        _ date: Date,
        dayItems: [DayItem],
        recordsByDate: [Date: [DayItemRecord]],
        eventCompletionDates: [UUID: Date],
        today: Date
    ) -> Bool {
        let activeIDs = activeDayItemIDs(on: date, dayItems: dayItems, eventCompletionDates: eventCompletionDates, today: today)
        guard !activeIDs.isEmpty else {
            return false
        }

        let completedIDs = Set(recordsByDate[calendar.startOfDay(for: date), default: []].map { $0.dayItemID })
        return activeIDs.isSubset(of: completedIDs)
    }

    private func longestPerfectDaysStreak(
        dates: [Date],
        dayItems: [DayItem],
        recordsByDate: [Date: [DayItemRecord]],
        eventCompletionDates: [UUID: Date],
        today: Date
    ) -> Int {
        var currentStreak = 0
        var longestStreak = 0

        for date in dates {
            if isPerfectDay(date, dayItems: dayItems, recordsByDate: recordsByDate, eventCompletionDates: eventCompletionDates, today: today) {
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
        dayItems: [DayItem],
        recordsByDate: [Date: [DayItemRecord]],
        eventCompletionDates: [UUID: Date],
        today: Date
    ) -> Int {
        var currentStreak = 0

        for date in dates {
            guard isPerfectDay(date, dayItems: dayItems, recordsByDate: recordsByDate, eventCompletionDates: eventCompletionDates, today: today) else {
                break
            }
            currentStreak += 1
        }

        return currentStreak
    }

    private func activeDayItemIDs(
        on date: Date,
        dayItems: [DayItem],
        eventCompletionDates: [UUID: Date],
        today: Date
    ) -> Set<UUID> {
        let startOfDay = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: today)
        let activeIDs = dayItems.compactMap { dayItem -> UUID? in
            if dayItem.isHabit {
                return isHabit(dayItem, activeOn: startOfDay) ? dayItem.id : nil
            }

            return isEvent(dayItem, activeOn: startOfDay, eventCompletionDates: eventCompletionDates, today: today) ? dayItem.id : nil
        }

        return Set(activeIDs)
    }

    private func analyticsHabitIDs(
        on date: Date,
        dayItems: [DayItem],
        dayItemStartDates: [UUID: Date],
        postponements: [String: String]
    ) -> Set<UUID> {
        let startOfDay = calendar.startOfDay(for: date)
        let habitIDs = dayItems.compactMap { dayItem -> UUID? in
            guard dayItem.isHabit,
                  isDayItemAvailable(dayItem, on: startOfDay, dayItemStartDates: dayItemStartDates),
                  DayItemInactivityCalculator.isHabitExpected(
                    dayItem,
                    on: startOfDay,
                    postponements: postponements,
                    calendar: calendar
                  ) else {
                return nil
            }

            return dayItem.id
        }

        return Set(habitIDs)
    }

    private func analyticsEventIDs(
        on date: Date,
        dayItems: [DayItem],
        eventCompletionDates: [UUID: Date],
        dayItemStartDates: [UUID: Date],
        postponements: [String: String],
        today: Date
    ) -> Set<UUID> {
        let startOfDay = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: today)
        let eventIDs = dayItems.compactMap { dayItem -> UUID? in
            guard !dayItem.isHabit,
                  isDayItemAvailable(dayItem, on: startOfDay, dayItemStartDates: dayItemStartDates) else {
                return nil
            }

            let effectiveDate = DayItemInactivityCalculator.effectiveEventDate(
                for: dayItem,
                postponements: postponements,
                calendar: calendar
            )
            let analyticsDate = eventCompletionDates[dayItem.id] ?? effectiveDate

            guard analyticsDate <= today,
                  calendar.isDate(analyticsDate, inSameDayAs: startOfDay) else {
                return nil
            }

            return dayItem.id
        }

        return Set(eventIDs)
    }

    private func isDayItemAvailable(_ dayItem: DayItem, on date: Date, dayItemStartDates: [UUID: Date]) -> Bool {
        let startOfDay = calendar.startOfDay(for: date)
        let createdDate = calendar.startOfDay(for: dayItemStartDates[dayItem.id] ?? dayItem.createdDate)

        if startOfDay < createdDate {
            return false
        }

        guard let archivedDate = dayItem.archivedDate else {
            return true
        }

        return startOfDay <= calendar.startOfDay(for: archivedDate)
    }

    private func makeDayItemStartDates(dayItems: [DayItem], records: [DayItemRecord]) -> [UUID: Date] {
        let recordsByDayItem = Dictionary(grouping: records) { $0.dayItemID }

        return Dictionary(uniqueKeysWithValues: dayItems.map { dayItem in
            let recordDates = recordsByDayItem[dayItem.id, default: []].map { calendar.startOfDay(for: $0.date) }
            let createdDate = calendar.startOfDay(for: dayItem.createdDate)
            var candidateDates = [createdDate]
            if let eventDate = dayItem.eventDate {
                candidateDates.append(calendar.startOfDay(for: eventDate))
            }
            candidateDates.append(contentsOf: recordDates)
            let startDate = candidateDates.min() ?? createdDate
            return (dayItem.id, startDate)
        })
    }

    private func isHabit(_ dayItem: DayItem, activeOn date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
        return dayItem.schedule.contains { $0.numberValue == adjustedWeekday }
    }

    private func isEvent(_ dayItem: DayItem, activeOn date: Date, eventCompletionDates: [UUID: Date], today: Date) -> Bool {
        if let completionDate = eventCompletionDates[dayItem.id] {
            return calendar.isDate(completionDate, inSameDayAs: date)
        }

        let eventDate = calendar.startOfDay(for: dayItem.eventDate ?? today)
        let activeDate = eventDate < today ? today : eventDate
        return calendar.isDate(activeDate, inSameDayAs: date)
    }

    private func fetchMoodsByDate() -> [String: Mood] {
        let rawMoods = UserDefaults.standard.dictionary(forKey: moodStorageKey) as? [String: String] ?? [:]
        return rawMoods.compactMapValues { Mood(rawValue: $0) }
    }

    private func moodKey(for date: Date) -> String {
        moodDateFormatter.string(from: date)
    }

    private func makeInsights(
        metrics: [DayMetric],
        moodMetrics: [DayMetric],
        stopListSlipCount: Int,
        sleepIntegrationEnabled: Bool,
        referenceDate: Date
    ) -> [AnalyticsInsight] {
        guard !metrics.isEmpty else {
            return []
        }

        var insights: [AnalyticsInsight] = [
            makeOverviewInsight(metrics: metrics)
        ]

        if let stopListInsight = makeStopListInsight(slipCount: stopListSlipCount) {
            insights.append(stopListInsight)
        }

        let comfortCandidate = makeComfortLoadCandidate(
            metrics: moodMetrics,
            allMetrics: metrics,
            referenceDate: referenceDate
        )
        let sleepCandidate = makeSleepCandidate(metrics: metrics, referenceDate: referenceDate)
        if let comfortCandidate {
            insights.append(makeComfortLoadInsight(candidate: comfortCandidate))
        } else {
            insights.append(
                AnalyticsInsight(
                    title: NSLocalizedString("analytics.comfort.title", comment: "Comfortable load title"),
                    value: NSLocalizedString("analytics.comfort.noData.value", comment: "Comfortable load missing data value"),
                    detail: String(
                        format: NSLocalizedString("analytics.comfort.noData.detail", comment: "Comfortable load missing data detail"),
                        minimumMoodDays
                    )
                )
            )
        }

        insights.append(
            makeSleepInsight(
                candidate: sleepCandidate,
                isEnabled: sleepIntegrationEnabled
            )
        )

        if let itemTypeInsight = makeItemTypeInsight(metrics: metrics) {
            insights.append(itemTypeInsight)
        }

        if let weekdayInsight = makeWeekdayInsight(metrics: metrics) {
            insights.append(weekdayInsight)
        }

        insights.append(
            makeAdviceInsight(
                comfortCandidate: comfortCandidate,
                sleepCandidate: sleepCandidate
            )
        )
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

    private func makeStopListInsight(slipCount: Int) -> AnalyticsInsight? {
        guard slipCount > 0 else {
            return nil
        }

        let slipWord = localizedSlipWord(for: slipCount)
        let format = NSLocalizedString("analytics.stopList.detail", comment: "Stop-list slips analytics detail")
        return AnalyticsInsight(
            title: NSLocalizedString("analytics.stopList.title", comment: "Stop-list slips analytics title"),
            value: "\(slipCount)",
            detail: String(format: format, slipCount, slipWord)
        )
    }

    private func makeComfortLoadCandidate(
        metrics: [DayMetric],
        allMetrics: [DayMetric],
        referenceDate: Date
    ) -> ComfortLoadCandidate? {
        let baselineRate = weightedRate(for: allMetrics, referenceDate: referenceDate)
        let typicalPlan = medianPlanCount(in: allMetrics)
        let groupedByMood = Dictionary(grouping: metrics) { $0.mood }
        var candidates: [(candidate: ComfortLoadCandidate, score: Double)] = []

        for (mood, moodMetrics) in groupedByMood {
            guard let mood, moodMetrics.count >= minimumMoodDays else {
                continue
            }

            let thresholds = Array(Set(moodMetrics.map { $0.plannedCount })).sorted().dropLast()
            for threshold in thresholds {
                let comfortableDays = moodMetrics.filter { $0.plannedCount <= threshold }
                let overloadedDays = moodMetrics.filter { $0.plannedCount > threshold }
                guard comfortableDays.count >= minimumLoadGroupDays,
                      overloadedDays.count >= minimumLoadGroupDays else {
                    continue
                }

                let comfortableRate = smoothedRate(
                    for: comfortableDays,
                    baselineRate: baselineRate,
                    referenceDate: referenceDate
                )
                let overloadedRate = smoothedRate(
                    for: overloadedDays,
                    baselineRate: baselineRate,
                    referenceDate: referenceDate
                )
                let candidate = ComfortLoadCandidate(
                    mood: mood,
                    comfortableLimit: threshold,
                    comfortableRate: comfortableRate,
                    overloadedRate: overloadedRate
                )
                let distanceFromTypicalPlan = abs(Double(threshold) - typicalPlan)
                let score = candidate.completionDrop - distanceFromTypicalPlan * 0.005
                candidates.append((candidate, score))
            }
        }

        return candidates.max(by: { $0.score < $1.score })?.candidate
    }

    private func makeComfortLoadInsight(candidate: ComfortLoadCandidate) -> AnalyticsInsight {
        let hasCompletionDrop = candidate.completionDrop >= 0.05
        let value: String
        if hasCompletionDrop {
            value = String(
                format: NSLocalizedString("analytics.comfort.value", comment: "Comfortable load value"),
                candidate.comfortableLimit,
                localizedItemWord(for: candidate.comfortableLimit)
            )
        } else {
            value = NSLocalizedString("analytics.comfort.stableValue", comment: "Stable comfortable load value")
        }
        let detailKey = hasCompletionDrop
            ? "analytics.comfort.detailDrop"
            : "analytics.comfort.detailStable"
        let detail: String
        if hasCompletionDrop {
            detail = String(
                format: NSLocalizedString(detailKey, comment: "Comfortable load detail"),
                candidate.mood.localizedName,
                percentage(candidate.comfortableRate),
                percentage(candidate.overloadedRate)
            )
        } else {
            detail = String(
                format: NSLocalizedString(detailKey, comment: "Comfortable load detail"),
                candidate.mood.localizedName,
                candidate.comfortableLimit,
                percentage(candidate.comfortableRate),
                percentage(candidate.overloadedRate)
            )
        }

        return AnalyticsInsight(
            title: NSLocalizedString("analytics.comfort.title", comment: "Comfortable load title"),
            value: value,
            detail: detail
        )
    }

    private func makeItemTypeInsight(metrics: [DayMetric]) -> AnalyticsInsight? {
        let habitPlanned = metrics.reduce(0) { $0 + $1.habitPlannedCount }
        let habitCompleted = metrics.reduce(0) { $0 + $1.habitCompletedCount }
        let eventPlanned = metrics.reduce(0) { $0 + $1.eventPlannedCount }
        let eventCompleted = metrics.reduce(0) { $0 + $1.eventCompletedCount }
        guard habitPlanned > 0, eventPlanned > 0 else {
            return nil
        }

        let habitRate = percentage(Double(habitCompleted) / Double(habitPlanned))
        let eventRate = percentage(Double(eventCompleted) / Double(eventPlanned))
        let value = String(
            format: NSLocalizedString("analytics.itemType.value", comment: "Item type analytics value"),
            habitRate,
            eventRate
        )
        let detail = String(
            format: NSLocalizedString("analytics.itemType.detail", comment: "Item type analytics detail"),
            habitCompleted,
            habitPlanned,
            eventCompleted,
            eventPlanned
        )

        return AnalyticsInsight(
            title: NSLocalizedString("analytics.itemType.title", comment: "Item type analytics title"),
            value: value,
            detail: detail
        )
    }

    private func makeSleepCandidate(
        metrics: [DayMetric],
        referenceDate: Date
    ) -> SleepCandidate? {
        let sleepMetrics = metrics.filter { ($0.sleepHours ?? 0) > 0 }
        guard sleepMetrics.count >= minimumSleepDays else {
            return nil
        }

        let sortedHours = sleepMetrics.compactMap { $0.sleepHours }.sorted()
        let middle = sortedHours.count / 2
        let typicalHours: Double
        if sortedHours.count.isMultiple(of: 2) {
            typicalHours = (sortedHours[middle - 1] + sortedHours[middle]) / 2
        } else {
            typicalHours = sortedHours[middle]
        }

        let shorterSleepMetrics = sleepMetrics.filter { ($0.sleepHours ?? 0) < typicalHours }
        let longerSleepMetrics = sleepMetrics.filter { ($0.sleepHours ?? 0) >= typicalHours }
        guard shorterSleepMetrics.count >= minimumSleepGroupDays,
              longerSleepMetrics.count >= minimumSleepGroupDays else {
            return nil
        }

        let baselineRate = weightedRate(for: metrics, referenceDate: referenceDate)
        return SleepCandidate(
            typicalHours: typicalHours,
            shorterSleepRate: smoothedRate(
                for: shorterSleepMetrics,
                baselineRate: baselineRate,
                referenceDate: referenceDate
            ),
            longerSleepRate: smoothedRate(
                for: longerSleepMetrics,
                baselineRate: baselineRate,
                referenceDate: referenceDate
            )
        )
    }

    private func makeSleepInsight(
        candidate: SleepCandidate?,
        isEnabled: Bool
    ) -> AnalyticsInsight {
        guard isEnabled else {
            return AnalyticsInsight(
                title: NSLocalizedString("analytics.sleep.title", comment: "Sleep analytics title"),
                value: NSLocalizedString("analytics.sleep.connect.value", comment: "Connect Health value"),
                detail: NSLocalizedString("analytics.sleep.connect.detail", comment: "Connect Health detail")
            )
        }

        guard let candidate else {
            return AnalyticsInsight(
                title: NSLocalizedString("analytics.sleep.title", comment: "Sleep analytics title"),
                value: NSLocalizedString("analytics.sleep.noData.value", comment: "Missing sleep data value"),
                detail: String(
                    format: NSLocalizedString("analytics.sleep.noData.detail", comment: "Missing sleep data detail"),
                    minimumSleepDays
                )
            )
        }

        let duration = formattedSleepDuration(candidate.typicalHours)
        let hasImprovement = candidate.improvementAfterLongerSleep >= 0.05
        let detailKey = hasImprovement
            ? "analytics.sleep.detailImprovement"
            : "analytics.sleep.detailStable"
        let detail = String(
            format: NSLocalizedString(detailKey, comment: "Sleep analytics detail"),
            duration,
            percentage(candidate.longerSleepRate),
            percentage(candidate.shorterSleepRate)
        )

        return AnalyticsInsight(
            title: NSLocalizedString("analytics.sleep.title", comment: "Sleep analytics title"),
            value: duration,
            detail: detail
        )
    }

    private func makeWeekdayInsight(metrics: [DayMetric]) -> AnalyticsInsight? {
        let grouped = Dictionary(grouping: metrics) { $0.weekdayIndex }
        let groups = grouped.compactMap { weekday, metrics -> (weekday: Int, rate: Double, count: Int)? in
            guard metrics.count >= minimumWeekdayDays else {
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

    private func makeAdviceInsight(
        comfortCandidate: ComfortLoadCandidate?,
        sleepCandidate: SleepCandidate?
    ) -> AnalyticsInsight {
        let sleepImprovement = sleepCandidate?.improvementAfterLongerSleep ?? 0
        let comfortDrop = comfortCandidate?.completionDrop ?? 0

        if let sleepCandidate,
           sleepImprovement >= 0.05,
           sleepImprovement >= comfortDrop {
            let detail = String(
                format: NSLocalizedString("analytics.advice.sleep.detail", comment: "Short sleep advice detail"),
                formattedSleepDuration(sleepCandidate.typicalHours)
            )
            return AnalyticsInsight(
                title: NSLocalizedString("analytics.advice.title", comment: "Advice analytics title"),
                value: NSLocalizedString("analytics.advice.sleep.value", comment: "Short sleep advice value"),
                detail: detail
            )
        }

        guard let candidate = comfortCandidate else {
            return AnalyticsInsight(
                title: NSLocalizedString("analytics.advice.title", comment: "Advice analytics title"),
                value: NSLocalizedString("analytics.advice.collect.value", comment: "Collect data advice value"),
                detail: NSLocalizedString("analytics.advice.collect.detail", comment: "Collect data advice detail")
            )
        }

        if candidate.completionDrop >= 0.05 {
            let detail = String(
                format: NSLocalizedString("analytics.advice.comfort.detail", comment: "Comfort limit advice detail"),
                candidate.mood.emoji,
                candidate.comfortableLimit
            )
            return AnalyticsInsight(
                title: NSLocalizedString("analytics.advice.title", comment: "Advice analytics title"),
                value: NSLocalizedString("analytics.advice.comfort.value", comment: "Comfort limit advice value"),
                detail: detail
            )
        }

        return AnalyticsInsight(
            title: NSLocalizedString("analytics.advice.title", comment: "Advice analytics title"),
            value: NSLocalizedString("analytics.advice.stable.value", comment: "Stable advice value"),
            detail: NSLocalizedString("analytics.advice.stableV2.detail", comment: "Stable advice detail")
        )
    }

    private func formattedSleepDuration(_ hours: Double) -> String {
        let totalMinutes = max(0, Int((hours * 60).rounded()))
        let hourCount = totalMinutes / 60
        let minuteCount = totalMinutes % 60
        if minuteCount == 0 {
            return String(
                format: NSLocalizedString("analytics.sleep.duration.hours", comment: "Sleep duration in hours"),
                hourCount
            )
        }

        return String(
            format: NSLocalizedString("analytics.sleep.duration.hoursMinutes", comment: "Sleep duration in hours and minutes"),
            hourCount,
            minuteCount
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

    private func weightedRate(for metrics: [DayMetric], referenceDate: Date) -> Double {
        let totals = weightedTotals(for: metrics, referenceDate: referenceDate)
        guard totals.planned > 0 else {
            return 0
        }

        return totals.completed / totals.planned
    }

    private func smoothedRate(
        for metrics: [DayMetric],
        baselineRate: Double,
        referenceDate: Date
    ) -> Double {
        let totals = weightedTotals(for: metrics, referenceDate: referenceDate)
        return (totals.completed + smoothingPriorItems * baselineRate)
            / (totals.planned + smoothingPriorItems)
    }

    private func weightedTotals(
        for metrics: [DayMetric],
        referenceDate: Date
    ) -> (planned: Double, completed: Double) {
        metrics.reduce(into: (planned: 0.0, completed: 0.0)) { result, metric in
            let daysAgo = max(
                0,
                calendar.dateComponents([.day], from: metric.date, to: referenceDate).day ?? 0
            )
            let weight = pow(0.5, Double(daysAgo) / recencyHalfLifeDays)
            result.planned += Double(metric.plannedCount) * weight
            result.completed += Double(metric.completedCount) * weight
        }
    }

    private func medianPlanCount(in metrics: [DayMetric]) -> Double {
        let values = metrics.map { $0.plannedCount }.sorted()
        guard !values.isEmpty else {
            return 0
        }

        let middle = values.count / 2
        if values.count.isMultiple(of: 2) {
            return Double(values[middle - 1] + values[middle]) / 2
        }

        return Double(values[middle])
    }

    private func percentage(_ value: Double) -> Int {
        Int(round(value * 100))
    }

    private func localizedSlipWord(for count: Int) -> String {
        let remainder10 = count % 10
        let remainder100 = count % 100
        if remainder10 == 1 && remainder100 != 11 {
            return NSLocalizedString("analytics.stopList.slip.one", comment: "One stop-list slip")
        } else if remainder10 >= 2 && remainder10 <= 4 && (remainder100 < 10 || remainder100 >= 20) {
            return NSLocalizedString("analytics.stopList.slip.few", comment: "Few stop-list slips")
        } else {
            return NSLocalizedString("analytics.stopList.slip.many", comment: "Many stop-list slips")
        }
    }

    private func localizedItemWord(for count: Int) -> String {
        let remainder10 = count % 10
        let remainder100 = count % 100
        let key: String
        if remainder10 == 1 && remainder100 != 11 {
            key = "analytics.item.one"
        } else if remainder10 >= 2 && remainder10 <= 4 && (remainder100 < 10 || remainder100 >= 20) {
            key = "analytics.item.few"
        } else {
            key = "analytics.item.many"
        }

        return NSLocalizedString(key, comment: "Planned item count word")
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
