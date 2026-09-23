import SwiftUI

/// Color belongs to the content surface; native glass is reserved for controls above it.
struct BeamletSurface: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        ZStack {
            (scheme == .dark ? Color(red: 0.075, green: 0.08, blue: 0.10)
                             : Color(red: 1, green: 0.975, blue: 0.95))
            if !reduceTransparency && contrast != .increased {
                RadialGradient(colors: [Color(red: 1, green: 0.51, blue: 0.35).opacity(scheme == .dark ? 0.10 : 0.20), .clear],
                               center: .topTrailing, startRadius: 0, endRadius: 280)
                LinearGradient(colors: [.clear, Color(red: 1, green: 0.76, blue: 0.51).opacity(scheme == .dark ? 0.02 : 0.07)],
                               startPoint: .top, endPoint: .bottom)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct BeamletPrimaryControl: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 26, *), !reduceTransparency, contrast != .increased {
            content.buttonStyle(.glassProminent).buttonBorderShape(.capsule)
        } else {
            content.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
        }
    }
}

/// Frequent menu actions get instant feedback, without entrance or layout animation.
struct BeamletRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Row(configuration: configuration)
    }

    private struct Row: View {
        let configuration: ButtonStyle.Configuration
        @Environment(\.isEnabled) private var enabled
        @Environment(\.colorSchemeContrast) private var contrast
        @State private var hovered = false

        var body: some View {
            configuration.label
                .foregroundStyle(Color.primary)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(enabled ? (configuration.isPressed ? 0.12 : hovered ? 0.06 : 0) : 0))
                }
                .overlay {
                    if contrast == .increased && hovered && enabled {
                        RoundedRectangle(cornerRadius: 10).strokeBorder(.primary, lineWidth: 1)
                    }
                }
                .opacity(enabled ? 1 : 0.50)
                .onHover { hovered = $0 }
        }
    }
}
