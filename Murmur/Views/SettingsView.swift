//
//  SettingsView.swift
//  In-app settings: your profile, the colour palette, and connecting with your
//  partner over CloudKit (a share link they tap to pair).
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

    @State private var preparedShare: CKShare?
    @State private var sharePresented = false
    @State private var isPreparingShare = false
    @State private var shareError: String?
    @State private var confirmReset = false

    var body: some View {
        ZStack {
            MurmurColor.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    profileSummary
                    connectSection
                    paletteSection
                    demoSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }

            VStack {
                header
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .confirmationDialog("Delete all murmurs?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Delete all", role: .destructive) {
                listModel.deleteAll(in: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $sharePresented) {
            if let preparedShare {
                CloudSharingView(share: preparedShare, container: CloudKitService.shared.container)
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text("Settings")
                .font(MurmurFont.wordmark(28))
                .foregroundStyle(MurmurColor.inkPrimary)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MurmurColor.inkSecondary)
                    .frame(width: 38, height: 38)
                    .background(MurmurColor.surface, in: Circle())
                    .overlay(Circle().strokeBorder(MurmurColor.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .background(MurmurColor.background)
    }

    // MARK: Profile

    private var profileSummary: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(profile.avatarColor).frame(width: 52, height: 52)
                Text(String(profile.userName.first ?? "?").uppercased())
                    .font(MurmurFont.display(22, weight: .medium))
                    .foregroundStyle(MurmurColor.background)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(profile.userName.isEmpty ? "You" : profile.userName)
                    .font(MurmurFont.rounded(17, weight: .semibold))
                    .foregroundStyle(MurmurColor.inkPrimary)
                Text(profile.partnerName.isEmpty ? "No partner yet" : "Paired with \(profile.partnerName)")
                    .font(MurmurFont.rounded(13))
                    .foregroundStyle(MurmurColor.inkTertiary)
            }
            Spacer()
        }
        .padding(.top, 76)
    }

    // MARK: Connect

    private var connectSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Partner").murmurOverline()

            Button {
                prepareAndPresentShare()
            } label: {
                sectionRow(icon: isPreparingShare ? "ellipsis" : "person.crop.circle.badge.plus",
                           title: "Connect with \(profile.partnerName.isEmpty ? "partner" : profile.partnerName)",
                           subtitle: isPreparingShare ? "Preparing invite…" : "Invite them to your private murmurs")
            }
            .buttonStyle(.plain)
            .disabled(isPreparingShare)

            if let shareError {
                Text(shareError)
                    .font(MurmurFont.rounded(12))
                    .foregroundStyle(MurmurColor.recordingDot)
            }
        }
    }

    private func sectionRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(MurmurColor.accent)
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
        }
        .padding(14)
        .background(MurmurColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(MurmurColor.hairline, lineWidth: 1))
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

    // MARK: Palette

    private var paletteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Palette").murmurOverline()
            ForEach(MurmurPalette.all) { palette in
                PaletteRow(palette: palette, isSelected: palette.id == theme.palette.id) {
                    withAnimation(.easeInOut(duration: 0.25)) { theme.select(palette) }
                }
            }
        }
    }

    // MARK: Demo

    private var demoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Demo").murmurOverline()

            Button {
                listModel.seedDemoMurmurs(in: modelContext, partnerName: profile.partnerName)
                dismiss()
            } label: {
                sectionRow(icon: "sparkles",
                           title: "Add demo murmurs",
                           subtitle: "Sample incoming messages to preview the inbox")
            }
            .buttonStyle(.plain)

            Button {
                confirmReset = true
            } label: {
                sectionRow(icon: "trash",
                           title: "Delete all murmurs",
                           subtitle: "Clear everything and start fresh")
            }
            .buttonStyle(.plain)

            Text("Demo murmurs are local-only stand-ins so you can see the two-person inbox without CloudKit pairing.")
                .font(MurmurFont.rounded(12))
                .foregroundStyle(MurmurColor.inkTertiary)
                .padding(.top, 2)
        }
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
/// Mail, etc.) with proper CloudKit read/write permissions on our zone-wide
/// share.
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
