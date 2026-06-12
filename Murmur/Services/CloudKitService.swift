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
        guard isEnabled else { return false }
        let status = (try? await container.accountStatus()) ?? .couldNotDetermine
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

        for murmur in pending {
            guard let recordName = try? await upload(murmur) else { continue }
            murmur.ckRecordName = recordName
            murmur.isUploaded = true
            try? context.save()
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
            for zone in zones {
                let query = CKQuery(recordType: Self.recordType, predicate: NSPredicate(value: true))
                let (matches, _) = try await sharedDB.records(matching: query,
                                                              inZoneWith: zone.zoneID,
                                                              desiredKeys: nil,
                                                              resultsLimit: CKQueryOperation.maximumResults)
                for (_, result) in matches {
                    guard let record = try? result.get() else { continue }
                    if upsertIncoming(record, into: context, partnerName: partnerName) { inserted += 1 }
                    // Acknowledge receipt (write-back) so the sender gets the
                    // delivered double-tick. We have read-write on the share.
                    if (record["received"] as? Int ?? 0) != 1 {
                        record["received"] = 1 as CKRecordValue
                        _ = try? await sharedDB.save(record)
                    }
                }
            }
        } catch {
            // Best-effort: a transient CloudKit error just means we try next sync.
        }
        return inserted
    }

    /// Inserts a new incoming murmur, or updates an existing one's reaction.
    /// Returns true only for a brand-new insert.
    private func upsertIncoming(_ record: CKRecord, into context: ModelContext, partnerName: String) -> Bool {
        let recordName = record.recordID.recordName
        let target: String? = recordName
        let predicate = #Predicate<Murmur> { $0.ckRecordName == target }
        let recordReaction = record["reaction"] as? String

        if let existing = (try? context.fetch(FetchDescriptor(predicate: predicate)))?.first {
            if existing.reaction != recordReaction {
                existing.reaction = recordReaction
                try? context.save()
            }
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
                            isUploaded: true,
                            reaction: recordReaction,
                            ckZoneOwner: record.recordID.zoneID.ownerName)
        context.insert(murmur)
        try? context.save()
        return true
    }

    /// Reads our OWN uploaded murmurs back from the private zone to pick up the
    /// partner's changes: delivered receipts and reactions they left. Returns the
    /// number of murmurs that *newly* gained a reaction, so the caller can raise
    /// a notification ("they loved your murmur").
    @discardableResult
    func fetchOwnUpdates(in context: ModelContext) async -> Int {
        guard await isAccountAvailable() else { return 0 }
        var newHearts = 0
        do {
            let query = CKQuery(recordType: Self.recordType, predicate: NSPredicate(value: true))
            let (matches, _) = try await privateDB.records(matching: query,
                                                           inZoneWith: zoneID,
                                                           desiredKeys: nil,
                                                           resultsLimit: CKQueryOperation.maximumResults)
            for (_, result) in matches {
                guard let record = try? result.get() else { continue }
                let name = record.recordID.recordName
                let target: String? = name
                let predicate = #Predicate<Murmur> { $0.ckRecordName == target }
                let delivered = (record["received"] as? Int ?? 0) == 1
                let reaction = record["reaction"] as? String

                if let murmur = (try? context.fetch(FetchDescriptor(predicate: predicate)))?.first {
                    // A heart that wasn't there before — worth a notification.
                    if reaction != nil && murmur.reaction != reaction { newHearts += 1 }
                    if murmur.isDelivered != delivered || murmur.reaction != reaction {
                        murmur.isDelivered = delivered
                        murmur.reaction = reaction
                        try? context.save()
                    }
                } else {
                    // The local store lost this sent murmur (a wipe or reinstall).
                    // CloudKit is the durable backstop — restore it from the zone.
                    restoreOwnMurmur(record, delivered: delivered, reaction: reaction, into: context)
                }
            }
        } catch {
            // Best-effort: try again on the next sync.
        }
        return newHearts
    }

    /// Recreates one of our own sent murmurs from its private-zone record after
    /// the local store was lost. The audio rides as a CKAsset we uploaded, so a
    /// sent murmur can be fully rehydrated — text, audio, reaction and all.
    private func restoreOwnMurmur(_ record: CKRecord, delivered: Bool, reaction: String?, into context: ModelContext) {
        guard let asset = record["audio"] as? CKAsset, let assetURL = asset.fileURL else { return }
        let fileName = "\(UUID().uuidString).m4a"
        let destination = URL.documentsDirectory.appendingPathComponent(fileName)
        try? FileManager.default.copyItem(at: assetURL, to: destination)

        let murmur = Murmur(senderName: record["senderName"] as? String ?? ProfileStore.shared.userName,
                            audioFileName: fileName,
                            transcript: record["transcript"] as? String,
                            duration: record["duration"] as? Double ?? 0,
                            createdAt: record["createdAt"] as? Date ?? .now,
                            isPlayed: true,
                            isOutgoing: true,
                            ckRecordName: record.recordID.recordName,
                            isUploaded: true,
                            reaction: reaction,
                            isDelivered: delivered)
        context.insert(murmur)
        try? context.save()
    }

    /// Pushes a reaction change to the murmur's CloudKit record (your own record
    /// in the private DB, or the partner's via the shared DB).
    func pushReaction(_ murmur: Murmur) async {
        guard isEnabled, let recordName = murmur.ckRecordName else { return }
        let database: CKDatabase
        let zone: CKRecordZone.ID
        if murmur.isOutgoing {
            database = privateDB
            zone = zoneID
        } else {
            guard let owner = murmur.ckZoneOwner else { return }
            database = sharedDB
            zone = CKRecordZone.ID(zoneName: Self.zoneName, ownerName: owner)
        }
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zone)
        guard let record = try? await database.record(for: recordID) else { return }
        record["reaction"] = murmur.reaction as? CKRecordValue
        _ = try? await database.save(record)
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

    /// Accepts a share the partner sent us (called from the scene delegate).
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
        _ = try? await database.save(subscription)
    }
}
