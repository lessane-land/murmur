//
//  MurmurListViewModel.swift
//  Inbox actions. The list itself is read with @Query in the view; this view
//  model owns mutations (delete) so the view stays declarative.
//

import Foundation
import SwiftData

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
}
