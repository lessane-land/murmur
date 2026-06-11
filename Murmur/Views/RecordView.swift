//
//  RecordView.swift
//  The recording sheet: a live waveform, a serif-italic timer, pulsing rings
//  around the send button, and Cancel / Send / Pause controls.
//

import SwiftUI
import SwiftData

struct RecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var theme = Theme.shared

    @StateObject private var model = RecordViewModel()
    @State private var blink = false

    private var partnerName: String { ProfileStore.shared.partnerName }

    var body: some View {
        ZStack {
            RadialGradient(colors: [MurmurColor.sheetTint, MurmurColor.backgroundWell],
                           center: .init(x: 0.5, y: 0.08), startRadius: 0, endRadius: 560)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                grabber
                header
                Spacer()
                centerStage
                Spacer()
                controls
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            Task { await model.startRecording() }
            withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) { blink = true }
        }
        .onChange(of: model.elapsed) { _, _ in
            if model.elapsed >= model.maxDuration && model.isRecording { save() }
        }
        .alert("Microphone access needed", isPresented: $model.permissionDenied) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text("Enable microphone access in Settings to record murmurs.")
        }
    }

    private var grabber: some View {
        Capsule().fill(MurmurColor.hairlineStrong)
            .frame(width: 38, height: 5)
            .padding(.top, 12)
    }

    // MARK: Header

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                MurmurAvatar(initial: String(partnerName.first ?? "M").uppercased(), size: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text("recording to")
                        .font(MurmurFont.rounded(11)).tracking(0.6).textCase(.uppercase)
                        .foregroundStyle(MurmurColor.inkTertiary)
                    Text(partnerName.isEmpty ? "your partner" : partnerName)
                        .font(MurmurFont.rounded(15, weight: .semibold))
                        .foregroundStyle(MurmurColor.inkPrimary)
                }
            }
            Spacer()
            GlassButton(systemName: "xmark", tint: MurmurColor.inkSecondary) {
                model.cancel(); dismiss()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    // MARK: Center stage

    private var centerStage: some View {
        VStack(spacing: 26) {
            VStack(spacing: 14) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(model.isPaused ? MurmurColor.inkTertiary : MurmurColor.recordingPink)
                        .frame(width: 7, height: 7)
                        .shadow(color: model.isPaused ? .clear : MurmurColor.recordingPink, radius: 5)
                        .opacity(model.isPaused ? 1 : (blink ? 0.25 : 1))
                    Text(model.isPaused ? "paused" : "listening")
                        .font(MurmurFont.rounded(11.5, weight: .semibold)).tracking(0.8).textCase(.uppercase)
                        .foregroundStyle(model.isPaused ? MurmurColor.inkTertiary : MurmurColor.inkSecondary)
                }
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(MurmurColor.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(MurmurColor.hairline, lineWidth: 1))

                Text(model.elapsedLabel)
                    .font(MurmurFont.timer(64))
                    .foregroundStyle(MurmurColor.inkPrimary)
                    .contentTransition(.numericText())
            }

            LiveWaveformView(level: model.level, paused: model.isPaused)
                .frame(height: 130)
                .padding(.horizontal, 24)
                .opacity(model.isPaused ? 0.4 : 1)
        }
    }

    // MARK: Controls

    private var controls: some View {
        HStack(alignment: .top, spacing: 40) {
            labeled("Cancel") {
                GlassButton(systemName: "trash", size: 52, iconSize: 21,
                            tint: MurmurColor.inkSecondary) { model.cancel(); dismiss() }
            }

            VStack(spacing: 9) {
                ZStack {
                    if !model.isPaused { PulsingRings(diameter: 92) }
                    Button(action: save) {
                        ZStack {
                            Circle().fill(MurmurColor.background)
                                .frame(width: 86, height: 86)
                                .overlay(Circle().strokeBorder(.white.opacity(0.16), lineWidth: 3))
                                .shadow(color: .black.opacity(0.5), radius: 12, y: 4)
                            Circle().fill(MurmurColor.accentGradient)
                                .frame(width: 70, height: 70)
                                .shadow(color: MurmurColor.accentDeep.opacity(0.5), radius: 14, y: 4)
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(MurmurColor.background)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.isRecording)
                }
                .frame(width: 92, height: 92)
                Text("Send").font(MurmurFont.rounded(12)).foregroundStyle(MurmurColor.inkTertiary)
            }

            labeled(model.isPaused ? "Resume" : "Pause") {
                GlassButton(systemName: model.isPaused ? "mic.fill" : "pause.fill",
                            size: 52, iconSize: 21, tint: MurmurColor.inkSecondary) {
                    model.togglePause()
                }
            }
        }
        .padding(.bottom, 50)
    }

    private func labeled<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(spacing: 9) {
            content()
            Text(label).font(MurmurFont.rounded(12)).foregroundStyle(MurmurColor.inkTertiary)
        }
    }

    // MARK: Actions

    private func save() {
        model.finish(in: modelContext)
        dismiss()
    }
}

#Preview {
    RecordView()
        .modelContainer(for: Murmur.self, inMemory: true)
}
