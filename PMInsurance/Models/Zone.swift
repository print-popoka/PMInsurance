import SwiftUI

enum Zone: String, CaseIterable, Sendable {
    case I, II, III, IV

    var name: String { "Zone \(rawValue)" }

    var label: String {
        switch self {
        case .I:   "대중교통 중심형"
        case .II:  "안전 PM 헤비유저"
        case .III: "저노출 주의형"
        case .IV:  "고위험 — Sleeping Dogs"
        }
    }

    var subtitle: String {
        switch self {
        case .I:   "자원 효율 그룹 · 저빈도·고안전"
        case .II:  "락인 핵심 고객 · 고빈도·고안전"
        case .III: "잠재 개선 그룹 · 저빈도·저안전"
        case .IV:  "신중 개입, 최대 15% 할증 · 고빈도·저안전"
        }
    }

    var color: Color {
        switch self {
        case .I:   .zoneI
        case .II:  .zoneII
        case .III: .zoneIII
        case .IV:  .zoneIV
        }
    }
}

extension Color {
    init(hex: String) {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        let v = UInt32(s, radix: 16) ?? 0
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    static let zoneI       = Color(hex: "34D399")
    static let zoneII      = Color(hex: "60A5FA")
    static let zoneIII     = Color(hex: "FBBF24")
    static let zoneIV      = Color(hex: "F87171")
    static let iosBlue     = Color(hex: "4A9EFF")
    static let iosRed      = Color(hex: "FF4B5C")
    static let bgNavy      = Color(hex: "0A1628")
    static let bgNavyDeep  = Color(hex: "1F3864")
    static let bgNavyOuter = Color(hex: "050810")
}

extension ShapeStyle where Self == Color {
    static var iosBlue: Color     { Color.iosBlue }
    static var iosRed: Color      { Color.iosRed }
    static var zoneI: Color       { Color.zoneI }
    static var zoneII: Color      { Color.zoneII }
    static var zoneIII: Color     { Color.zoneIII }
    static var zoneIV: Color      { Color.zoneIV }
    static var bgNavy: Color      { Color.bgNavy }
    static var bgNavyDeep: Color  { Color.bgNavyDeep }
    static var bgNavyOuter: Color { Color.bgNavyOuter }
}
