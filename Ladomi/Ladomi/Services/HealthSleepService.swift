import Foundation
import HealthKit

final class HealthSleepService {
    static let shared = HealthSleepService()

    enum SleepError: LocalizedError {
        case unavailable
        case sleepTypeUnavailable
        case queryFailed(Error)

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return NSLocalizedString("analytics.sleep.error.unavailable", comment: "Health data unavailable error")
            case .sleepTypeUnavailable:
                return NSLocalizedString("analytics.sleep.error.typeUnavailable", comment: "Sleep data unavailable error")
            case .queryFailed:
                return NSLocalizedString("analytics.sleep.error.read", comment: "Sleep data read error")
            }
        }
    }

    private let healthStore = HKHealthStore()
    private let enabledKey = "health.sleepAnalysisEnabled"
    private let calendar = Calendar.current

    private(set) var cachedSleepHoursByDate: [String: Double] = [:]

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private init() {}

    func requestAccess(completion: @escaping (Result<[String: Double], Error>) -> Void) {
        guard isAvailable else {
            completion(.failure(SleepError.unavailable))
            return
        }

        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(.failure(SleepError.sleepTypeUnavailable))
            return
        }

        healthStore.requestAuthorization(toShare: [], read: [sleepType]) { [weak self] success, error in
            guard let self else {
                return
            }

            if let error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard success else {
                DispatchQueue.main.async {
                    completion(.failure(SleepError.unavailable))
                }
                return
            }

            UserDefaults.standard.set(true, forKey: self.enabledKey)
            self.loadRecentSleep(days: 28, completion: completion)
        }
    }

    func loadRecentSleep(
        days: Int,
        completion: @escaping (Result<[String: Double], Error>) -> Void
    ) {
        guard isEnabled else {
            DispatchQueue.main.async {
                completion(.success([:]))
            }
            return
        }

        guard isAvailable else {
            DispatchQueue.main.async {
                completion(.failure(SleepError.unavailable))
            }
            return
        }

        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            DispatchQueue.main.async {
                completion(.failure(SleepError.sleepTypeUnavailable))
            }
            return
        }

        let today = calendar.startOfDay(for: Date())
        let queryStart = calendar.date(byAdding: .day, value: -max(days, 1), to: today) ?? today
        let queryEnd = calendar.date(byAdding: .day, value: 1, to: today) ?? Date()
        let predicate = HKQuery.predicateForSamples(
            withStart: queryStart,
            end: queryEnd,
            options: [.strictStartDate, .strictEndDate]
        )
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let self else {
                return
            }

            if let error {
                DispatchQueue.main.async {
                    completion(.failure(SleepError.queryFailed(error)))
                }
                return
            }

            let categorySamples = (samples as? [HKCategorySample]) ?? []
            let sleepHours = self.aggregateSleepHours(from: categorySamples)
            DispatchQueue.main.async {
                self.cachedSleepHoursByDate = sleepHours
                completion(.success(sleepHours))
            }
        }

        healthStore.execute(query)
    }

    private func aggregateSleepHours(from samples: [HKCategorySample]) -> [String: Double] {
        let asleepSamples = samples.filter { isAsleepValue($0.value) }
        let groupedByWakeDate = Dictionary(grouping: asleepSamples) { sample in
            storageDateKey(for: sample.endDate)
        }

        return groupedByWakeDate.compactMapValues { samples in
            let intervals = samples
                .map { DateInterval(start: $0.startDate, end: $0.endDate) }
                .filter { $0.duration > 0 }
                .sorted { $0.start < $1.start }
            let seconds = mergedDuration(of: intervals)
            guard seconds >= 60 * 30 else {
                return nil
            }

            return seconds / 3_600
        }
    }

    private func mergedDuration(of intervals: [DateInterval]) -> TimeInterval {
        guard var current = intervals.first else {
            return 0
        }

        var total: TimeInterval = 0
        for interval in intervals.dropFirst() {
            if interval.start <= current.end {
                current = DateInterval(start: current.start, end: max(current.end, interval.end))
            } else {
                total += current.duration
                current = interval
            }
        }

        return total + current.duration
    }

    private func isAsleepValue(_ rawValue: Int) -> Bool {
        if #available(iOS 16.0, *) {
            guard let value = HKCategoryValueSleepAnalysis(rawValue: rawValue) else {
                return false
            }
            return HKCategoryValueSleepAnalysis.allAsleepValues.contains(value)
        }

        return rawValue == HKCategoryValueSleepAnalysis.asleep.rawValue
    }

    private func storageDateKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
