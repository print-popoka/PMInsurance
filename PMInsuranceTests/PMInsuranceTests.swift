import Testing
@testable import PMInsurance

// MARK: - 부록 3.4 보험료 계산 검증 케이스 3개

@Suite("Premium calculation — 부록 3.4 검증")
struct PremiumTests {
    @Test("Zone II — pmShare 60%, RS 85점 → 35,438원")
    func zoneII() {
        #expect(calculatePremium(pmShare: 60, rs: 85) == 35_438)
        #expect(classifyZone(pmShare: 60, rs: 85) == .II)
    }

    @Test("Zone IV — pmShare 70%, RS 40점 → 43,313원")
    func zoneIV() {
        #expect(calculatePremium(pmShare: 70, rs: 40) == 43_313)
        #expect(classifyZone(pmShare: 70, rs: 40) == .IV)
    }

    @Test("Zone I — pmShare 15%, RS 90점 → 32,063원")
    func zoneI() {
        #expect(calculatePremium(pmShare: 15, rs: 90) == 32_063)
        #expect(classifyZone(pmShare: 15, rs: 90) == .I)
    }
}

// MARK: - RF/W lookup 함수 검증

@Suite("RF_behavior 5등급 lookup")
struct RFBehaviorTests {
    @Test("RS 85+ → 0.90")          func tier1() { #expect(rfBehavior(rs: 85) == 0.90); #expect(rfBehavior(rs: 100) == 0.90) }
    @Test("RS 70..<85 → 0.97")      func tier2() { #expect(rfBehavior(rs: 70) == 0.97); #expect(rfBehavior(rs: 84) == 0.97) }
    @Test("RS 50..<70 → 1.04")      func tier3() { #expect(rfBehavior(rs: 50) == 1.04); #expect(rfBehavior(rs: 69) == 1.04) }
    @Test("RS 30..<50 → 1.10")      func tier4() { #expect(rfBehavior(rs: 30) == 1.10); #expect(rfBehavior(rs: 49) == 1.10) }
    @Test("RS <30 → 1.13")          func tier5() { #expect(rfBehavior(rs: 29) == 1.13); #expect(rfBehavior(rs: 0)  == 1.13) }
}

@Suite("w_modal 3구간 lookup")
struct WModalTests {
    @Test("PM <30 → 0.95")           func low()  { #expect(wModal(pmShare: 29) == 0.95); #expect(wModal(pmShare: 0)  == 0.95) }
    @Test("PM 30..<60 → 1.00")       func mid()  { #expect(wModal(pmShare: 30) == 1.00); #expect(wModal(pmShare: 59) == 1.00) }
    @Test("PM 60+ → 1.05")           func high() { #expect(wModal(pmShare: 60) == 1.05); #expect(wModal(pmShare: 100) == 1.05) }
}

// MARK: - Zone 4분면 경계 검증

@Suite("Zone 분류 — 경계 (x=30%, y=70)")
struct ZoneTests {
    @Test("경계 정확값") func boundaries() {
        #expect(classifyZone(pmShare: 30, rs: 70) == .II)
        #expect(classifyZone(pmShare: 29, rs: 70) == .I)
        #expect(classifyZone(pmShare: 30, rs: 69) == .IV)
        #expect(classifyZone(pmShare: 29, rs: 69) == .III)
    }

    @Test("Zone 라벨 — 부록 기준") func labels() {
        #expect(Zone.I.label == "대중교통 중심형")
        #expect(Zone.II.label == "안전 PM 헤비유저")
        #expect(Zone.III.label == "저노출 주의형")
        #expect(Zone.IV.label == "고위험 — Sleeping Dogs")
    }
}

// MARK: - Behavior 가중치 합

@Suite("Behavior 5변수 가중치")
struct BehaviorWeightsTests {
    @Test("가중치 합 = 1.00") func sum() {
        #expect(BehaviorWeights.total == 1.00)
    }

    @Test("개별 값 검증") func values() {
        #expect(BehaviorWeights.rapidAccel == 0.30)
        #expect(BehaviorWeights.zigzag == 0.25)
        #expect(BehaviorWeights.sidewalk == 0.25)
        #expect(BehaviorWeights.nightRatio == 0.10)
        #expect(BehaviorWeights.distance == 0.10)
    }

    @Test("RS = 100 - 가중치 합 (모든 변수 0 → RS 100)") func zeroRisk() {
        let rs = computeRS(rapidAccel: 0, zigzag: 0, sidewalk: 0, nightRatio: 0, distance: 0)
        #expect(rs == 100)
    }

    @Test("모든 변수 100 → RS 0") func maxRisk() {
        let rs = computeRS(rapidAccel: 100, zigzag: 100, sidewalk: 100, nightRatio: 100, distance: 100)
        #expect(rs == 0)
    }
}

// MARK: - Grade

@Suite("Grade — A~E 5단계")
struct GradeTests {
    @Test("등급 매핑") func mapping() {
        #expect(grade(rs: 95) == "A")
        #expect(grade(rs: 80) == "B")
        #expect(grade(rs: 60) == "C")
        #expect(grade(rs: 40) == "D")
        #expect(grade(rs: 10) == "E")
    }
}

// MARK: - FAQ 매칭

@Suite("FAQ 매칭 — 12개 항목")
struct FAQTests {
    @Test("12개 항목 로드 확인") func count() {
        #expect(faqEntries.count == 12)
    }

    @Test("음주 키워드 매칭") func drink() {
        let r = matchFAQ(query: "음주 운전 시 어떻게 되나요?")
        #expect(r?.article == "제15조")
    }

    @Test("매칭 실패 시 nil") func nilOnNoMatch() {
        let r = matchFAQ(query: "오늘 날씨 어때")
        #expect(r == nil)
    }
}
