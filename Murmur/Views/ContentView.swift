//
//  ContentView.swift
//  The home screen: the murmur inbox (newest first), a record button, and a
//  settings panel. Tap a row to expand its inline player; swipe to delete.
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
            VStack(alignment: .leading, spacing: 2) {
                Text("Murmur")
                    .font(MurmurFont.wordmark(34))
                    .foregroundStyle(MurmurColor.inkPrimary)
                Text(murmurs.isEmpty ? "no murmurs yet" : "\(murmurs.count) murmurs")
                    .font(MurmurFont.rounded(13))
                    .foregroundStyle(MurmurColor.inkTertiary)
            }
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
        .padding(.bottom, 18)
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

    // MARK: Inbox list

    private var inbox: some View {
        List {
            ForEach(murmurs) { murmur in
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
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .safeAreaPadding(.bottom, 120)
        .refreshable { await SyncBridge.shared.sync() }
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
                Text(murmur.createdAt, format: .dateTime.weekday().hour().minute())
                    .font(MurmurFont.rounded(12))
                    .foregroundStyle(MurmurColor.inkTertiary)
            }

            Spacer()

            if !murmur.isPlayed {
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
}

#Preview {
    ContentView()
        .modelContainer(for: Murmur.self, inMemory: true)
}
