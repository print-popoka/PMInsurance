import SwiftUI

enum PillTone {
    case white, blue, red, green, amber, custom(Color)

    var fg: Color {
        switch self {
        case .white:        Color.white
        case .blue:         Color(hex: "7BB6FF")
        case .red:          Color(hex: "FF8A95")
        case .green:        Color(hex: "6EE7B7")
        case .amber:        Color(hex: "FCD34D")
        case .custom(let c): c
        }
    }

    var bg: Color {
        switch self {
        case .white:        Color.white.opacity(0.10)
        case .blue:         Color.iosBlue.opacity(0.15)
        case .red:          Color.iosRed.opacity(0.15)
        case .green:        Color(hex: "34D399").opacity(0.15)
        case .amber:        Color(hex: "FBBF24").opacity(0.15)
        case .custom(let c): c.opacity(0.15)
        }
    }

    var border: Color {
        switch self {
        case .white:        Color.white.opacity(0.10)
        case .blue:         Color.iosBlue.opacity(0.30)
        case .red:          Color.iosRed.opacity(0.30)
        case .green:        Color(hex: "34D399").opacity(0.30)
        case .amber:        Color(hex: "FBBF24").opacity(0.30)
        case .custom(let c): c.opacity(0.30)
        }
    }
}

struct Pill<Content: View>: View {
    let tone: PillTone
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 4) {
            content()
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(tone.fg)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(tone.bg))
        .overlay(Capsule().strokeBorder(tone.border, lineWidth: 1))
    }
}
