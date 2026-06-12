//
//  CloudKitService.swift
//  Two-person sync over CloudKit.
//
//  Design (the "why"): two people, two iCloud accounts. Each person owns their
//  outgoing murmurs in their *private* database, inside a custom record zone
//  ("Murmurs") shared with the partner through one zone-wide CKShare. The
//  partner reads those murmurs through their *shared* database. Audio rides
//  along as a CKAsset. A database subscription delivers a silent push when new
//  murmurs arrive so we can pull them and raise a local notification.
//
//  Everything here is best-effort and local-first: if there's no iCloud account
//  or the capability isn't provisioned yet, these calls no-op rather than
//  throwing into the UI. SwiftData remains the source of truth.
//

import Foundation
import CloudKit
import SwiftData

/// A small in-app log so sync activity is visible on TestFlight (where there's
/// no Xcode console). Shown in Settings → Sync activity.
@MainActor
final class SyncLog: ObservableObject {
    static let shared = SyncLog()
    @Published private(set) var lines: [String] = []

    func add(_ line: String) {
        let time = Date().formatted(date: .omitted, time: .standard)
        lines.append("\(time)  \(line)")
        if lines.count > 40 { lines.removeFirst(lines.count - 40) }
        print("Murmur.sync: \(line)")
    }
}

@MainActor
final class CloudKitService {
    static let shared = CloudKitService()

    /// Sync runs only when the user has turned it on in Settings (which they do
    /// after adding the iCloud capability). Until then CKContainer.default() —
    /// which needs the iCloud entitlement — is never touched.
    private var isEnabled: Bool { ProfileStore.shared.syncEnabled }

    /// Lazy so it's only created when CloudKit is actually enabled.
    lazy var container = CKContainer.default()
    private var privateDB: CKDatabase { container.privateCloudDatabase }
    private var sharedDB: CKDatabase { container.sharedCloudDatabase }

    static let zoneName = "Murmurs"
    static let recordType = "Murmur"

    private let zoneID = CKRecordZone.ID(zoneName: CloudKitService.zoneName,
                                         ownerName: CKCurrentUserDefaultName)

    // MARK: Account

    func isAccountAvailable() async -> Bool {
        guard isEnabled else {
            SyncLog.shared.add("OFF — turn on Settings → Sync")
            return false
        }
        let status = (try? await container.accountStatus()) ?? .couldNotDetermine
        let label: String
        switch status {
        case .available: label = "available"
        case .noAccount: label = "NO iCloud account — sign in"
        case .restricted: label = "restricted"
        case .temporarilyUnavailable: label = "temporarily unavailable"
        default: label = "could not determine"
        }
        SyncLog.shared.add("iCloud status = \(label)")
        return status == .available
    }

    // MARK: Zone

    /// Sharing requires a custom zone — the default zone cannot be shared.
    private func ensureZone() async throws {
        let zone = CKRecordZone(zoneID: zoneID)
        _ = try await privateDB.modifyRecordZones(saving: [zone], deleting: [])
    }

    // MARK: Outgoing

    /// Uploads every local outgoing murmur that hasn't been pushed yet.
    func uploadPending(in context: ModelContext) async {
        guard await isAccountAvailable() else { return }
        let predicate = #Predicate<Murmur> { $0.isOutgoing && !$0.isUploaded }
        guard let pending = try? context.fetch(FetchDescriptor(predicate: predicate)) else { return }
        SyncLog.shared.add("\(pending.count) murmur(s) pending upload")

        for murmur in pending {
            do {
                let recordName = try await upload(murmur)
                murmur.ckRecordName = recordName
                murmur.isUploaded = true
                try? context.save()
                SyncLog.shared.add("uploaded \(recordName)")
            } catch {
                SyncLog.shared.add("upload FAILED — \(error)")
            }
        }
    }

    @discardableResult
    private func upload(_ murmur: Murmur) async throws -> String {
        try await ensureZone()

        let recordID = CKRecord.ID(recordName: murmur.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        record["senderName"] = murmur.senderName as CKRecordValue
        record["duration"] = murmur.duration as CKRecordValue
        record["createdAt"] = murmur.createdAt as CKRecordValue
        if let transcript = murmur.transcript {
            record["transcript"] = transcript as CKRecordValue
        }
        record["audio"] = CKAsset(fileURL: murmur.audioFileURL)

        let saved = try await privateDB.save(record)
        return saved.recordID.recordName
    }

    // MARK: Incoming

    /// Pulls the partner's murmurs from the shared database into SwiftData.
    /// Returns the number of newly inserted murmurs.
    @discardableResult
    func fetchIncoming(into context: ModelContext, partnerName: String) async -> Int {
        guard await isAccountAvailable() else { return 0 }

        var inserted = 0
        do {
            let zones = try await sharedDB.allRecordZones()
            SyncLog.shared.add("found \(zones.count) shared zone(s) from partner")
            for zone in zones {
                let query = CKQuery(recordType: Self.recordType, predicate: NSPredicate(value: true))
                let (matches, _) = try await sharedDB.records(matching: query,
                                                              inZoneWith: zone.zoneID,
                                                              desiredKeys: nil,
                                                              resultsLimit: CKQueryOperation.maximumResults)
                for (_, result) in matches {
                    guard let record = try? result.get() else { continue }
                    if insertIfNew(record, into: context, partnerName: partnerName) { inserted += 1 }
                }
            }
        } catch {
            SyncLog.shared.add("fetch incoming failed — \(error)")
        }
        return inserted
    }

    private func insertIfNew(_ record: CKRecord, into context: ModelContext, partnerName: String) -> Bool {
        let recordName = record.recordID.recordName
        // Compare optional-to-optional so the predicate macro type-checks.
        let target: String? = recordName
        let predicate = #Predicate<Murmur> { $0.ckRecordName == target }
        if let existing = try? context.fetch(FetchDescriptor(predicate: predicate)), !existing.isEmpty {
            return false
        }

        guard let asset = record["audio"] as? CKAsset, let assetURL = asset.fileURL else { return false }
        let fileName = "\(UUID().uuidString).m4a"
        let destination = URL.documentsDirectory.appendingPathComponent(fileName)
        try? FileManager.default.copyItem(at: assetURL, to: destination)

        let murmur = Murmur(senderName: record["senderName"] as? String ?? partnerName,
                            audioFileName: fileName,
                            transcript: record["transcript"] as? String,
                            duration: record["duration"] as? Double ?? 0,
                            createdAt: record["createdAt"] as? Date ?? .now,
                            isPlayed: false,
                            isOutgoing: false,
                            ckRecordName: recordName,
                            isUploaded: true)
        context.insert(murmur)
        try? context.save()
        return true
    }

    // MARK: Sharing

    /// Returns the zone-wide share for our Murmurs zone, creating it if needed.
    /// Send `share.url` to the partner; tapping it opens the app and accepts.
    func fetchOrCreateShare() async throws -> CKShare {
        guard isEnabled else { throw CKError(.notAuthenticated) }
        try await ensureZone()

        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
        if let existing = try? await privateDB.record(for: shareID) as? CKShare {
            return existing
        }

        let share = CKShare(recordZoneID: zoneID)
        share[CKShare.SystemFieldKey.title] = "Our Murmurs" as CKRecordValue
        share.publicPermission = .none

        let result = try await privateDB.modifyRecords(saving: [share], deleting: [])
        for (_, saveResult) in result.saveResults {
            if let saved = try? saveResult.get() as? CKShare { return saved }
        }
        return share
    }

    /// Accepts a share the partner sent us (called from the app delegate).
    func accept(_ metadata: CKShare.Metadata) async {
        guard isEnabled else { return }
        await withCheckedContinuation { continuation in
            let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
            operation.acceptSharesResultBlock = { _ in continuation.resume() }
            container.add(operation)
        }
    }

    // MARK: Push subscriptions (silent)

    /// Registers silent-push database subscriptions so we learn about new
    /// murmurs without polling. Safe to call repeatedly.
    func registerSubscriptions() async {
        guard await isAccountAvailable() else { return }
        await registerDatabaseSubscription(in: sharedDB, id: "murmur-shared-changes")
        await registerDatabaseSubscription(in: privateDB, id: "murmur-private-changes")
    }

    private func registerDatabaseSubscription(in database: CKDatabase, id: String) async {
        let subscription = CKDatabaseSubscription(subscriptionID: id)
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true   // silent push, no alert
        subscription.notificationInfo = info
        do {
            _ = try await database.save(subscription)
        } catch let error as CKError where error.code == .serverRejectedRequest {
            // Subscription already exists — fine.
        } catch {
            SyncLog.shared.add("subscription registration failed — \(error)")
        }
    }
}
