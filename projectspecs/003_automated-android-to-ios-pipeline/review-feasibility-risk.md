# Review: Feasibility & Risk Analysis

**Reviewer**: Feasibility & Risk Analyst (AI Agent)
**Date**: 2026-03-26
**Status**: Complete

---

## 1. Feasibility Assessment

**Is this technically achievable with current AI capabilities (Claude API)?**

Partially. The broad architecture -- webhook trigger, commit analysis, file mapping, AI translation, build verification, commit -- is sound and each individual piece is buildable. However, the spec treats Claude as a deterministic compiler when it is a probabilistic text generator. The gap between "can translate isolated Kotlin files to Swift in a lab" and "can reliably maintain a living, compiling iOS codebase commit-by-commit with zero human intervention" is enormous. The pipeline is achievable as an *assistant* (generates drafts that a human reviews). It is not achievable as a fully autonomous "zero manual iOS coding" system for a codebase of this complexity (450+ files, C++ bridging, custom map engine, multi-module SPM).

**Realistic success rate for automated Kotlin-to-Swift translation?**

- Simple data models, DTOs, mappers: 85-95% success rate (high structural regularity).
- ViewModels, repositories, use cases: 60-80% (pattern-based, but subtle async/state management differences trip up AI).
- Compose-to-SwiftUI screens: 40-60% (layout DSLs are superficially similar but semantically very different -- modifiers, state ownership, lifecycle, gestures, animation APIs).
- Anything touching MapLibre, C++ bridging, Firebase iOS SDK specifics, or platform-specific concurrency edge cases: below 30%.

The spec's success criterion of "90%+ commits translated without manual intervention" is optimistic. A more realistic target for the first 6 months is 50-65% of commits fully automated, with the rest requiring at least minor human fixes.

**Can incremental diff-based translation actually work reliably?**

This is the spec's single most fragile assumption. Incremental translation ("apply only the delta to the existing iOS file") requires the AI to understand the full semantic context of both the Kotlin diff and the existing Swift file, then surgically insert/modify/remove only the relevant Swift code. In practice:

- Context loss is near-guaranteed for non-trivial diffs.
- Cross-file dependencies are the norm, not the exception.
- The incremental mode will silently produce code that compiles but is semantically wrong.

Recommendation: Default to **full-file re-translation** and treat incremental as an optimization to explore later.

**Is the 10-minute SLA realistic?**

For 1-3 file commits using Sonnet: plausible. But:
- `xcodebuild clean build` on a 19-module SPM project takes 3-8 minutes alone.
- Retries push to 15-25 minutes.
- The 10-minute SLA is realistic only for trivial commits on the first attempt. 20-30 minutes is more honest.

---

## 2. Critical Risks (Ranked by Severity)

**Risk 1: Semantic Correctness Without Functional Tests**
- The build gate only checks compilation, not correctness. The spec says test failures still result in commits.
- **Likelihood**: Near-certain. **Impact**: Critical.
- **Mitigation**: Tests must be a hard gate. Auto-generate basic tests at minimum.

**Risk 2: Incremental Translation Drift (Accumulated Errors)**
- Each incremental translation introduces a small probability of error. Over 100+ commits, these compound.
- **Likelihood**: High. **Impact**: Critical.
- **Mitigation**: Periodically run full-file re-translation of entire codebase and diff against incremental result.

**Risk 3: Context Window Limits for Complex Files**
- Large files (500+ lines) plus all the prompt context will hit or exceed context limits.
- **Likelihood**: High. **Impact**: High.
- **Mitigation**: Add pre-flight token estimation. For large files, use chunking or switch to Opus.

**Risk 4: No Rollback Strategy for Bad Translations**
- No mechanism to revert a compiling but incorrect translation pushed to main.
- **Likelihood**: Medium-High. **Impact**: High.
- **Mitigation**: Translate to a staging branch first. Auto-merge after hold period or approval.

**Risk 5: macOS CI Runner Cost and Availability**
- GitHub macOS runners are 10x more expensive than Linux. ~$360/month just for CI compute.
- **Likelihood**: Certain. **Impact**: Medium.
- **Mitigation**: Include CI compute costs in budget. Use incremental builds.

**Risk 6: Concurrency Model Translation is Fundamentally Hard**
- Kotlin Coroutines and Swift Concurrency have different semantics around cancellation, backpressure, lifecycle.
- **Likelihood**: High. **Impact**: High.
- **Mitigation**: Build verified library of concurrency pattern translations. Require human review for Flow/coroutine files initially.

**Risk 7: Pipeline Maintenance Burden**
- 5 new skills + 3 agents + Actions workflow + state system + drift detector = significant system.
- **Likelihood**: Medium. **Impact**: Medium-High.
- **Mitigation**: Ruthlessly minimize scope. MVP should be a single script, not multi-agent orchestration.

---

## 3. Blind Spots

1. **iOS-specific code with no Android counterpart** (@main lifecycle, Scene delegates, Info.plist capabilities, APNs registration, privacy manifest).
2. **Third-party SDK API differences** (Firebase iOS vs Android SDK, MapLibre iOS vs Android).
3. **Xcode project file management** (.pbxproj is complex and not addressed).
4. **Asset handling beyond strings** (image densities, vector drawables vs SF Symbols, custom fonts).
5. **New dependency discovery** (Android adds a Gradle dependency -- how does iOS get the equivalent?).
6. **Merge conflict resolution** (manual iOS fixes + next auto-translation = conflicts).
7. **API rate limits and reliability** (bursts of commits could hit rate limits).

**Unstated critical assumptions:**
- The iOS codebase from spec 002 will be perfectly translated before this pipeline starts.
- Claude's translation quality will remain stable across model updates.
- The Android codebase follows consistent patterns.

---

## 4. Cost Reality Check

| Cost Component | Spec Estimate | Realistic Estimate |
|---|---|---|
| Claude API (Sonnet) | $13.50/month | $40-80/month |
| Claude API (Opus fallback) | Not estimated | $50-150/month |
| macOS CI runner (GitHub-hosted) | Not estimated | $200-400/month |
| macOS CI runner (self-hosted) | Not estimated | $50/month + $700 upfront |
| Developer time (pipeline maintenance) | Not estimated | 5-15 hours/month |
| Developer time (fixing translations) | Not estimated | 10-30 hours/month |

**Realistic total monthly cost**: $300-700/month. The spec's "$13.50/month with Sonnet" framing is misleading.

---

## 5. Top 5 Recommendations

1. **Redefine success metric** from "zero manual iOS coding" to "AI-assisted iOS coding with human review." Produce PRs, not direct main pushes. Add confidence scoring.

2. **Build MVP as a local CLI tool**, not a CI/CD pipeline. Run `./translate-commit <sha>` on 50 real commits before automating.

3. **Default to full-file translation**, not incremental. The cost difference is negligible; the reliability difference is massive.

4. **Make test passage a hard gate**, not a soft warning. Auto-generate basic tests if none exist.

5. **Add translation confidence output** and route low-confidence files to a PR branch instead of main. This converts "fragile autonomous system" to "robust assistant."
