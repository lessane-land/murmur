//
//  TranscriptionService.swift
//  On-device speech-to-text for finished murmurs. Tries Apple's SpeechAnalyzer
//  (iOS 26, per CLAUDE.md); if that fails or yields nothing, falls back to
//  on-device SFSpeechRecognizer so transcription is reliable. Fully on-device —
//  audio never leaves the phone.
//

import Foundation
import Speech
import AVFoundation

enum TranscriptionError: Error {
    case notAuthorized
    case noLocale
    case empty
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
        print("Murmur.transcribe: authorized=\(authorized) file=\(url.lastPathComponent)")

        // 1) Try the modern SpeechAnalyzer pipeline.
        do {
            let text = try await transcribeWithAnalyzer(url: url, preferred: preferred)
            if !text.isEmpty {
                print("Murmur.transcribe: SpeechAnalyzer OK (\(text.count) chars)")
                return text
            }
            print("Murmur.transcribe: SpeechAnalyzer returned empty — falling back")
        } catch {
            print("Murmur.transcribe: SpeechAnalyzer failed (\(error)) — falling back")
        }

        // 2) Fall back to the proven on-device recognizer.
        let text = try await transcribeWithRecognizer(url: url, preferred: preferred)
        print("Murmur.transcribe: SFSpeechRecognizer OK (\(text.count) chars)")
        return text
    }

    // MARK: - SpeechAnalyzer (iOS 26)

    private func transcribeWithAnalyzer(url: URL, preferred: Locale) async throws -> String {
        let supported = await SpeechTranscriber.supportedLocales
        guard let locale = bestLocale(from: supported, preferred: preferred) else {
            throw TranscriptionError.noLocale
        }
        print("Murmur.analyzer: locale=\(locale.identifier(.bcp47))")

        let transcriber = SpeechTranscriber(locale: locale,
                                            transcriptionOptions: [],
                                            reportingOptions: [],
                                            attributeOptions: [])

        if let installation = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            print("Murmur.analyzer: installing on-device model…")
            try await installation.downloadAndInstall()
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let audioFile = try AVAudioFile(forReading: url)

        let collector = Task { () throws -> String in
            var text = AttributedString()
            for try await result in transcriber.results { text += result.text }
            return String(text.characters)
        }

        if let lastSample = try await analyzer.analyzeSequence(from: audioFile) {
            try await analyzer.finalizeAndFinish(through: lastSample)
        } else {
            await analyzer.cancelAndFinishNow()
        }

        return try await collector.value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func bestLocale(from supported: [Locale], preferred: Locale) -> Locale? {
        let wanted = preferred.identifier(.bcp47)
        if let exact = supported.first(where: { $0.identifier(.bcp47) == wanted }) { return exact }
        if let code = preferred.language.languageCode?.identifier,
           let sameLanguage = supported.first(where: { $0.language.languageCode?.identifier == code }) {
            return sameLanguage
        }
        if let english = supported.first(where: { $0.language.languageCode?.identifier == "en" }) { return english }
        return supported.first
    }

    // MARK: - SFSpeechRecognizer fallback (on-device)

    private func transcribeWithRecognizer(url: URL, preferred: Locale) async throws -> String {
        guard await requestAuthorization() else { throw TranscriptionError.notAuthorized }

        let recognizer = SFSpeechRecognizer(locale: preferred)
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            ?? SFSpeechRecognizer()
        guard let recognizer, recognizer.isAvailable else { throw TranscriptionError.noLocale }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    if !resumed { resumed = true; continuation.resume(throwing: error) }
                    return
                }
                guard let result, result.isFinal, !resumed else { return }
                resumed = true
                continuation.resume(returning: result.bestTranscription.formattedString)
            }
        }
    }
}
