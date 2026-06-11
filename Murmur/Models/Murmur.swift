//
//  Murmur.swift
//  The SwiftData model for a single voice message.
//
//  Fields follow CLAUDE.md: id, senderName, audioFileURL (local), transcript
//  (optional), duration, createdAt, isPlayed, isOutgoing. The audio file lives
//  in the app's Documents directory and is named with the murmur's UUID; we
//  store the file *name* (not an absolute URL) because the Documents container
//  path can change between launches.
//

import Foundation
import SwiftData

@Model
final class Murmur {
    /// Stable identity (also used to name the on-disk audio file).
    @Attribute(.unique) var id: UUID

    /// Display name of whoever recorded it. Hardcoded for MVP until onboarding.
    var senderName: String

    /// File name of the recording inside Documents, e.g. `"<uuid>.m4a"`.
    var audioFileName: String

    /// On-device transcript. Optional: nil until transcription finishes.
    var transcript: String?

    /// Clip length in seconds.
    var duration: TimeInterval

    /// When the recording was captured.
    var createdAt: Date

    /// Whether it has been listened to yet.
    var isPlayed: Bool

    /// True when *you* recorded it; false when it arrived from your partner.
    var isOutgoing: Bool

    /// Normalised 0...1 waveform bar heights captured while recording.
    /// Optional so rows without a stored waveform still decode.
    var waveform: [Double]?

    init(id: UUID = UUID(),
         senderName: String,
         audioFileName: String,
         transcript: String? = nil,
         duration: TimeInterval,
         createdAt: Date = .now,
         isPlayed: Bool = false,
         isOutgoing: Bool = true,
         waveform: [Double]? = nil) {
        self.id = id
        self.senderName = senderName
        self.audioFileName = audioFileName
        self.transcript = transcript
        self.duration = duration
        self.createdAt = createdAt
        self.isPlayed = isPlayed
        self.isOutgoing = isOutgoing
        self.waveform = waveform
    }
}

// MARK: - Derived

extension Murmur {
    /// Resolves the audio file's current location in Documents.
    var audioFileURL: URL {
        URL.documentsDirectory.appendingPathComponent(audioFileName)
    }

    /// `0:48`, `1:05`, … for display.
    var durationLabel: String {
        let total = Int(duration.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Single-letter avatar initial.
    var avatarInitial: String {
        String(senderName.first ?? "?").uppercased()
    }

    /// Stable waveform bars for display — uses the captured waveform when
    /// present, otherwise a deterministic synthetic one seeded by the id.
    func displayWaveform(barCount: Int = 48) -> [Double] {
        if let waveform, !waveform.isEmpty { return waveform }
        return Waveform.synthetic(seed: id.hashValue, count: barCount)
    }
}

// MARK: - Deterministic waveform synthesis

enum Waveform {
    /// Stable pseudo-random bars for a given seed with a gentle speech-like
    /// envelope so the ends taper. Used as a fallback when no real waveform was
    /// captured.
    static func synthetic(seed: Int, count: Int = 48) -> [Double] {
        var out: [Double] = []
        var x = Double(seed % 100_000) * 0.0001 + 0.123
        for i in 0..<count {
            x = (sin(x * 12.9898 + Double(i) * 78.233) * 43758.5453)
                .truncatingRemainder(dividingBy: 1)
            let v = abs(x)
            let env = 0.55 + 0.45 * sin(Double(i) / Double(count) * .pi)
            out.append(0.18 + v * 0.82 * env)
        }
        return out
    }
}
