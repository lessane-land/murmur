//
//  SettingsView.swift
//  In-app settings. Phase 1: choose the colour palette (Aurora / Golden Hour /
//  Deep Ocean). The choice is persisted and applied app-wide instantly.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var theme = Theme.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            MurmurColor.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header

                Text("Palette").murmurOverline()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)

                VStack(spacing: 12) {
                    ForEach(MurmurPalette.all) { palette in
                        PaletteRow(palette: palette,
                                   isSelected: palette.id == theme.palette.id) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                theme.select(palette)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.top, 16)
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            Text("Settings")
                .font(MurmurFont.rounded(26, weight: .bold))
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
        .padding(.bottom, 28)
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

#Preview {
    SettingsView()
}
