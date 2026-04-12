import SwiftUI

enum AppMotion {
    static let press = Animation.spring(response: 0.2, dampingFraction: 0.84, blendDuration: 0.06)
    static let feedback = Animation.spring(response: 0.24, dampingFraction: 0.82, blendDuration: 0.08)
    static let quickFade = Animation.easeInOut(duration: 0.2)
    static let reveal = Animation.easeOut(duration: 0.22)
    static let reorder = Animation.spring(response: 0.26, dampingFraction: 0.88, blendDuration: 0.08)
    static let monthSlide = Animation.spring(response: 0.26, dampingFraction: 0.9, blendDuration: 0.1)
}

struct TactileButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.97
    var pressedOpacity: Double = 0.92

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .animation(AppMotion.press, value: configuration.isPressed)
    }
}

private struct PressableCardFeedbackModifier: ViewModifier {
    let pressedScale: CGFloat
    let pressedOpacity: Double
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? pressedScale : 1)
            .opacity(isPressed ? pressedOpacity : 1)
            .animation(AppMotion.press, value: isPressed)
            .onLongPressGesture(
                minimumDuration: 0,
                maximumDistance: .infinity,
                pressing: { pressing in
                    isPressed = pressing
                },
                perform: {}
            )
    }
}

private struct CadenceSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(surfaceBorder)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .inset(by: 1)
                        .fill(surfaceFill)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius - 1, style: .continuous)
                    .strokeBorder(topEdgeTint, lineWidth: 1)
                    .mask(
                        LinearGradient(
                            colors: [
                                .white,
                                .white.opacity(0.08),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay {
                if colorScheme == .dark {
                    RoundedRectangle(cornerRadius: cornerRadius - 1, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.035), lineWidth: 1)
                        .blur(radius: 1)
                        .opacity(0.65)
                }
            }
    }

    // MARK: - Surface Fill (this is EVERYTHING)

    private var surfaceFill: Color {
        colorScheme == .light
        ? Color(red: 0.992, green: 0.988, blue: 0.978)
        : Color(white: 0.14)
    }

    // MARK: - Border (barely visible, but critical)

    private var surfaceBorder: Color {
        colorScheme == .light
        ? Color.black.opacity(0.035)
        : Color.white.opacity(0.045)
    }

    private var topEdgeTint: Color {
        colorScheme == .light
            ? Color.white.opacity(0.5)
            : Color.white.opacity(0.075)
    }
}

private struct CadenceAmbientSurfaceModifier: ViewModifier {
    let accent: Color
    let accentKey: String
    let motionEnabled: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animateSurface = false

    func body(content: Content) -> some View {
        let ambient = max(0, Double(CadenceTokens.Intensity.ambientSurface))

        content
            .background(alignment: .top) {
                LinearGradient(
                    colors: [
                        accent.opacity((colorScheme == .dark ? 0.24 : 0.14) * ambient),
                        accent.opacity((colorScheme == .dark ? 0.1 : 0.06) * ambient),
                        .clear
                    ],
                    startPoint: animateSurface ? .topLeading : .topTrailing,
                    endPoint: animateSurface ? .bottomTrailing : .bottomLeading
                )
                .blur(radius: 40 + (8 * (ambient - 1)))
                .frame(height: 240)
                .allowsHitTesting(false)
                .ignoresSafeArea(edges: .top)
                .mask(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.7), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 260)
                    .ignoresSafeArea(edges: .top)
                )
                .id(accentKey)
            }
        .onAppear {
            restartAmbientAnimation()
        }
        .onChange(of: accentKey) { _, _ in
            restartAmbientAnimation()
        }
        .onChange(of: motionEnabled) { _, _ in
            restartAmbientAnimation()
        }
        .onChange(of: reduceMotion) { _, _ in
            restartAmbientAnimation()
        }
    }

    private func restartAmbientAnimation() {
        guard motionEnabled, !reduceMotion else {
            animateSurface = false
            return
        }

        animateSurface = false
        withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
            animateSurface = true
        }
    }
}

private struct CadenceControlChromeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(CadenceTokens.Color.Background.secondary, in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.05), radius: 6, y: 2)
    }
}

extension View {
    func pressableCardFeedback(
        scale: CGFloat = 0.97,
        opacity: Double = 0.96
    ) -> some View {
        modifier(
            PressableCardFeedbackModifier(
                pressedScale: scale,
                pressedOpacity: opacity
            )
        )
    }

    func cadenceSurface(cornerRadius: CGFloat = CadenceTokens.Surface.elevatedCornerRadius) -> some View {
        modifier(
            CadenceSurfaceModifier(
                cornerRadius: cornerRadius
            )
        )
    }

    func cadenceSurface(
        accent: Color,
        accentKey: String = "default",
        motionEnabled: Bool = true
    ) -> some View {
        modifier(
            CadenceAmbientSurfaceModifier(
                accent: accent,
                accentKey: accentKey,
                motionEnabled: motionEnabled
            )
        )
    }

    func cadenceControlChrome() -> some View {
        modifier(CadenceControlChromeModifier())
    }
}
