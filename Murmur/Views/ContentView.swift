//
//  ContentView.swift
//  The inbox: a timeline of murmurs as chat bubbles grouped by day, a partner
//  card, and the breathing record dock. Tap a bubble to open its player.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var theme = Theme.shared
    @ObservedObject private var profile = ProfileStore.shared
    @StateObject private var listModel = MurmurListViewModel()
    @Query(sort: \Murmur.createdAt, order: .reverse) private var murmurs: [Murmur]

    @State private var path: [Murmur] = []
    @State private var showRecorder = false
    @State private var showSettings = false
    @State private var pendingDelete: Murmur?

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                MurmurColor.background.ignoresSafeArea()
                auroraGlow

                VStack(spacing: 0) {
                    header
                    if !profile.partnerName.isEmpty { partnerCard }
                    if murmurs.isEmpty { emptyState } else { timeline }
                }

                recordDock
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Murmur.self) { murmur in
                PlayerView(murmur: murmur,
                           onReply: { showRecorder = true },
                           onPlaybackStarted: { listModel.markPlayed(murmur, in: modelContext) })
            }
        }
        .tint(MurmurColor.accent)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showRecorder) { RecordView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .confirmationDialog("Delete this murmur?",
                            isPresented: deleteDialogBinding, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let pendingDelete { listModel.delete(pendingDelete, in: modelContext) }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        }
    }

    // MARK: Ambient glow

    private var auroraGlow: some View {
        Circle()
            .fill(RadialGradient(
                colors: [MurmurColor.accent.opacity(0.20), MurmurColor.accentSoft.opacity(0.10), .clear],
                center: .center, startRadius: 10, endRadius: 210))
            .frame(width: 460, height: 340)
            .blur(radius: 8)
            .offset(y: -360)
            .allowsHitTesting(false)
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text("Murmur")
                .font(MurmurFont.wordmark(30))
                .foregroundStyle(MurmurColor.inkPrimary)
            Spacer()
            GlassButton(systemName: "ellipsis", iconSize: 17,
                        tint: MurmurColor.inkSecondary) { showSettings = true }
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
    }

    // MARK: Partner card

    private var partnerCard: some View {
        HStack(spacing: 12) {
            MurmurAvatar(initial: String(profile.partnerName.first ?? "?").uppercased(), size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.partnerName)
                    .font(MurmurFont.rounded(16, weight: .semibold))
                    .foregroundStyle(MurmurColor.inkPrimary)
                HStack(spacing: 6) {
                    Image(systemName: "moon.stars").font(.system(size: 11)).foregroundStyle(MurmurColor.inkTertiary)
                    Text("across the distance")
                        .font(MurmurFont.rounded(12.5))
                        .foregroundStyle(MurmurColor.inkSecondary)
                }
            }
            Spacer()
            if unplayedCount > 0 {
                Text("\(unplayedCount) new")
                    .font(MurmurFont.serifItalic(13))
                    .foregroundStyle(MurmurColor.accent)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(MurmurColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(MurmurColor.hairline, lineWidth: 1))
        .padding(.horizontal, 22).padding(.top, 18)
    }

    // MARK: Timeline

    private var timeline: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(groupedMurmurs, id: \.day) { group in
                    dayDivider(group.label)
                    ForEach(group.items) { murmur in
                        MurmurBubble(murmur: murmur,
                                     mine: murmur.isOutgoing,
                                     youColor: profile.avatarColor)
                            .onTapGesture { path.append(murmur) }
                            .contextMenu {
                                Button(role: .destructive) { pendingDelete = murmur } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .padding(.bottom, 14)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 150)
        }
        .scrollIndicators(.hidden)
    }

    private func dayDivider(_ label: String) -> some View {
        HStack(spacing: 12) {
            Rectangle().fill(MurmurColor.hairline).frame(height: 1)
            Text(label)
                .font(MurmurFont.serifItalic(14))
                .foregroundStyle(MurmurColor.inkTertiary)
                .fixedSize()
            Rectangle().fill(MurmurColor.hairline).frame(height: 1)
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "waveform").font(.system(size: 44, weight: .light))
                .foregroundStyle(MurmurColor.accent)
            Text("No murmurs yet")
                .font(MurmurFont.serifItalic(22))
                .foregroundStyle(MurmurColor.inkSecondary)
            Text("Tap the button below to leave your first one.")
                .font(MurmurFont.rounded(14)).foregroundStyle(MurmurColor.inkTertiary)
            Spacer(); Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Record dock

    private var recordDock: some View {
        VStack {
            Spacer()
            VStack(spacing: 14) {
                BreathingRecordButton { showRecorder = true }
                Text(profile.partnerName.isEmpty ? "leave a murmur"
                                                 : "leave a murmur for \(profile.partnerName)")
                    .font(MurmurFont.serifItalic(14))
                    .foregroundStyle(MurmurColor.inkTertiary)
            }
            .padding(.bottom, 30)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [MurmurColor.background.opacity(0),
                                        MurmurColor.background.opacity(0.85),
                                        MurmurColor.background],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 170)
                    .allowsHitTesting(false),
                alignment: .bottom
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: Grouping

    private struct DayGroup { let day: Date; let label: String; let items: [Murmur] }

    private var groupedMurmurs: [DayGroup] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: murmurs) { calendar.startOfDay(for: $0.createdAt) }
        return groups.keys.sorted(by: >).map {
            DayGroup(day: $0, label: Self.dayLabel(for: $0), items: groups[$0] ?? [])
        }
    }

    private var unplayedCount: Int { murmurs.filter { !$0.isOutgoing && !$0.isPlayed }.count }

    private static func dayLabel(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        let daysAgo = calendar.dateComponents([.day], from: day, to: Date()).day ?? 0
        if daysAgo < 7 { return day.formatted(.dateTime.weekday(.wide)) }
        return day.formatted(.dateTime.month(.abbreviated).day())
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }
}

// MARK: - Bubble

private struct MurmurBubble: View {
    let murmur: Murmur
    let mine: Bool
    let youColor: Color

    private var unplayed: Bool { !mine && !murmur.isPlayed }
    private var progress: Double { (mine || murmur.isPlayed) ? 1 : 0 }

    var body: some View {
        HStack {
            if mine { Spacer(minLength: 40) }
            bubble
            if !mine { Spacer(minLength: 40) }
        }
    }

    private var bubble: some View {
        HStack(spacing: 12) {
            playAffordance
            VStack(alignment: .leading, spacing: 7) {
                WaveformView(bars: murmur.displayWaveform(barCount: 32),
                             progress: progress, height: 28, barWidth: 2.5, gap: 2, minHeight: 3,
                             activeStyle: mine ? AnyShapeStyle(MurmurColor.inkSecondary)
                                               : AnyShapeStyle(MurmurColor.accentGradient),
                             inactiveColor: mine ? .white.opacity(0.14) : MurmurColor.waveInactive)
                    .frame(width: 120)
                meta
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(mine ? AnyShapeStyle(Color.white.opacity(0.035)) : AnyShapeStyle(MurmurColor.surface),
                    in: bubbleShape)
        .overlay(bubbleShape.strokeBorder(
            unplayed ? MurmurColor.accent.opacity(0.35) : MurmurColor.hairline, lineWidth: 1))
        .shadow(color: unplayed ? MurmurColor.accentDeep.opacity(0.12) : .clear, radius: 14, y: 6)
    }

    private var bubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 20, bottomLeadingRadius: mine ? 20 : 6,
            bottomTrailingRadius: mine ? 6 : 20, topTrailingRadius: 20, style: .continuous)
    }

    private var playAffordance: some View {
        ZStack {
            Circle()
                .fill(mine ? AnyShapeStyle(Color.clear) : AnyShapeStyle(MurmurColor.accentGradientSoft))
                .frame(width: 34, height: 34)
                .overlay(Circle().strokeBorder(
                    mine ? MurmurColor.hairlineStrong : MurmurColor.accent.opacity(0.4),
                    lineWidth: mine ? 1.5 : 1))
            Image(systemName: "play.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(mine ? MurmurColor.inkSecondary : MurmurColor.accent)
                .offset(x: 1)
        }
    }

    private var meta: some View {
        HStack(spacing: 7) {
            Text(murmur.durationLabel)
                .font(MurmurFont.rounded(12.5, weight: .medium).monospacedDigit())
                .foregroundStyle(mine ? MurmurColor.inkSecondary : MurmurColor.inkPrimary)
            Circle().fill(MurmurColor.inkTertiary).frame(width: 3, height: 3)
            Text(MurmurBubble.timeLabel(for: murmur.createdAt))
                .font(MurmurFont.serifItalic(13))
                .foregroundStyle(MurmurColor.inkTertiary)
            if mine {
                Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                    .foregroundStyle(MurmurColor.accent)
            }
            if unplayed {
                Circle().fill(MurmurColor.accent).frame(width: 8, height: 8)
                    .shadow(color: MurmurColor.accent, radius: 6)
            }
        }
    }

    static func timeLabel(for date: Date) -> String {
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
