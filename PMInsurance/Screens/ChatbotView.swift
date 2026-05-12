import SwiftUI

struct ChatbotView: View {
    @EnvironmentObject private var state: AppState
    @State private var messages: [ChatMessage] = [
        .bot("안녕하세요. PM 약관 챗봇이자 AI 어드바이저입니다. 약관 질문에도 답하고, \"Zone IV 보여줘\" 같은 명령으로 자동 시뮬레이션도 해드려요.")
    ]
    @State private var input: String = ""
    @State private var isTyping: Bool = false
    @FocusState private var inputFocused: Bool
    @StateObject private var ai = AIChatService()
    @StateObject private var speech = SpeechRecognizer()
    @StateObject private var memory = ChatMemory()
    @State private var lastVerificationPassed: Bool = true

    private let suggested: [String] = [
        "사고 났어!",
        "Zone IV 보여줘",
        "보험료 어떻게 줄여?",
        "음주 운전은 보장되나요?",
        "Zone II 사례",
        "헬멧 안 썼을 때",
    ]

    var body: some View {
        ZStack {
            NavyBackground(soft: true)
            VStack(spacing: 0) {
                principlesBar
                conversation
                suggestionsBar
                inputBar
            }
        }
        .navigationTitle("약관 챗봇")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let pending = state.pendingChatQuery {
                state.acknowledgeChatQuery()
                Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    await MainActor.run { send(pending) }
                }
            }
        }
    }

    // MARK: - Status bar (Foundation Models + RAG retrieval + verification / memory)

    private var principlesBar: some View {
        HStack(spacing: 6) {
            PrinciplePill(
                icon: ai.isReady ? "cpu" : "text.magnifyingglass",
                text: ai.statusLabel,
                tone: ai.isReady ? .blue : .white
            )
            if ai.retriever.isReady {
                PrinciplePill(
                    icon: "magnifyingglass",
                    text: ai.lastRetrieval.isEmpty
                        ? "RAG · 약관 \(ai.retriever.indexedCount)건 인덱스"
                        : "RAG · top-\(ai.lastRetrieval.count) 검색됨",
                    tone: .green
                )
            }
            if !lastVerificationPassed {
                PrinciplePill(icon: "exclamationmark.shield.fill", text: "검증 실패 → 매칭", tone: .amber)
            }
            if memory.totalEntries > 0 {
                PrinciplePill(icon: "brain", text: "메모리 \(memory.totalEntries)건", tone: .blue)
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    // MARK: - Conversation

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(messages) { msg in
                        MessageBubble(
                            message: msg,
                            onPositiveFeedback: { /* 강화 신호 — 별도 처리 안 함 */ },
                            onNegativeFeedback: { handleNegativeFeedback(for: msg) }
                        )
                        .id(msg.id)
                    }
                    if isTyping {
                        TypingIndicator()
                            .id("typing")
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.md)
            }
            .onChange(of: messages.count) { _, _ in scrollToBottom(proxy: proxy) }
            .onChange(of: isTyping) { _, _ in scrollToBottom(proxy: proxy) }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.snappy(duration: 0.25)) {
            if isTyping {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let last = messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    // MARK: - Suggestions

    private var suggestionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggested, id: \.self) { q in
                    Button { send(q) } label: {
                        Text(q)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(.white.opacity(0.08)))
                            .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.xl)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: 6) {
            if speech.isRecording {
                recordingIndicator
            }
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: speech.isRecording ? "waveform" : "text.bubble")
                        .foregroundStyle(speech.isRecording ? .iosRed : .white.opacity(0.4))
                        .font(.system(size: 14))
                    TextField(
                        "",
                        text: $input,
                        prompt: Text(speech.isRecording ? "듣는 중..." : "질문하거나 명령하세요")
                            .foregroundStyle(.white.opacity(0.4)),
                        axis: .vertical
                    )
                    .focused($inputFocused)
                    .tint(.iosBlue)
                    .foregroundStyle(.white)
                    .font(.system(size: 15))
                    .lineLimit(1...3)
                    .submitLabel(.send)
                    .onSubmit { send(input) }
                    .disabled(speech.isRecording)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 1))

                if speech.isAvailable {
                    Button { toggleMic() } label: {
                        Image(systemName: speech.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(speech.isRecording ? Color.iosRed : Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .disabled(isTyping)
                    .animation(.snappy(duration: 0.15), value: speech.isRecording)
                }

                Button { send(input) } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(canSend ? Color.iosBlue : Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .animation(.snappy(duration: 0.15), value: canSend)
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, 10)
        .background(.black.opacity(0.20))
        .onChange(of: speech.transcript) { _, newValue in
            if speech.isRecording { input = newValue }
        }
        .onChange(of: speech.isRecording) { wasRecording, isNow in
            if wasRecording, !isNow,
               !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                send(input)
            }
        }
    }

    @State private var recordingPulse: Bool = false
    private var recordingIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.iosRed)
                .frame(width: 8, height: 8)
                .opacity(recordingPulse ? 1 : 0.35)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: recordingPulse)
            Text("음성 인식 중 — 멈추려면 ◾ 버튼을 누르세요")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.iosRed)
            Spacer()
        }
        .padding(.horizontal, 4)
        .onAppear { recordingPulse = true }
    }

    private func toggleMic() {
        if speech.isRecording { speech.stop() }
        else { Task { await speech.start() } }
    }

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTyping
    }

    // MARK: - Send / route (memory → LLM → verify → fallback)

    private func send(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isTyping else { return }

        withAnimation(.snappy(duration: 0.2)) {
            messages.append(.user(text))
            input = ""
        }

        // 0) Advisor commands — bypass LLM intent classification and dispatch directly.
        //    Korean commands like "Zone IV 보여줘" / "사고 났어" are frequently misclassified
        //    as plain chat by the model. Pattern-match first to guarantee demo stability.
        if let cmd = matchAdvisorCommand(text) {
            Task {
                try? await Task.sleep(for: .milliseconds(280))
                await MainActor.run {
                    withAnimation(.snappy(duration: 0.25)) {
                        messages.append(.bot(cmd.narration, source: .llm))
                        lastVerificationPassed = true
                    }
                }
                await runAdvisor(cmd)
            }
            return
        }

        Task {
            // 1) Memory lookup (MobileGPT cache) — instant reply on cache hit
            if let cached = memory.lookup(query: text) {
                try? await Task.sleep(for: .milliseconds(180))
                await MainActor.run {
                    withAnimation(.snappy(duration: 0.25)) {
                        appendBotResponse(query: text, response: cached.response, source: .memory)
                        lastVerificationPassed = true
                    }
                }
                return
            }

            // 2) LLM call
            await MainActor.run {
                withAnimation(.snappy(duration: 0.2)) { isTyping = true }
            }

            if ai.isReady, let response = await ai.respond(to: text) {
                // 3) VeriSafe verification
                let verification = ai.verify(response)
                try? await Task.sleep(for: .milliseconds(400))
                await MainActor.run {
                    withAnimation(.snappy(duration: 0.25)) {
                        isTyping = false
                        if verification.isPassed {
                            memory.remember(query: text, response: response)
                            appendBotResponse(query: text, response: response, source: .llm)
                            lastVerificationPassed = true
                        } else {
                            // Verification failed → keyword-match fallback
                            appendKeywordFallback(query: text)
                            lastVerificationPassed = false
                        }
                    }
                }
                return
            }

            // 4) LLM unavailable → keyword-match fallback
            try? await Task.sleep(for: .milliseconds(400))
            await MainActor.run {
                withAnimation(.snappy(duration: 0.25)) {
                    isTyping = false
                    appendKeywordFallback(query: text)
                    lastVerificationPassed = true   // verifier disabled (LLM not invoked)
                }
            }
        }
    }

    private func appendBotResponse(query: String, response: ChatResponse, source: ChatMessage.Source) {
        if response.inScope, !response.answer.isEmpty {
            let related = parseRelated(response.relatedArticles)
            messages.append(.bot(
                response.answer,
                article: response.article.isEmpty ? nil : response.article,
                relatedArticles: related,
                source: source
            ))
            dispatchAdvisorAction(response)
        } else if response.intent != "chat", !response.intent.isEmpty, !response.targetScreen.isEmpty {
            // Advisor-only case — empty Q&A answer but a target action exists (e.g. "Zone IV 보여줘")
            messages.append(.bot(
                response.narration.isEmpty ? "시연을 시작합니다." : response.narration,
                article: nil,
                relatedArticles: [],
                source: source
            ))
            dispatchAdvisorAction(response)
        } else {
            messages.append(.bot(faqFallback, outOfScope: true, source: source))
        }
    }

    private func appendKeywordFallback(query: String) {
        let matches = AIChatService.keywordMatchAll(query: query)
        if let primary = matches.first {
            let related = matches.dropFirst().map(\.article)
            messages.append(.bot(
                primary.answer,
                article: primary.article,
                relatedArticles: Array(related),
                source: .keyword
            ))
        } else {
            messages.append(.bot(faqFallback, outOfScope: true, source: .fallback))
        }
    }

    private func parseRelated(_ s: String) -> [String] {
        s.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Advisor dispatch (Plan X')

    private func dispatchAdvisorAction(_ response: ChatResponse) {
        let intent = response.intent
        guard intent != "chat", !intent.isEmpty,
              let screen = parseScreen(response.targetScreen) else { return }

        Task {
            state.startAdvisorMode()
            try? await Task.sleep(for: .milliseconds(700))

            // Subtitle first
            if !response.narration.isEmpty {
                await MainActor.run {
                    state.showNarration(response.narration, duration: 4.5)
                }
            }

            // Auto-adjust sliders in the background
            if intent == "simulate" {
                let pm = response.targetPMShare
                let rs = response.targetRS
                await MainActor.run {
                    state.setSliders(
                        pmShare: pm >= 0 ? pm : nil,
                        rs: rs >= 0 ? rs : nil
                    )
                }
            }

            try? await Task.sleep(for: .milliseconds(300))

            // Navigate
            await MainActor.run {
                state.navigate(to: screen)
                if intent == "trigger" {
                    state.requestFNOLStart()
                }
            }

            // Exit advisor mode (subtitle hides via its own timer)
            try? await Task.sleep(for: .seconds(5))
            await MainActor.run {
                state.stopAdvisorMode()
            }
        }
    }

    // MARK: - Advisor pattern matching (instant dispatch, bypasses LLM)

    private func matchAdvisorCommand(_ text: String) -> AdvisorCommand? {
        let normalized = text.lowercased().replacingOccurrences(of: " ", with: "")

        // Zone simulation — preset sliders + navigate
        let zone: Zone? = {
            if normalized.contains("zone4") || normalized.contains("zoneiv") { return .IV }
            if normalized.contains("zone3") || normalized.contains("zoneiii") { return .III }
            if normalized.contains("zone2") || normalized.contains("zoneii") { return .II }
            if normalized.contains("zone1") || normalized.contains("zonei") { return .I }
            return nil
        }()
        if let zone {
            return AdvisorCommand(intent: .simulate, screen: .sim, zone: zone, narration: zoneNarration(zone))
        }

        // FNOL claim trigger — match a broad set of natural-language phrasings
        if normalized.contains("fnol")
            || normalized.contains("사고처리")
            || normalized.contains("사고나")        // "사고 났어", "사고 나면"
            || normalized.contains("사고가")        // "사고가 났어요"
            || normalized.contains("사고발생")
            || normalized.contains("사고접수")
            || normalized.contains("자동처리")
            || normalized.contains("충돌")
            || normalized.contains("부딪")          // "부딪쳤어"
            || normalized.contains("넘어졌")
            || normalized.contains("다쳤")
            || normalized.contains("보험금청구")
            || normalized.contains("클레임")
            || normalized.contains("보상신청") {
            return AdvisorCommand(
                intent: .trigger, screen: .fnol, zone: nil,
                narration: "사고 신고 접수 — 자동 처리를 시작합니다"
            )
        }

        // Navigation
        if normalized.contains("보험료")
            && (normalized.contains("시뮬") || normalized.contains("계산") || normalized.contains("어떻게") || normalized.contains("줄")) {
            return AdvisorCommand(
                intent: .navigate, screen: .sim, zone: nil,
                narration: "보험료 시뮬레이터로 이동합니다."
            )
        }
        if normalized.contains("좌표") || normalized.contains("4분면") || normalized.contains("사분면") {
            return AdvisorCommand(
                intent: .navigate, screen: .coord, zone: nil,
                narration: "좌표 평면으로 이동합니다."
            )
        }
        if normalized.contains("행동점수")
            || normalized.contains("행동스코어")
            || (normalized.contains("행동") && normalized.contains("점수")) {
            return AdvisorCommand(
                intent: .navigate, screen: .behavior, zone: nil,
                narration: "행동 점수 화면으로 이동합니다."
            )
        }

        return nil
    }

    private func zoneNarration(_ zone: Zone) -> String {
        switch zone {
        case .I:   return "Zone I — 대중교통 중심형, 안전한 저빈도 사용자"
        case .II:  return "Zone II — 안전 PM 헤비유저, 락인 핵심 고객"
        case .III: return "Zone III — 잠재 개선 그룹"
        case .IV:  return "Zone IV — Sleeping Dogs, 최대 15% 할증 대상"
        }
    }

    private func runAdvisor(_ cmd: AdvisorCommand) async {
        state.startAdvisorMode()
        try? await Task.sleep(for: .milliseconds(500))

        state.showNarration(cmd.narration, duration: 4.5)

        if cmd.intent == .simulate, let zone = cmd.zone {
            state.applyZonePreset(zone)
        }

        try? await Task.sleep(for: .milliseconds(300))
        state.navigate(to: cmd.screen)
        if cmd.intent == .trigger {
            state.requestFNOLStart()
        }

        try? await Task.sleep(for: .seconds(5))
        state.stopAdvisorMode()
    }

    private func parseScreen(_ s: String) -> AppScreen? {
        switch s.lowercased() {
        case "sim":      return .sim
        case "coord":    return .coord
        case "behavior": return .behavior
        case "fnol":     return .fnol
        case "chat":     return .chat
        default:         return nil
        }
    }

    // MARK: - HITL feedback

    private func handleNegativeFeedback(for msg: ChatMessage) {
        // Find the most recent user query and remove it from memory
        guard let botIndex = messages.firstIndex(where: { $0.id == msg.id }),
              botIndex > 0 else { return }
        let userQuery = messages[botIndex - 1].text
        memory.forget(query: userQuery)

        withAnimation(.snappy(duration: 0.2)) {
            messages.append(.bot(
                "피드백 반영했습니다. 다음에 같은 질문을 하시면 모델에서 새로 답변하겠습니다.",
                source: .fallback
            ))
        }
    }
}

// MARK: - Advisor command (for pre-LLM pattern matching)

private enum AdvisorIntent: Sendable { case navigate, simulate, trigger }

private struct AdvisorCommand: Sendable {
    let intent: AdvisorIntent
    let screen: AppScreen
    let zone: Zone?
    let narration: String
}

// MARK: - Message model

private struct ChatMessage: Identifiable, Sendable {
    let id = UUID()
    let role: Role
    let text: String
    let article: String?
    let relatedArticles: [String]
    let outOfScope: Bool
    let source: Source

    enum Role: Sendable { case user, bot }
    enum Source: Sendable {
        case user, memory, llm, keyword, fallback

        var sourceLabel: String {
            switch self {
            case .memory:  return "🧠 메모리 (0ms)"
            case .llm:     return "✨ Foundation Models"
            case .keyword: return "🔍 키워드 매칭"
            default:       return ""
            }
        }

        var sourceColor: Color {
            switch self {
            case .memory:  return Color(hex: "60A5FA")
            case .llm:     return Color(hex: "A78BFA")
            case .keyword: return Color(hex: "FBBF24")
            default:       return .white.opacity(0.4)
            }
        }

        var showsHITL: Bool {
            // Show HITL buttons only for answers where user feedback is valuable
            self == .memory || self == .llm
        }
    }

    static func user(_ text: String) -> ChatMessage {
        ChatMessage(role: .user, text: text, article: nil, relatedArticles: [], outOfScope: false, source: .user)
    }
    static func bot(_ text: String, article: String? = nil, relatedArticles: [String] = [], outOfScope: Bool = false, source: Source = .llm) -> ChatMessage {
        ChatMessage(role: .bot, text: text, article: article, relatedArticles: relatedArticles, outOfScope: outOfScope, source: source)
    }
}

// MARK: - Bubble

private struct MessageBubble: View {
    let message: ChatMessage
    var onPositiveFeedback: () -> Void = {}
    var onNegativeFeedback: () -> Void = {}

    @State private var feedbackGiven: Feedback? = nil
    enum Feedback { case positive, negative }

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isUser {
                Spacer(minLength: 40)
            } else {
                BotAvatar()
            }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                bubbleBody
                metaRow
            }
            if !isUser {
                Spacer(minLength: 40)
            }
        }
    }

    private var bubbleBody: some View {
        Text(message.text)
            .font(.system(size: 15))
            .foregroundStyle(isUser ? .white : .white.opacity(0.92))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bubbleShape.fill(bubbleFill))
            .overlay(bubbleShape.strokeBorder(.white.opacity(message.outOfScope ? 0.18 : 0.08), lineWidth: 1))
            .frame(maxWidth: 280, alignment: isUser ? .trailing : .leading)
    }

    @ViewBuilder
    private var metaRow: some View {
        if !isUser {
            VStack(alignment: .leading, spacing: 4) {
                articleRow
                if !message.source.sourceLabel.isEmpty {
                    HStack(spacing: 8) {
                        Text(message.source.sourceLabel)
                            .font(.system(size: 10))
                            .foregroundStyle(message.source.sourceColor)
                        Spacer()
                        if message.source.showsHITL {
                            feedbackButtons
                        }
                    }
                    .padding(.leading, 4)
                    .frame(maxWidth: 280, alignment: .leading)
                }
            }
        }
    }

    @ViewBuilder
    private var articleRow: some View {
        if let article = message.article {
            HStack(spacing: 5) {
                citationBox(article: article, primary: true)
                ForEach(message.relatedArticles, id: \.self) { related in
                    citationBox(article: related, primary: false)
                }
            }
            .padding(.leading, 4)
        }
    }

    private var feedbackButtons: some View {
        HStack(spacing: 4) {
            Button {
                feedbackGiven = .positive
                onPositiveFeedback()
            } label: {
                Image(systemName: feedbackGiven == .positive ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(feedbackGiven == .positive ? Color(hex: "6EE7B7") : .white.opacity(0.5))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(.white.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .disabled(feedbackGiven != nil)

            Button {
                feedbackGiven = .negative
                onNegativeFeedback()
            } label: {
                Image(systemName: feedbackGiven == .negative ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(feedbackGiven == .negative ? Color.iosRed : .white.opacity(0.5))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(.white.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .disabled(feedbackGiven != nil)
        }
    }

    private var bubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading:     18,
                bottomLeading:  isUser ? 18 : 4,
                bottomTrailing: isUser ? 4 : 18,
                topTrailing:    18
            ),
            style: .continuous
        )
    }

    private var bubbleFill: AnyShapeStyle {
        if isUser {
            return AnyShapeStyle(LinearGradient(colors: [.iosBlue, Color(hex: "2563EB")], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        if message.outOfScope {
            return AnyShapeStyle(Color(hex: "FBBF24").opacity(0.10))
        }
        return AnyShapeStyle(Color.white.opacity(0.08))
    }

    private func citationBox(article: String, primary: Bool) -> some View {
        let color = primary ? Color(hex: "6EE7B7") : Color(hex: "60A5FA")
        return HStack(spacing: 4) {
            if primary {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 9))
            }
            Text(primary ? "근거: 약관 \(article)" : "관련: \(article)")
                .font(.system(size: primary ? 11 : 10, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(color)
        .padding(.horizontal, primary ? 8 : 7)
        .padding(.vertical, primary ? 4 : 3)
        .background(Capsule().fill(color.opacity(0.12)))
        .overlay(Capsule().strokeBorder(color.opacity(0.35), lineWidth: 1))
    }
}

// MARK: - Bot avatar + typing indicator

private struct BotAvatar: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.iosBlue, .bgNavyDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 28, height: 28)
        .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 1))
    }
}

private struct TypingIndicator: View {
    @State private var pulse: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            BotAvatar()
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(.white.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .opacity(pulse ? 1 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                            value: pulse
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: 18, bottomLeading: 4, bottomTrailing: 18, topTrailing: 18),
                    style: .continuous
                )
                .fill(.white.opacity(0.06))
            )
            Spacer(minLength: 40)
        }
        .onAppear { pulse = true }
        .transition(.opacity)
    }
}

// MARK: - Principle pill

private struct PrinciplePill: View {
    let icon: String
    let text: String
    let tone: PillTone

    var body: some View {
        Pill(tone: tone) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
        }
    }
}

#Preview {
    NavigationStack {
        ChatbotView()
    }
    .environmentObject(AppState())
    .preferredColorScheme(.dark)
}
