import Foundation
import WatchConnectivity

@MainActor
final class WatchPlanStore: NSObject, ObservableObject {
    @Published private(set) var plans: [WatchPlan] = []
    @Published private(set) var isRefreshing = false

    private let cacheKey = "watch.todayPlans"
    private var session: WCSession?
    private var lastPayloadUpdate: TimeInterval = 0

    override init() {
        super.init()
        restoreCache()
        activateSession()
    }

    var completedCount: Int {
        plans.filter(\.isCompleted).count
    }

    func toggle(_ plan: WatchPlan) {
        guard let index = plans.firstIndex(where: { $0.id == plan.id }) else {
            return
        }

        let message: [String: Any]
        if plans[index].hasMultipleRepetitions {
            guard !plans[index].isCompleted else { return }
            plans[index].completedRepetitions += 1
            message = [
                "action": "addCompletion",
                "id": plan.id.uuidString,
                "dayKey": Self.dayKey(for: Date())
            ]
        } else {
            plans[index].completedRepetitions = plans[index].isCompleted ? 0 : 1
            message = [
                "action": "setCompleted",
                "id": plan.id.uuidString,
                "isCompleted": plans[index].isCompleted
            ]
        }
        persistCache()

        if let session, session.isReachable {
            session.sendMessage(message, replyHandler: { [weak self] reply in
                Task { @MainActor in
                    self?.applyPayload(reply)
                }
            }, errorHandler: { [weak self] _ in
                self?.session?.transferUserInfo(message)
            })
        } else {
            session?.transferUserInfo(message)
        }
    }

    func refresh() {
        guard let session else { return }
        isRefreshing = true

        if session.isReachable {
            session.sendMessage(["action": "requestPlans"], replyHandler: { [weak self] reply in
                Task { @MainActor in
                    self?.applyPayload(reply)
                    self?.isRefreshing = false
                }
            }, errorHandler: { [weak self] _ in
                Task { @MainActor in self?.isRefreshing = false }
            })
        } else {
            isRefreshing = false
        }
    }

    private func activateSession() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        self.session = session
        session.delegate = self
        session.activate()
    }

    private func applyPayload(_ payload: [String: Any]) {
        guard let rawPlans = payload["plans"] as? [[String: Any]] else { return }
        if let updatedAt = payload["updatedAt"] as? TimeInterval {
            guard updatedAt >= lastPayloadUpdate else { return }
            lastPayloadUpdate = updatedAt
        }
        plans = rawPlans.compactMap(WatchPlan.init(dictionary:))
        persistCache()
    }

    private func restoreCache() {
        guard
            let data = UserDefaults.standard.data(forKey: cacheKey),
            let cachedPlans = try? JSONDecoder().decode([WatchPlan].self, from: data)
        else {
            return
        }
        plans = cachedPlans
    }

    private func persistCache() {
        guard let data = try? JSONEncoder().encode(plans) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    private static func dayKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

extension WatchPlanStore: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        Task { @MainActor in
            if !session.receivedApplicationContext.isEmpty {
                applyPayload(session.receivedApplicationContext)
            }
            refresh()
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in applyPayload(applicationContext) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in applyPayload(message) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in applyPayload(userInfo) }
    }
}
