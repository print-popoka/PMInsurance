import Foundation

enum Premium {
    static let basePure: Double = 30_000
    static let loading: Double = 1.25
}

func rfBehavior(rs: Double) -> Double {
    switch rs {
    case 85...:    0.90
    case 70..<85:  0.97
    case 50..<70:  1.04
    case 30..<50:  1.10
    default:       1.13
    }
}

/// 6-cell pricing grid. PM tier (low, mid, high) crossed with RS safe flag.
/// Safe riders get a bigger discount the less they ride. Risky riders get
/// a bigger surcharge the more they ride. Every cell stays inside the
/// 15 percent surcharge ceiling.
func wModal(pmShare: Double, rs: Double) -> Double {
    let safe = rs >= 70
    let pmTier = pmShare < 30 ? 0 : (pmShare < 60 ? 1 : 2)
    if safe {
        switch pmTier {
        case 0:  return 0.85   // Safe Eco       (-15%)
        case 1:  return 0.90   // Safe Balanced  (-10%)
        default: return 0.95   // Safe Power     (-5%)
        }
    } else {
        switch pmTier {
        case 0:  return 1.00   // Latent         (neutral — PM exposure low)
        case 1:  return 1.10   // Caution        (+10%)
        default: return 1.15   // Risk Heavy     (+15% — surcharge ceiling)
        }
    }
}

/// Persona label for the UI.
func personaName(pmShare: Double, rs: Double) -> String {
    let safe = rs >= 70
    let pmTier = pmShare < 30 ? 0 : (pmShare < 60 ? 1 : 2)
    return switch (safe, pmTier) {
    case (true,  0): "Safe Eco"
    case (true,  1): "Safe Balanced"
    case (true,  _): "Safe Power"
    case (false, 0): "Latent"
    case (false, 1): "Caution"
    case (false, _): "Risk Heavy"
    }
}

func classifyZone(pmShare: Double, rs: Double) -> Zone {
    let heavy = pmShare >= 30
    let safe  = rs >= 70
    return switch (heavy, safe) {
    case (true,  true):  .II
    case (false, true):  .I
    case (true,  false): .IV
    case (false, false): .III
    }
}

func calculatePremium(pmShare: Double, rs: Double) -> Int {
    let raw = Premium.basePure * Premium.loading * rfBehavior(rs: rs) * wModal(pmShare: pmShare, rs: rs)
    // Match the verification table exactly. Two fixes needed.
    // Swift's default `.rounded()` is banker's rounding, so 32062.5 goes to
    // 32062 instead of 32063. Use the away-from-zero rule.
    // IEEE-754 also stores 47437.5 as 47437.499..., which would still round
    // down. The 1e-9 nudge fixes that.
    return Int((raw + 1e-9).rounded(.toNearestOrAwayFromZero))
}

func grade(rs: Double) -> String {
    switch rs {
    case 85...:    "A"
    case 70..<85:  "B"
    case 50..<70:  "C"
    case 30..<50:  "D"
    default:       "E"
    }
}
