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
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundColor)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(borderColor, lineWidth: 1.2)
                    }
                    .shadow(
                        color: shadowColor,
                        radius: shadowRadius,
                        x: 0,
                        y: shadowYOffset
                    )
            }
    }

    private var backgroundColor: Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.04)
        } else {
            return Color(uiColor: .systemBackground)
        }
    }

    private var borderColor: Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.12)
        } else {
            return Color.black.opacity(0.08)
        }
    }

    private var shadowColor: Color {
        if colorScheme == .dark {
            return Color.black.opacity(0.25)
        } else {
            return Color.black.opacity(0.08)
        }
    }

    private var shadowRadius: CGFloat {
        colorScheme == .dark ? 8 : 6
    }

    private var shadowYOffset: CGFloat {
        colorScheme == .dark ? 4 : 2
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

    func cadenceSurface(cornerRadius: CGFloat = 20) -> some View {
        modifier(
            CadenceSurfaceModifier(
                cornerRadius: cornerRadius
            )
        )
    }
}
