import Foundation

struct FAQEntry: Identifiable, Sendable {
    let id = UUID()
    let keywords: [String]
    let article: String
    let answer: String
}

let faqEntries: [FAQEntry] = [
    .init(keywords: ["음주", "술", "음주운전"], article: "제15조",
          answer: "약관 제15조에 따르면 음주 운전 중 사고는 면책 사유로 보험금 지급이 제한됩니다."),
    .init(keywords: ["보험금", "한도", "얼마"], article: "제8조",
          answer: "약관 제8조에 따르면 대인 1억원, 대물 5천만원이 기본 보장입니다."),
    .init(keywords: ["헬멧", "안전모", "미착용"], article: "제12조",
          answer: "약관 제12조에 따르면 안전모 미착용 사고는 본인 부담률 30%가 적용됩니다."),
    .init(keywords: ["인도", "보도", "보행자도로"], article: "제18조",
          answer: "약관 제18조에 따르면 인도 주행 중 사고는 면책 사유에 해당합니다."),
    .init(keywords: ["2인", "동승", "탑승"], article: "제20조",
          answer: "약관 제20조에 따르면 PM 2인 탑승 시 보장이 제한됩니다."),
    .init(keywords: ["야간", "밤", "심야"], article: "제14조",
          answer: "약관 제14조에 따르면 야간 운행은 위험 가중치가 적용되어 할증될 수 있습니다."),
    .init(keywords: ["청소년", "미성년", "고등학생"], article: "제22조",
          answer: "약관 제22조에 따르면 청소년 운행은 보호자 동의가 필요합니다."),
    .init(keywords: ["보행자", "사람", "행인"], article: "제9조",
          answer: "약관 제9조에 따르면 보행자 사고는 대인 보장이 우선 적용됩니다."),
    .init(keywords: ["신고", "사고접수", "절차"], article: "제25조",
          answer: "약관 제25조에 따르면 사고 발생 후 24시간 내 신고가 의무입니다."),
    .init(keywords: ["면책", "보장안됨"], article: "제15~20조",
          answer: "약관 제15~20조에 면책 사유가 종합 명시되어 있습니다 — 음주·인도·2인 탑승 등."),
    .init(keywords: ["환급", "환불", "해지"], article: "제30조",
          answer: "약관 제30조에 따르면 미사용 기간에 대한 환급이 가능합니다."),
    .init(keywords: ["변경", "약관변경", "고지"], article: "제35조",
          answer: "약관 제35조에 따르면 약관 변경 시 사전 고지 의무가 있습니다."),
]

let faqFallback = "약관에 명시되지 않았습니다. 보험사 고객센터(1588-XXXX)로 문의 바랍니다."

func matchFAQ(query: String) -> FAQEntry? {
    let q = query.lowercased()
    return faqEntries.first { entry in
        entry.keywords.contains { q.contains($0.lowercased()) }
    }
}

/// MobiBench multi-path — a single query may span multiple clauses, return all matches.
func matchFAQAll(query: String) -> [FAQEntry] {
    let q = query.lowercased()
    return faqEntries.filter { entry in
        entry.keywords.contains { q.contains($0.lowercased()) }
    }
}
