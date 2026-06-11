//
//  AudioService.swift
//  AVAudioEngine-based recorder.
//
//  Taps the input node, encodes straight to an AAC `.m4a` in the app's
//  Documents directory (named `<uuid>.m4a`), and hands back the file URL when
//  recording stops. Also publishes a smoothed input level and elapsed time so
//  the record UI can animate.
//

import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioService: ObservableObject {

    /// True while the engine is running and writing to disk.
    @Published private(set) var isRecording = false
    /// Seconds since the current recording began.
    @Published private(set) var elapsed: TimeInterval = 0
    /// Smoothed input loudness, 0...1 — drives the pulsing ring.
    @Published private(set) var level: CGFloat = 0

    private let engine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var currentURL: URL?
    private var startDate: Date?
    private var timer: Timer?

    // MARK: Permission

    /// Requests microphone access (iOS 17 API). Returns whether it was granted.
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: Recording lifecycle

    /// Configures the session, opens the output file and starts the engine.
    func startRecording() throws {
        guard !isRecording else { return }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        let fileName = "\(UUID().uuidString).m4a"
        let url = URL.documentsDirectory.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings)

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            try? file.write(from: buffer)
            self?.processLevel(buffer)
        }

        engine.prepare()
        try engine.start()

        audioFile = file
        currentURL = url
        startDate = Date()
        isRecording = true
        elapsed = 0
        startTimer()
    }

    /// Stops the engine and returns the finished file's URL (nil if not recording).
    @discardableResult
    func stopRecording() -> URL? {
        guard isRecording else { return nil }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        audioFile = nil

        timer?.invalidate()
        timer = nil
        try? AVAudioSession.sharedInstance().setActive(false)

        isRecording = false
        level = 0
        elapsed = 0
        startDate = nil

        let url = currentURL
        currentURL = nil
        return url
    }

    /// Aborts the current recording and deletes its partial file.
    func cancelRecording() {
        guard let url = currentURL else {
            stopRecording()
            return
        }
        stopRecording()
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: Metering

    /// Computes RMS loudness off the audio thread and publishes a smoothed
    /// 0...1 value on the main actor.
    private nonisolated func processLevel(_ buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return }

        var sum: Float = 0
        for i in 0..<frames {
            let sample = channel[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frames))
        let db = 20 * log10(max(rms, 1e-7))
        // Map roughly -50 dB...0 dB onto 0...1.
        let normalized = max(0, min(1, (db + 50) / 50))

        Task { @MainActor [weak self] in
            guard let self else { return }
            // Light smoothing so the ring breathes rather than jitters.
            self.level = self.level * 0.7 + CGFloat(normalized) * 0.3
        }
    }

    private func startTimer() {
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let start = self.startDate else { return }
                self.elapsed = Date().timeIntervalSince(start)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
