//
//  MurmurListViewModel.swift
//  Inbox actions. The list itself is read with @Query in the view; this view
//  model owns mutations (delete, demo seeding) so the view stays declarative.
//

import Foundation
import SwiftData
import AVFoundation

@MainActor
final class MurmurListViewModel: ObservableObject {

    /// Deletes a murmur and its audio file from disk.
    func delete(_ murmur: Murmur, in context: ModelContext) {
        try? FileManager.default.removeItem(at: murmur.audioFileURL)
        context.delete(murmur)
        try? context.save()
    }

    /// Marks a murmur as played (no-op if already played).
    func markPlayed(_ murmur: Murmur, in context: ModelContext) {
        guard !murmur.isPlayed else { return }
        murmur.isPlayed = true
        try? context.save()
    }

    /// Deletes every murmur and its audio (used to reset demo data).
    func deleteAll(in context: ModelContext) {
        guard let all = try? context.fetch(FetchDescriptor<Murmur>()) else { return }
        for murmur in all { delete(murmur, in: context) }
    }

    // MARK: - Demo mode

    /// Seeds a few incoming murmurs from the partner so the two-person inbox can
    /// be experienced on one device without the full CloudKit pairing. Each gets
    /// a real (synthesised) audio file so playback, waveform and duration work.
    func seedDemoMurmurs(in context: ModelContext, partnerName: String) {
        let sender = partnerName.isEmpty ? "Mara" : partnerName

        // (transcript, seconds, tone Hz, hours-ago, alreadyPlayed)
        let scripts: [(String, Double, Double, Double, Bool)] = [
            ("Morning — well, your morning. The light was doing that gold thing on the tiles again and I kept wanting to point at it and turn to you.",
             14, 246.94, 1, false),
            ("It's late here. Three hours ahead of you and already missing tomorrow with you in it. Sleep well, love.",
             9, 329.63, 3, false),
            ("Coffee's on. Pretend you're across the table from me for a second. There. Okay — go conquer your day.",
             11, 293.66, 26, true),
            ("Long one, sorry. Work was a lot but I saved the good part for you. Remind me to tell you about the dog at the bus stop.",
             18, 220.00, 30, true),
        ]

        for (transcript, seconds, hz, hoursAgo, played) in scripts {
            guard let fileName = makeToneFile(seconds: seconds, frequency: hz) else { continue }
            let murmur = Murmur(senderName: sender,
                                audioFileName: fileName,
                                transcript: transcript,
                                duration: seconds,
                                createdAt: Date().addingTimeInterval(-hoursAgo * 3600),
                                isPlayed: played,
                                isOutgoing: false)
            context.insert(murmur)
        }
        try? context.save()
    }

    /// Writes a short, gently-enveloped sine tone to an .m4a in Documents and
    /// returns its file name. Stand-in audio for demo murmurs.
    private func makeToneFile(seconds: Double, frequency: Double) -> String? {
        let sampleRate = 44_100.0
        let fileName = "demo-\(UUID().uuidString).m4a"
        let url = URL.documentsDirectory.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        guard let file = try? AVAudioFile(forWriting: url, settings: settings) else { return nil }

        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(seconds * sampleRate)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else { return nil }

        buffer.frameLength = frameCount
        let total = Int(frameCount)
        let omega = 2.0 * Double.pi * frequency
        for i in 0..<total {
            let t = Double(i) / sampleRate
            // Fade in/out so it doesn't click, plus a slow tremolo for warmth.
            let envelope = sin(Double(i) / Double(total) * Double.pi)
            let tremolo = 0.85 + 0.15 * sin(2.0 * Double.pi * 4.0 * t)
            channel[i] = Float(sin(omega * t) * 0.28 * envelope * tremolo)
        }

        do {
            try file.write(from: buffer)
            return fileName
        } catch {
            print("Murmur: demo tone write failed — \(error)")
            return nil
        }
    }
}
