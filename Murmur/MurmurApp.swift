//
//  MurmurApp.swift
//  App entry point. Stands up the SwiftData container and shows ContentView.
//

import SwiftUI
import SwiftData

@main
struct MurmurApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Murmur.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
