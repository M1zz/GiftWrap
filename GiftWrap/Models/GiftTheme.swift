import SwiftUI

/// Card palettes. Vivid, edge-to-edge color washes in the spirit of App Store gift cards —
/// but drawn from scratch here, with no Apple artwork or marks reproduced.
enum GiftTheme: String, Codable, CaseIterable, Identifiable {
    case sunrise, aurora, mint, blossom, graphite

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sunrise:  return "Sunrise"
        case .aurora:   return "Aurora"
        case .mint:     return "Mint"
        case .blossom:  return "Blossom"
        case .graphite: return "Graphite"
        }
    }

    /// base → mid → top, painted diagonally.
    var stops: [Color] {
        switch self {
        case .sunrise:
            return [Color(hex: 0xFF3D77), Color(hex: 0xFF7A59), Color(hex: 0xFFC15E)]
        case .aurora:
            return [Color(hex: 0x3D5AFE), Color(hex: 0x7A5BFF), Color(hex: 0x2ED8C3)]
        case .mint:
            return [Color(hex: 0x0BA98A), Color(hex: 0x34E0A1), Color(hex: 0xB8F5D8)]
        case .blossom:
            return [Color(hex: 0xE0489A), Color(hex: 0xFF7FB2), Color(hex: 0xFFD3C1)]
        case .graphite:
            return [Color(hex: 0x161618), Color(hex: 0x2C2C2E), Color(hex: 0x5B5B60)]
        }
    }

    /// Soft light bloom colors layered over the base gradient.
    var blooms: [Color] {
        switch self {
        case .sunrise:  return [Color(hex: 0xFFD98A), Color(hex: 0xFF4FA3)]
        case .aurora:   return [Color(hex: 0x8AF0FF), Color(hex: 0xB08CFF)]
        case .mint:     return [Color(hex: 0xEFFFF7), Color(hex: 0x00C2A8)]
        case .blossom:  return [Color(hex: 0xFFE7C9), Color(hex: 0xFF5C9E)]
        case .graphite: return [Color(hex: 0x8E8E93), Color(hex: 0x3A3A3C)]
        }
    }

    var ink: Color { .white }
    var inkSecondary: Color { .white.opacity(0.78) }

    /// Hex strings for the exported HTML page.
    var hexStops: [String] { stops.map { $0.hexString } }
    var hexBlooms: [String] { blooms.map { $0.hexString } }

    var gradient: LinearGradient {
        LinearGradient(colors: stops, startPoint: .bottomLeading, endPoint: .topTrailing)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: 1
        )
    }

    /// Best-effort hex for HTML export.
    var hexString: String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? NSColor.white
        let r = Int((ns.redComponent * 255).rounded())
        let g = Int((ns.greenComponent * 255).rounded())
        let b = Int((ns.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
