import SwiftUI

struct ZoneBadge: View {
    let zone: Zone
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(zone.color)
                .frame(width: 6, height: 6)
            Text(zone.name)
                .font(.system(size: compact ? 11 : 13, weight: .semibold))
            if !compact {
                Text("·")
                    .foregroundStyle(.white.opacity(0.4))
                Text(zone.label)
                    .font(.system(size: 13, weight: .medium))
            }
        }
        .foregroundStyle(zone.color)
        .padding(.horizontal, compact ? 8 : 12)
        .padding(.vertical, compact ? 3 : 6)
        .background(Capsule().fill(zone.color.opacity(0.12)))
        .overlay(Capsule().strokeBorder(zone.color.opacity(0.35), lineWidth: 1))
    }
}
