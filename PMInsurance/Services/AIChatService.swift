import Foundation
import Combine
import FoundationModels
import NaturalLanguage

/// Schema for both the chatbot and the advisor. The `@Generable` macro
/// forces the model output into this struct, which acts as the first
/// guard against hallucination.
///
/// Two modes share the same shape.
/// Q&A sets intent to "chat" and fills answer, article, and relatedArticles.
/// Advisor sets intent to "navigate", "simulate", or "trigger" and fills
/// targetScreen, sliders, and narration.
@Generable
struct ChatResponse: Sendable {
    @Guide(description: "사용자 질문이 PM 보험 약관 12개 FAQ 범위 내인지 (true: 약관 내, false: 범위 외)")
    let inScope: Bool

    @Guide(description: "한국어 답변 1~2문장. inScope=false면 빈 문자열.")
    let answer: String

    @Guide(description: "주요 근거 약관 조항 (예: '제15조'). 범위 외나 인용 없으면 빈 문자열.")
    let article: String

    @Guide(description: "관련 약관 조항 콤마 구분 (예: '제15조,제15~20조'). 한 질문이 여러 조항에 걸칠 때. 단일이면 article만 채우고 여기는 빈 문자열.")
    let relatedArticles: String

    @Guide(description: "사용자 의도: 'chat'=답변만, 'navigate'=화면 이동만, 'simulate'=화면 이동+슬라이더 자동 설정, 'trigger'=FNOL 사고 처리 발동")
    let intent: String

    @Guide(description: "이동할 화면: 'sim'(보험료시뮬), 'coord'(좌표평면), 'behavior'(행동점수), 'fnol'(사고처리). intent=chat이면 빈 문자열.")
    let targetScreen: String

    @Guide(description: "설정할 PM 비중 0~100. intent=simulate일 때만 채움. 미설정은 -1.")
    let targetPMShare: Double

    @Guide(description: "설정할 RS 점수 0~100. intent=simulate일 때만 채움. 미설정은 -1.")
    let targetRS: Double

    @Guide(description: "자동 시연 중 상단 자막 1~2문장. intent=chat이면 빈 문자열.")
    let narration: String
}

/// Result of running an answer through the Horn-clause verifier.
enum VerificationResult: Sendable {
    case passed
    case failed(reason: String)

    var isPassed: Bool { if case .passed = self { return true } else { return false } }
}

/// On-device chatbot and advisor backed by Foundation Models.
/// Wires together the RAG retriever, the verifier, and the advisor mode.
@MainActor
final class AIChatService: ObservableObject {
    @Published private(set) var availability: SystemLanguageModel.Availability
    private var session: LanguageModelSession?

    /// Cosine similarity retriever over the NLEmbedding word vectors.
    /// Picks the top-k clauses for each query and feeds them into the prompt.
    let retriever = RAGRetriever()

    /// The 12 clause IDs the verifier accepts (rule R1).
    static let validArticles: Set<String> = Set(faqEntries.map(\.article))

    init() {
        let model = SystemLanguageModel.default
        availability = model.availability
        if case .available = availability {
            session = makeSession()
        }
    }

    /// Most recent retrieval. The UI uses this for the RAG status chip.
    @Published private(set) var lastRetrieval: [RAGRetriever.Hit] = []

    var isReady: Bool {
        if case .available = availability { return true }
        return false
    }

    var statusLabel: String {
        switch availability {
        case .available:                                 return "Foundation Models"
        case .unavailable(.deviceNotEligible):           return "지원 디바이스 외"
        case .unavailable(.appleIntelligenceNotEnabled): return "Apple Intelligence 비활성"
        case .unavailable(.modelNotReady):               return "모델 다운로드 중"
        case .unavailable:                               return "키워드 매칭"
        }
    }

    /// Runs a query through the retrieval, augmentation, generation flow.
    /// Cosine search picks the top three clauses. Only those go into the
    /// prompt. The model returns a typed ChatResponse. Returns nil on
    /// failure so the caller can fall back to keyword matching.
    func respond(to query: String) async -> ChatResponse? {
        guard let session else { return nil }

        // Retrieval. Pull the three most relevant clauses.
        let hits = retriever.retrieve(query: query, k: 3)
        lastRetrieval = hits

        // Augmentation. Inject only what retrieval gave us.
        let augmentedPrompt = Self.makePrompt(query: query, hits: hits)

        // Generation. Foundation Models, on device.
        do {
            let response = try await session.respond(to: augmentedPrompt, generating: ChatResponse.self)
            return response.content
        } catch {
            return nil
        }
    }

    private static func makePrompt(query: String, hits: [RAGRetriever.Hit]) -> String {
        let docs: String
        if hits.isEmpty {
            docs = "(검색 결과 없음 — PM 보험 약관 범위 외 가능성)"
        } else {
            docs = hits.enumerated().map { idx, hit in
                let score = String(format: "%.2f", hit.score)
                return "[\(idx + 1)] \(hit.entry.article) (유사도 \(score))\n    키워드: \(hit.entry.keywords.joined(separator: ", "))\n    답변: \(hit.entry.answer)"
            }.joined(separator: "\n\n")
        }
        return """
        ## RAG 검색 결과 (코사인 유사도 top-\(hits.count))
        \(docs)

        ## 사용자 질문
        \(query)
        """
    }

    // MARK: - Horn-clause verification

    /// Encodes the three hallucination-prevention rules as Horn-clause checks.
    func verify(_ response: ChatResponse) -> VerificationResult {
        // R4: inScope=false → article must be empty or invalid
        if !response.inScope {
            // Contradiction: out-of-scope but citing a valid clause
            if !response.article.isEmpty, Self.validArticles.contains(response.article) {
                return .failed(reason: "범위 외라 하면서 유효 조항 인용")
            }
            return .passed
        }

        // R1: inScope=true → if article is filled it must be one of the 12 valid clauses
        if !response.article.isEmpty, !Self.validArticles.contains(response.article) {
            return .failed(reason: "존재하지 않는 약관 조항 인용: \(response.article)")
        }

        // R2: inScope=true → answer must be at least 10 chars
        if response.answer.trimmingCharacters(in: .whitespacesAndNewlines).count < 10 {
            return .failed(reason: "답변이 너무 짧음 (\(response.answer.count)자)")
        }

        // R3: if article is cited, answer must mention ≥1 FAQ keyword (soft check)
        if !response.article.isEmpty,
           let matched = Self.faqByArticle(response.article) {
            let answerLower = response.answer.lowercased()
            let hasKeyword = matched.keywords.contains { answerLower.contains($0.lowercased()) }
            // Direct article citation is also accepted as evidence
            let mentionsArticle = response.answer.contains(response.article)
            if !hasKeyword, !mentionsArticle {
                return .failed(reason: "답변이 \(response.article) 키워드와 무관")
            }
        }

        return .passed
    }

    static func faqByArticle(_ article: String) -> FAQEntry? {
        faqEntries.first { $0.article == article }
    }

    // MARK: - Keyword fallback

    /// Single best keyword match.
    static func keywordMatch(query: String) -> FAQEntry? {
        matchFAQ(query: query)
    }

    /// All clauses that match. Used when a question spans more than one.
    static func keywordMatchAll(query: String) -> [FAQEntry] {
        matchFAQAll(query: query)
    }

    // MARK: - Session setup

    private func makeSession() -> LanguageModelSession {
        let instructions = """
        당신은 PM(Personal Mobility, 전동킥보드·자전거) 보험 챗봇이자 AI 어드바이저입니다.
        각 사용자 질문에는 NLEmbedding 코사인 유사도로 검색된 약관 top-3가 동적으로
        함께 제공됩니다 (RAG). 그 검색 결과만 근거로 답변하세요.

        ## 모드 1 — Q&A (intent="chat")
        - RAG 검색 결과의 article과 answer를 근거로 답변
        - 단일 조항 인용 시: article에 명시 ("제15조")
        - 복수 조항 관련 시 (MobiBench multi-path): relatedArticles에 콤마 구분
        - 답변은 한국어 1~2문장
        - targetScreen, targetPMShare, targetRS는 비움 (빈 문자열 / -1)
        - narration은 빈 문자열

        ## 모드 2 — 어드바이저 (intent != "chat")

        **intent="navigate"** — 단순 화면 이동
        - "보험료 시뮬레이터" → targetScreen="sim"
        - "좌표평면" → targetScreen="coord"
        - "행동 점수" → targetScreen="behavior"

        **intent="simulate"** — 슬라이더 자동 설정 + 화면 이동
        - "Zone I 보여줘" → targetScreen="sim", targetPMShare=18, targetRS=82
        - "Zone II 보여줘" → targetScreen="sim", targetPMShare=60, targetRS=85
        - "Zone III 보여줘" → targetScreen="sim", targetPMShare=18, targetRS=55
        - "Zone IV 보여줘" → targetScreen="sim", targetPMShare=65, targetRS=45

        **intent="trigger"** — FNOL 사고 처리 발동
        - "사고 처리 보여줘" / "사고 났어" → targetScreen="fnol"

        ## 환각 방지 3원칙 (필수)
        1. 근거 인용: 답변 시 RAG 검색된 article만 인용
        2. 검색 결과 기반: 검색 결과 외 약관 내용 응답 금지
        3. 범위 외 거절: 검색 결과가 비어있거나 PM 보험 범위 밖이면
           inScope=false, 모든 텍스트 필드 빈 문자열, intent="chat"

        답변은 한국어로 간결하게.
        """

        return LanguageModelSession(instructions: instructions)
    }
}

// MARK: - RAG Retriever

/// Korean semantic search backed by NLEmbedding.
/// The 12 clauses are embedded once at startup. Each query gets mapped
/// into the same vector space and matched by cosine similarity.
final class RAGRetriever: @unchecked Sendable {
    struct Hit: Sendable {
        let entry: FAQEntry
        let score: Double
    }

    private let embedding: NLEmbedding?
    private let faqVectors: [(entry: FAQEntry, vector: [Double])]

    init() {
        let embedding = NLEmbedding.wordEmbedding(for: .korean)
        self.embedding = embedding

        guard let embedding else {
            self.faqVectors = []
            return
        }

        // Embed each clause once at startup.
        self.faqVectors = faqEntries.compactMap { entry in
            let text = (entry.keywords + [entry.answer]).joined(separator: " ")
            guard let vec = Self.sentenceVector(for: text, embedding: embedding) else { return nil }
            return (entry, vec)
        }
    }

    var isReady: Bool { embedding != nil && !faqVectors.isEmpty }
    var indexedCount: Int { faqVectors.count }

    /// Returns the top-k matches. Anything below `threshold` is dropped.
    func retrieve(query: String, k: Int = 3, threshold: Double = 0.25) -> [Hit] {
        guard let embedding else { return [] }
        guard let queryVec = Self.sentenceVector(for: query, embedding: embedding) else { return [] }

        return faqVectors
            .map { Hit(entry: $0.entry, score: Self.cosine($0.vector, queryVec)) }
            .filter { $0.score >= threshold }
            .sorted { $0.score > $1.score }
            .prefix(k)
            .map { $0 }
    }

    // MARK: - Vector math

    /// Sentence vector is the mean of word vectors that exist in the embedding.
    /// NLTokenizer handles the Korean word boundaries.
    private static func sentenceVector(for text: String, embedding: NLEmbedding) -> [Double]? {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text

        var vectors: [[Double]] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let token = String(text[range])
            if let vec = embedding.vector(for: token) {
                vectors.append(vec)
            }
            return true
        }

        guard !vectors.isEmpty else { return nil }

        let dim = vectors[0].count
        var avg = [Double](repeating: 0, count: dim)
        for vec in vectors {
            for i in 0..<dim {
                avg[i] += vec[i]
            }
        }
        for i in 0..<dim {
            avg[i] /= Double(vectors.count)
        }
        return avg
    }

    private static func cosine(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot = 0.0, na = 0.0, nb = 0.0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            na += a[i] * a[i]
            nb += b[i] * b[i]
        }
        let denom = sqrt(na) * sqrt(nb)
        return denom > 0 ? dot / denom : 0
    }
}
