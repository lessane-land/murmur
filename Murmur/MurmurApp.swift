//
//  MurmurApp.swift
//  App entry point. Stands up SwiftData, gates first launch on onboarding, and
//  drives CloudKit sync + push handling through an app delegate.
//

import SwiftUI
import SwiftData
import CloudKit
import UserNotifications
import UIKit

@main
struct MurmurApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    let sharedModelContainer: ModelContainer = MurmurApp.makeModelContainer()

    /// Builds the SwiftData container, recovering from an incompatible on-disk
    /// store. The schema evolved across early development, so a store written by
    /// an older build can't be migrated automatically — rather than hard-crash,
    /// we delete the stale store and recreate it. (Pre-release only; once the
    /// model stabilises this should become a real VersionedSchema migration.)
    static func makeModelContainer() -> ModelContainer {
        // Plain schema: SwiftData auto-applies lightweight migrations for
        // additive changes (new fields), preserving existing murmurs.
        let schema = Schema([Murmur.self])
        // cloudKitDatabase: .none is important. The app carries an iCloud
        // CloudKit entitlement (for our manual CKShare-based two-person sync in
        // CloudKitService), and SwiftData would otherwise auto-enable its own
        // CloudKit mirroring — which forbids unique constraints and requires
        // every attribute to be optional/defaulted, crashing the load. We sync
        // manually, so SwiftData stays purely local.
        let configuration = ModelConfiguration(schema: schema,
                                               isStoredInMemoryOnly: false,
                                               cloudKitDatabase: .none)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Last resort only: an old/incompatible dev store that predates the
            // versioned schema. Reset once; migrations handle changes after this.
            print("Murmur: model store load failed (\(error)); resetting store.")
            deleteStore(at: configuration.url)
            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                print("Murmur: store reset failed (\(error)); falling back to in-memory.")
                let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return try! ModelContainer(for: schema, configurations: [memory])
            }
        }
    }

    /// Removes the SQLite store and its -wal / -shm sidecar files.
    private static func deleteStore(at url: URL) {
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let path = url.path + suffix
            try? fm.removeItem(atPath: path)
        }
    }

    init() {
        // Make the container available to background push handling. Hop to the
        // main actor since SyncBridge is main-actor isolated.
        let container = sharedModelContainer
        Task { @MainActor in SyncBridge.shared.modelContainer = container }
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
        // Read our own uploaded murmurs back to pick up the partner's delivered
        // receipts and any reactions they left.
        await CloudKitService.shared.fetchOwnUpdates(in: context)
        await transcribeMissing(in: context)
    }

    /// Transcribes any received murmurs that arrived without a transcript
    /// (e.g. uploaded before the sender finished transcribing).
    private func transcribeMissing(in context: ModelContext) async {
        let predicate = #Predicate<Murmur> { !$0.isOutgoing && $0.transcript == nil }
        guard let needing = try? context.fetch(FetchDescriptor(predicate: predicate)), !needing.isEmpty else { return }
        let transcriber = TranscriptionService()
        for murmur in needing {
            if let text = try? await transcriber.transcribe(fileURL: murmur.audioFileURL) {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    murmur.transcript = trimmed
                    try? context.save()
                    SyncLog.shared.add("transcribed a received murmur")
                }
            }
        }
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

// MARK: - App delegate (remote notifications + scene routing)

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    /// Silent push: a murmur changed in CloudKit — pull it.
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Task { @MainActor in
            await SyncBridge.shared.sync()
            completionHandler(.newData)
        }
    }

    /// SwiftUI is scene-based, so CloudKit delivers share acceptance to the
    /// SCENE — not the app delegate. Route the scene through SceneDelegate.
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

// MARK: - Scene delegate (CloudKit share acceptance)

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    /// Cold start: app launched by tapping the invite link.
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        if let metadata = connectionOptions.cloudKitShareMetadata {
            handleShare(metadata)
        }
    }

    /// Warm: app already running when the invite is tapped.
    func windowScene(_ windowScene: UIWindowScene,
                     userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        handleShare(cloudKitShareMetadata)
    }

    private func handleShare(_ metadata: CKShare.Metadata) {
        Task { @MainActor in
            SyncLog.shared.add("invite tapped — accepting share…")
            await CloudKitService.shared.accept(metadata)
            await SyncBridge.shared.sync()
        }
    }
}
