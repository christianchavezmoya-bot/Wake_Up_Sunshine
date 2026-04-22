import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color("Background").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        ForEach(viewModel.groupedHistory.keys.sorted().reversed(), id: \.self) { date in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(formatDateHeader(date))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 24)

                                VStack(spacing: 8) {
                                    ForEach(viewModel.groupedHistory[date] ?? []) { item in
                                        HistoryItemRow(item: item)
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("History")
        }
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
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: item.avatarColor))
                    .frame(width: 48, height: 48)

                Text(item.name.prefix(1).uppercased())
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if let message = item.message {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatTime(item.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)

                StatusBadge(status: item.status)
            }
        }
        .padding(16)
        .background(Color("Surface"))
        .cornerRadius(12)
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
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
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
            case .confirmed: return Color("Success").opacity(0.1)
            case .delivered: return Color("Secondary").opacity(0.1)
            case .dismissed: return Color("Error").opacity(0.1)
            case .pending: return Color.gray.opacity(0.1)
            }
        }

        var foregroundColor: Color {
            switch self {
            case .confirmed: return Color("Success")
            case .delivered: return Color("Secondary")
            case .dismissed: return Color("Error")
            case .pending: return .gray
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

        // Today
        let today = calendar.startOfDay(for: Date())

        // Yesterday
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // This week
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