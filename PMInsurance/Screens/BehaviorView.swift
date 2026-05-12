import SwiftUI

struct BehaviorView: View {
    @EnvironmentObject private var state: AppState

    @StateObject private var motion = MotionManager()
    @State private var liveShake: Bool = false
    @State private var accelSmoothed: Double = 38

    private var risks: [String: Double] { state.risks }
    private var rsValue: Double {
        computeRS(
            rapidAccel: risks["accel"] ?? 0,
            zigzag:     risks["swerve"] ?? 0,
            sidewalk:   risks["sidewalk"] ?? 0,
            nightRatio: risks["night"] ?? 0,
            distance:   risks["distance"] ?? 0
        )
    }
    private var gradeLetter: String { grade(rs: rsValue) }
    private var rfMultiplier: Double { rfBehavior(rs: rsValue) }
    private var rsColor: Color {
        switch gradeLetter {
        case "A": .zoneI
        case "B": .zoneII
        case "C": .zoneIII
        default:  .zoneIV
        }
    }

    var body: some View {
        ZStack {
            NavyBackground(soft: true)
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    rsGaugeCard
                    motionCard
                    contributionsCard
                    slidersCard
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.sm)
            }
        }
        .navigationTitle("행동 점수")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { stopShake() }
    }

    // MARK: - RS gauge

    private var rsGaugeCard: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(rsColor.opacity(0.28))
                .frame(width: 200, height: 200)
                .blur(radius: 70)
                .offset(x: 40, y: -60)
                .allowsHitTesting(false)

            GlassCard(strong: true) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack {
                        Text("실시간 행동 점수").uppercaseLabel()
                        Spacer()
                        Pill(tone: liveShake ? .red : .blue) {
                            Image(systemName: liveShake ? "waveform.path" : "info.circle")
                                .font(.system(size: 9))
                            Text(liveShake ? "라이브" : "5변수 가중")
                        }
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(Int(rsValue.rounded()).formatted(.number))
                            .font(.system(size: 64, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(rsColor)
                            .contentTransition(.numericText())
                            .animation(.snappy(duration: 0.25), value: Int(rsValue.rounded()))
                        Text("점")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.55))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("등급")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.5))
                            Text(gradeLetter)
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(rsColor)
                        }
                    }
                    rsBar
                    HStack(spacing: 8) {
                        Text("RF_behavior")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("× \(rfMultiplier.formatted(.number.precision(.fractionLength(2))))")
                            .font(.system(size: 13, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(rsColor)
                        Spacer()
                        Text(gradeDescription)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
        }
    }

    private var rsBar: some View {
        GeometryReader { geo in
            let frac = CGFloat(min(max(rsValue, 0), 100) / 100)
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: [.zoneIV, .zoneIII, .zoneII, .zoneI], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(10, geo.size.width * frac))
                ForEach([30, 50, 70, 85], id: \.self) { mark in
                    let m = CGFloat(mark) / 100
                    Rectangle()
                        .fill(.black.opacity(0.4))
                        .frame(width: 1, height: 10)
                        .offset(x: geo.size.width * m - 0.5)
                }
            }
        }
        .frame(height: 10)
        .clipShape(Capsule())
    }

    private var gradeDescription: String {
        switch gradeLetter {
        case "A": "Zone II 락인 후보"
        case "B": "양호 — 우대"
        case "C": "주의"
        case "D": "위험 — 코칭 권장"
        default:  "Sleeping Dogs"
        }
    }

    // MARK: - CoreMotion card

    private var motionCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("CoreMotion 실시간 연동").uppercaseLabel()
                    Spacer()
                    if !motion.isAvailable {
                        Pill(tone: .amber) { Text("센서 없음") }
                    }
                }

                Text(liveShake ? "지금 폰을 흔들어보세요" : "버튼을 누른 뒤 폰을 흔들면 급가속 위험이 실시간으로 반영됩니다.")
                    .font(.body14)
                    .foregroundStyle(.white.opacity(0.8))

                magnitudeGauge

                Button {
                    liveShake ? stopShake() : startShake()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: liveShake ? "stop.circle.fill" : "waveform.path.ecg")
                            .font(.system(size: 16, weight: .semibold))
                        Text(liveShake ? "센서 중단" : "지금 흔들어보세요")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .fill(liveShake ? Color.iosRed : Color.iosBlue)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!motion.isAvailable)
            }
        }
    }

    private var magnitudeGauge: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("가속도 magnitude")
                    .font(.caption11)
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text(motion.magnitude.formatted(.number.precision(.fractionLength(2))) + " g")
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(motion.spike ? .iosRed : .white.opacity(0.85))
            }
            GeometryReader { geo in
                let frac = CGFloat(min(motion.magnitude / 3.0, 1.0))
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.06))
                    Capsule()
                        .fill(motion.spike ? Color.iosRed : Color.iosBlue)
                        .frame(width: max(8, geo.size.width * frac))
                        .animation(.easeOut(duration: 0.15), value: motion.magnitude)
                }
            }
            .frame(height: 8)
        }
    }

    private func startShake() {
        guard motion.isAvailable else { return }
        motion.start()
        liveShake = true
    }

    private func stopShake() {
        motion.stop()
        liveShake = false
    }

    // MARK: - Contributions card

    private var contributionsCard: some View {
        let maxContribution = behaviorVariables.map { $0.weight * 100 }.max() ?? 1
        return GlassCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("기여도 막대").uppercaseLabel()
                    Spacer()
                    Text("위험 \(Int((100 - rsValue).rounded()))점 / 100")
                        .font(.caption11)
                        .foregroundStyle(.white.opacity(0.5))
                        .monospacedDigit()
                }
                ForEach(behaviorVariables) { variable in
                    ContributionRow(
                        variable: variable,
                        rawValue: risks[variable.id] ?? 0,
                        maxContribution: maxContribution
                    )
                }
            }
        }
    }

    // MARK: - Sliders card

    private var slidersCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("5변수 위험 입력").uppercaseLabel()
                ForEach(behaviorVariables) { variable in
                    BehaviorSliderRow(
                        variable: variable,
                        value: binding(for: variable.id),
                        live: liveShake && variable.id == "accel"
                    )
                }
                Text("기본값은 RS 77점 / B등급 시연용 — 각 슬라이더는 0~100 위험 척도입니다.")
                    .font(.caption11)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 4)
            }
        }
        .onReceive(motion.$magnitude) { mag in
            guard liveShake else { return }
            // Map [0, 3] g → [0, 100] risk, smoothed by EMA so the slider
            // doesn't jitter every frame. Spike adds a brief boost.
            let raw = min(100, mag * 33.0) + (motion.spike ? 15 : 0)
            accelSmoothed = 0.65 * accelSmoothed + 0.35 * raw
            state.risks["accel"] = min(100, accelSmoothed)
        }
    }

    private func binding(for id: String) -> Binding<Double> {
        Binding(
            get: { state.risks[id] ?? 0 },
            set: { state.risks[id] = $0 }
        )
    }
}

// MARK: - Sub-rows

private struct ContributionRow: View {
    let variable: BehaviorVariable
    let rawValue: Double
    let maxContribution: Double

    private var contribution: Double { variable.weight * rawValue }
    private var fillFraction: CGFloat { CGFloat(contribution / maxContribution) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: variable.icon)
                    .frame(width: 18)
                    .foregroundStyle(Color(hex: variable.colorHex))
                Text(variable.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text("w \(variable.weight.formatted(.number.precision(.fractionLength(2))))")
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.45))
                Text("\(contribution.formatted(.number.precision(.fractionLength(1))))점")
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color(hex: variable.colorHex))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.06))
                    Capsule()
                        .fill(Color(hex: variable.colorHex))
                        .frame(width: max(6, geo.size.width * fillFraction))
                        .animation(.snappy(duration: 0.25), value: fillFraction)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 2)
    }
}

private struct BehaviorSliderRow: View {
    let variable: BehaviorVariable
    @Binding var value: Double
    var live: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: variable.icon)
                    .frame(width: 22)
                    .foregroundStyle(Color(hex: variable.colorHex))
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(variable.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        if live {
                            Pill(tone: .red) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 8))
                                Text("LIVE")
                            }
                        }
                    }
                    Text(variable.rationale)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
                Spacer()
                Text("\(Int(value))")
                    .font(.system(size: 17, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color(hex: variable.colorHex))
                Text("점")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Slider(value: $value, in: 0...100, step: 1)
                .tint(Color(hex: variable.colorHex))
                .disabled(live)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        BehaviorView()
    }
    .environmentObject(AppState())
    .preferredColorScheme(.dark)
}
