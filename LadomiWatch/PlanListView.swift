import SwiftUI

struct PlanListView: View {
    @EnvironmentObject private var store: WatchPlanStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                header

                if store.plans.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(store.plans) { plan in
                            PlanCard(plan: plan) {
                                withAnimation(.snappy(duration: 0.22)) {
                                    store.toggle(plan)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(Text("watch.title"))
        .refreshable { store.refresh() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.16), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(.green, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(store.completedCount)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text("watch.today")
                    .font(.headline)
                Text("\(store.completedCount)/\(store.plans.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checklist")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("watch.empty")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("watch.refresh") {
                store.refresh()
            }
            .buttonStyle(.bordered)
            .disabled(store.isRefreshing)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
    }

    private var progress: CGFloat {
        guard !store.plans.isEmpty else { return 0 }
        return CGFloat(store.completedCount) / CGFloat(store.plans.count)
    }
}

private struct PlanCard: View {
    let plan: WatchPlan
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Text(plan.emoji.isEmpty ? "•" : plan.emoji)
                    .font(.system(size: 22))
                    .frame(width: 30)

                Text(plan.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: plan.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(plan.isCompleted ? .black : .black.opacity(0.45))
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 11)
            .background(plan.color.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(plan.isCompleted ? 0.68 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(plan.title)
        .accessibilityValue(Text(plan.isCompleted ? "watch.completed" : "watch.notCompleted"))
    }
}

#Preview {
    PlanListView()
        .environmentObject(WatchPlanStore())
}
