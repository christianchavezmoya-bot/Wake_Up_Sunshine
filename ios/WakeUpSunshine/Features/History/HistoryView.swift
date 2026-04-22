import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.lg, pinnedViews: .sectionHeaders) {
                        ForEach(viewModel.groupedHistory.keys.sorted().reversed(), id: \.self) { date in
                            Section {
                                ForEach(viewModel.groupedHistory[date] ?? []) { item in
                                    HistoryItemRow(item: item)
                                        .transition(.scale.combined(with: .opacity).animation(.springStandard))
                                }
                            } header: {
                                DateHeaderView(date: date)
                            }
                        }
                    }
                    .padding(.top, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.xxl)
                }
                .refreshable {
                    // Pull-to-refresh action
                    isRefreshing = true
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    isRefreshing = false
                }
            }
            .navigationTitle("History")
        }
    }
}

// MARK: - Date Header View
struct DateHeaderView: View {
    let date: Date

    var body: some View {
        HStack {
            Text(formatDateHeader(date))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.textSecondary)
            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(Color.appBackground)
    }

    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - History Item Row
struct HistoryItemRow: View {
    let item: HistoryItem

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color(hex: item.avatarColor))
                    .frame(width: DesignSystem.TouchTargets.minimum, height: DesignSystem.TouchTargets.minimum)

                Text(item.name.prefix(1).uppercased())
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            // Info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                HStack(spacing: DesignSystem.Spacing.xxs) {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)

                    // Direction indicator
                    Image(systemName: item.isIncoming ? "arrow.down" : "arrow.up")
                        .font(.caption2)
                        .foregroundColor(.textTertiary)
                }

                if let message = item.message {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Time and Status
            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xxs) {
                Text(formatTime(item.timestamp))
                    .font(.caption)
                    .foregroundColor(.textTertiary)

                StatusBadge(status: item.status)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.appCard)
        .cornerRadius(DesignSystem.Spacing.buttonRadius)
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let status: HistoryItem.HistoryStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, DesignSystem.Spacing.xs + 2)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .background(status.backgroundColor)
            .foregroundColor(status.foregroundColor)
            .clipShape(Capsule())
    }
}

// MARK: - History Item Model
struct HistoryItem: Identifiable {
    let id: String
    let name: String
    let avatarColor: String
    let title: String
    let message: String?
    let timestamp: Date
    let status: HistoryStatus
    let isIncoming: Bool

    enum HistoryStatus {
        case confirmed
        case delivered
        case dismissed
        case pending

        var displayName: String {
            switch self {
            case .confirmed: return "Confirmed"
            case .delivered: return "Delivered"
            case .dismissed: return "Dismissed"
            case .pending: return "Pending"
            }
        }

        var backgroundColor: Color {
            switch self {
            case .confirmed: return DesignSystem.Colors.successLight
            case .delivered: return DesignSystem.Colors.primaryOrange.opacity(0.1)
            case .dismissed: return DesignSystem.Colors.errorLight
            case .pending: return DesignSystem.Colors.surfaceLight.opacity(0.5)
            }
        }

        var foregroundColor: Color {
            switch self {
            case .confirmed: return DesignSystem.Colors.success
            case .delivered: return DesignSystem.Colors.primaryOrange
            case .dismissed: return DesignSystem.Colors.error
            case .pending: return .textSecondary
            }
        }
    }
}

// MARK: - History ViewModel
class HistoryViewModel: ObservableObject {
    @Published var groupedHistory: [Date: [HistoryItem]] = [:]

    init() {
        loadMockData()
    }

    func loadMockData() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let thisWeek = calendar.date(byAdding: .day, value: -3, to: today)!

        groupedHistory = [
            today: [
                HistoryItem(id: "1", name: "Alex Chen", avatarColor: "#667eea", title: "Woke Alex Chen", message: "Morning shift - don't forget!", timestamp: Date(), status: .confirmed, isIncoming: false),
                HistoryItem(id: "2", name: "Sarah Miller", avatarColor: "#f5576c", title: "Woke Sarah Miller", message: "Flight time!", timestamp: calendar.date(byAdding: .hour, value: -5, to: Date())!, status: .confirmed, isIncoming: false),
            ],
            yesterday: [
                HistoryItem(id: "3", name: "Mike Johnson", avatarColor: "#4facfe", title: "Mike Johnson woke you", message: "Good morning!", timestamp: calendar.date(byAdding: .hour, value: -24, to: Date())!, status: .dismissed, isIncoming: true),
                HistoryItem(id: "4", name: "Alex Chen", avatarColor: "#667eea", title: "Woke Alex Chen", message: "Team meeting in 30 min", timestamp: calendar.date(byAdding: .hour, value: -20, to: Date())!, status: .confirmed, isIncoming: false),
            ],
            thisWeek: [
                HistoryItem(id: "5", name: "Emma Davis", avatarColor: "#43e97b", title: "Woke Emma Davis", message: "Dentist appointment", timestamp: calendar.date(byAdding: .day, value: -3, to: Date())!, status: .delivered, isIncoming: false),
            ]
        ]
    }
}

#Preview {
    HistoryView()
}
