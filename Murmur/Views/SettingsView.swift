//
//  SettingsView.swift
//  In-app settings: your profile, your partner (name + location), the colour
//  style, and managing your murmurs.
//

import SwiftUI
import CloudKit
import UIKit

struct SettingsView: View {
    @ObservedObject private var theme = Theme.shared
    @ObservedObject private var profile = ProfileStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var listModel = MurmurListViewModel()

    @State private var confirmClear = false
    @State private var showLocationPicker = false
    @State private var preparedShare: CKShare?
    @State private var sharePresented = false
    @State private var isPreparingShare = false
    @State private var shareError: String?

    var body: some View {
        ZStack {
            MurmurColor.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    youSection
                    partnerSection
                    syncSection
                    styleSection
                    murmursSection
                    aboutSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 80)
                .padding(.bottom, 40)
            }

            VStack { header; Spacer() }
        }
        .preferredColorScheme(.dark)
        .confirmationDialog("Delete all murmurs?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Delete all", role: .destructive) { listModel.deleteAll(in: modelContext) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes every murmur and its audio.")
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerView { selected in
                profile.partnerCity = selected.city
                profile.partnerTimeZoneID = selected.timeZoneID
            }
        }
        .sheet(isPresented: $sharePresented) {
            if let preparedShare {
                CloudSharingView(share: preparedShare, container: CloudKitService.shared.container)
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: Sync

    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sync").murmurOverline()

            Toggle(isOn: $profile.syncEnabled) {
                Text("Sync privately with \(profile.partnerName.isEmpty ? "your partner" : profile.partnerName)")
                    .font(MurmurFont.rounded(15, weight: .semibold))
                    .foregroundStyle(MurmurColor.inkPrimary)
            }
            .tint(MurmurColor.accent)
            .padding(14)
            .background(MurmurColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(MurmurColor.hairline, lineWidth: 1))
            .onChange(of: profile.syncEnabled) { _, on in
                if on { Task { await SyncBridge.shared.bootstrap() } }
            }

            if profile.syncEnabled {
                Button { prepareAndPresentShare() } label: {
                    HStack(spacing: 14) {
                        Image(systemName: isPreparingShare ? "ellipsis" : "person.crop.circle.badge.plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(MurmurColor.accent)
                            .frame(width: 44, height: 44)
                            .background(MurmurColor.surfaceHi, in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Invite \(profile.partnerName.isEmpty ? "your partner" : profile.partnerName)")
                                .font(MurmurFont.rounded(15, weight: .semibold))
                                .foregroundStyle(MurmurColor.inkPrimary)
                            Text(isPreparingShare ? "Preparing private invite…" : "Send them a private CloudKit invite")
                                .font(MurmurFont.rounded(12))
                                .foregroundStyle(MurmurColor.inkTertiary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(MurmurColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(MurmurColor.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(isPreparingShare)
            }

            if let shareError {
                Text(shareError).font(MurmurFont.rounded(12)).foregroundStyle(MurmurColor.recordingDot)
            }

            Text("Both of you turn this on and accept each other's invite. Murmurs then sync privately through iCloud.")
                .font(MurmurFont.rounded(11.5)).foregroundStyle(MurmurColor.inkTertiary).padding(.top, 2)
        }
    }

    private func prepareAndPresentShare() {
        isPreparingShare = true
        shareError = nil
        Task {
            do {
                guard await CloudKitService.shared.isAccountAvailable() else {
                    shareError = "Sign in to iCloud to invite your partner."
                    isPreparingShare = false
                    return
                }
                preparedShare = try await CloudKitService.shared.fetchOrCreateShare()
                sharePresented = true
            } catch {
                shareError = error.localizedDescription
            }
            isPreparingShare = false
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text("Settings")
                .font(MurmurFont.wordmark(28))
                .foregroundStyle(MurmurColor.inkPrimary)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MurmurColor.inkSecondary)
                    .frame(width: 38, height: 38)
                    .background(MurmurColor.surface, in: Circle())
                    .overlay(Circle().strokeBorder(MurmurColor.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 16)
        .background(MurmurColor.background)
    }

    // MARK: You

    private var youSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("You").murmurOverline()
            HStack(spacing: 14) {
                MurmurAvatar(initial: String(profile.userName.first ?? "?").uppercased(), size: 52)
                TextField("Your name", text: $profile.userName)
                    .font(MurmurFont.rounded(17, weight: .semibold))
                    .foregroundStyle(MurmurColor.inkPrimary)
            }
            .padding(14)
            .background(MurmurColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(MurmurColor.hairline, lineWidth: 1))
        }
    }

    // MARK: Partner

    private var partnerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Partner").murmurOverline()

            HStack(spacing: 14) {
                MurmurAvatar(initial: String(profile.partnerName.first ?? "?").uppercased(),
                             size: 52, night: profile.partnerIsNight)
                TextField("Partner's name", text: $profile.partnerName)
                    .font(MurmurFont.rounded(17, weight: .semibold))
                    .foregroundStyle(MurmurColor.inkPrimary)
            }
            .padding(14)
            .background(MurmurColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(MurmurColor.hairline, lineWidth: 1))

            Button { showLocationPicker = true } label: {
                sectionRow(icon: "location.fill",
                           title: "In \(profile.partnerCity)",
                           subtitle: "\(profile.partnerLocalTime) · \(profile.partnerOffsetLabel)")
            }
            .buttonStyle(.plain)
        }
    }

    private func sectionRow(icon: String, title: String, subtitle: String, tint: Color = MurmurColor.accent) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(MurmurColor.surfaceHi, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(MurmurFont.rounded(15, weight: .semibold))
                    .foregroundStyle(MurmurColor.inkPrimary)
                Text(subtitle)
                    .font(MurmurFont.rounded(12))
                    .foregroundStyle(MurmurColor.inkTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MurmurColor.inkTertiary)
        }
        .padding(14)
        .background(MurmurColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(MurmurColor.hairline, lineWidth: 1))
    }

    // MARK: Style

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Style").murmurOverline()
            ForEach(MurmurPalette.all) { palette in
                PaletteRow(palette: palette, isSelected: palette.id == theme.palette.id) {
                    withAnimation(.easeInOut(duration: 0.25)) { theme.select(palette) }
                }
            }
        }
    }

    // MARK: Murmurs

    private var murmursSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Murmurs").murmurOverline()
            Button { confirmClear = true } label: {
                HStack(spacing: 14) {
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(MurmurColor.recordingDot)
                        .frame(width: 44, height: 44)
                        .background(MurmurColor.surfaceHi, in: Circle())
                    Text("Delete all murmurs")
                        .font(MurmurFont.rounded(15, weight: .semibold))
                        .foregroundStyle(MurmurColor.inkPrimary)
                    Spacer()
                }
                .padding(14)
                .background(MurmurColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(MurmurColor.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("About").murmurOverline()
            Text("Murmur")
                .font(MurmurFont.wordmark(20))
                .foregroundStyle(MurmurColor.inkSecondary)
            Text("Voice messages for two, across time zones.\nTranscribed privately on your iPhone.")
                .font(MurmurFont.rounded(12))
                .foregroundStyle(MurmurColor.inkTertiary)
        }
        .padding(.top, 4)
    }
}

// MARK: - Palette row

private struct PaletteRow: View {
    let palette: MurmurPalette
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Circle()
                    .fill(palette.gradient)
                    .frame(width: 40, height: 40)
                    .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                Text(palette.name)
                    .font(MurmurFont.rounded(16, weight: .semibold))
                    .foregroundStyle(MurmurColor.inkPrimary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? MurmurColor.accent : MurmurColor.inkTertiary)
            }
            .padding(14)
            .background(MurmurColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? MurmurColor.accent.opacity(0.6) : MurmurColor.hairline,
                                  lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CloudKit sharing controller

/// Wraps UICloudSharingController so the partner can be invited (via Messages,
/// Mail, etc.) with read/write permission on our private zone-wide share.
struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            print("Murmur: share save failed — \(error)")
        }
        func itemTitle(for csc: UICloudSharingController) -> String? { "Our Murmurs" }
        func itemThumbnailData(for csc: UICloudSharingController) -> Data? { nil }
    }
}

#Preview {
    SettingsView()
}
