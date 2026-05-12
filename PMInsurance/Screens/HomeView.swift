import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var state: AppState

    private let weeklyValues = UserRideHistory.weeklyRSValues
    private let weeklyLabels = UserRideHistory.weeklyDayLabels

    private var pmShare: Double { state.pmShare }
    private var rs: Double { state.rs }
    private var premium: Int { calculatePremium(pmShare: pmShare, rs: rs) }
    private var zone: Zone { classifyZone(pmShare: pmShare, rs: rs) }
    private var weeklyAverage: Double {
        Double(weeklyValues.reduce(0, +)) / Double(weeklyValues.count)
    }

    var body: some View {
        ZStack {
            NavyBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    greeting
                    premiumCard
                    advisorCard
                    menuGrid
                    weeklyChartCard
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.sm)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Greeting

    private var greeting: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(todayString)
                    .font(.body13)
                    .foregroundStyle(.white.opacity(0.5))
                Text("안녕하세요, 현중님")
                    .font(.display28)
            }
            Spacer()
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.iosBlue, .bgNavyDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
                Text("현")
                    .font(.system(size: 15, weight: .semibold))
                Circle().strokeBorder(.white.opacity(0.15), lineWidth: 1)
            }
            .frame(width: 44, height: 44)
        }
        .padding(.top, Spacing.sm)
    }

    private var todayString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월 d일 EEEE"
        return f.string(from: Date())
    }

    // MARK: - Premium card

    private var premiumCard: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(Color.iosBlue.opacity(0.30))
                .frame(width: 180, height: 180)
                .blur(radius: 60)
                .offset(x: 60, y: -60)
                .allowsHitTesting(false)

            GlassCard(strong: true) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack {
                        Text("이번 달 예상 보험료").uppercaseLabel()
                        Spacer()
                        ZoneBadge(zone: zone, compact: true)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(premium.formatted(.number))
                            .font(.display44)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(.snappy(duration: 0.3), value: premium)
                        Text("원")
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.right")
                            .font(.system(size: 12, weight: .semibold))
                        Text("지난달 대비 −8.4%")
                            .font(.body13)
                    }
                    .foregroundStyle(Color(hex: "6EE7B7"))

                    Divider().background(.white.opacity(0.10)).padding(.vertical, 4)

                    HStack(spacing: 0) {
                        StatCell(label: "행동 점수", value: "\(Int(rs))", suffix: "점")
                        Spacer()
                        StatCell(label: "PM 이용률", value: "\(Int(pmShare))", suffix: "%")
                        Spacer()
                        StatCell(label: "등급", value: grade(rs: rs), tint: .zoneII)
                    }
                }
            }
        }
    }

    // MARK: - Advisor card (Plan X' — Home entry point)

    private var advisorCard: some View {
        GlassCard(strong: true) {
            VStack(alignment: .leading, spacing: 10) {
                Button { state.navigateToChat() } label: {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.iosBlue, Color(hex: "A78BFA")], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 32, height: 32)
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("AI 어드바이저")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("질문하면 답변 + 시뮬레이션을 자동 시연")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)

                HStack(spacing: 6) {
                    AdvisorQuickPill(text: "보험료 어떻게 줄여?") {
                        state.navigateToChat(with: "보험료 어떻게 줄여?")
                    }
                    AdvisorQuickPill(text: "Zone IV 보여줘") {
                        state.navigateToChat(with: "Zone IV 보여줘")
                    }
                }
                AdvisorQuickPill(text: "사고나면 어떻게 처리돼?") {
                    state.navigateToChat(with: "사고나면 어떻게 처리돼?")
                }
            }
        }
    }

    // MARK: - Menu grid

    private var menuGrid: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("바로가기")
                .font(.body13)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.leading, 4)

            HStack(spacing: Spacing.md) {
                MenuTile(label: "보험료 시뮬", icon: "chart.line.uptrend.xyaxis", tint: .iosBlue) { state.navigate(to: .sim) }
                MenuTile(label: "좌표평면",     icon: "circle.grid.2x2.fill",     tint: .zoneI)   { state.navigate(to: .coord) }
            }
            HStack(spacing: Spacing.md) {
                MenuTile(label: "행동 점수",    icon: "waveform.path.ecg",        tint: .zoneIII) { state.navigate(to: .behavior) }
                MenuTile(label: "약관 챗봇",    icon: "bubble.left.and.bubble.right.fill", tint: Color(hex: "A78BFA")) { state.navigate(to: .chat) }
            }
            MenuTile(label: "사고 처리", icon: "exclamationmark.shield.fill", tint: .iosRed,
                     subtitle: "사고 자동 탐지·알림·보상", wide: true) { state.navigate(to: .fnol) }
        }
    }

    // MARK: - Weekly chart

    private var weeklyChartCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("이번 주 안전 운전").uppercaseLabel()
                        Text("평균 \(weeklyAverage, format: .number.precision(.fractionLength(1))) 점")
                            .font(.display20)
                            .monospacedDigit()
                    }
                    Spacer()
                    Pill(tone: .green) {
                        Text("+4.2 vs 지난주")
                    }
                }
                WeeklyBarChart(values: weeklyValues, labels: weeklyLabels, highlightIndex: 5)
            }
        }
    }
}

private struct AdvisorQuickPill: View {
    let text: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(.white.opacity(0.10)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environmentObject(AppState())
    .preferredColorScheme(.dark)
}
