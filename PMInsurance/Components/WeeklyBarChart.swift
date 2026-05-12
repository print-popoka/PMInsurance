import SwiftUI

struct WeeklyBarChart: View {
    let values: [Int]
    let labels: [String]
    var highlightIndex: Int? = nil
    var maxValue: Int = 100

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(zip(values, labels).enumerated()), id: \.offset) { idx, pair in
                let (value, label) = pair
                let isHighlighted = idx == highlightIndex
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(barGradient(highlighted: isHighlighted))
                                .frame(height: max(2, geo.size.height * (CGFloat(value) / CGFloat(maxValue))))
                        }
                    }
                    .frame(height: 110)
                    Text(label)
                        .font(.micro10)
                        .foregroundStyle(isHighlighted ? Color(hex: "6EE7B7") : .white.opacity(0.4))
                    Text("\(value)")
                        .font(.micro10)
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.top, -4)
                }
            }
        }
    }

    private func barGradient(highlighted: Bool) -> LinearGradient {
        if highlighted {
            return LinearGradient(
                colors: [Color(hex: "6EE7B7"), Color(hex: "34D399")],
                startPoint: .top, endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: [Color.iosBlue.opacity(0.9), Color.iosBlue.opacity(0.5)],
            startPoint: .top, endPoint: .bottom
        )
    }
}

#Preview {
    ZStack {
        NavyBackground()
        WeeklyBarChart(
            values: [72, 78, 65, 81, 74, 88, 78],
            labels: ["월","화","수","목","금","토","일"],
            highlightIndex: 5
        )
        .padding()
    }
}
