//
//  TranscriptionService.swift
//  On-device speech-to-text for finished murmurs.
//
//  CLAUDE.md asks for Apple's SpeechAnalyzer. That API is iOS 26+ only, while
//  Murmur targets iOS 17, so this implementation uses SFSpeechRecognizer with
//  `requiresOnDeviceRecognition = true` — fully on-device, nothing leaves the
//  phone. When the deployment target moves to iOS 26 this is the one file to
//  swap for SpeechAnalyzer / SpeechTranscriber.
//
//  Audio never leaves the device; transcription runs after recording stops.
//

import Foundation
import Speech

enum TranscriptionError: Error {
    case notAuthorized
    case recognizerUnavailable
    case onDeviceUnavailable
}

@MainActor
final class TranscriptionService {

    /// Requests speech-recognition authorization. Returns whether it was granted.
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Transcribes the audio file at `url` on-device. `locale` defaults to the
    /// user's current locale; CLAUDE.md notes Spanish + English are both wanted,
    /// and the device locale covers the common case for the MVP.
    func transcribe(fileURL url: URL,
                    locale: Locale = .current) async throws -> String {
        guard await requestAuthorization() else { throw TranscriptionError.notAuthorized }

        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }
        guard recognizer.supportsOnDeviceRecognition else {
            throw TranscriptionError.onDeviceUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    if !didResume { didResume = true; continuation.resume(throwing: error) }
                    return
                }
                guard let result, result.isFinal else { return }
                if !didResume {
                    didResume = true
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}
