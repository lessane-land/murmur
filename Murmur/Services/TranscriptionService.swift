//
//  TranscriptionService.swift
//  On-device speech-to-text for finished murmurs using Apple's SpeechAnalyzer
//  (iOS 26+), exactly as CLAUDE.md specifies. Fully on-device — audio never
//  leaves the phone. Runs after recording stops.
//

import Foundation
import Speech
import AVFoundation

enum TranscriptionError: Error {
    case notAuthorized
    case localeUnsupported
}

@MainActor
final class TranscriptionService {

    /// Requests speech authorization. Returns whether it was granted.
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Transcribes the audio file at `url` on-device with SpeechAnalyzer.
    /// `locale` defaults to the user's current locale; CLAUDE.md notes Spanish +
    /// English are both wanted, and the device locale covers the common case.
    func transcribe(fileURL url: URL, locale: Locale = .current) async throws -> String {
        guard await requestAuthorization() else { throw TranscriptionError.notAuthorized }

        // Resolve a locale the transcriber actually supports.
        let supported = await SpeechTranscriber.supportedLocales
        let wanted = locale.identifier(.bcp47)
        let chosen = supported.first { $0.identifier(.bcp47) == wanted }
            ?? supported.first { $0.language.languageCode == locale.language.languageCode }
        guard let chosen else { throw TranscriptionError.localeUnsupported }

        let transcriber = SpeechTranscriber(locale: chosen,
                                            transcriptionOptions: [],
                                            reportingOptions: [],
                                            attributeOptions: [])

        // Ensure the on-device model for this locale is installed.
        if let installation = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await installation.downloadAndInstall()
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let audioFile = try AVAudioFile(forReading: url)

        // Collect transcript results concurrently while the file is analysed.
        let collector = Task {
            var text = AttributedString()
            for try await case let result in transcriber.results {
                text += result.text
            }
            return text
        }

        if let lastSample = try await analyzer.analyzeSequence(from: audioFile) {
            try await analyzer.finalizeAndFinish(through: lastSample)
        } else {
            await analyzer.cancelAndFinishNow()
        }

        let transcript = try await collector.value
        return String(transcript.characters)
    }
}
