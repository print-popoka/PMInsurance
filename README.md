# PM Insurance Demo App

An iOS app I built as a solo side project. The chatbot runs on Apple
Foundation Models with a small Korean RAG layer, and the rest of the
app is a working multimodal UBI insurance demo built around it.
Some features were implemented under a simulated virtual environment.

![iOS](https://img.shields.io/badge/iOS-26.4%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![Foundation%20Models](https://img.shields.io/badge/Apple%20Foundation%20Models-on--device-green)
![External Dependencies](https://img.shields.io/badge/external%20deps-0-brightgreen)


## Why I built it

I wanted to take RAG-based LLM prototyping past a one-line CV item and
build it end-to-end. The Korean PM (Personal Mobility) insurance market
felt like a good place to anchor it. There are roughly 2,300 PM
accidents a year, more than half come down to risky riding behavior,
and there is no real working underwriting model for it yet.

It also lines up well with what I want to keep working on: mobile AI
agents, on-device interactive systems, and public-service UX.

The result is one iPhone app that runs the whole thing locally. No API
keys, no network calls, nothing leaves the device.


## What's inside

**L1. Multimodal underwriting.** A bivariate engine over PM usage
share and a behavior score. Six pricing cells instead of the usual
four quadrants, which fixes a pricing paradox in the original design.

**L2. Reverse dynamic pricing.** Premiums start low and rise when
riskier behavior shows up. Inspired by prospect-theory loss aversion.
Surcharge caps at +15 percent.

**L3. On-device RAG chatbot.** NLEmbedding cosine search over twelve
Korean clauses, top three results fed into a Foundation Models call.
A Horn-clause verifier checks the answer before display. If anything
fails, it falls back to keyword matching.

There is also an advisor mode. The chatbot doubles as a GUI agent.
You can say things like "Zone IV 보여줘" or "사고 났어" and the app
will navigate, move sliders, or trigger the claim flow on its own.


## Pricing grid

```
                  PM < 30%     PM 30~60%    PM ≥ 60%
RS ≥ 70    Safe Eco -15%    Balanced -10%   Power  -5%
RS < 70    Latent     0%    Caution  +10%   Risk  +15%
```

Behavior score uses five features. Weights come from public TAAS
accident statistics (2019 to 2024).

```
RS = 0.30·rapid_accel + 0.25·zigzag + 0.25·sidewalk
   + 0.10·night + 0.10·distance
```

Premium formula:

```
Premium = base × loading × RF_behavior(RS) × w_modal(PM, RS)
        = 30,000 × 1.25 × {0.90~1.13} × {0.85~1.15}
```

Rounding uses `.toNearestOrAwayFromZero` with a 1 nano-won epsilon. The
epsilon is there to stop IEEE-754 from rounding 47,437.5 down to 47,437
under banker's rounding. All six anchor cases match the appendix to
the won.


## How the RAG chatbot works

Each query goes through four stages.

```
[1] Retrieval     NLEmbedding (Korean) + NLTokenizer
                  cosine similarity, top 3 from 12 clauses
                  threshold 0.25

[2] Augmentation  Only the retrieved clauses go into the prompt
                  The model can't cite anything outside that set

[3] Generation    Foundation Models with @Generable
                  ChatResponse is a typed struct, free text is impossible

[4] Verification  VeriSafe Horn-clause rules R1 to R4
                  Falls back to keyword matching on failure
```

Stack:

| Layer | Implementation |
|---|---|
| Korean word embedding | `NLEmbedding.wordEmbedding(for: .korean)` |
| Tokenization | `NLTokenizer(unit: .word)` |
| Similarity | Cosine of mean-pooled token vectors |
| LLM | `SystemLanguageModel.default` and `LanguageModelSession` |
| Schema | `@Generable` and `@Guide` macros |
| Verification | `verify(_:)` with Horn-clause rules |
| Fallback | Multi-path keyword match |

Three safety nets stack on top of each other. The model only sees what
retrieval gave it. The output is forced into a typed struct, so no
free-form text. The verifier rejects answers that don't line up.


## Advisor mode

Some commands skip the LLM entirely and dispatch by pattern.

| User says | App does |
|---|---|
| Zone IV 보여줘 | Goes to Premium Simulator, animates sliders to (65, 45), shows narration |
| 보험료 어떻게 줄여? | Goes to Behavior screen |
| 좌표 보여줘 | Goes to the Coordinate plane |
| 사고 났어 / 충돌 / 부딪쳤어 | Triggers the 8-second FNOL claim flow, auto-scrolls to the payout |

A translucent watermark stays centered while this runs so it's clear
what's happening. Open questions still go through the RAG pipeline.


## Screens

1. Home dashboard with the premium card and weekly safety chart
2. Premium Simulator with two sliders and a comparison against
   single-score UBI
3. Coordinate plane with a synthetic 200-user scatter
4. Behavior Score with live CoreMotion input
5. Chatbot with citation pills and a RAG status chip
6. FNOL with a five-stage automated claim animation


## Tech stack

Only Apple frameworks. No CocoaPods, no SPM packages, no network calls.

| Framework | What for |
|---|---|
| SwiftUI | All UI, including iOS 26 Liquid Glass |
| Charts | Coordinate scatter, behavior bars |
| FoundationModels | On-device LLM |
| NaturalLanguage | RAG embedding and tokenization |
| Speech, AVFoundation | Korean STT |
| CoreMotion | Accelerometer, crash detection |
| CoreLocation | Reserved for a Phase 2 GPS feature |


## Requirements

Xcode 26+ and iOS 26.4+. The LLM path needs an iPhone 15 Pro or newer
with Apple Intelligence enabled. On unsupported devices the app falls
back to keyword retrieval.


## Build

```bash
git clone https://github.com/print-popoka/PMInsurance.git
cd PMInsurance
open PMInsurance.xcodeproj
```

For a physical demo, sign with a free Apple ID profile (seven-day
validity), enable Apple Intelligence in Settings, and mirror to a Mac
through QuickTime.


## Project layout

```
PMInsurance/
├── PMInsuranceApp.swift         App entry
├── ContentView.swift            Navigation, advisor overlay
├── Models/
│   ├── Premium.swift            6-cell w_modal, RF lookup
│   ├── Zone.swift               Zone enum and colors
│   ├── FAQ.swift                12 insurance clauses (RAG source)
│   ├── BehaviorWeights.swift    5 risk features
│   ├── UserRideHistory.swift    7-day synthetic ride data
│   └── TAAS.swift               Public accident statistics
├── Services/
│   ├── AIChatService.swift      RAG retriever, FoundationModels, verifier
│   ├── AppState.swift           Navigation, sliders, advisor mode
│   ├── ChatMemory.swift         Hierarchical query cache
│   ├── SpeechRecognizer.swift   Korean STT wrapper
│   └── MotionManager.swift      Accelerometer wrapper
├── Screens/                     6 main views
└── Components/                  Shared UI pieces
```


## Verification table

These six anchor cases come from the technical appendix. They double
as regression checks.

| Persona | (PM, RS) | RF × w | Premium |
|---|---|---|---|
| Safe Eco | (15, 90) | 0.90 × 0.85 | 28,688 |
| Safe Balanced | (45, 80) | 0.97 × 0.90 | 32,738 |
| Safe Power | (70, 85) | 0.90 × 0.95 | 32,063 |
| Latent | (15, 55) | 1.04 × 1.00 | 39,000 |
| Caution | (45, 50) | 1.04 × 1.10 | 42,900 |
| Risk Heavy | (70, 40) | 1.10 × 1.15 | 47,438 |

Spread is 48,731 over 28,688 minus 1, about 70 percent. Single-score
UBI gives around 26 percent on the same data.


## Notes

I built this on my own. The underwriting math, the RAG pipeline, the
verifier, and the whole SwiftUI surface are mine. Accident numbers
come from public TAAS data. The twelve insurance clauses are
synthetic, written for the demo, not based on any insurer's policy.

Originally put together as a live demo for an insurance AI competition.


## License

Prototype. Not licensed for production use.
