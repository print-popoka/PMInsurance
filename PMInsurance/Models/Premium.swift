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

/// 6-cell w_modal — exposure-aligned pricing grid (option D2 final).
/// PM-tier (3 bands) × RS safe-flag = 6 personas. Safe pool gets bigger
/// discount with lower PM exposure; risky pool gets bigger surcharge with
/// heavier PM use. All cells stay within ±15% of single-score UBI baseline.
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

/// 6-persona label for UI display.
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
    // Standard arithmetic rounding (Math.round equivalent). Two corrections
    // are required to match the Appendix §3.4 verification table exactly:
    //   1. .toNearestOrAwayFromZero — Swift's default .rounded() uses banker's
    //      rounding (32,062.5 → 32,062), but the report uses Math.round style.
    //   2. + 1e-9 epsilon — IEEE-754 representation makes 47,437.5 be stored
    //      as 47,437.499…, which would round down under any half-up rule.
    //      One-nano-won bias preserves the theoretical value across all cells.
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
