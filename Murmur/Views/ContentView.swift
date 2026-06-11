//
//  ContentView.swift
//  The home screen: the murmur inbox grouped by day (newest first), a partner
//  header, a record button, and a settings panel. Tap a row to expand its
//  inline player; swipe to delete.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var theme = Theme.shared
    @ObservedObject private var profile = ProfileStore.shared
    @StateObject private var listModel = MurmurListViewModel()
    @Query(sort: \Murmur.createdAt, order: .reverse) private var murmurs: [Murmur]

    @State private var showRecorder = false
    @State private var showSettings = false
    @State private var expandedID: UUID?
    @State private var pendingDelete: Murmur?

    var body: some View {
        ZStack {
            MurmurColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                if !profile.partnerName.isEmpty { partnerHeader }
                if murmurs.isEmpty {
                    emptyState
                } else {
                    inbox
                }
            }

            micButton
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showRecorder) { RecordView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .confirmationDialog("Delete this murmur?",
                            isPresented: deleteDialogBinding,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let murmur = pendingDelete {
                    listModel.delete(murmur, in: modelContext)
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Murmur")
                .font(MurmurFont.wordmark(34))
                .foregroundStyle(MurmurColor.inkPrimary)
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(MurmurColor.inkSecondary)
                    .frame(width: 40, height: 40)
                    .background(MurmurColor.surface, in: Circle())
                    .overlay(Circle().strokeBorder(MurmurColor.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    // MARK: Partner header

    private var partnerHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(MurmurColor.accentGradient).frame(width: 38, height: 38)
                Text(String(profile.partnerName.first ?? "?").uppercased())
                    .font(MurmurFont.display(16, weight: .medium))
                    .foregroundStyle(MurmurColor.background)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(profile.partnerName)
                    .font(MurmurFont.rounded(15, weight: .semibold))
                    .foregroundStyle(MurmurColor.inkPrimary)
                Text(unplayedCount > 0 ? "\(unplayedCount) new murmur\(unplayedCount == 1 ? "" : "s")"
                                       : "across the distance")
                    .font(MurmurFont.rounded(12))
                    .foregroundStyle(unplayedCount > 0 ? MurmurColor.accent : MurmurColor.inkTertiary)
            }
            Spacer()
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 14))
                .foregroundStyle(MurmurColor.inkTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(MurmurColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(MurmurColor.hairline, lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "waveform")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(MurmurColor.accent)
            Text("No murmurs yet")
                .font(MurmurFont.display(20, weight: .medium))
                .foregroundStyle(MurmurColor.inkSecondary)
            Text("Tap the mic to leave your first one.")
                .font(MurmurFont.rounded(14))
                .foregroundStyle(MurmurColor.inkTertiary)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Inbox list (grouped by day)

    private var inbox: some View {
        List {
            ForEach(groupedMurmurs, id: \.day) { group in
                Section {
                    ForEach(group.items) { murmur in
                        row(for: murmur)
                    }
                } header: {
                    Text(group.label)
                        .font(MurmurFont.rounded(12, weight: .semibold))
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(MurmurColor.inkTertiary)
                }
                .listSectionSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .safeAreaPadding(.bottom, 120)
        .refreshable { await SyncBridge.shared.sync() }
    }

    @ViewBuilder
    private func row(for murmur: Murmur) -> some View {
        VStack(spacing: 10) {
            MurmurRow(murmur: murmur,
                      isExpanded: expandedID == murmur.id,
                      avatarColor: murmur.isOutgoing ? profile.avatarColor : nil)
                .contentShape(Rectangle())
                .onTapGesture { toggle(murmur) }

            if expandedID == murmur.id {
                PlayerView(murmur: murmur) {
                    listModel.markPlayed(murmur, in: modelContext)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingDelete = murmur
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: Mic button

    private var micButton: some View {
        VStack {
            Spacer()
            Button {
                showRecorder = true
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(MurmurColor.background)
                    .frame(width: 72, height: 72)
                    .background(MurmurColor.accentGradient, in: Circle())
                    .shadow(color: MurmurColor.accentDeep.opacity(0.5), radius: 16, y: 8)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 36)
        }
    }

    // MARK: Grouping

    private struct DayGroup {
        let day: Date
        let label: String
        let items: [Murmur]
    }

    private var groupedMurmurs: [DayGroup] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: murmurs) { calendar.startOfDay(for: $0.createdAt) }
        return groups.keys.sorted(by: >).map { day in
            DayGroup(day: day, label: Self.dayLabel(for: day), items: groups[day] ?? [])
        }
    }

    private var unplayedCount: Int {
        murmurs.filter { !$0.isOutgoing && !$0.isPlayed }.count
    }

    private static func dayLabel(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        let daysAgo = calendar.dateComponents([.day], from: day, to: Date()).day ?? 0
        if daysAgo < 7 { return day.formatted(.dateTime.weekday(.wide)) }
        return day.formatted(.dateTime.month(.abbreviated).day())
    }

    // MARK: Helpers

    private var deleteDialogBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } })
    }

    private func toggle(_ murmur: Murmur) {
        withAnimation(.easeInOut(duration: 0.22)) {
            expandedID = (expandedID == murmur.id) ? nil : murmur.id
        }
    }
}

// MARK: - Row

private struct MurmurRow: View {
    let murmur: Murmur
    let isExpanded: Bool
    /// Outgoing rows use your profile colour; incoming fall back to the palette.
    var avatarColor: Color?

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Group {
                    if let avatarColor {
                        Circle().fill(avatarColor)
                    } else {
                        Circle().fill(MurmurColor.accentGradient)
                    }
                }
                .frame(width: 44, height: 44)
                Text(murmur.avatarInitial)
                    .font(MurmurFont.display(18, weight: .medium))
                    .foregroundStyle(MurmurColor.background)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(murmur.senderName)
                    .font(MurmurFont.rounded(15, weight: .semibold))
                    .foregroundStyle(MurmurColor.inkPrimary)
                Text(Self.timeLabel(for: murmur.createdAt))
                    .font(MurmurFont.rounded(12))
                    .foregroundStyle(MurmurColor.inkTertiary)
            }

            Spacer()

            if !murmur.isPlayed && !murmur.isOutgoing {
                Circle()
                    .fill(MurmurColor.accent)
                    .frame(width: 8, height: 8)
            }

            Text(murmur.durationLabel)
                .font(MurmurFont.rounded(14, weight: .medium).monospacedDigit())
                .foregroundStyle(MurmurColor.inkSecondary)
        }
        .padding(14)
        .background(MurmurColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(isExpanded ? MurmurColor.accent.opacity(0.5) : MurmurColor.hairline,
                          lineWidth: isExpanded ? 1.5 : 1))
    }

    /// Relative for recent murmurs, otherwise the time of day.
    private static func timeLabel(for date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
        if Calendar.current.isDateInToday(date) { return "\(Int(seconds / 3600))h ago" }
        return date.formatted(.dateTime.hour().minute())
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Murmur.self, inMemory: true)
}
