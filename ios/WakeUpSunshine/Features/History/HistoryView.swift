import SwiftUI
import Combine

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    @State private var showDeleteAllConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if viewModel.isLoading && viewModel.groupedHistory.isEmpty {
                    ProgressView()
                        .tint(DesignSystem.Colors.primaryOrange)
                } else if !viewModel.isLoading && viewModel.groupedHistory.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 52))
                            .foregroundColor(DesignSystem.Colors.primaryOrange.opacity(0.4))
                        Text("No wake history yet")
                            .font(.headline)
                            .foregroundColor(.textSecondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: DesignSystem.Spacing.lg, pinnedViews: .sectionHeaders) {
                            ForEach(viewModel.groupedHistory.keys.sorted().reversed(), id: \.self) { date in
                                Section {
                                    ForEach(viewModel.groupedHistory[date] ?? []) { item in
                                        HistoryItemRow(item: item)
                                            .transition(.scale.combined(with: .opacity).animation(.springStandard))
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    viewModel.delete(id: item.id)
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                    }
                                } header: {
                                    DateHeaderView(date: date)
                                }
                            }
                        }
                        .padding(.top, DesignSystem.Spacing.md)
                        .padding(.bottom, DesignSystem.Spacing.xxl)
                    }
                    .refreshable { await viewModel.load() }
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.groupedHistory.isEmpty {
                        Button {
                            showDeleteAllConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .alert("Delete All History?", isPresented: $showDeleteAllConfirm) {
                Button("Delete All", role: .destructive) { viewModel.deleteAll() }
                Button("Cancel", role: .cancel) {}
            }
            .task { await viewModel.load() }
            .onReceive(NotificationCenter.default.publisher(for: .wakeResponseReceived)) { _ in
                Task { await viewModel.load() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .wakeSent)) { _ in
                Task { await viewModel.load() }
            }
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

                    Image(systemName: item.isIncoming ? "arrow.down" : "arrow.up")
                        .font(.caption2)
                        .foregroundColor(.textTertiary)
                }

                HStack(spacing: 4) {
                    if let soundId = item.alarmSoundId {
                        let soundName = AlarmSound.from(id: soundId).displayName
                        Image(systemName: "bell.fill")
                            .font(.caption2)
                            .foregroundColor(.textTertiary)
                        Text(soundName)
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    if let message = item.message, !message.isEmpty {
                        if item.alarmSoundId != nil {
                            Text("·").font(.caption).foregroundColor(.textTertiary)
                        }
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                            .lineLimit(1)
                    }
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
    let alarmSoundId: String?
    let timestamp: Date
    let status: HistoryStatus
    let isIncoming: Bool

    enum HistoryStatus {
        case confirmed
        case snoozed
        case delivered
        case dismissed
        case pending

        var displayName: String {
            switch self {
            case .confirmed: return "Awake"
            case .snoozed: return "Snoozed"
            case .delivered: return "Delivered"
            case .dismissed: return "Dismissed"
            case .pending: return "Pending"
            }
        }

        var backgroundColor: Color {
            switch self {
            case .confirmed: return DesignSystem.Colors.successLight
            case .snoozed: return DesignSystem.Colors.warning.opacity(0.15)
            case .delivered: return DesignSystem.Colors.primaryOrange.opacity(0.1)
            case .dismissed: return DesignSystem.Colors.errorLight
            case .pending: return DesignSystem.Colors.surfaceLight.opacity(0.5)
            }
        }

        var foregroundColor: Color {
            switch self {
            case .confirmed: return DesignSystem.Colors.success
            case .snoozed: return DesignSystem.Colors.warning
            case .delivered: return DesignSystem.Colors.primaryOrange
            case .dismissed: return DesignSystem.Colors.error
            case .pending: return .textSecondary
            }
        }
    }
}

// MARK: - Backend History Response
private struct GetHistoryResponse: Decodable {
    let success: Bool
    let history: [BackendHistoryItem]
    let error: String?
}

private struct BackendHistoryItem: Decodable {
    let id: String
    let direction: String
    let otherUserName: String?
    let otherUserEmail: String?
    let avatarColor: String?
    let alarmSoundId: String?
    let message: String?
    let status: String
    let responseAction: String?
    let respondedAt: String?
    let sentAt: String?
    let createdAt: String
}

// MARK: - History ViewModel
class HistoryViewModel: ObservableObject {
    @Published var groupedHistory: [Date: [HistoryItem]] = [:]
    @Published var isLoading = false

    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private let isoFormatterShort: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result: GetHistoryResponse = try await APIClient.shared.request(
                endpoint: "/wake/history",
                method: "GET"
            )
            guard result.success else { return }
            let calendar = Calendar.current
            var grouped: [Date: [HistoryItem]] = [:]
            for item in result.history {
                let ts = parseDate(item.sentAt ?? item.createdAt)
                let dayKey = calendar.startOfDay(for: ts)
                let name = (item.otherUserName?.isEmpty == false ? item.otherUserName : item.otherUserEmail) ?? "Unknown"
                let direction = item.direction == "sent"
                let title = direction ? "Woke \(name)" : "\(name) woke you"
                let historyStatus = mapStatus(item.responseAction ?? item.status)
                let hi = HistoryItem(
                    id: item.id,
                    name: name,
                    avatarColor: item.avatarColor ?? "#FF6B35",
                    title: title,
                    message: item.message,
                    alarmSoundId: item.alarmSoundId,
                    timestamp: ts,
                    status: historyStatus,
                    isIncoming: !direction
                )
                grouped[dayKey, default: []].append(hi)
            }
            groupedHistory = grouped
        } catch {
            print("[HistoryViewModel] load error: \(error)")
        }
    }

    @MainActor
    func deleteAll() {
        groupedHistory = [:]
    }

    @MainActor
    func delete(id: String) {
        for (date, items) in groupedHistory {
            if let idx = items.firstIndex(where: { $0.id == id }) {
                groupedHistory[date]!.remove(at: idx)
                if groupedHistory[date]!.isEmpty {
                    groupedHistory.removeValue(forKey: date)
                }
                return
            }
        }
    }

    private func parseDate(_ iso: String) -> Date {
        isoFormatter.date(from: iso) ?? isoFormatterShort.date(from: iso) ?? Date()
    }

    private func mapStatus(_ raw: String) -> HistoryItem.HistoryStatus {
        switch raw {
        case "confirmed": return .confirmed
        case "snoozed": return .snoozed
        case "delivered", "sent": return .delivered
        case "dismissed", "timed_out": return .dismissed
        default: return .pending
        }
    }
}

#Preview {
    HistoryView()
}
