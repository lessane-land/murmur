//
//  MurmurApp.swift
//  App entry point. Stands up SwiftData, gates first launch on onboarding, and
//  drives CloudKit sync + push handling through an app delegate.
//

import SwiftUI
import SwiftData
import CloudKit
import UserNotifications

@main
struct MurmurApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    let sharedModelContainer: ModelContainer = {
        let schema = Schema([Murmur.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // Make the container available to background push handling.
        SyncBridge.shared.modelContainer = sharedModelContainer
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}

/// Switches between onboarding and the inbox, and kicks off sync once shown.
struct RootView: View {
    @ObservedObject private var profile = ProfileStore.shared

    var body: some View {
        Group {
            if profile.isOnboarded {
                ContentView()
            } else {
                OnboardingView()
            }
        }
        .task {
            SyncBridge.shared.requestNotificationAuthorization()
            await SyncBridge.shared.bootstrap()
        }
    }
}

// MARK: - Sync bridge

/// Glue between CloudKit, SwiftData and notifications. Holds the container so
/// push handling (which happens outside the SwiftUI environment) can sync.
@MainActor
final class SyncBridge: ObservableObject {
    static let shared = SyncBridge()
    var modelContainer: ModelContainer?

    func requestNotificationAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// One-time-ish setup: register push subscriptions, then sync.
    func bootstrap() async {
        await CloudKitService.shared.registerSubscriptions()
        await sync()
    }

    /// Uploads pending outgoing murmurs and pulls the partner's new ones,
    /// raising a local notification for anything that arrived.
    func sync() async {
        guard let container = modelContainer else { return }
        let context = ModelContext(container)
        let partnerName = ProfileStore.shared.partnerName

        await CloudKitService.shared.uploadPending(in: context)
        let inserted = await CloudKitService.shared.fetchIncoming(into: context, partnerName: partnerName)
        if inserted > 0 { postLocalNotification(partnerName: partnerName) }
    }

    private func postLocalNotification(partnerName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Murmur"
        content.body = "\(partnerName.isEmpty ? "Someone" : partnerName) left you a murmur"
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - App delegate (remote notifications + share acceptance)

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    /// Silent push: a murmur changed in CloudKit — pull it.
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        await SyncBridge.shared.sync()
        return .newData
    }

    /// The partner tapped our share link — accept it, then sync.
    func application(_ application: UIApplication,
                     userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        Task {
            await CloudKitService.shared.accept(cloudKitShareMetadata)
            await SyncBridge.shared.sync()
        }
    }
}
