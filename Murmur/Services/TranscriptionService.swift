//
//  TranscriptionService.swift
//  On-device speech-to-text. Since SFSpeechRecognizer needs a fixed locale, we
//  transcribe with a few candidate languages (the user's preferred languages
//  plus English and Spanish) and keep whichever result the recognizer is most
//  confident about — an effective "detect the language" for a bilingual user.
//  Fully private: on-device recognition where available.
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

    /// Transcribes the audio at `url`, choosing the best-scoring language.
    func transcribe(fileURL url: URL, preferred: Locale = .current) async throws -> String {
        let authorized = await requestAuthorization()
        print("Murmur.transcribe: authorized=\(authorized), file=\(url.lastPathComponent)")
        guard authorized else { throw TranscriptionError.notAuthorized }

        var best: (text: String, score: Double)?
        var lastError: Error?

        for locale in candidateLocales(preferred: preferred) {
            guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else { continue }
            do {
                let (text, score) = try await recognize(url: url, recognizer: recognizer)
                print("Murmur.transcribe: [\(locale.identifier)] score=\(String(format: "%.2f", score)) text=\"\(text.prefix(40))\"")
                if !text.isEmpty, best == nil || score > best!.score {
                    best = (text, score)
                }
            } catch {
                print("Murmur.transcribe: [\(locale.identifier)] failed — \(error)")
                lastError = error
            }
        }

        if let best { return best.text }
        if let lastError { throw lastError }
        throw TranscriptionError.unavailable
    }

    // MARK: - Candidate languages

    private func candidateLocales(preferred: Locale) -> [Locale] {
        var raw: [String] = Array(Locale.preferredLanguages.prefix(3))
        raw.append(preferred.identifier)
        raw.append(contentsOf: ["en-US", "es-ES"])

        var seenLanguage = Set<String>()
        var result: [Locale] = []
        for id in raw {
            let locale = Locale(identifier: id)
            let code = locale.language.languageCode?.identifier ?? id
            if seenLanguage.insert(code).inserted { result.append(locale) }
        }
        return result
    }

    // MARK: - Recognition

    /// Returns the transcript and a confidence-weighted score for ranking.
    private func recognize(url: URL, recognizer: SFSpeechRecognizer) async throws -> (text: String, score: Double) {
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
                let transcription = result.bestTranscription
                let segments = transcription.segments
                let words = max(segments.count, transcription.formattedString.split(separator: " ").count)
                let avgConfidence = segments.isEmpty
                    ? 0.0
                    : Double(segments.map { $0.confidence }.reduce(0, +)) / Double(segments.count)
                // Weight by confidence; fall back to length when confidence is 0.
                let score = max(avgConfidence, 0.01) * Double(words)
                continuation.resume(returning: (transcription.formattedString, score))
            }
        }
    }
}
