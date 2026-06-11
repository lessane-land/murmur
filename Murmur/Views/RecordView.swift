//
//  RecordView.swift
//  The recording sheet — a big tap-to-record button with a pulsing ring while
//  live, a serif timer, and Save / Cancel. Backed by RecordViewModel.
//

import SwiftUI
import SwiftData

struct RecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var theme = Theme.shared

    @StateObject private var model = RecordViewModel()

    var body: some View {
        ZStack {
            RadialGradient(colors: [MurmurColor.accentDeep.opacity(0.22),
                                    MurmurColor.background],
                           center: .init(x: 0.5, y: 0.12),
                           startRadius: 0, endRadius: 520)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer()
                centerStage
                Spacer()
                controls
            }
            .padding(.top, 16)
        }
        .preferredColorScheme(.dark)
        .onChange(of: model.elapsed) { _, _ in
            // Enforce the 3-minute maximum.
            if model.reachedMax && model.isRecording { save() }
        }
        .alert("Microphone access needed", isPresented: $model.permissionDenied) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text("Enable microphone access in Settings to record murmurs.")
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("new murmur").murmurOverline()
                Text(model.isRecording ? "listening…" : "tap to record")
                    .font(MurmurFont.rounded(16, weight: .semibold))
                    .foregroundStyle(MurmurColor.inkPrimary)
            }
            Spacer()
            Button {
                model.cancel()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MurmurColor.inkSecondary)
                    .frame(width: 38, height: 38)
                    .background(MurmurColor.surface, in: Circle())
                    .overlay(Circle().strokeBorder(MurmurColor.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
    }

    // MARK: Center stage

    private var centerStage: some View {
        VStack(spacing: 36) {
            VStack(spacing: 8) {
                Text(model.elapsedLabel)
                    .font(MurmurFont.timer(66))
                    .foregroundStyle(MurmurColor.inkPrimary)
                    .contentTransition(.numericText())
                Text("up to 3:00")
                    .font(MurmurFont.rounded(12))
                    .foregroundStyle(MurmurColor.inkTertiary)
                    .opacity(model.isRecording ? 1 : 0)
            }

            recordButton
        }
    }

    private var recordButton: some View {
        ZStack {
            if model.isRecording {
                PulsingRing(level: model.level)
            }

            Button(action: toggleRecording) {
                ZStack {
                    Circle()
                        .fill(MurmurColor.surface)
                        .frame(width: 116, height: 116)
                        .overlay(Circle().strokeBorder(MurmurColor.hairlineStrong, lineWidth: 3))

                    Circle()
                        .fill(MurmurColor.accentGradient)
                        .frame(width: 96, height: 96)
                        .shadow(color: MurmurColor.accentDeep.opacity(0.55), radius: 18, y: 8)

                    Image(systemName: model.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: model.isRecording ? 34 : 40, weight: .medium))
                        .foregroundStyle(MurmurColor.background)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .buttonStyle(.plain)
        }
        .frame(width: 220, height: 220)
    }

    // MARK: Controls

    private var controls: some View {
        HStack {
            Button("Cancel") {
                model.cancel()
                dismiss()
            }
            .font(MurmurFont.rounded(16, weight: .medium))
            .foregroundStyle(MurmurColor.inkSecondary)

            Spacer()

            Button("Save") { save() }
                .font(MurmurFont.rounded(16, weight: .semibold))
                .foregroundStyle(model.isRecording ? MurmurColor.accentSoft : MurmurColor.inkTertiary)
                .disabled(!model.isRecording)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 44)
    }

    // MARK: Actions

    private func toggleRecording() {
        if model.isRecording {
            save()
        } else {
            Task { await model.startRecording() }
        }
    }

    private func save() {
        model.finish(in: modelContext)
        dismiss()
    }
}

// MARK: - Pulsing ring

/// Three concentric rings that expand and fade outward while recording, lightly
/// energised by the live input level.
private struct PulsingRing: View {
    var level: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                Ring(delay: Double(index) * 0.7)
            }
            Circle()
                .fill(MurmurColor.recordingDot.opacity(0.18))
                .frame(width: 130, height: 130)
                .scaleEffect(1 + level * 0.35)
                .animation(.easeOut(duration: 0.12), value: level)
        }
    }

    private struct Ring: View {
        let delay: Double
        @State private var animate = false

        var body: some View {
            Circle()
                .strokeBorder(MurmurColor.recordingDot.opacity(0.55), lineWidth: 2)
                .frame(width: 116, height: 116)
                .scaleEffect(animate ? 1.9 : 1)
                .opacity(animate ? 0 : 0.6)
                .onAppear {
                    withAnimation(.easeOut(duration: 2.1)
                        .repeatForever(autoreverses: false)
                        .delay(delay)) {
                        animate = true
                    }
                }
        }
    }
}

#Preview {
    RecordView()
        .modelContainer(for: Murmur.self, inMemory: true)
}
