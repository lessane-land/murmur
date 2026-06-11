//
//  OnboardingView.swift
//  First-launch setup (CLAUDE.md MVP #5): your name, your style (one of the
//  three palettes, applied live), and your partner's name + iCloud email.
//

import SwiftUI

struct OnboardingView: View {
    @ObservedObject private var profile = ProfileStore.shared
    @ObservedObject private var theme = Theme.shared

    @State private var name = ""
    @State private var partnerName = ""
    @State private var partnerEmail = ""

    private var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !partnerName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            MurmurColor.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    intro
                    avatarPreview
                    field("Your name", text: $name, prompt: "Vane")
                    stylePicker
                    field("Partner's name", text: $partnerName, prompt: "Manal")
                    field("Partner's iCloud email", text: $partnerEmail,
                          prompt: "manal@icloud.com", keyboard: .emailAddress)
                }
                .padding(24)
                .padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack {
                Spacer()
                continueButton
                    .background(
                        LinearGradient(colors: [MurmurColor.background.opacity(0), MurmurColor.background],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: 120)
                            .allowsHitTesting(false),
                        alignment: .bottom
                    )
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.25), value: theme.palette.id)
    }

    // MARK: Sections

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Murmur")
                .font(MurmurFont.wordmark(40))
                .foregroundStyle(MurmurColor.inkPrimary)
            Text("Voice messages for two, across time zones.")
                .font(MurmurFont.rounded(15))
                .foregroundStyle(MurmurColor.inkSecondary)
        }
        .padding(.top, 24)
    }

    private var avatarPreview: some View {
        HStack {
            Spacer()
            ZStack {
                Circle()
                    .fill(MurmurColor.accentGradient)
                    .frame(width: 88, height: 88)
                    .shadow(color: MurmurColor.accentDeep.opacity(0.5), radius: 16, y: 6)
                Text(initial)
                    .font(MurmurFont.display(40, weight: .medium))
                    .foregroundStyle(MurmurColor.background)
            }
            Spacer()
        }
    }

    private func field(_ label: String,
                       text: Binding<String>,
                       prompt: String,
                       keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).murmurOverline()
            TextField("", text: text, prompt: Text(prompt).foregroundColor(MurmurColor.inkTertiary))
                .font(MurmurFont.rounded(17))
                .foregroundStyle(MurmurColor.inkPrimary)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                .autocorrectionDisabled(keyboard == .emailAddress)
                .padding(14)
                .background(MurmurColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(MurmurColor.hairline, lineWidth: 1))
        }
    }

    // MARK: Style picker (the three palettes, applied live)

    private var stylePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose your style").murmurOverline()
            HStack(spacing: 12) {
                ForEach(MurmurPalette.all) { palette in
                    let selected = palette.id == theme.palette.id
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { theme.select(palette) }
                    } label: {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(palette.gradient)
                                .frame(width: 54, height: 54)
                                .overlay(Circle().strokeBorder(.white,
                                                               lineWidth: selected ? 3 : 0))
                                .shadow(color: palette.accentEnd.opacity(selected ? 0.5 : 0),
                                        radius: 10, y: 4)
                            Text(palette.name)
                                .font(MurmurFont.rounded(12, weight: selected ? .semibold : .regular))
                                .foregroundStyle(selected ? MurmurColor.inkPrimary : MurmurColor.inkTertiary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Continue

    private var continueButton: some View {
        Button {
            profile.complete(userName: name.trimmingCharacters(in: .whitespaces),
                             partnerName: partnerName.trimmingCharacters(in: .whitespaces),
                             partnerEmail: partnerEmail.trimmingCharacters(in: .whitespaces),
                             colorHex: theme.palette.avatarHex)
        } label: {
            Text("Start murmuring")
                .font(MurmurFont.rounded(17, weight: .semibold))
                .foregroundStyle(canContinue ? MurmurColor.background : MurmurColor.inkSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background {
                    if canContinue {
                        Capsule().fill(MurmurColor.accentGradient)
                    } else {
                        Capsule()
                            .fill(MurmurColor.surfaceHi)
                            .overlay(Capsule().strokeBorder(MurmurColor.hairlineStrong, lineWidth: 1))
                    }
                }
                .shadow(color: canContinue ? MurmurColor.accentDeep.opacity(0.45) : .clear, radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!canContinue)
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }

    private var initial: String {
        String(name.trimmingCharacters(in: .whitespaces).first ?? "?").uppercased()
    }
}

#Preview {
    OnboardingView()
}
