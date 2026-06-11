//
//  OnboardingView.swift
//  First-launch setup (CLAUDE.md MVP #5): your name, an avatar colour, and your
//  partner's name + iCloud email. No login wall — this is just local profile.
//

import SwiftUI

struct OnboardingView: View {
    @ObservedObject private var profile = ProfileStore.shared

    @State private var name = ""
    @State private var partnerName = ""
    @State private var partnerEmail = ""
    @State private var colorHex: UInt32 = AvatarColor.options.first!.hex

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
                    colorPicker
                    field("Partner's name", text: $partnerName, prompt: "Manal")
                    field("Partner's iCloud email", text: $partnerEmail,
                          prompt: "manal@icloud.com", keyboard: .emailAddress)
                }
                .padding(24)
                .padding(.bottom, 100)
            }

            VStack {
                Spacer()
                continueButton
            }
        }
        .preferredColorScheme(.dark)
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
                    .fill(Color(hex: colorHex))
                    .frame(width: 88, height: 88)
                    .shadow(color: Color(hex: colorHex).opacity(0.5), radius: 16, y: 6)
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

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your colour").murmurOverline()
            HStack(spacing: 14) {
                ForEach(AvatarColor.options) { choice in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { colorHex = choice.hex }
                    } label: {
                        Circle()
                            .fill(choice.color)
                            .frame(width: 38, height: 38)
                            .overlay(Circle().strokeBorder(.white,
                                                           lineWidth: choice.hex == colorHex ? 2.5 : 0))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var continueButton: some View {
        Button {
            profile.complete(userName: name.trimmingCharacters(in: .whitespaces),
                             partnerName: partnerName.trimmingCharacters(in: .whitespaces),
                             partnerEmail: partnerEmail.trimmingCharacters(in: .whitespaces),
                             colorHex: colorHex)
        } label: {
            Text("Start murmuring")
                .font(MurmurFont.rounded(17, weight: .semibold))
                .foregroundStyle(MurmurColor.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(MurmurColor.accentGradient, in: Capsule())
                .opacity(canContinue ? 1 : 0.4)
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
