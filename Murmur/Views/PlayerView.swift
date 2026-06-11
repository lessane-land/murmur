//
//  PlayerView.swift
//  Inline waveform player shown when a murmur row is expanded. Play/pause, a
//  tappable waveform progress bar, and a collapsible transcript.
//

import SwiftUI
import SwiftData
import AVFoundation

struct PlayerView: View {
    let murmur: Murmur
    var onPlaybackStarted: () -> Void = {}

    @StateObject private var controller = AudioPlayerController()
    @State private var showTranscript = false

    private var bars: [Double] { murmur.displayWaveform() }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                playButton
                waveform
                Text(timeLabel)
                    .font(MurmurFont.rounded(13, weight: .medium).monospacedDigit())
                    .foregroundStyle(MurmurColor.inkSecondary)
                    .frame(width: 44, alignment: .trailing)
            }

            transcriptSection
        }
        .padding(16)
        .background(MurmurColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(MurmurColor.hairline, lineWidth: 1))
        .onDisappear { controller.stop() }
    }

    // MARK: Play / pause

    private var playButton: some View {
        Button {
            if controller.isPlaying {
                controller.pause()
            } else {
                controller.play(url: murmur.audioFileURL)
                onPlaybackStarted()
            }
        } label: {
            Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(MurmurColor.background)
                .frame(width: 44, height: 44)
                .background(MurmurColor.accentGradient, in: Circle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
    }

    // MARK: Waveform

    private var waveform: some View {
        GeometryReader { geo in
            let progress = controller.progress
            HStack(alignment: .center, spacing: 2) {
                ForEach(Array(bars.enumerated()), id: \.offset) { index, value in
                    let fraction = bars.isEmpty ? 0 : Double(index) / Double(bars.count)
                    Capsule()
                        .fill(fraction <= progress ? MurmurColor.accent : MurmurColor.hairlineStrong)
                        .frame(height: max(3, CGFloat(value) * geo.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .onTapGesture { location in
                let fraction = max(0, min(1, location.x / geo.size.width))
                controller.seek(toFraction: fraction, url: murmur.audioFileURL)
            }
        }
        .frame(height: 40)
    }

    // MARK: Transcript

    @ViewBuilder
    private var transcriptSection: some View {
        if let transcript = murmur.transcript, !transcript.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showTranscript.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Text("Transcript").murmurOverline()
                        Image(systemName: showTranscript ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(MurmurColor.inkTertiary)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)

                if showTranscript {
                    Text(transcript)
                        .font(MurmurFont.rounded(15))
                        .foregroundStyle(MurmurColor.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else {
            HStack {
                Text("Transcribing…").murmurOverline()
                Spacer()
            }
        }
    }

    private var timeLabel: String {
        let remaining = max(0, murmur.duration * (1 - controller.progress))
        let total = Int(remaining.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Playback controller

@MainActor
final class AudioPlayerController: NSObject, ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var progress: Double = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func play(url: URL) {
        if player == nil {
            configureSession()
            player = try? AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
        }
        player?.play()
        isPlaying = true
        startTimer()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        timer?.invalidate()
    }

    func seek(toFraction fraction: Double, url: URL) {
        if player == nil { play(url: url); pause() }
        guard let player else { return }
        player.currentTime = fraction * player.duration
        progress = fraction
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        progress = 0
        timer?.invalidate()
        timer = nil
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
    }

    private func startTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player, player.duration > 0 else { return }
                self.progress = player.currentTime / player.duration
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}

extension AudioPlayerController: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.progress = 0
            self.timer?.invalidate()
        }
    }
}
