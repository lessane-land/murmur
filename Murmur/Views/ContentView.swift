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
    @Query(sort: \Murmur.createdAt, order: .forward) private var murmurs: [Murmur]

    @State private var path: [Murmur] = []
    @State private var showRecorder = false
    @State private var showSettings = false
    @State private var pendingDelete: Murmur?
    @State private var searching = false
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                // Glow is an OVERLAY of the (screen-sized) background so its
                // 460pt width can't expand the layout and push content off-screen.
                MurmurColor.background
                    .overlay(auroraGlow, alignment: .top)
                    .clipped()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    if searching {
                        searchBar
                    } else if !profile.partnerName.isEmpty {
                        partnerCard
                    }
                    if filteredMurmurs.isEmpty {
                        searching ? AnyView(noResults) : AnyView(emptyState)
                    } else {
                        timeline
                    }
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
            .offset(y: -150)
            .allowsHitTesting(false)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Text("Murmur")
                .font(MurmurFont.wordmark(30))
                .foregroundStyle(MurmurColor.inkPrimary)
            Spacer()
            GlassButton(systemName: "magnifyingglass", iconSize: 16,
                        tint: MurmurColor.inkSecondary) {
                withAnimation(.easeInOut(duration: 0.2)) { searching.toggle() }
                if searching { searchFocused = true } else { searchText = "" }
            }
            GlassButton(systemName: "ellipsis", iconSize: 17,
                        tint: MurmurColor.inkSecondary) { showSettings = true }
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
    }

    // MARK: Search

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(MurmurColor.inkTertiary)
            TextField("Search words in your murmurs", text: $searchText)
                .focused($searchFocused)
                .autocorrectionDisabled()
                .foregroundStyle(MurmurColor.inkPrimary)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { searching = false }
                searchText = ""
            } label: {
                Text("Cancel").font(MurmurFont.rounded(14)).foregroundStyle(MurmurColor.accent)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(MurmurColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(MurmurColor.hairline, lineWidth: 1))
        .padding(.horizontal, 22).padding(.top, 16)
    }

    private var noResults: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "text.magnifyingglass").font(.system(size: 38, weight: .light))
                .foregroundStyle(MurmurColor.inkTertiary)
            Text("No murmurs match \u{201C}\(searchText)\u{201D}")
                .font(MurmurFont.rounded(14)).foregroundStyle(MurmurColor.inkTertiary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Spacer(); Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Partner card

    private var partnerCard: some View {
        // Refresh ~every minute so the partner's local time stays current.
        TimelineView(.periodic(from: .now, by: 60)) { _ in
            HStack(spacing: 12) {
                MurmurAvatar(initial: String(profile.partnerName.first ?? "?").uppercased(),
                             size: 42, night: profile.partnerIsNight)
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.partnerName)
                        .font(MurmurFont.rounded(16, weight: .semibold))
                        .foregroundStyle(MurmurColor.inkPrimary)
                    HStack(spacing: 6) {
                        Image(systemName: profile.partnerIsNight ? "moon.stars.fill" : "sun.max.fill")
                            .font(.system(size: 11)).foregroundStyle(MurmurColor.inkTertiary)
                        Text("\(profile.partnerLocalTime) in \(profile.partnerCity)")
                            .font(MurmurFont.rounded(12.5))
                            .foregroundStyle(MurmurColor.inkSecondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(profile.partnerOffsetLabel)
                        .font(MurmurFont.rounded(11, weight: .medium)).tracking(0.5)
                        .foregroundStyle(MurmurColor.inkTertiary)
                    Text(profile.partnerStatus)
                        .font(MurmurFont.serifItalic(13))
                        .foregroundStyle(MurmurColor.accent)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(MurmurColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(MurmurColor.hairline, lineWidth: 1))
            .padding(.horizontal, 22).padding(.top, 18)
        }
    }

    // MARK: Timeline

    private var timeline: some View {
        GeometryReader { geo in
            // Fixed bubble width (a fraction of the row) so nothing can overflow.
            let bubbleWidth = min((geo.size.width - 36) * 0.82, 320)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(groupedMurmurs, id: \.day) { group in
                            dayDivider(group.label)
                            ForEach(group.items) { murmur in
                                MurmurBubble(murmur: murmur,
                                             mine: murmur.isOutgoing,
                                             bubbleWidth: bubbleWidth,
                                             onDelete: { pendingDelete = murmur },
                                             onPlayToggle: { togglePlay(murmur) })
                                    .onTapGesture(count: 2) { toggleLove(murmur) }
                                    .onTapGesture { path.append(murmur) }
                                    .padding(.bottom, 14)
                            }
                        }
                        // Anchor that keeps the newest murmur above the record dock.
                        Color.clear.frame(height: 150).id(Self.bottomAnchor)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 20)
                }
                .scrollIndicators(.hidden)
                .onAppear { scrollToBottom(proxy, animated: false) }
                .onChange(of: murmurs.count) { _, _ in scrollToBottom(proxy, animated: true) }
            }
        }
    }

    private static let bottomAnchor = "murmur-bottom-anchor"

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo(Self.bottomAnchor, anchor: .bottom) }
            } else {
                proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
            }
        }
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

    private var filteredMurmurs: [Murmur] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard searching, !query.isEmpty else { return murmurs }
        return murmurs.filter {
            ($0.transcript?.lowercased().contains(query) ?? false) ||
            $0.senderName.lowercased().contains(query)
        }
    }

    private var groupedMurmurs: [DayGroup] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filteredMurmurs) { calendar.startOfDay(for: $0.createdAt) }
        // Oldest day first (top) → newest day last (bottom), chat-style.
        return groups.keys.sorted(by: <).map {
            DayGroup(day: $0, label: Self.dayLabel(for: $0), items: groups[$0] ?? [])
        }
    }

    private var unplayedCount: Int { murmurs.filter { !$0.isOutgoing && !$0.isPlayed }.count }

    /// Play (or pause) a murmur straight from the chat. Marks an incoming murmur
    /// as played the first time it starts.
    private func togglePlay(_ murmur: Murmur) {
        if !murmur.isOutgoing && !murmur.isPlayed {
            murmur.isPlayed = true
            try? modelContext.save()
        }
        MurmurPlaybackController.shared.toggle(murmur)
    }

    /// Double-tap a murmur to send a heart (or take it back). Syncs to the
    /// partner's record so their device can surface a notification.
    private func toggleLove(_ murmur: Murmur) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
            murmur.reaction = (murmur.reaction == MurmurReaction.heart) ? nil : MurmurReaction.heart
        }
        try? modelContext.save()
        Task {
            await CloudKitService.shared.pushReaction(murmur)
            await SyncBridge.shared.sync()
        }
    }

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
    @ObservedObject private var theme = Theme.shared
    @ObservedObject private var playback = MurmurPlaybackController.shared
    let murmur: Murmur
    let mine: Bool
    let bubbleWidth: CGFloat
    var onDelete: () -> Void = {}
    var onPlayToggle: () -> Void = {}

    @State private var dragOffset: CGFloat = 0

    private var unplayed: Bool { !mine && !murmur.isPlayed }
    private var isPlayingThis: Bool { playback.isCurrent(murmur) && playback.isPlaying }
    private var progress: Double {
        if playback.isCurrent(murmur) { return playback.progress }
        return (mine || murmur.isPlayed) ? 1 : 0
    }

    var body: some View {
        ZStack {
            // Trash revealed as you swipe the bubble left.
            HStack {
                Spacer()
                Image(systemName: "trash.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MurmurColor.recordingDot)
                    .opacity(min(1, Double(-dragOffset) / 55))
                    .padding(.trailing, 14)
            }
            HStack(spacing: 0) {
                if mine { Spacer(minLength: 0) }
                bubble
                if !mine { Spacer(minLength: 0) }
            }
            .offset(x: dragOffset)
        }
        .gesture(
            DragGesture(minimumDistance: 18)
                .onChanged { value in
                    if value.translation.width < 0,
                       abs(value.translation.width) > abs(value.translation.height) {
                        dragOffset = max(-80, value.translation.width)
                    }
                }
                .onEnded { value in
                    let delete = value.translation.width < -55 &&
                                 abs(value.translation.width) > abs(value.translation.height)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { dragOffset = 0 }
                    if delete { onDelete() }
                }
        )
    }

    private var bubble: some View {
        HStack(spacing: 12) {
            playAffordance
            VStack(alignment: .leading, spacing: 7) {
                WaveformView(bars: murmur.displayWaveform(barCount: 30),
                             progress: progress, height: 30, gap: 2.5, minHeight: 3,
                             activeStyle: mine ? AnyShapeStyle(MurmurColor.inkSecondary)
                                               : AnyShapeStyle(MurmurColor.accentGradient),
                             inactiveColor: mine ? .white.opacity(0.14) : MurmurColor.waveInactive)
                meta
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        // Force an exact width here (before the background) so the bubble can
        // never overflow and the waveform fills the space inside it.
        .frame(width: bubbleWidth, alignment: .leading)
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
        Button(action: onPlayToggle) {
            ZStack {
                Circle()
                    .fill(mine ? AnyShapeStyle(Color.clear) : AnyShapeStyle(MurmurColor.accentGradientSoft))
                    .frame(width: 34, height: 34)
                    .overlay(Circle().strokeBorder(
                        mine ? MurmurColor.hairlineStrong : MurmurColor.accent.opacity(0.4),
                        lineWidth: mine ? 1.5 : 1))
                Image(systemName: isPlayingThis ? "pause.fill" : "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(mine ? MurmurColor.inkSecondary : MurmurColor.accent)
                    .offset(x: isPlayingThis ? 0 : 1)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .buttonStyle(.plain)
    }

    private var meta: some View {
        HStack(spacing: 7) {
            Text(murmur.durationLabel)
                .font(MurmurFont.rounded(12.5, weight: .medium).monospacedDigit())
                .foregroundStyle(mine ? MurmurColor.inkSecondary : MurmurColor.inkPrimary)
            Circle().fill(MurmurColor.inkTertiary).frame(width: 3, height: 3)
            // Aligned to this murmur's minute boundary so "just now" flips to the
            // clock time exactly one minute after it was sent.
            TimelineView(.periodic(from: murmur.createdAt, by: 60)) { context in
                Text(MurmurBubble.timeLabel(for: murmur.createdAt, now: context.date))
                    .font(MurmurFont.serifItalic(13))
                    .foregroundStyle(MurmurColor.inkTertiary)
            }
            if let reaction = murmur.reaction {
                Image(systemName: reaction)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MurmurColor.accent)
            }
            if mine {
                // One tick = sent, two ticks = delivered to the partner's device.
                deliveryTicks
            }
            if unplayed {
                Circle().fill(MurmurColor.accent).frame(width: 8, height: 8)
                    .shadow(color: MurmurColor.accent, radius: 6)
            }
        }
    }

    /// Delivery receipt: a single tick once sent, a second overlapping tick once
    /// the partner's device has pulled it down (isDelivered).
    private var deliveryTicks: some View {
        ZStack(alignment: .leading) {
            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
            if murmur.isDelivered {
                Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                    .offset(x: 4)
            }
        }
        .foregroundStyle(MurmurColor.accent)
        .frame(width: murmur.isDelivered ? 15 : 11, alignment: .leading)
    }

    // "just now" for the first minute, then the absolute clock time (the day
    // divider supplies the date). `now` is injected so a TimelineView can flip it.
    static func timeLabel(for date: Date, now: Date = .now) -> String {
        if now.timeIntervalSince(date) < 60 { return "just now" }
        return date.formatted(.dateTime.hour().minute())
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Murmur.self, inMemory: true)
}
