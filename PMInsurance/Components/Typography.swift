import SwiftUI

extension Font {
    static let display80   = Font.system(size: 80, weight: .semibold, design: .default)
    static let display60   = Font.system(size: 60, weight: .semibold, design: .default)
    static let display48   = Font.system(size: 48, weight: .semibold, design: .default)
    static let display44   = Font.system(size: 44, weight: .semibold, design: .default)
    static let display34   = Font.system(size: 34, weight: .semibold, design: .default)
    static let display28   = Font.system(size: 28, weight: .semibold, design: .default)
    static let display24   = Font.system(size: 24, weight: .semibold, design: .default)
    static let display20   = Font.system(size: 20, weight: .semibold, design: .default)
    static let title17     = Font.system(size: 17, weight: .semibold)
    static let body15      = Font.system(size: 15, weight: .regular)
    static let body14      = Font.system(size: 14, weight: .regular)
    static let body13      = Font.system(size: 13, weight: .regular)
    static let caption12   = Font.system(size: 12, weight: .regular)
    static let caption11   = Font.system(size: 11, weight: .regular)
    static let micro10     = Font.system(size: 10, weight: .regular)
}

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

enum Radius {
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 28
}

extension View {
    func uppercaseLabel(letterSpacing: CGFloat = 1.6) -> some View {
        self
            .font(.caption11)
            .foregroundStyle(.white.opacity(0.5))
            .textCase(.uppercase)
            .tracking(letterSpacing)
    }

    func glassShadow() -> some View {
        self.shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 12)
    }
}
