import Foundation

enum BehaviorWeights {
    static let rapidAccel: Double = 0.30
    static let zigzag:     Double = 0.25
    static let sidewalk:   Double = 0.25
    static let nightRatio: Double = 0.10
    static let distance:   Double = 0.10

    static var total: Double { rapidAccel + zigzag + sidewalk + nightRatio + distance }
}

func weightedRiskSum(rapidAccel: Double, zigzag: Double, sidewalk: Double, nightRatio: Double, distance: Double) -> Double {
    BehaviorWeights.rapidAccel * rapidAccel
        + BehaviorWeights.zigzag     * zigzag
        + BehaviorWeights.sidewalk   * sidewalk
        + BehaviorWeights.nightRatio * nightRatio
        + BehaviorWeights.distance   * distance
}

func computeRS(rapidAccel: Double, zigzag: Double, sidewalk: Double, nightRatio: Double, distance: Double) -> Double {
    let sum = weightedRiskSum(rapidAccel: rapidAccel, zigzag: zigzag, sidewalk: sidewalk, nightRatio: nightRatio, distance: distance)
    return max(0, min(100, 100 - sum))
}

struct BehaviorVariable: Identifiable, Sendable {
    let id: String
    let name: String
    let weight: Double
    let icon: String
    let colorHex: String
    let rationale: String
}

let behaviorVariables: [BehaviorVariable] = [
    .init(id: "accel",    name: "급가속 · 급감속", weight: BehaviorWeights.rapidAccel, icon: "gauge.with.dots.needle.67percent", colorHex: "FF4B5C",
          rationale: "TAAS 안전운전 의무 불이행 56% 직결"),
    .init(id: "swerve",   name: "갈지자 주행",     weight: BehaviorWeights.zigzag,     icon: "arrow.triangle.branch",            colorHex: "FBBF24",
          rationale: "차대사람 보도통행중 19.4% 근거"),
    .init(id: "sidewalk", name: "GPS 인도 진입",   weight: BehaviorWeights.sidewalk,   icon: "mappin.slash",                     colorHex: "A78BFA",
          rationale: "도로교통법 위반 핵심 — 자동 검지 가능"),
    .init(id: "night",    name: "야간 비중",        weight: BehaviorWeights.nightRatio, icon: "moon.fill",                        colorHex: "60A5FA",
          rationale: "TAAS 야간 23.4% — 차별 우려로 상한 0.10"),
    .init(id: "distance", name: "주행거리",         weight: BehaviorWeights.distance,   icon: "road.lanes",                       colorHex: "34D399",
          rationale: "안전 운전자 페널티 우려로 상한 0.10"),
]
