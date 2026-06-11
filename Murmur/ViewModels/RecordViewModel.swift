//
//  RecordViewModel.swift
//  Drives the recording sheet: owns the AudioService, persists the finished
//  murmur to SwiftData, and kicks off on-device transcription. Enforces the
//  3-minute maximum from CLAUDE.md.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class RecordViewModel: ObservableObject {

    /// Keep murmurs intimate, not podcasts (CLAUDE.md).
    let maxDuration: TimeInterval = 180

    @Published var permissionDenied = false

    private let audio = AudioService()
    private let transcription = TranscriptionService()
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Re-publish the AudioService's changes so views observing this view
        // model update as recording progresses.
        audio.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: Forwarded state

    var isRecording: Bool { audio.isRecording }
    var elapsed: TimeInterval { audio.elapsed }
    var level: CGFloat { audio.level }

    var elapsedLabel: String {
        let total = Int(elapsed)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Whether the clip has reached the maximum length.
    var reachedMax: Bool { elapsed >= maxDuration }

    // MARK: Lifecycle

    func startRecording() async {
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

    func cancel() {
        audio.cancelRecording()
    }

    /// Stops recording, persists a Murmur, and starts background transcription.
    /// Returns false (saving nothing) for clips too short to be meaningful.
    @discardableResult
    func finish(in context: ModelContext) -> Bool {
        let duration = audio.elapsed
        let waveform = audio.waveformSnapshot()
        let url = audio.stopRecording()
        guard let url, duration >= 0.4 else {
            // Discard clips too short to be meaningful, removing any partial file.
            if let url { try? FileManager.default.removeItem(at: url) }
            return false
        }

        let murmur = Murmur(senderName: "You",
                            audioFileName: url.lastPathComponent,
                            duration: duration,
                            isOutgoing: true,
                            waveform: waveform.isEmpty ? nil : waveform)
        context.insert(murmur)
        try? context.save()

        transcribe(murmur, in: context)
        return true
    }

    // MARK: Transcription

    private func transcribe(_ murmur: Murmur, in context: ModelContext) {
        let url = murmur.audioFileURL
        Task { [transcription] in
            do {
                let text = try await transcription.transcribe(fileURL: url)
                murmur.transcript = text
                try? context.save()
            } catch {
                print("Murmur: transcription failed — \(error)")
            }
        }
    }
}
