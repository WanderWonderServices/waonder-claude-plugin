# Review: Architecture & Scalability

**Reviewer**: Architecture & Scalability Agent
**Date**: 2026-03-26

---

## 1. Architecture Strengths

- **Clean component boundaries**: Commit Analyzer / Translator / Validator separation with single responsibilities
- **Translation Plan as first-class data structure**: Enables auditability, replay, and debugging
- **Pragmatic escape hatches**: Correctly identifies untranslatable categories (C++, ProGuard, etc.)
- **Three translation modes**: Incremental/full-file/full-repo covers the escalation spectrum
- **Reuse of 63 existing skills**: Leverage multiplier instead of monolithic translator
- **Realistic MVP scoping**: Manual trigger + single-file + build check is the right starting point

---

## 2. Architecture Weaknesses

### Over-Engineered
- **Agent/skill proliferation**: 5 new skills + 3 new agents on top of 63+8 existing. The `mobile-android-commit-classifier` and `mobile-ios-translation-validator` overlap heavily with the orchestrator. Consolidate.
- **Drift detection (weekly job)**: Premature. If the pipeline works, drift is zero. If not, you have bigger problems.

### Under-Engineered
- **No semantic validation layer** between translation and build. A lightweight pre-check (e.g., "does every `struct Foo: View` have a `var body: some View`?") would catch 30-40% of build errors before the expensive xcodebuild step.
- **No handling of multi-commit sequences** that form a logical unit. Developers push 3-5 related commits that should be translated as one batch.
- **No rollback mechanism** for the iOS repo beyond "don't push if build fails."

### Missing Components
- **Translation cache/deduplication**: Re-translating unchanged files wastes API cost
- **Xcode project file management (`.pbxproj`)**: Hard blocker for compilation when files are added/removed
- **Resource translation pipeline**: strings.xml -> .xcstrings needs deterministic converters, not AI

---

## 3. Translation Engine Critique

### Skill Selection Algorithm
The "first match wins" approach is brittle. A `FooScreen.kt` containing both Composable and inline ViewModel patterns would match "screen" but miss ViewModel translation. Rules 14-16 (coroutines/Flow enrichment) contradict "first match wins" since they're additive.

**Fix**: Split into (1) primary classification (mutually exclusive) and (2) trait detection (additive, applied on top).

### Translation Plan Schema Edge Cases
1. **Moved files**: `action` supports modify/create/skip but not rename. Git represents renames as delete+create; the analyzer must reconstruct renames.
2. **Multi-skill files**: How do multiple skills compose? Sequential? Merged prompt? Unspecified.
3. **Binary files**: No handling for non-text files (images, .proto, certificates).

### Incremental vs Full-File
Incremental is fragile for AI-based translation. Claude has no reliable way to "apply only the diff" without potentially misidentifying the change location, re-translating surrounding code, or missing structural implications.

**Fix**: Default to full-file. Use incremental only after empirical validation, and only for diffs < 20% of file size.

### Cross-File Dependencies (Weakest Point)
The `dependencies` field handles intra-commit ordering but not the harder problem: **a change in file A requires cascading changes in files B, C, D that were not in the commit.**

Example: Adding `animationType` to `ChatMessage.kt` may require changes in `ChatMessageModel.swift`, `ChatMappers.swift`, `ChatStore.swift`, and consuming ViewModels -- even if the Android developer only touched one file.

**Fix**: Add a "dependency expansion" step that uses the iOS import graph to identify downstream consumers that may need re-translation.

---

## 4. CI/CD Pipeline Design

### GitHub Actions Concurrency Bug
The spec uses `concurrency: { group: ios-translation, cancel-in-progress: false }`. **This is not FIFO queuing.** GitHub Actions with `cancel-in-progress: false` waits for the running job, but only queues ONE pending job. If commits A, B, C arrive while A runs, B is queued but C cancels B.

**Fix**: Implement explicit queuing (state file tracking pending SHAs, or external queue).

### Retry Logic
3-attempt retry at file level but build validation at project level. Re-translating file A might fix A but break file B. The retry loop should track cross-file error propagation.

### Test Skip
`continue-on-error: true` on tests should have a concrete timeline for removal.

---

## 5. State Management

### Translation State File Flaw
Committing `.translation-state.json` to the iOS repo means every pipeline run modifies this file, triggering iOS-side CI workflows. Racing pipeline runs produce conflicting state changes.

**Fix**: Store state externally (GitHub Actions cache, dedicated state repo, or key-value store). Not in the content repo.

### State Corruption
The spec doesn't address: state says last SHA = X but iOS HEAD doesn't contain X; pipeline crashes mid-run; state references a rebased-away commit.

**Fix**: Treat state as a hint, not truth. On every run, verify actual state by scanning iOS commit messages for `Source: waonder-android@<sha>` tags.

---

## 6. Scalability Concerns

### Token Limits
Sending full Kotlin file + full Swift file + diff + architectural decisions to every call is wasteful. Distill the spec 002 context to a compact reference card (< 500 tokens). For files > 300 lines, consider section-by-section translation.

### Large Refactors (50+ Files)
Independent per-file translation produces inconsistent results for cross-file refactors. The 30-min timeout is insufficient.

**Fix**: For commits touching > 15 files, use "batch translation mode" -- single Claude session with full change set. Sacrifices parallelism for coherence.

---

## 7. Top 5 Architectural Improvements

1. **Add a Dependency Expansion Step** between Commit Analyzer and Translation Engine. Use the iOS import graph to identify downstream files that may need re-translation.

2. **Replace GitHub Actions Concurrency with Explicit Queue.** FIFO queue stored externally. Batch consecutive commits touching overlapping files.

3. **Default to Full-File Translation.** Make incremental opt-in after empirical validation.

4. **Add Xcode Project File Management.** Use deterministic tools (`xcodegen`, `xcodeproj` gem) for `.pbxproj` updates. Never ask AI to edit this file.

5. **Decouple State from Content Repos.** Store externally. Make pipeline self-healing by always verifying actual repo state on startup.
