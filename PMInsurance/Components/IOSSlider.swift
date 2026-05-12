import SwiftUI

struct IOSSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...100
    var step: Double = 1
    var label: String
    var hint: String?
    var valueLabel: String
    var accent: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                    if let hint {
                        Text(hint)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                Spacer()
                Text(valueLabel)
                    .font(.system(size: 17, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(accent)
            }
            Slider(value: $value, in: range, step: step)
                .tint(accent)
        }
    }
}
