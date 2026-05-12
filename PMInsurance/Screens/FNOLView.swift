import SwiftUI

struct FNOLView: View {
    @EnvironmentObject private var state: AppState

    // -1 = idle, 0...4 = running that stage, 5 = all complete.
    @State private var stageIndex: Int = -1
    @State private var task: Task<Void, Never>?
    @State private var autoDetect: Bool = false
    @StateObject private var motion = MotionManager()

    private let stages: [FNOLStage] = FNOLStage.all
    private let stageMillis: Int = 1600  // 5 × 1.6s = 8.0s total
    private let payoutWon: Int = 287_000

    private var isRunning: Bool { stageIndex >= 0 && stageIndex < stages.count }
    private var isDone: Bool { stageIndex >= stages.count }

    var body: some View {
        ZStack {
            NavyBackground(soft: true)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.xl) {
                        headerCard
                        triggerCard
                        stagesCard
                        if isDone {
                            completionCard
                                .id("completion")
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.sm)
                    .animation(.snappy(duration: 0.30), value: stageIndex)
                }
                .onChange(of: isDone) { _, done in
                    // Auto-scroll to the completion card on done.
                    // (Demo flows entered via the advisor don't require manual scroll.)
                    if done {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.snappy(duration: 0.45)) {
                                proxy.scrollTo("completion", anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("사고 처리")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            cancel()
            motion.stop()
        }
        .onChange(of: autoDetect) { _, isOn in
            if isOn {
                motion.start()
            } else {
                motion.stop()
            }
        }
        .onChange(of: motion.crashDetected) { _, detected in
            if detected, autoDetect, !isRunning, !isDone {
                start()
            }
        }
        .onAppear {
            if state.pendingFNOLStart, !isRunning, !isDone {
                start()
                state.acknowledgeFNOLStart()
            }
        }
        .onChange(of: state.pendingFNOLStart) { _, pending in
            if pending, !isRunning, !isDone {
                start()
                state.acknowledgeFNOLStart()
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("FNOL 자동 처리").uppercaseLabel()
                    Spacer()
                    Pill(tone: isDone ? .green : (isRunning ? .red : .blue)) {
                        Image(systemName: isDone ? "checkmark.circle.fill" : (isRunning ? "waveform.path" : "info.circle"))
                            .font(.system(size: 9))
                        Text(isDone ? "처리 완료" : (isRunning ? "처리 중" : "대기"))
                    }
                }
                Text("First Notice of Loss — 사고 자동 탐지부터 보험금 지급까지 8초.")
                    .font(.body14)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    // MARK: - Trigger card

    private var triggerCard: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(Color.iosRed.opacity(isRunning ? 0.45 : 0.30))
                .frame(width: 200, height: 200)
                .blur(radius: 70)
                .offset(x: 50, y: -50)
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isRunning)

            GlassCard(strong: true) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.iosRed)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("사고 트리거")
                                .font(.system(size: 17, weight: .semibold))
                            Text(triggerSubtitle)
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        Spacer()
                    }
                    autoDetectRow
                    Button(action: triggerAction) {
                        HStack(spacing: 8) {
                            Image(systemName: triggerIcon)
                                .font(.system(size: 17, weight: .semibold))
                            Text(triggerLabel)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .fill(triggerFill)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .strokeBorder(.white.opacity(0.20), lineWidth: 1)
                        )
                        .shadow(color: Color.iosRed.opacity(isRunning ? 0 : 0.4), radius: 16, x: 0, y: 8)
                    }
                    .buttonStyle(.plain)
                    .disabled(isRunning)
                }
            }
        }
    }

    private var autoDetectRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sensor.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(autoDetect ? .iosRed : .white.opacity(0.5))
                Text("센서 자동 탐지")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                if autoDetect {
                    Pill(tone: .red) {
                        Image(systemName: "waveform").font(.system(size: 8))
                        Text("감지 대기")
                    }
                }
                Spacer()
                Toggle("", isOn: $autoDetect)
                    .labelsHidden()
                    .tint(.iosRed)
                    .disabled(!motion.isAvailable || isRunning)
            }
            if autoDetect {
                magnitudeBar
                Text("폰을 흔들면 (\(motion.crashThreshold.formatted(.number.precision(.fractionLength(1))))g 이상) 자동으로 사고 처리가 시작됩니다.")
                    .font(.caption11)
                    .foregroundStyle(.white.opacity(0.5))
            } else if !motion.isAvailable {
                Text("이 디바이스에선 모션 센서를 사용할 수 없습니다 (시뮬레이터).")
                    .font(.caption11)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(.white.opacity(autoDetect ? 0.15 : 0.06), lineWidth: 1)
        )
    }

    private var magnitudeBar: some View {
        GeometryReader { geo in
            let frac = CGFloat(min(motion.magnitude / motion.crashThreshold, 1.0))
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.06))
                Capsule()
                    .fill(motion.crashDetected ? Color.iosRed : (motion.spike ? Color(hex: "FBBF24") : Color.iosBlue))
                    .frame(width: max(8, geo.size.width * frac))
                    .animation(.easeOut(duration: 0.15), value: motion.magnitude)
            }
        }
        .frame(height: 6)
    }

    private var triggerSubtitle: String {
        if isDone { return "지급 완료 — 다시 시연하려면 리셋" }
        if isRunning { return "사고 시그널 감지 — 자동 처리 진행" }
        return "충돌·낙상·급정거 시 자동 발동 (시연용 버튼)"
    }

    private var triggerIcon: String {
        if isDone { return "arrow.counterclockwise" }
        if isRunning { return "waveform.path" }
        return "exclamationmark.shield.fill"
    }

    private var triggerLabel: String {
        if isDone { return "다시 시연" }
        if isRunning { return "처리 중..." }
        return "사고 트리거 발동"
    }

    private var triggerFill: AnyShapeStyle {
        if isRunning {
            return AnyShapeStyle(Color.iosRed.opacity(0.55))
        }
        return AnyShapeStyle(
            LinearGradient(
                colors: [.iosRed, Color(hex: "DC2626")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func triggerAction() {
        if isDone {
            reset()
        } else if !isRunning {
            start()
        }
    }

    // MARK: - Stages card

    private var stagesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("처리 단계").uppercaseLabel()
                    Spacer()
                    Text(progressLabel)
                        .font(.caption11)
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.55))
                }
                VStack(spacing: 0) {
                    ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                        StageRow(stage: stage, status: status(for: index))
                        if index < stages.count - 1 {
                            connector(active: stageIndex > index)
                        }
                    }
                }
            }
        }
    }

    private var progressLabel: String {
        if isDone { return "5 / 5 단계" }
        if isRunning { return "\(stageIndex + 1) / 5 단계" }
        return "0 / 5 단계"
    }

    private func status(for index: Int) -> StageStatus {
        if stageIndex > index { return .done }
        if stageIndex == index { return .running }
        return .idle
    }

    private func connector(active: Bool) -> some View {
        Rectangle()
            .fill(active ? Color.zoneI.opacity(0.6) : Color.white.opacity(0.10))
            .frame(width: 2, height: 14)
            .padding(.leading, 17)
            .animation(.snappy(duration: 0.25), value: active)
    }

    // MARK: - Completion card

    private var completionCard: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(Color.zoneI.opacity(0.30))
                .frame(width: 180, height: 180)
                .blur(radius: 60)
                .offset(x: 40, y: -50)
                .allowsHitTesting(false)
            GlassCard(strong: true) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.zoneI)
                            .font(.system(size: 20, weight: .semibold))
                        Text("처리 완료")
                            .font(.system(size: 18, weight: .semibold))
                        Spacer()
                        Pill(tone: .green) { Text("자동 지급") }
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(payoutWon.formatted(.number))
                            .font(.display44)
                            .monospacedDigit()
                            .foregroundStyle(.white)
                        Text("원")
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Divider().background(.white.opacity(0.12))
                    HStack(spacing: 0) {
                        FNOLStat(label: "총 처리 시간", value: "8.0", suffix: "초", tint: .zoneI)
                        Spacer()
                        FNOLStat(label: "수동 처리 대비", value: "−98", suffix: "%", tint: .zoneII)
                        Spacer()
                        FNOLStat(label: "면책 항목", value: "없음", suffix: "", tint: .white)
                    }
                    Text("AI 손해사정이 약관 제8조(보장 한도) 및 제25조(신고 의무)에 따라 결정한 자동 지급 금액입니다.")
                        .font(.caption11)
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.top, 2)
                }
            }
        }
    }

    // MARK: - State machine

    private func start() {
        cancel()
        stageIndex = 0
        task = Task { @MainActor in
            for next in 1...stages.count {
                try? await Task.sleep(for: .milliseconds(stageMillis))
                if Task.isCancelled { return }
                withAnimation(.snappy(duration: 0.30)) {
                    stageIndex = next
                }
            }
        }
    }

    private func reset() {
        cancel()
        withAnimation(.snappy(duration: 0.30)) {
            stageIndex = -1
        }
    }

    private func cancel() {
        task?.cancel()
        task = nil
    }
}

// MARK: - Stage model

private struct FNOLStage: Identifiable, Sendable {
    let id: Int
    let title: String
    let detail: String
    let icon: String

    static let all: [FNOLStage] = [
        .init(id: 0, title: "탐지",  detail: "CoreMotion · GPS 충돌 시그널 감지",    icon: "sensor.fill"),
        .init(id: 1, title: "알림",  detail: "보험사 · 응급 연락처 자동 통보",         icon: "bell.badge.fill"),
        .init(id: 2, title: "증거",  detail: "GPS 좌표 · 가속도 · 사고 직전 영상",     icon: "camera.metering.matrix"),
        .init(id: 3, title: "사정",  detail: "AI 손해사정 + 약관 매칭",                icon: "doc.text.magnifyingglass"),
        .init(id: 4, title: "지급",  detail: "본인 계좌 자동 송금",                    icon: "creditcard.fill"),
    ]
}

private enum StageStatus { case idle, running, done }

// MARK: - Stage row

private struct StageRow: View {
    let stage: FNOLStage
    let status: StageStatus

    @State private var running: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            badge
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("\(stage.id + 1). \(stage.title)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(textColor)
                    if status == .running {
                        Pill(tone: .red) {
                            Image(systemName: "waveform")
                                .font(.system(size: 8))
                            Text("진행 중")
                        }
                    }
                    if status == .done {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.zoneI)
                    }
                }
                Text(stage.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.50))
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .opacity(opacityForStatus)
    }

    private var badge: some View {
        ZStack {
            Circle()
                .fill(circleFill)
                .frame(width: 36, height: 36)
            Circle()
                .strokeBorder(circleStroke, lineWidth: 1)
                .frame(width: 36, height: 36)
            if status == .running {
                Circle()
                    .strokeBorder(Color.iosRed.opacity(0.65), lineWidth: 2)
                    .frame(width: 48, height: 48)
                    .scaleEffect(running ? 1.15 : 1.0)
                    .opacity(running ? 0 : 1)
            }
            Image(systemName: stage.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
        }
        .onAppear { running = true }
        .animation(
            status == .running
                ? .easeOut(duration: 1.2).repeatForever(autoreverses: false)
                : .default,
            value: running
        )
    }

    private var circleFill: Color {
        switch status {
        case .idle:    Color.white.opacity(0.05)
        case .running: Color.iosRed.opacity(0.18)
        case .done:    Color.zoneI.opacity(0.18)
        }
    }
    private var circleStroke: Color {
        switch status {
        case .idle:    Color.white.opacity(0.10)
        case .running: Color.iosRed.opacity(0.50)
        case .done:    Color.zoneI.opacity(0.50)
        }
    }
    private var iconColor: Color {
        switch status {
        case .idle:    Color.white.opacity(0.4)
        case .running: Color.iosRed
        case .done:    Color.zoneI
        }
    }
    private var textColor: Color {
        switch status {
        case .idle:    Color.white.opacity(0.55)
        case .running: Color.white
        case .done:    Color.white.opacity(0.85)
        }
    }
    private var opacityForStatus: Double {
        status == .idle ? 0.65 : 1.0
    }
}

// MARK: - Stat cell

private struct FNOLStat: View {
    let label: String
    let value: String
    let suffix: String
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
                if !suffix.isEmpty {
                    Text(suffix)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        FNOLView()
    }
    .environmentObject(AppState())
    .preferredColorScheme(.dark)
}
