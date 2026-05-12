import SwiftUI

struct PremiumSimulatorView: View {
    @EnvironmentObject private var state: AppState

    private var pmShare: Double { state.pmShare }
    private var rs: Double { state.rs }
    private var rf: Double      { rfBehavior(rs: rs) }
    private var wm: Double      { wModal(pmShare: pmShare, rs: rs) }
    private var premium: Int    { calculatePremium(pmShare: pmShare, rs: rs) }
    private var zone: Zone      { classifyZone(pmShare: pmShare, rs: rs) }

    // Single-score UBI: drops the modal-share term — same RS, no PM weighting.
    private var singleScorePremium: Int {
        Int((Premium.basePure * Premium.loading * rf).rounded())
    }
    private var deltaWonVsSingle: Int { premium - singleScorePremium }

    var body: some View {
        ZStack {
            NavyBackground(soft: true)
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    bigPremiumCard
                    slidersCard
                    breakdownCard
                    comparisonCard
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.sm)
            }
        }
        .navigationTitle("보험료 시뮬레이터")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Big premium card

    private var bigPremiumCard: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(zone.color.opacity(0.28))
                .frame(width: 180, height: 180)
                .blur(radius: 60)
                .offset(x: 50, y: -50)
                .allowsHitTesting(false)

            GlassCard(strong: true) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack {
                        Text("예상 월 보험료").uppercaseLabel()
                        Spacer()
                        ZoneBadge(zone: zone, compact: true)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(premium.formatted(.number))
                            .font(.display48)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(.snappy(duration: 0.25), value: premium)
                        Text("원")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Text(zone.subtitle)
                        .font(.body13)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }

    // MARK: - Sliders card

    private var slidersCard: some View {
        GlassCard {
            VStack(spacing: Spacing.lg) {
                IOSSlider(
                    value: $state.pmShare,
                    label: "PM 이용 비중",
                    hint: "이동 중 PM이 차지하는 비율",
                    valueLabel: "\(Int(pmShare))%",
                    accent: .iosBlue
                )
                Divider().background(.white.opacity(0.08))
                IOSSlider(
                    value: $state.rs,
                    label: "행동 점수 (RS)",
                    hint: "5변수 가중 평균 · 등급 \(grade(rs: rs))",
                    valueLabel: "\(Int(rs))점",
                    accent: .zoneI
                )
            }
        }
    }

    // MARK: - Calculation breakdown

    private var breakdownCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("계산 과정").uppercaseLabel()
                    Spacer()
                    Pill(tone: .blue) { Text("부록 3.4 수식") }
                }

                BreakdownRow(
                    label: "기준 순보험료",
                    detail: "Pure Premium",
                    value: Premium.basePure.formatted(.number) + "원"
                )
                BreakdownRow(
                    label: "× 부가료",
                    detail: "사업비 0.20 + 이윤 0.05",
                    value: "× 1.25"
                )
                BreakdownRow(
                    label: "× RF_behavior",
                    detail: "RS \(Int(rs))점 · \(grade(rs: rs))등급",
                    value: "× " + rf.formatted(.number.precision(.fractionLength(2))),
                    accent: .zoneI
                )
                BreakdownRow(
                    label: "× w_modal",
                    detail: pmModalLabel,
                    value: "× " + wm.formatted(.number.precision(.fractionLength(2))),
                    accent: .iosBlue
                )

                Divider().background(.white.opacity(0.15)).padding(.vertical, 2)

                HStack {
                    Text("월 보험료")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Text("\(premium.formatted(.number))원")
                        .font(.system(size: 22, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.25), value: premium)
                }
            }
        }
    }

    private var pmModalLabel: String {
        let persona = personaName(pmShare: pmShare, rs: rs)
        let pct: String
        switch persona {
        case "Safe Eco":      pct = "(-15%)"
        case "Safe Balanced": pct = "(-10%)"
        case "Safe Power":    pct = "(-5%)"
        case "Latent":        pct = "(중립)"
        case "Caution":       pct = "(+10%)"
        default:              pct = "(+15%)"   // Risk Heavy
        }
        return "\(persona) \(pct)"
    }

    // MARK: - Comparison card (simplified + flattened visual hierarchy)

    private var comparisonCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("왜 보험료가 다를까?").uppercaseLabel()
                    Spacer()
                    Pill(tone: .blue) { Text("더 정밀한 차등") }
                }

                HStack(spacing: Spacing.md) {
                    ComparePill(
                        title: "행동 점수만 본다면",
                        subtitle: "기존 UBI 방식",
                        amountWon: singleScorePremium,
                        tint: .white.opacity(0.55)
                    )
                    ComparePill(
                        title: "+ PM 이용량까지",
                        subtitle: "멀티모달 방식",
                        amountWon: premium,
                        tint: zone.color
                    )
                }

                deltaRow

                Text("같은 운전 습관도 PM 사용량에 따라 위험 노출이 달라요 · 약 1.5배 더 정밀")
                    .font(.caption11)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 2)
            }
        }
    }

    /// Delta message — surcharge cases are framed as *incentive* to soften the negative read.
    private var deltaRow: some View {
        let savings = deltaWonVsSingle < 0
        let magnitude = Swift.abs(deltaWonVsSingle)
        let icon = savings ? "checkmark.circle.fill" : "scope"
        let tint: Color = savings ? Color(hex: "6EE7B7") : Color(hex: "93C5FD")
        let description = savings
            ? "PM 적게 타서 \(magnitude.formatted(.number))원 절약"
            : "정밀 차등 \(magnitude.formatted(.number))원 · 안전 운전 점수로 다음 달 인하 가능"
        return HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(description)
                .font(.body13)
        }
        .foregroundStyle(tint)
        .padding(.top, 2)
    }
}

// MARK: - Sub-views

private struct BreakdownRow: View {
    let label: String
    let detail: String
    let value: String
    var accent: Color = .white

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(accent)
        }
    }
}

private struct ComparePill: View {
    let title: String
    let subtitle: String
    let amountWon: Int
    var tint: Color = .white
    var emphasised: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(amountWon.formatted(.number))
                    .font(.system(size: emphasised ? 22 : 19, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(emphasised ? .white : .white.opacity(0.8))
                Text("원")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .contentTransition(.numericText())
            .animation(.snappy(duration: 0.25), value: amountWon)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(tint.opacity(emphasised ? 0.12 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(tint.opacity(emphasised ? 0.35 : 0.10), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        PremiumSimulatorView()
    }
    .environmentObject(AppState())
    .preferredColorScheme(.dark)
}
