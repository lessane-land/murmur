//
//  ContentView.swift
//  The home surface. Phase 1: lists saved murmurs and exposes a mic button that
//  opens the recording sheet.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var theme = Theme.shared
    @Query(sort: \Murmur.createdAt, order: .reverse) private var murmurs: [Murmur]

    @State private var showRecorder = false
    @State private var showSettings = false

    var body: some View {
        ZStack {
            MurmurColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if murmurs.isEmpty {
                    emptyState
                } else {
                    list
                }
            }

            micButton
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showRecorder) {
            RecordView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("murmur")
                    .font(MurmurFont.rounded(30, weight: .bold))
                    .foregroundStyle(MurmurColor.inkPrimary)
                Text("\(murmurs.count) recorded")
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
        .padding(.bottom, 20)
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "waveform")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(MurmurColor.accent)
            Text("No murmurs yet")
                .font(MurmurFont.rounded(18, weight: .semibold))
                .foregroundStyle(MurmurColor.inkSecondary)
            Text("Tap the mic to leave your first one.")
                .font(MurmurFont.rounded(14))
                .foregroundStyle(MurmurColor.inkTertiary)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: List

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(murmurs) { murmur in
                    MurmurRow(murmur: murmur)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 140)
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
}

// MARK: - Row

private struct MurmurRow: View {
    let murmur: Murmur

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "waveform")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(MurmurColor.accent)
                .frame(width: 44, height: 44)
                .background(MurmurColor.surfaceHi, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(murmur.createdAt, format: .dateTime.weekday().hour().minute())
                    .font(MurmurFont.rounded(15, weight: .semibold))
                    .foregroundStyle(MurmurColor.inkPrimary)
                Text(murmur.isFromMe ? "You" : "Partner")
                    .font(MurmurFont.rounded(12))
                    .foregroundStyle(MurmurColor.inkTertiary)
            }

            Spacer()

            Text(murmur.durationLabel)
                .font(MurmurFont.rounded(14, weight: .medium).monospacedDigit())
                .foregroundStyle(MurmurColor.inkSecondary)
        }
        .padding(14)
        .background(MurmurColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(MurmurColor.hairline, lineWidth: 1))
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Murmur.self, inMemory: true)
}
