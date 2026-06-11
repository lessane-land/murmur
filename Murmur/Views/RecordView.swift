//
//  RecordView.swift
//  The recording sheet — a big tap-to-record button with a pulsing ring while
//  live, a rounded serifless timer, and Save / Cancel.
//

import SwiftUI
import SwiftData

struct RecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var theme = Theme.shared

    @StateObject private var audio = AudioService()
    @State private var permissionDenied = false

    var body: some View {
        ZStack {
            // Warm dark canvas with a soft rose glow up top.
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
        .alert("Microphone access needed",
               isPresented: $permissionDenied) {
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
                Text(audio.isRecording ? "listening…" : "tap to record")
                    .font(MurmurFont.rounded(16, weight: .semibold))
                    .foregroundStyle(MurmurColor.inkPrimary)
            }
            Spacer()
            Button {
                audio.cancelRecording()
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
        VStack(spacing: 40) {
            Text(timeLabel)
                .font(MurmurFont.timer(64))
                .foregroundStyle(MurmurColor.inkPrimary)
                .contentTransition(.numericText())

            recordButton
        }
    }

    private var recordButton: some View {
        ZStack {
            if audio.isRecording {
                PulsingRing(level: audio.level)
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

                    Image(systemName: audio.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: audio.isRecording ? 34 : 40, weight: .medium))
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
                audio.cancelRecording()
                dismiss()
            }
            .font(MurmurFont.rounded(16, weight: .medium))
            .foregroundStyle(MurmurColor.inkSecondary)

            Spacer()

            Button("Save") { save() }
                .font(MurmurFont.rounded(16, weight: .semibold))
                .foregroundStyle(audio.isRecording || audio.elapsed > 0
                                 ? MurmurColor.accentSoft : MurmurColor.inkTertiary)
                .disabled(!audio.isRecording && audio.elapsed == 0)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 44)
    }

    // MARK: Helpers

    private var timeLabel: String {
        let total = Int(audio.elapsed)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func toggleRecording() {
        if audio.isRecording {
            save()
        } else {
            Task {
                guard await audio.requestPermission() else {
                    permissionDenied = true
                    return
                }
                do {
                    try audio.startRecording()
                } catch {
                    print("Murmur: failed to start recording — \(error)")
                }
            }
        }
    }

    private func save() {
        let duration = audio.elapsed
        guard let url = audio.stopRecording() else { return }

        let murmur = Murmur(audioFileName: url.lastPathComponent, duration: duration)
        modelContext.insert(murmur)
        try? modelContext.save()
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
            // Inner halo that swells with loudness.
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
