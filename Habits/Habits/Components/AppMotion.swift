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
                if colorScheme == .dark {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(darkSurfaceFill)
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(stops: [
                                            .init(color: cardAmbientTint.opacity(cardAmbientDarkTopOpacity), location: 0.0),
                                            .init(color: cardAmbientTint.opacity(cardAmbientDarkMidOpacity), location: 0.22),
                                            .init(color: .clear, location: 0.58)
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(surfaceBorder)

                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .inset(by: 1)
                            .fill(surfaceFill)

                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .inset(by: 1)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: cardAmbientTint.opacity(cardAmbientTopOpacity), location: 0.0),
                                        .init(color: cardAmbientTint.opacity(cardAmbientMidOpacity), location: 0.2),
                                        .init(color: .clear, location: 0.56)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                }
            }
            .overlay {
                if colorScheme == .dark {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(darkEdgeStroke, lineWidth: 1)
                } else {
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
            }
    }

    // MARK: - Surface Fill (this is EVERYTHING)

    private var surfaceFill: Color {
        Color(red: 0.992, green: 0.988, blue: 0.978)
    }

    // MARK: - Border (barely visible, but critical)

    private var surfaceBorder: Color {
        Color.black.opacity(0.032)
    }

    private var topEdgeTint: Color {
        Color.white.opacity(0.44)
    }

    private var darkSurfaceFill: LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color(red: 0.056, green: 0.058, blue: 0.072), location: 0.0),
                .init(color: Color(red: 0.050, green: 0.051, blue: 0.062), location: 0.16),
                .init(color: Color(red: 0.050, green: 0.051, blue: 0.062), location: 1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var darkEdgeStroke: LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color(red: 0.84, green: 0.89, blue: 1.0).opacity(0.072), location: 0.0),
                .init(color: Color(red: 0.84, green: 0.89, blue: 1.0).opacity(0.066), location: 0.2),
                .init(color: Color(red: 0.80, green: 0.86, blue: 0.97).opacity(0.06), location: 1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var cardAmbientTint: Color {
        Color(red: 0.66, green: 0.75, blue: 0.84)
    }

    private var cardAmbientTopOpacity: Double {
        0.032
    }

    private var cardAmbientMidOpacity: Double {
        0.016
    }

    private var cardAmbientDarkTopOpacity: Double {
        0.018
    }

    private var cardAmbientDarkMidOpacity: Double {
        0.008
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
                ZStack(alignment: .top) {
                    if colorScheme == .dark {
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.white.opacity(0.03 * ambient), location: 0.0),
                                .init(color: Color.white.opacity(0.014 * ambient), location: 0.26),
                                .init(color: .clear, location: 0.72)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )

                        RadialGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color(red: 0.50, green: 0.58, blue: 0.66).opacity(0.088 * ambient), location: 0.0),
                                .init(color: Color(red: 0.50, green: 0.58, blue: 0.66).opacity(0.054 * ambient), location: 0.42),
                                .init(color: .clear, location: 1.0)
                            ]),
                            center: animateSurface ? UnitPoint(x: -0.12, y: -0.2) : UnitPoint(x: -0.18, y: -0.24),
                            startRadius: 72,
                            endRadius: 680
                        )
                        .blur(radius: 198)

                        RadialGradient(
                            gradient: Gradient(stops: [
                                .init(color: accent.opacity(0.016 * ambient), location: 0.0),
                                .init(color: accent.opacity(0.01 * ambient), location: 0.44),
                                .init(color: .clear, location: 1.0)
                            ]),
                            center: animateSurface ? UnitPoint(x: -0.12, y: -0.2) : UnitPoint(x: -0.18, y: -0.24),
                            startRadius: 84,
                            endRadius: 700
                        )
                        .blur(radius: 198)

                        RadialGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color(red: 0.47, green: 0.56, blue: 0.63).opacity(0.06 * ambient), location: 0.0),
                                .init(color: Color(red: 0.47, green: 0.56, blue: 0.63).opacity(0.036 * ambient), location: 0.46),
                                .init(color: .clear, location: 1.0)
                            ]),
                            center: animateSurface ? UnitPoint(x: 1.22, y: 0.86) : UnitPoint(x: 1.16, y: 0.8),
                            startRadius: 70,
                            endRadius: 640
                        )
                        .blur(radius: 188)
                    } else {
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: accent.opacity(0.146 * ambient), location: 0.0),
                                .init(color: accent.opacity(0.064 * ambient), location: 0.24),
                                .init(color: accent.opacity(0.022 * ambient), location: 0.58),
                                .init(color: .clear, location: 1.0)
                            ]),
                            startPoint: animateSurface ? UnitPoint(x: 0.46, y: 0.0) : UnitPoint(x: 0.54, y: 0.03),
                            endPoint: animateSurface ? UnitPoint(x: 0.58, y: 1.0) : UnitPoint(x: 0.42, y: 0.97)
                        )
                        .blur(radius: 42 + (8 * (ambient - 1)))

                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.white.opacity(0.042 * ambient), location: 0.0),
                                .init(color: Color.white.opacity(0.016 * ambient), location: 0.22),
                                .init(color: .clear, location: 0.74)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .blendMode(.screen)
                    }
                }
                .frame(height: colorScheme == .dark ? 320 : 292)
                .allowsHitTesting(false)
                .ignoresSafeArea(edges: .top)
                .mask(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .white, location: 0.0),
                            .init(color: .white, location: colorScheme == .dark ? 0.38 : 0.56),
                            .init(color: .white.opacity(colorScheme == .dark ? 0.45 : 0.74), location: colorScheme == .dark ? 0.62 : 0.8),
                            .init(color: .clear, location: 1.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 324)
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
        withAnimation(.easeInOut(duration: 32).repeatForever(autoreverses: true)) {
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
