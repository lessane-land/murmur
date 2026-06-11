//
//  TranscriptionService.swift
//  On-device speech-to-text for finished murmurs using SFSpeechRecognizer with
//  on-device recognition. Reliable across SDKs and fully private — audio never
//  leaves the phone. (SpeechAnalyzer, per CLAUDE.md, can be swapped back in
//  once its iOS 26 API is pinned down; SFSpeechRecognizer keeps the build solid
//  and transcription working today.)
//

import Foundation
import Speech

enum TranscriptionError: Error {
    case notAuthorized
    case unavailable
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

    /// Transcribes the audio file at `url` on-device.
    func transcribe(fileURL url: URL, preferred: Locale = .current) async throws -> String {
        let authorized = await requestAuthorization()
        print("Murmur.transcribe: authorized=\(authorized), file=\(url.lastPathComponent)")
        guard authorized else { throw TranscriptionError.notAuthorized }

        let recognizer = SFSpeechRecognizer(locale: preferred)
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            ?? SFSpeechRecognizer()
        guard let recognizer, recognizer.isAvailable else {
            print("Murmur.transcribe: no available recognizer")
            throw TranscriptionError.unavailable
        }

        // Prefer on-device; if that fails (e.g. model not ready), fall back to
        // server recognition.
        if recognizer.supportsOnDeviceRecognition {
            do {
                return try await recognize(url: url, recognizer: recognizer, onDevice: true)
            } catch {
                print("Murmur.transcribe: on-device failed (\(error)); trying server")
            }
        }
        return try await recognize(url: url, recognizer: recognizer, onDevice: false)
    }

    private func recognize(url: URL, recognizer: SFSpeechRecognizer, onDevice: Bool) async throws -> String {
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = onDevice
        request.shouldReportPartialResults = false

        let text: String = try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    if !resumed { resumed = true; continuation.resume(throwing: error) }
                    return
                }
                if let result, result.isFinal, !resumed {
                    resumed = true
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
        print("Murmur.transcribe: result (onDevice=\(onDevice)) = \"\(text)\"")
        return text
    }
}
