# Review: Feasibility & Risk Analysis

**Reviewer**: Feasibility & Risk Analyst Agent
**Date**: 2026-03-26

---

## 1. Feasibility Assessment

**Is this technically achievable with current AI capabilities (Claude API)?**

Partially. The architecture is sound and each individual piece is buildable. However, the spec treats Claude as a deterministic compiler when it is a probabilistic text generator. The gap between "can translate isolated Kotlin files to Swift in a lab" and "can reliably maintain a living, compiling iOS codebase commit-by-commit with zero human intervention" is enormous. The pipeline is achievable as an *assistant* (generates drafts that a human reviews). It is not achievable as a fully autonomous "zero manual iOS coding" system for a codebase of this complexity (450+ files, C++ bridging, custom map engine, multi-module SPM).

**Realistic success rate for automated Kotlin-to-Swift translation?**

- Simple data models, DTOs, mappers: 85-95% success rate
- ViewModels, repositories, use cases: 60-80%
- Compose-to-SwiftUI screens: 40-60%
- MapLibre, C++ bridging, Firebase iOS SDK specifics: below 30%

The spec's success criterion of "90%+ commits translated without manual intervention" is optimistic. A more realistic target for the first 6 months is 50-65% of commits fully automated.

**Can incremental diff-based translation work reliably?**

This is the spec's single most fragile assumption. Context loss is near-guaranteed for non-trivial diffs. Adding a parameter to a Kotlin data class might require changes to the Swift struct, its Equatable conformance, callers across multiple files, and the DI container -- none of which appear in the diff. The incremental mode will silently produce code that compiles but is semantically wrong.

**Recommendation**: Default to full-file re-translation and treat incremental as an optimization to explore later.

**Is the 10-minute SLA realistic?**

For trivial commits that compile on the first attempt only. `xcodebuild clean build` on a 19-module SPM project takes 3-8 minutes alone. Any retry pushes to 15-25 minutes. Honest SLA: 10 minutes for simple commits, 20-30 minutes for anything requiring a retry.

---

## 2. Critical Risks (Ranked by Severity)

### Risk 1: Semantic Correctness Without Functional Tests
- **Description**: The build gate only checks compilation. Tests are soft-gated (`continue-on-error: true`). The pipeline will push semantically broken Swift code to main.
- **Likelihood**: Near-certain
- **Impact**: Critical -- iOS app ships bugs that never existed on Android
- **Mitigation**: Tests must be a hard gate. Consider auto-generated snapshot/screenshot tests.

### Risk 2: Incremental Translation Drift
- **Description**: Each incremental translation introduces small errors. Over 100+ commits, these compound. The weekly drift detector only checks file existence, not content correctness.
- **Likelihood**: High
- **Impact**: Critical -- after 3-6 months, only full re-translation can fix
- **Mitigation**: Content-level drift detection. Periodically run full-file re-translation to measure accumulated error.

### Risk 3: Context Window Limits for Complex Files
- **Description**: Large files (500+ lines) with full context easily exceed practical token limits, producing truncated or hallucinated translations.
- **Likelihood**: High
- **Impact**: High
- **Mitigation**: Pre-flight token estimation. Chunking strategy for large files. Opus fallback.

### Risk 4: No Rollback Strategy for Bad Translations
- **Description**: No mechanism to revert a compiling-but-incorrect translation pushed to main. A bad translation blocks all subsequent translations.
- **Likelihood**: Medium-High
- **Impact**: High
- **Mitigation**: Translate to a staging branch first. Auto-merge to main after a hold period or explicit approval.

### Risk 5: macOS CI Runner Cost and Availability
- **Description**: macOS runners are 10x more expensive than Linux ($0.08/min). A 30-min job at 5 commits/day = $360/month just for compute.
- **Likelihood**: Certain
- **Impact**: Medium -- cost estimates ignore CI infrastructure entirely
- **Mitigation**: Include CI costs in budget. Use self-hosted Mac Mini. Use incremental builds.

### Risk 6: Concurrency Model Translation is Fundamentally Hard
- **Description**: Kotlin Coroutines/Flow and Swift Concurrency have different semantics around cancellation, backpressure, and lifecycle. AI will pattern-match syntax but miss semantic differences.
- **Likelihood**: High
- **Impact**: High -- concurrency bugs are hardest to diagnose
- **Mitigation**: Build a verified library of concurrency pattern translations. Require human review for concurrency-heavy files initially.

### Risk 7: Pipeline Maintenance Burden
- **Description**: 5 new skills + 3 new agents + CI workflow + state management + drift detector + notifications = a significant system to maintain. For a solo developer, maintaining the pipeline may consume more time than manual iOS coding.
- **Likelihood**: Medium
- **Impact**: Medium-High
- **Mitigation**: Ruthlessly minimize scope. MVP should be a single script, not a multi-agent orchestration system.

---

## 3. Blind Spots

1. **iOS-only code with no Android counterpart**: `@main` app lifecycle, entitlements, ATS exceptions, privacy manifest. Who writes this?
2. **Third-party SDK API differences**: Firebase iOS SDK != Firebase Android SDK in API shape.
3. **Xcode project file management**: `.pbxproj` is complex and not addressed.
4. **Asset handling beyond strings**: Image densities, vector drawables, custom fonts.
5. **New dependency discovery**: Android adds a Gradle dependency -- where's the iOS equivalent?
6. **Merge conflicts**: Manual iOS fixes followed by auto-translation can conflict.
7. **API rate limits**: Bursts of commits can hit Claude API limits.

**Unstated assumptions**:
- Spec 002 will produce a perfectly compiling iOS codebase before this starts
- Claude's translation quality remains stable across model updates
- Android codebase follows consistent patterns

---

## 4. Cost Reality Check

| Cost Component | Spec Estimate | Realistic Estimate |
|---|---|---|
| Claude API (Sonnet) | $13.50/month | $40-80/month |
| Claude API (Opus fallback) | Not estimated | $50-150/month |
| macOS CI runner (GitHub-hosted) | Not estimated | $200-400/month |
| macOS CI runner (self-hosted) | Not estimated | $50/month + $700 upfront |
| Developer time maintaining pipeline | Not estimated | 5-15 hours/month |
| Developer time fixing bad translations | Not estimated | 10-30 hours/month |

**Realistic total**: $300-700/month. The spec's "$13.50/month with Sonnet" is misleading.

---

## 5. Top 5 Recommendations

1. **Redefine success from "zero manual iOS coding" to "AI-assisted with human review."** Produce PRs with confidence scores, not direct main pushes.

2. **Build MVP as a local CLI tool, not CI/CD.** `./translate-commit <sha>`. Run on 50 real commits. Measure success rate. Then decide on automation.

3. **Default to full-file translation, not incremental.** The cost difference ($0.06 vs $0.20 per file) is negligible compared to debugging bad incremental translations.

4. **Make test passage a hard gate.** A compiling but non-functional app is worse than no app.

5. **Add translation confidence scoring.** Route low-confidence files to a PR branch instead of main. This converts "fragile autonomous system" to "robust assistant."
