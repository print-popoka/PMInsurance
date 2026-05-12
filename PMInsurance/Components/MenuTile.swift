import SwiftUI

struct MenuTile: View {
    let label: String
    let icon: String
    let tint: Color
    var subtitle: String = "바로 열기"
    var wide: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            content
        }
        .buttonStyle(MenuTilePressStyle())
    }

    @ViewBuilder
    private var content: some View {
        if wide {
            HStack(spacing: 12) {
                iconBadge
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption11)
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.tint(Color.white.opacity(0.05)), in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        } else {
            VStack(alignment: .leading, spacing: 12) {
                iconBadge
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption11)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.tint(Color.white.opacity(0.05)), in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        }
    }

    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(tint.opacity(0.4), lineWidth: 1)
                )
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(tint)
        }
        .frame(width: 40, height: 40)
    }
}

private struct MenuTilePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

struct StatCell: View {
    let label: String
    let value: String
    var suffix: String = ""
    var tint: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption11)
                .foregroundStyle(.white.opacity(0.5))
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                if !suffix.isEmpty {
                    Text(suffix)
                        .font(.caption12)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
    }
}
