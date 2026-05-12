import SwiftUI
import Charts

struct CoordinateView: View {
    @EnvironmentObject private var state: AppState

    private var pmShare: Double { state.pmShare }
    private var rs: Double { state.rs }
    private let sample: [SamplePoint] = SamplePoint.distribution
    private var zone: Zone { classifyZone(pmShare: pmShare, rs: rs) }
    private var peerCount: Int {
        sample.filter { $0.zone == zone }.count
    }

    var body: some View {
        ZStack {
            NavyBackground(soft: true)
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    headerCard
                    slidersCard
                    chartCard
                    legendCard
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.sm)
            }
        }
        .navigationTitle("좌표평면")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerCard: some View {
        GlassCard(strong: true) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("내 좌표").uppercaseLabel()
                    Spacer()
                    ZoneBadge(zone: zone, compact: true)
                }
                HStack(spacing: Spacing.lg) {
                    CoordStatCell(label: "PM 이용", value: "\(Int(pmShare))", suffix: "%")
                    Divider().frame(height: 36).background(.white.opacity(0.08))
                    CoordStatCell(label: "행동 점수", value: "\(Int(rs))", suffix: "점")
                    Divider().frame(height: 36).background(.white.opacity(0.08))
                    CoordStatCell(label: "동일 구역", value: "\(peerCount)", suffix: "명", tint: zone.color)
                }
                Text(zone.subtitle)
                    .font(.body13)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    // MARK: - Chart card

    private var chartCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("이변수 분포 · 가상 200명").uppercaseLabel()
                    Spacer()
                    Pill(tone: .blue) { Text("X: PM 비중 · Y: 행동 점수") }
                }
                chart
                    .frame(height: 320)
                    .padding(.top, 4)
                Text("경계선: PM 30% / RS 70점 → Zone I·II·III·IV 자동 분류")
                    .font(.caption11)
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(sample) { point in
                PointMark(
                    x: .value("PM", point.pmShare),
                    y: .value("RS", point.rs)
                )
                .symbolSize(point.zone == zone ? 50 : 30)
                .foregroundStyle(point.zone.color.opacity(point.zone == zone ? 0.85 : 0.45))
            }
            RuleMark(x: .value("X-boundary", 30))
                .foregroundStyle(.white.opacity(0.30))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
            RuleMark(y: .value("Y-boundary", 70))
                .foregroundStyle(.white.opacity(0.30))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
        }
        .chartXScale(domain: 0...100)
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: [0, 30, 60, 100]) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.06))
                AxisTick().foregroundStyle(.white.opacity(0.15))
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text("\(v)%")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: [0, 30, 50, 70, 100]) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.06))
                AxisTick().foregroundStyle(.white.opacity(0.15))
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text("\(v)")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
        }
        .chartPlotStyle { plot in
            plot
                .background(.white.opacity(0.02))
                .border(.white.opacity(0.08), width: 1)
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                if let plotAnchor = proxy.plotFrame {
                    let plotRect = geo[plotAnchor]
                    ZStack {
                        quadrantLabels(in: plotRect, proxy: proxy)
                        meDot(in: plotRect, proxy: proxy)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func quadrantLabels(in rect: CGRect, proxy: ChartProxy) -> some View {
        let centers: [(Zone, Double, Double)] = [
            (.I,   15, 88),
            (.II,  65, 88),
            (.III, 15, 18),
            (.IV,  65, 18),
        ]
        ForEach(centers, id: \.0) { triple in
            let (z, cx, cy) = triple
            if let x = proxy.position(forX: cx),
               let y = proxy.position(forY: cy) {
                VStack(spacing: 1) {
                    Text(z.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(z.color.opacity(0.85))
                    Text(z.label)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.black.opacity(0.35))
                )
                .position(x: rect.minX + x, y: rect.minY + y)
                .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private func meDot(in rect: CGRect, proxy: ChartProxy) -> some View {
        if let x = proxy.position(forX: pmShare),
           let y = proxy.position(forY: rs) {
            PulsingDot(color: zone.color, size: 16, ringColor: zone.color)
                .position(x: rect.minX + x, y: rect.minY + y)
                .allowsHitTesting(false)
                .animation(.snappy(duration: 0.25), value: pmShare)
                .animation(.snappy(duration: 0.25), value: rs)
        }
    }

    // MARK: - Legend

    private var legendCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("4 구역 의미").uppercaseLabel()
                LegendRow(zone: .II,  count: sample.filter { $0.zone == .II }.count,  highlight: zone == .II)
                LegendRow(zone: .I,   count: sample.filter { $0.zone == .I }.count,   highlight: zone == .I)
                LegendRow(zone: .III, count: sample.filter { $0.zone == .III }.count, highlight: zone == .III)
                LegendRow(zone: .IV,  count: sample.filter { $0.zone == .IV }.count,  highlight: zone == .IV)
            }
        }
    }

    // MARK: - Sliders

    private var slidersCard: some View {
        GlassCard {
            VStack(spacing: Spacing.lg) {
                IOSSlider(
                    value: $state.pmShare,
                    label: "PM 이용 비중",
                    hint: "X축 좌표",
                    valueLabel: "\(Int(pmShare))%",
                    accent: .iosBlue
                )
                Divider().background(.white.opacity(0.08))
                IOSSlider(
                    value: $state.rs,
                    label: "행동 점수 (RS)",
                    hint: "Y축 좌표 · 등급 \(grade(rs: rs))",
                    valueLabel: "\(Int(rs))점",
                    accent: .zoneI
                )
            }
        }
    }
}

// MARK: - Legend row

private struct LegendRow: View {
    let zone: Zone
    let count: Int
    var highlight: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(zone.color)
                .frame(width: 10, height: 10)
                .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1))
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(zone.name)
                        .font(.system(size: 13, weight: highlight ? .semibold : .medium))
                        .foregroundStyle(highlight ? zone.color : .white.opacity(0.85))
                    Text(zone.label)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Text(zone.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
            }
            Spacer()
            Text("\(count)명")
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(highlight ? zone.color : .white.opacity(0.6))
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Sample distribution (deterministic)

private struct SamplePoint: Identifiable, Sendable {
    let id: Int
    let pmShare: Double
    let rs: Double
    var zone: Zone { classifyZone(pmShare: pmShare, rs: rs) }
}

private extension SamplePoint {
    static let distribution: [SamplePoint] = makeDistribution()

    static func makeDistribution() -> [SamplePoint] {
        // (centerPM, centerRS, count, spreadPM, spreadRS) — counts sum to 200.
        let clusters: [(Double, Double, Int, Double, Double)] = [
            (55, 80, 60, 22, 12),  // → mostly Zone II
            (18, 82, 55, 14, 12),  // → mostly Zone I
            (18, 55, 45, 14, 18),  // → mostly Zone III
            (60, 50, 40, 22, 16),  // → mostly Zone IV
        ]
        var rng = SeededRNG(seed: 1828)
        var out: [SamplePoint] = []
        out.reserveCapacity(200)
        var id = 0
        for (cpm, crs, count, spm, srs) in clusters {
            for _ in 0..<count {
                let noisePM = rng.nextSigned()
                let noiseRS = rng.nextSigned()
                let pm = (cpm + noisePM * spm).clamped(to: 1.0...99.0)
                let rs = (crs + noiseRS * srs).clamped(to: 1.0...99.0)
                out.append(SamplePoint(id: id, pmShare: pm, rs: rs))
                id += 1
            }
        }
        return out
    }
}

/// Deterministic LCG — Numerical Recipes constants. Yields reproducible
/// distributions without touching SystemRandom across renders.
private struct SeededRNG {
    private var state: UInt64

    init(seed: UInt64) { self.state = seed &* 6364136223846793005 &+ 1442695040888963407 }

    mutating func nextUnit() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let bits = (state >> 33) & 0xFFFFFF
        return Double(bits) / Double(0x1_000_000)
    }

    mutating func nextSigned() -> Double {
        nextUnit() * 2.0 - 1.0
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - StatCell (file-private; HomeView keeps its own copy)

private struct CoordStatCell: View {
    let label: String
    let value: String
    var suffix: String = ""
    var tint: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.5))
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                Text(suffix)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}

#Preview {
    NavigationStack {
        CoordinateView()
    }
    .environmentObject(AppState())
    .preferredColorScheme(.dark)
}
