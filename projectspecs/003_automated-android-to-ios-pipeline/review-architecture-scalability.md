# Review: Architecture & Scalability

**Reviewer**: Architecture & Scalability Analyst (AI Agent)
**Date**: 2026-03-26
**Status**: Complete

---

## 1. Architecture Strengths

- **Clean component boundaries.** Commit Analyzer / Translator / Validator separation is sound. The Translation Plan JSON is a well-designed handoff point.
- **Three translation modes** (incremental / full-file / full-repo) cover the spectrum with proper escalation paths.
- **Reuse of 63 existing skills** as translation backends is a leverage multiplier.
- **Realistic MVP scoping** — manual trigger + single-file translation + build check is the correct validation approach.
- **Escape hatch design is pragmatic** — correctly identifies untranslatable patterns.

---

## 2. Architecture Weaknesses

### Over-Engineered
- **Agent/skill proliferation.** 5 new skills + 3 new agents overlaps heavily. The `mobile-android-commit-classifier` and `mobile-ios-translation-validator` agents duplicate orchestrator functionality. Subsume them.
- **Drift detection system** is premature. If the pipeline works, drift is zero. If not, weekly reports don't help.

### Under-Engineered
- **No semantic validation layer** between translation and build. A lightweight pre-check (protocol conformances, import validity, struct body requirements) would catch 30-40% of build errors before expensive xcodebuild.
- **No handling of multi-commit sequences** that form a logical unit. Translating each independently wastes tokens and may produce non-compiling intermediate states.
- **No rollback mechanism** for bad translations pushed to iOS repo.

### Missing Components
- **Translation cache/deduplication.** Re-translating unchanged files wastes API cost.
- **Xcode project file management (.pbxproj).** Adding/removing files requires pbxproj updates — this is a hard blocker not addressed.
- **Resource translation pipeline.** strings.xml -> .xcstrings needs deterministic converters, not AI.

---

## 3. Translation Engine Critique

### Skill Selection Algorithm
The "first match wins" rules are brittle. Real files span multiple categories:
- A screen with inline ViewModels matches "screen" but misses ViewModel patterns.
- Rules 14-16 (coroutine/Flow enrichment) are additive traits, not primary classifications.

**Fix:** Split into (1) primary classification (mutually exclusive) and (2) trait detection (additive).

### Translation Plan Schema: Edge Cases
1. **Moved files.** No `action: "rename"` with `old_ios_path` / `new_ios_path`. Git diffs show rename as delete+create.
2. **Multi-skill composition.** How do multiple skills compose? Sequential? Merged prompt? Unspecified.
3. **Binary files.** No handling for images, .proto, certificates in diffs.

### Incremental vs Full-File
Incremental is conceptually appealing but practically fragile for AI-based translation. The AI cannot reliably "apply only the diff" without introducing inconsistencies.

**Fix:** Default to full-file. Use incremental only after empirical validation, and only for files where diff < 20% of file size.

### Cross-File Dependencies (Critical Gap)
This is the weakest point. The `dependencies` field handles intra-commit ordering but not **cascading changes** to files NOT in the commit.

Example: Adding `animationType` to `ChatMessage.kt` may require changes to `ChatMessageModel.swift`, `ChatMappers.swift`, `ChatStore.swift`, and ViewModels — none of which appear in the Android commit.

**Fix:** Add a "dependency expansion" step using the iOS import graph to identify downstream files needing re-translation.

---

## 4. CI/CD Pipeline Design

### GitHub Actions Concurrency Bug
The spec uses `cancel-in-progress: false` and describes it as queuing. **This is incorrect.** GitHub Actions concurrency groups with `cancel-in-progress: false` queue only ONE pending job. If commits A, B, C arrive while A runs, C cancels B.

**Fix:** Implement explicit FIFO queuing outside Actions (state file tracking pending SHAs).

### Retry Logic
3-attempt retry at file level, but build validation is project-level. Re-translating file A could break file B. Each retry requires a full xcodebuild (15-20 min added per failure).

### Test Gate
`continue-on-error: true` on tests should have a removal timeline. Silently failing tests lead to a permanently broken test suite.

---

## 5. State Management

### State File Problems
Committing `.translation-state.json` to iOS repo means:
- Every pipeline run creates a commit modifying this file.
- Racing pipeline runs produce conflicting state changes.

**Fix:** Move state external to both repos (GitHub Actions cache or dedicated store).

### State Corruption Not Addressed
What happens when: state says `last_sha = X` but iOS HEAD doesn't contain X? Pipeline crashes mid-run? State references a rebased-away commit?

**Fix:** Treat state as a hint. On every run, verify actual state by comparing commit logs. Use iOS commit messages (`Source: waonder-android@<sha>`) as source of truth.

---

## 6. Scalability Concerns

### Large Refactors (50+ Files)
- 30-minute Actions timeout is insufficient for 50+ file translation + build.
- Per-file independent translation produces inconsistent cross-file interfaces.

**Fix:** For commits > 15 files, batch into a single Claude session with extended context for coherence.

### Token Limits
Sending full Kotlin file + full Swift file + diff + architectural context + naming conventions per file. Large files easily exceed practical limits.

**Fix:** Distill architectural context to a compact reference card (< 500 tokens). Split files > 300 lines into sections.

---

## 7. Top 5 Architectural Improvements

1. **Add a Dependency Expansion Step** after the Translation Plan — use the iOS import graph to identify files that transitively depend on changed files and may need re-translation.

2. **Replace GitHub Actions Concurrency with Explicit Queue** — FIFO queue stored externally. Batch consecutive commits touching overlapping files.

3. **Default to Full-File Translation** — flip the default. More expensive but dramatically more reliable. Make incremental opt-in after empirical validation.

4. **Add Xcode Project File Management** — use `xcodegen` or `xcodeproj` gem for deterministic pbxproj updates. Never ask AI to edit pbxproj.

5. **Decouple State from Content Repos** — move to external store. Make pipeline self-healing by always verifying actual repo state on startup.
