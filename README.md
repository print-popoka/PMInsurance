# PM Insurance — Multimodal UBI Demo (iOS)

> A solo side project exploring **on-device mobile AI agents** and
> **RAG-grounded LLM interaction** in a real consumer domain.
> Built end-to-end in SwiftUI on iOS 26.

![iOS](https://img.shields.io/badge/iOS-26.4%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![Foundation%20Models](https://img.shields.io/badge/Apple%20Foundation%20Models-on--device-green)
![External Dependencies](https://img.shields.io/badge/external%20deps-0-brightgreen)

---

## Why I built this

My research interests sit at the intersection of three trajectories:

- **Mobile AI agents & human–AI interaction** — agents that drive a real
  mobile UI on the user's behalf, with trustworthy behavior guarantees
  rather than free-text guesses.
- **Context-aware, on-device interactive systems** — real-time inference
  pipelines that keep user data on the device.
- **Public-service UX** — insurance, transit, ticketing, and other
  high-friction touchpoints that need clearer interaction design than
  a generic form.

I started this app to push "RAG-based LLM prototyping" from a single
line on my CV into a real end-to-end implementation. Korea's Personal
Mobility (PM) insurance market — annually around **2,300 accidents**
with **56% caused by failure-to-observe-safe-driving** and no working
underwriting model — gave me a concrete consumer-facing domain to
anchor the experiment. The result is a single iPhone app that runs:

- A bivariate underwriting engine resolving a real economic failure
  (adverse selection × moral hazard in PM insurance).
- An **Apple Foundation Models** chatbot grounded in **NLEmbedding
  retrieval over Korean insurance clauses**, with a Horn-clause
  **VeriSafe verifier** as the third hallucination-defense layer.
- A natural-language advisor mode that **drives the live UI** —
  speech in → sliders move → screen transitions — a small-scale
  demonstration of mobile GUI agents.

All inference is on-device. No API keys, no network, no PII leaves
the phone.

---

## The 3-Layer Solution

| Layer | Failure resolved | Mechanism |
|------|------------------|-----------|
| **L1 — Multimodal MMS Engine** | Adverse selection | Bivariate `(PM share, behavior score)` underwriting, GLM × XGBoost ensemble |
| **L2 — Reverse Dynamic Pricing** | Moral hazard | Prospect-theory loss-aversion: start cheap, premium *rises* on risky behavior |
| **L3 — On-device RAG LLM + FNOL** | Information asymmetry & claim friction | NLEmbedding retrieval → Apple Foundation Models generation → VeriSafe verification → 8-second automated claim |

### Coordinate-plane BESPOKE — 6-cell pricing grid

Two-axis user classification (`PM share × Risk Score`) with a **6-cell
pricing multiplier**. The grid resolves three structural flaws of
single-variable UBI: the PM 30~60% mid-band has zero differentiation,
safe heavy-users are penalized against the lock-in intent, and exposure
economics are inverted.

```
                  PM < 30%        PM 30~60%        PM ≥ 60%
RS ≥ 70    Safe Eco -15%   Safe Balanced -10%   Safe Power  -5%
RS < 70    Latent     0%   Caution       +10%   Risk Heavy +15%
```

All six cells stay within ±15% of the single-score UBI baseline,
matching the surcharge ceiling in the technical appendix.

### Behavior Score — 5 weighted features

```
RS = 0.30·rapid_accel + 0.25·zigzag + 0.25·sidewalk + 0.10·night + 0.10·distance
```

Weights are derived from TAAS 2019~2024 public Korean accident data:
- `rapid_accel 0.30` ← 56% of accidents stem from failure-to-observe-safe-driving
- `zigzag 0.25` ← 19.4% pedestrian-collision-on-sidewalk
- `sidewalk 0.25` ← regulatory direct ground
- `night 0.10` ← 23.4% of accidents occur 22:00~06:00 (capped for fairness)
- `distance 0.10` ← exposure correction (capped to protect safe heavy users)

### Premium formula

```
Premium = base × loading × RF_behavior(RS) × w_modal(PM, RS)
        = 30,000 × 1.25 × {0.90 ~ 1.13} × {0.85 ~ 1.15}
```

`.toNearestOrAwayFromZero` with a 1 nano-won epsilon — necessary to
keep the IEEE-754 representation of `47,437.5` from rounding down
under banker's rounding. Six anchor cases match the appendix to the won.

---

## On-device RAG-LLM pipeline (L3)

Every chatbot query passes through three independent safety nets — all
running locally, no network required:

```
User query
   ↓
[1] Retrieval     NLEmbedding (Korean) + NLTokenizer → cosine similarity top-3
   ↓              from 12 pre-embedded clauses (threshold 0.25)
[2] Augmentation  Only the retrieved top-3 are injected into the LLM prompt
   ↓              (hallucination cannot reference clauses outside the result)
[3] Generation    Apple Foundation Models (iOS 26+) with @Generable macro
   ↓              forcing ChatResponse struct (9 typed fields — free-text impossible)
[4] Verification  VeriSafe Horn-clause R1~R4 — falsifies inconsistent answers,
                  falls back to deterministic keyword matching on failure
```

| Capability | Implementation |
|---|---|
| Korean word embedding | `NLEmbedding.wordEmbedding(for: .korean)` |
| Tokenization | `NLTokenizer(unit: .word)` |
| Similarity | Cosine of mean-pooled token vectors |
| LLM | `SystemLanguageModel.default` + `LanguageModelSession` |
| Schema enforcement | `@Generable` + `@Guide` macros |
| Verification | `verify(_:)` — Horn-clause logic over 4 rules |
| Fallback | Multi-path keyword match → suggestion chip |

This is the *trustworthy agent behavior* part of my research interests
made concrete: an LLM that cannot fabricate clauses outside the retrieved
top-3, cannot emit free-form text outside the typed schema, and is
post-checked by deterministic logic before display.

---

## Mobile AI agent — natural-language advisor mode

The chatbot doubles as a **GUI agent**. Utterances dispatch directly
to screens and drive sliders / triggers without an LLM round-trip:

| Utterance | Action |
|---|---|
| *"Zone IV 보여줘"* | Navigate to Premium Simulator → animate sliders to (PM 65, RS 45) → show narration |
| *"보험료 어떻게 줄여?"* | Navigate to Behavior screen |
| *"좌표 보여줘"* | Navigate to Coordinate plane |
| *"사고 났어"* / *"충돌"* / *"부딪쳤어"* | Navigate to FNOL → trigger 8-second automated claim → auto-scroll to payout card |

Korean commands are matched by pattern (with a centered, translucent
"AI auto demo" watermark visible so the user can still see what the UI
is doing). Free-form questions go through the RAG-LLM path described
above. This split — deterministic dispatch for commands, retrieval-grounded
LLM for open-ended queries — is what makes the agent demoable in front
of a non-technical audience.

---

## 6 Screens

1. **Home / Dashboard** — Premium card + 5-tile menu grid + weekly safety chart
2. **Premium Simulator** — Two sliders → live formula breakdown + single-score UBI comparison
3. **Coordinate** — 4-quadrant scatter chart with a pulsing "you are here" dot + 200-user synthetic distribution
4. **Behavior Score** — 5 risk sliders + live CoreMotion accelerometer ("shake your phone" → live RS)
5. **Chatbot (RAG)** — iMessage-style UI with citation pills, on-device RAG status chip, voice input
6. **FNOL** — Red trigger → 5-stage automated animation (detect → notify → evidence → adjudicate → pay) → completion card in 8 seconds total

---

## Tech stack — zero external dependencies

Only Apple-shipped frameworks. No CocoaPods, no SPM packages, no network calls.

| Framework | Use |
|---|---|
| `SwiftUI` | All UI, including iOS 26 Liquid Glass material |
| `Charts` | Coordinate scatter + behavior contribution bars |
| `FoundationModels` | On-device LLM (iOS 26+, requires Apple Intelligence) |
| `NaturalLanguage` | RAG embedding + tokenization (Korean, works on iOS 14+) |
| `Speech` + `AVFoundation` | Korean STT for the chatbot mic |
| `CoreMotion` | Live accelerometer + FNOL crash detection |
| `CoreLocation` | Reserved for a Phase 2 GPS-on-sidewalk detector |

---

## Requirements

- **Xcode 26+**
- **iOS 26.4+** simulator or device
- **iPhone 15 Pro or newer** with Apple Intelligence enabled for the
  on-device LLM path (the app falls back to keyword retrieval on
  unsupported devices)

---

## Build & Run

```bash
git clone https://github.com/print-popoka/PMInsurance.git
cd PMInsurance
open PMInsurance.xcodeproj
# Cmd+R in Xcode
```

For physical-device demos:
1. Sign with a free Apple ID provisioning profile (7-day validity).
2. Enable Apple Intelligence in Settings → General → Apple Intelligence.
3. Mirror to a Mac via cable → QuickTime → New Movie Recording → camera = iPhone.

---

## Project structure

```
PMInsurance/
├── PMInsuranceApp.swift         @main entry
├── ContentView.swift            NavigationStack + advisor overlay
├── Models/
│   ├── Premium.swift            6-cell w_modal + RF lookup + persona naming
│   ├── Zone.swift               4-quadrant enum + visualization colors
│   ├── FAQ.swift                12 insurance clauses (RAG retrieval source)
│   ├── BehaviorWeights.swift    5 weighted risk features
│   ├── UserRideHistory.swift    7-day synthetic ride history
│   └── TAAS.swift               Public accident statistics (cited in UI)
├── Services/
│   ├── AIChatService.swift      RAG retriever + FoundationModels + VeriSafe verifier
│   ├── AppState.swift           Global nav + slider state + advisor mode
│   ├── ChatMemory.swift         MobileGPT-style hierarchical query cache
│   ├── SpeechRecognizer.swift   Korean STT wrapper
│   └── MotionManager.swift      CoreMotion accelerometer + crash detection
├── Screens/                     6 main views
└── Components/                  Reusable UI primitives
```

---

## Formula verification — appendix anchor table

The six anchor cases below must produce these exact won amounts. They
double as regression checks against any future tuning.

| Persona | (PM, RS) | RF × w | Premium |
|---|---|---|---|
| Safe Eco | (15, 90) | 0.90 × 0.85 | **28,688** |
| Safe Balanced | (45, 80) | 0.97 × 0.90 | **32,738** |
| Safe Power | (70, 85) | 0.90 × 0.95 | **32,063** |
| Latent | (15, 55) | 1.04 × 1.00 | **39,000** |
| Caution | (45, 50) | 1.04 × 1.10 | **42,900** |
| Risk Heavy | (70, 40) | 1.10 × 1.15 | **47,438** |

Max spread = `48,731 / 28,688 − 1 ≈ 69.8%` — roughly **2.7× sharper**
than single-score UBI (25.6% spread).

---

## Notes

- Built as a solo extended side project. Underwriting math, on-device
  RAG pipeline, the verifier, and the entire SwiftUI surface are mine.
- All Korean accident statistics are derived from public TAAS 2019~2024
  data; the chatbot answers are written against a 12-clause synthetic
  insurance policy designed for the demo (not a real insurer's policy).
- Originally prepared as a live demonstration prototype for an insurance
  AI competition.

## License

Prototype submission. Not licensed for production use.
