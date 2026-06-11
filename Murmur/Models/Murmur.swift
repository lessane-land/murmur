//
//  Murmur.swift
//  The SwiftData model for a single voice message.
//
//  Phase 1 stores only what local recording produces: the audio file, how long
//  it is, when it was made, and who it's from. Transcript and sync metadata are
//  present but unused until later phases.
//

import Foundation
import SwiftData

@Model
final class Murmur {
    /// Stable identity (also used to name the on-disk audio file).
    @Attribute(.unique) var id: UUID

    /// File name of the recording inside the app's Documents directory, e.g.
    /// `"<uuid>.m4a"`. We store the name (not an absolute URL) because the
    /// Documents container path can change between launches.
    var audioFileName: String

    /// Clip length in seconds.
    var duration: TimeInterval

    /// When the recording was captured.
    var createdAt: Date

    /// True when *you* recorded it; false when it arrived from your partner.
    var isFromMe: Bool

    /// Whether the recipient has listened to it yet.
    var isPlayed: Bool

    /// On-device transcript — populated in a later phase.
    var transcript: String

    /// Normalised 0...1 waveform bar heights captured while recording.
    /// Optional so older rows without a waveform still decode.
    var waveform: [Double]?

    init(id: UUID = UUID(),
         audioFileName: String,
         duration: TimeInterval,
         createdAt: Date = .now,
         isFromMe: Bool = true,
         isPlayed: Bool = false,
         transcript: String = "",
         waveform: [Double]? = nil) {
        self.id = id
        self.audioFileName = audioFileName
        self.duration = duration
        self.createdAt = createdAt
        self.isFromMe = isFromMe
        self.isPlayed = isPlayed
        self.transcript = transcript
        self.waveform = waveform
    }
}

// MARK: - Derived

extension Murmur {
    /// Resolves the audio file's current location in Documents.
    var audioURL: URL {
        URL.documentsDirectory.appendingPathComponent(audioFileName)
    }

    /// `0:48`, `1:05`, … for display.
    var durationLabel: String {
        let total = Int(duration.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
