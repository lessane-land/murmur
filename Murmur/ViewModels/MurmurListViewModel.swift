//
//  MurmurListViewModel.swift
//  Inbox actions. The list itself is read with @Query in the view; this view
//  model owns mutations (delete, mark played) so the view stays declarative.
//

import Foundation
import SwiftData

@MainActor
final class MurmurListViewModel: ObservableObject {

    /// Deletes a murmur and its audio files (the recording and any voice reply).
    func delete(_ murmur: Murmur, in context: ModelContext) {
        try? FileManager.default.removeItem(at: murmur.audioFileURL)
        if let replyURL = murmur.reactionAudioURL {
            try? FileManager.default.removeItem(at: replyURL)
        }
        context.delete(murmur)
        try? context.save()
    }

    /// Marks a murmur as played (no-op if already played).
    func markPlayed(_ murmur: Murmur, in context: ModelContext) {
        guard !murmur.isPlayed else { return }
        murmur.isPlayed = true
        try? context.save()
    }

    /// Deletes every murmur and its audio.
    func deleteAll(in context: ModelContext) {
        guard let all = try? context.fetch(FetchDescriptor<Murmur>()) else { return }
        for murmur in all { delete(murmur, in: context) }
    }
}
