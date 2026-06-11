//
//  Components.swift
//  Shared visual atoms that carry the design language: waveforms (static +
//  live), the gradient avatar, the glass icon button, and the breathing record
//  button (the emotional centre).
//

import SwiftUI

// MARK: - Static waveform with progress

/// Bars 0...1 tall; bars before `progress` use the accent gradient, the rest
/// are muted. The visual signature of a murmur.
struct WaveformView: View {
    let bars: [Double]
    var progress: Double = 1
    var height: CGFloat = 40
    var gap: CGFloat = 2.5
    var minHeight: CGFloat = 3
    var activeStyle: AnyShapeStyle = AnyShapeStyle(MurmurColor.accentGradient)
    var inactiveColor: Color = MurmurColor.waveInactive

    var body: some View {
        // Bars fill the available width exactly, so the waveform can never
        // overflow its container regardless of how many samples there are.
        GeometryReader { geo in
            let n = max(bars.count, 1)
            let barW = max(1, (geo.size.width - CGFloat(n - 1) * gap) / CGFloat(n))
            let playIndex = Int((progress * Double(n)).rounded())
            HStack(alignment: .center, spacing: gap) {
                ForEach(bars.indices, id: \.self) { i in
                    Capsule()
                        .fill(i < playIndex ? activeStyle : AnyShapeStyle(inactiveColor))
                        .frame(width: barW, height: max(minHeight, CGFloat(bars[i]) * height))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
        }
        .frame(height: height)
    }
}

// MARK: - Live recording waveform

/// Animated bars that peak in the middle and breathe with the input `level`.
struct LiveWaveformView: View {
    var level: CGFloat
    var paused: Bool = false
    var barCount: Int = 33
    var height: CGFloat = 130

    var body: some View {
        TimelineView(.animation(paused: paused)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let barW: CGFloat = 4, gap: CGFloat = 4
                let totalW = CGFloat(barCount) * barW + CGFloat(barCount - 1) * gap
                let startX = (size.width - totalW) / 2
                let shading = GraphicsContext.Shading.linearGradient(
                    Gradient(colors: [MurmurColor.accentSoft, MurmurColor.accent, MurmurColor.accentDeep]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: size.width, y: 0))
                for i in 0..<barCount {
                    let mid = CGFloat(barCount - 1) / 2
                    let center = 1 - abs(CGFloat(i) - mid) / mid
                    let phase = t * 6.2
                    let wobble = (sin(phase * (0.7 + Double(i) * 0.05) + Double(i) * 0.9)
                                  + sin(phase * 1.9 + Double(i) * 2.1)) / 2
                    let base = 0.12 + (0.5 + 0.5 * CGFloat(wobble)) * (0.25 + center * 0.75)
                    let amp = paused ? 0.12 : min(1, base * (0.45 + level))
                    let h = max(6, amp * height)
                    let x = startX + CGFloat(i) * (barW + gap)
                    let rect = CGRect(x: x, y: (size.height - h) / 2, width: barW, height: h)
                    context.fill(Capsule().path(in: rect), with: shading)
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - Avatar

/// Gradient circle with a serif-italic initial and an optional night badge.
struct MurmurAvatar: View {
    var initial: String
    var size: CGFloat = 40
    /// Optional solid fill (e.g. your profile colour); defaults to the gradient.
    var solidColor: Color? = nil
    var night: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(solidColor.map { AnyShapeStyle($0) } ?? AnyShapeStyle(MurmurColor.accentGradient))
                .frame(width: size, height: size)
                .overlay(
                    Text(initial)
                        .font(MurmurFont.serifItalic(size * 0.46, weight: .medium))
                        .foregroundStyle(MurmurColor.background)
                )
                .shadow(color: MurmurColor.accentDeep.opacity(0.32), radius: 10, y: 4)

            if night {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: size * 0.22))
                    .foregroundStyle(MurmurColor.accentSoft)
                    .padding(size * 0.07)
                    .background(Circle().fill(MurmurColor.background))
                    .offset(x: 3, y: 3)
            }
        }
    }
}

// MARK: - Glass icon button

struct GlassButton: View {
    let systemName: String
    var size: CGFloat = 38
    var iconSize: CGFloat = 16
    var tint: Color = MurmurColor.inkPrimary
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(MurmurColor.hairlineStrong, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Breathing record button (the emotional centre)

struct BreathingRecordButton: View {
    var size: CGFloat = 74
    var action: () -> Void
    @State private var breathe = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [MurmurColor.accentSoft.opacity(0.45),
                                 MurmurColor.accentDeep.opacity(0.15), .clear],
                        center: .center, startRadius: 4, endRadius: size * 0.85))
                    .frame(width: size * 1.7, height: size * 1.7)
                    .scaleEffect(breathe ? 1.12 : 1)
                    .opacity(breathe ? 1 : 0.85)

                Circle()
                    .fill(MurmurColor.accentGradient)
                    .frame(width: size, height: size)
                    .overlay(Circle().strokeBorder(.white.opacity(0.55), lineWidth: 2).padding(4))
                    .shadow(color: MurmurColor.accentDeep.opacity(0.45), radius: 18, y: 10)

                Image(systemName: "mic.fill")
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundStyle(MurmurColor.background)
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) { breathe = true }
        }
    }
}

// MARK: - Pulsing rings (recording stop button)

struct PulsingRings: View {
    var diameter: CGFloat = 92
    var color: Color = MurmurColor.recordingPink

    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Ring(delay: Double(i) * 0.8, diameter: diameter, color: color)
            }
        }
    }

    private struct Ring: View {
        let delay: Double
        let diameter: CGFloat
        let color: Color
        @State private var animate = false

        var body: some View {
            Circle()
                .strokeBorder(color.opacity(0.55), lineWidth: 2)
                .frame(width: diameter, height: diameter)
                .scaleEffect(animate ? 2.0 : 1)
                .opacity(animate ? 0 : 0.55)
                .onAppear {
                    withAnimation(.easeOut(duration: 2.4).repeatForever(autoreverses: false).delay(delay)) {
                        animate = true
                    }
                }
        }
    }
}
