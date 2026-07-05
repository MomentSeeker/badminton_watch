import SwiftUI

enum KVColor {
    static let background = Color(red: 0.05, green: 0.05, blue: 0.05)
    static let surface = Color(red: 0.11, green: 0.11, blue: 0.11)
    static let surfaceHigh = Color(red: 0.18, green: 0.18, blue: 0.18)
    static let lime = Color(red: 0.76, green: 0.96, blue: 0.0)
    static let cyan = Color(red: 0.0, green: 0.95, blue: 1.0)
    static let load = Color(red: 0.92, green: 1.0, blue: 0.18)
    static let courtAmber = Color(red: 1.0, green: 0.72, blue: 0.16)
    static let pink = Color(red: 1.0, green: 0.30, blue: 0.48)
    static let amber = Color(red: 1.0, green: 0.77, blue: 0.18)
    static let text = Color(red: 0.90, green: 0.89, blue: 0.88)
    static let muted = Color(red: 0.63, green: 0.65, blue: 0.57)
    static let outline = Color.white.opacity(0.10)
}

enum KVFont {
    static func headline(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func data(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension View {
    func glassTile(radius: CGFloat = 8, borderColor: Color = KVColor.outline) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(KVColor.surface.opacity(0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
    }

    func telemetryGlow(_ color: Color = KVColor.lime) -> some View {
        self.shadow(color: color.opacity(0.45), radius: 9, x: 0, y: 0)
    }
}
