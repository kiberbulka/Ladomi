import SwiftUI

@main
struct LadomiWatchApp: App {
    @StateObject private var store = WatchPlanStore()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                PlanListView()
                    .environmentObject(store)
            }
        }
    }
}
