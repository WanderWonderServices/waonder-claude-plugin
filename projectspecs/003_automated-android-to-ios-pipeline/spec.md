# Automated Android-to-iOS Translation Pipeline

**Milestone**: 003_automated-android-to-ios-pipeline
**Created**: 2026-03-26
**Status**: Draft
**Depends on**: 002_android-to-ios-full-migration (iOS codebase must exist first)

## Overview

Build a locally-executed pipeline that translates every Android commit into its iOS equivalent — no manual iOS coding required. After a developer completes work on the Android app, they invoke the translation pipeline locally via Claude Code CLI on their Mac. The pipeline:

1. Detects untranslated commits on `waonder-android` main
2. Analyzes what was modified (Kotlin files, resources, configs)
3. Translates each change to its Swift/iOS equivalent using Claude AI agents
4. Validates the iOS build compiles and tests pass on the local machine
5. Commits and pushes the translated changes to the iOS repository

The pipeline runs entirely on Gabriel's Mac — no CI/CD, no cloud runners, no webhooks. It is invoked on-demand via a Claude Code skill or slash command (`/translate-android`). The end result: both repositories maintain parallel commit histories where every Android change has a corresponding iOS change.

---

## Problem Statement

Waonder is an Android-first team. The iOS app must be a structural mirror of Android, but maintaining two codebases manually is:

- **Expensive**: Every feature requires double implementation
- **Error-prone**: Structural drift between platforms is inevitable
- **Slow**: iOS always lags behind Android
- **Unsustainable**: Gabriel (the developer) is new to iOS and shouldn't need to learn platform intricacies to keep parity

The solution: treat Android as the **single source of truth** and automate the translation to iOS using AI.

---

## Goals

- Zero manual iOS coding for changes that originate on Android
- Parallel commit histories between Android and iOS repositories
- Automated build verification before any iOS commit is pushed
- Full structural parity enforced by the pipeline (modules, folders, files)
- Transparent process with clear logs and rollback capability
- Human-in-the-loop escape hatch for complex changes that need review

---

## Requirements

### Functional Requirements

- [ ] **FR-01**: Detect untranslated commits on `waonder-android` main branch (compare against baseline + translated SHAs in iOS commit messages)
- [ ] **FR-02**: Parse each commit to identify changed files, their types, and scope
- [ ] **FR-03**: Map each changed Android file to its iOS counterpart using the naming convention table from spec 002
- [ ] **FR-04**: Translate Kotlin source files to Swift using Claude AI with the appropriate android-to-ios skill
- [ ] **FR-05**: Translate Android resources (strings.xml, drawables, etc.) to iOS equivalents (.xcstrings, .xcassets)
- [ ] **FR-06**: Update iOS dependency graph (Package.swift) when Android modules change (build.gradle.kts)
- [ ] **FR-07**: Build the iOS project after translation to verify compilation
- [ ] **FR-08**: Run iOS tests after translation to verify correctness
- [ ] **FR-09**: Commit translated changes to `waonder-ios` with a mirrored commit message referencing the Android commit SHA
- [ ] **FR-10**: Push the iOS commit to remote only after build + tests pass (with developer confirmation)
- [ ] **FR-11**: Print a summary of what was translated, what succeeded, and what needs attention
- [ ] **FR-12**: Process multiple untranslated commits in a single invocation (sequential or batched)
- [ ] **FR-13**: Support re-running translation for a specific commit SHA
- [ ] **FR-17**: Support `--set-baseline <sha>` to establish the starting point after initial iOS migration
- [ ] **FR-18**: Support `--batch` to merge multiple Android commits into a single iOS commit
- [ ] **FR-14**: Handle new file creation (Android adds a new file -> iOS gets the equivalent new file)
- [ ] **FR-15**: Handle file deletion (Android deletes a file -> iOS deletes the counterpart)
- [ ] **FR-16**: Handle file rename/move (Android renames -> iOS renames with convention mapping)

### Non-Functional Requirements

- [ ] **NFR-01**: Translation of a typical commit (1-5 files) should complete in under 10 minutes
- [ ] **NFR-02**: Pipeline must be idempotent — re-running on the same commit produces the same result
- [ ] **NFR-03**: All translation decisions must be logged for auditability
- [ ] **NFR-04**: Failed translations must not corrupt the iOS repository (atomic commits)
- [ ] **NFR-05**: The pipeline must handle commits that touch C++ native code gracefully (flag for manual review)
- [ ] **NFR-06**: All translations should prioritize quality over speed — always use the best available model

---

## Architecture

### High-Level Flow

```
┌─────────────────┐     ┌──────────────────────────────────────┐     ┌─────────────────────┐
│  waonder-android │     │  Gabriel's Mac (local execution)     │     │  waonder-ios        │
│  (local repo)    │────>│                                      │────>│  (local repo)       │
│                  │     │  Claude Code CLI                     │     │                     │
└─────────────────┘     │  $ /translate-android                │     └─────────────────────┘
                         │                                      │
                         │  ┌────────────┐  ┌───────────────┐  │
                         │  │ 1. Analyze │  │ 2. Translate  │  │
                         │  │   Commits  │─>│   Files       │  │
                         │  └────────────┘  └───────────────┘  │
                         │                         │            │
                         │                         ▼            │
                         │  ┌────────────┐  ┌──────────────┐   │
                         │  │ 3. Build   │  │ 4. Commit    │   │
                         │  │   & Test   │─>│   & Push     │   │
                         │  └────────────┘  └──────────────┘   │
                         └──────────────────────────────────────┘
```

### Execution Model

The pipeline is a **Claude Code skill** (`/translate-android`) that Gabriel invokes manually from his terminal. It runs entirely on his Mac, using both local repos at their known paths:

- **Android repo**: `~/Documents/WaonderApps/waonder-android`
- **iOS repo**: `~/Documents/WaonderApps/waonder-ios` (to be created via spec 002)

There are no webhooks, no CI/CD, no cloud runners. Gabriel decides when to run it — typically after finishing a feature or bug fix on Android.

### Component Breakdown

#### 1. Trigger: Claude Code Slash Command
- Gabriel runs `/translate-android` (or `/translate-android <sha>` for a specific commit)
- The skill pulls latest on both repos, compares commit histories, and identifies untranslated commits
- No polling, no webhooks — fully on-demand

#### 2. Translation Orchestrator (Central Controller)
- Reads both local repos directly (no cloning needed)
- Identifies untranslated commits by scanning iOS commit messages for `Source: waonder-android@<sha>` tags
- Delegates to specialized agents based on file type
- Processes commits sequentially (oldest untranslated first)
- Handles success/failure/retry logic

#### 3. Commit Analyzer Agent
- Parses `git diff` for the commit
- Classifies each change: `source_code | resource | config | build | native | test`
- Maps Android file paths to iOS file paths using the convention table
- Detects structural changes (new modules, deleted folders)
- Produces a **Translation Plan** — a structured manifest of what needs translating

#### 4. Claude AI Translator Agents (the core)
Each file type gets routed to the appropriate Claude agent/skill:

| Change Type | Agent/Skill Used | Strategy |
|-------------|-----------------|----------|
| Kotlin source → Swift | `generic-android-to-ios-migration-expert` + domain-specific skill | Full AI translation with context |
| ViewModel | `generic-android-to-ios-viewmodel` | Pattern-matched translation |
| Compose UI → SwiftUI | `generic-android-to-ios-compose` + `composable` | UI framework translation |
| Repository/UseCase | `generic-android-to-ios-repository` / `usecase` | Architecture pattern translation |
| Room Entity → SwiftData | `generic-android-to-ios-room-database` | Data layer translation |
| Retrofit → URLSession | `generic-android-to-ios-retrofit` | Networking translation |
| strings.xml → .xcstrings | `generic-android-to-ios-localization` | Resource translation |
| build.gradle.kts → Package.swift | `generic-android-to-ios-gradle-modules` | Build config translation |
| Build variants / BuildConfig → xcconfig / schemes | `generic-android-to-ios-build-variants` skill + `generic-android-to-ios-environment-expert` agent | Environment & build variant translation |
| AndroidManifest → Info.plist | `generic-android-to-ios-manifest` | Config translation |
| Navigation graph | `generic-android-to-ios-navigation` | Navigation translation |
| Coroutines → Swift Concurrency | `generic-android-to-ios-coroutines` | Concurrency translation |
| Hilt DI → Protocol DI | `generic-android-to-ios-dependency-injection` skill + `generic-android-to-ios-dependency-injection-expert` agent | DI translation |
| Test files | `generic-android-to-ios-unit-testing` / `mocking` | Test translation |
| C++ / JNI | Flag for manual review | Too platform-specific for auto-translation |

**Translation Context Strategy**: Each translator agent receives:
- The Android file being translated (full content)
- The existing iOS counterpart (if updating, not creating)
- The `git diff` (what changed, to enable incremental translation)
- The iOS project's dependency context (imports, module structure)
- The naming convention mapping table
- The architectural decisions from spec 002

#### 5. Build & Test Validator
- Runs `xcodebuild` locally to compile the iOS project after translation
- Runs `swift test` for unit tests
- If build fails: feeds errors back to the translator for a retry (max 3 attempts)
- If tests fail: warns Gabriel and asks whether to commit or fix
- Xcode and simulators are already installed on Gabriel's Mac — no setup overhead

#### 6. Commit & Push Layer
- Creates an iOS commit with message format:
  ```
  [auto-translate] <original Android commit message>

  Source: waonder-android@<sha>
  Translated-by: Claude AI Pipeline
  Files-translated: <count>
  ```
- Commits locally first, then asks Gabriel for confirmation before pushing to remote
- Tags the commit with the source Android SHA for traceability

---

## Translation Modes

### Mode 1: Incremental Translation (Default)
- Triggered per-commit
- Only translates the diff (changed lines/files)
- Fast (seconds to minutes)
- Best for: feature development, bug fixes, small refactors

### Mode 2: Full File Re-translation
- Translates entire files, not just diffs
- Triggered when incremental translation fails or when drift is detected
- Slower but more accurate
- Best for: large refactors, new modules

### Mode 3: Full Repository Sync
- Re-translates the entire Android codebase to iOS from scratch
- Used for initial setup or major structural changes
- Runs the full 002 migration spec pipeline
- Best for: recovery from drift, major architectural changes

---

## Infrastructure

### Local-Only Execution

The pipeline runs entirely on Gabriel's Mac. No cloud infrastructure, no CI runners, no webhooks.

**Requirements:**
- macOS with Xcode installed (already present for iOS development)
- Claude Code CLI with an active API key
- Both repos cloned locally at their standard paths
- Internet access for `git push` and Claude API calls

**Advantages over CI/CD:**
- Zero infrastructure cost (runs on Gabriel's Mac)
- Full control over Xcode version and simulator configuration
- Immediate feedback — Gabriel sees translation output in real-time
- Can intervene mid-translation if something looks wrong
- Uses the exact same build environment as manual iOS development
- No webhook/secret management overhead

**Trade-off:**
- Not automatic — Gabriel must remember to run it after pushing Android changes
- Ties up the terminal during execution (5-15 minutes per commit)
- Cannot run while Gabriel is away (no background processing)

These trade-offs are acceptable for a solo developer workflow. If the team grows, a CI/CD layer can be added later on top of the same skills and agents.

---

## Translation Quality Assurance

### Guardrails

1. **Structural Parity Check**: After translation, verify iOS file tree matches Android (using `generic-android-to-ios-structure-expert` agent)
2. **Compilation Gate**: iOS project must compile before commit
3. **Import Validation**: All Swift imports must resolve to existing modules
4. **Naming Convention Enforcement**: File/class names follow the mapping table
5. **No Orphan Files**: Every translated file must be part of an SPM target

### Feedback Loop

When translation fails:
1. Translator agent gets the build error
2. Re-attempts translation with error context (up to 3 times)
3. If still failing: prints a detailed error report in the terminal with the failing file, error message, and suggested fix
4. Gabriel can manually fix in Xcode and re-run, or skip that commit and continue

### Drift Detection

On-demand via `/translate-android --drift-check`:
1. Compares Android and iOS file trees
2. Identifies files that exist on one platform but not the other
3. Identifies files that are out of sync (Android changed but iOS didn't)
4. Prints a drift report in the terminal

---

## Bootstrapping: The Starting Point Problem

The Android repo already has hundreds of commits. The iOS repo will be created from scratch by spec 002 (a full migration, not a commit-by-commit replay). When the pipeline starts, there is no 1:1 mapping between existing Android commits and the iOS codebase.

### Baseline Marker

When spec 002 completes the initial iOS migration, the pipeline must establish a **baseline** — the Android commit SHA that the iOS codebase is equivalent to at that point. This is done by creating a special commit in the iOS repo:

```
[auto-translate] Baseline: iOS codebase synced to Android state

Source: waonder-android@<android-sha-at-time-of-migration>
Baseline: true
```

All Android commits **before** this SHA are considered "already translated" (they were covered by the full migration). The pipeline only processes commits **after** this SHA.

### First Run

```bash
# Establish baseline (run once after spec 002 completes)
/translate-android --set-baseline <android-sha>

# From now on, only new commits after the baseline are processed
/translate-android
```

---

## Commit History Strategy

### Goal: Similar (Not Identical) Histories

The Android repo has many small, granular commits. Translating each one individually is often wasteful — some won't compile in isolation (e.g., "add model" followed by "use model in ViewModel"). The iOS repo will have **fewer, coarser commits** that batch related Android changes.

### Commit Batching

The pipeline supports two modes:

**1:1 mode** (default for isolated, self-contained commits):
```
waonder-android                    waonder-ios
─────────────────                  ──────────────────
abc1234 feat: add chat bubbles     def5678 [auto-translate] feat: add chat bubbles
                                           Source: waonder-android@abc1234
```

**Batch mode** (for sequences of small commits that form a logical unit):
```
waonder-android                    waonder-ios
─────────────────                  ──────────────────
abc1230 add ChatBubble model       def5678 [auto-translate] feat: add chat bubbles
abc1231 add ChatBubbleRepo                 Source: waonder-android@abc1230..abc1234
abc1232 add ChatBubbleUseCase              Batched: 5 Android commits
abc1233 wire ChatBubble to VM
abc1234 add ChatBubbleScreen
```

Gabriel can control this:
```bash
# Translate commits one-by-one (default)
/translate-android

# Batch all untranslated commits into a single iOS commit
/translate-android --batch

# Batch specific range
/translate-android --batch abc1230..abc1234
```

### Tracking Which Commits Are Translated

Each iOS commit message contains the source Android SHA(s). The pipeline determines untranslated commits by:

1. Scanning iOS commit messages for `Source: waonder-android@<sha>` tags
2. Comparing against the Android commit log (everything after the baseline)
3. The difference = untranslated commits

This is computed at runtime — no external state file is strictly required. The `.translation-state.json` file acts as a cache to speed this up and track statistics.

### Rules
- iOS commit message always references the Android SHA(s) it covers
- Batch mode references a range: `Source: waonder-android@<first-sha>..<last-sha>`
- If translation fails, Gabriel can skip and continue (the skipped commit stays untranslated)
- Skipped commits are tracked in `.translation-state.json` so they show up on subsequent runs

---

## Escape Hatches

Not everything can be auto-translated. The pipeline must gracefully handle:

| Scenario | Behavior |
|----------|----------|
| C++ / JNI changes | Flag for manual review, skip auto-translation |
| New Gradle module added | Create iOS SPM target skeleton, flag for review |
| Gradle plugin changes | Skip (no iOS equivalent) |
| CI/CD config changes | Skip (platform-specific) |
| Android-only files (ProGuard, etc.) | Skip |
| Translation confidence < threshold | Warn Gabriel in terminal, ask for confirmation before committing |

---

## Claude Skills & Agents Required

### New Skills to Create

| Skill | Purpose |
|-------|---------|
| `mobile-translate-android` | **Main entry point.** The `/translate-android` slash command. Orchestrates the full pipeline end-to-end locally. |
| `mobile-android-commit-analyzer` | Parse Android commits, classify changes, produce translation plan |
| `mobile-ios-build-validator` | Build iOS project locally via `xcodebuild`, run tests, report results |
| `mobile-ios-drift-detector` | Compare Android/iOS file trees, report divergences (invoked via `--drift-check` flag) |

### New Agents to Create

| Agent | Purpose |
|-------|---------|
| `mobile-android-to-ios-pipeline-orchestrator` | Master agent that runs the full pipeline |
| `mobile-android-commit-classifier` | Classifies commit changes by type and maps to iOS |
| `mobile-ios-translation-validator` | Validates translated code before commit |

### Existing Skills to Leverage (from android-to-ios-claude-plugin)

All 63 existing android-to-ios skills are available as the translation engine. The pipeline orchestrator selects the right skill(s) per file based on the commit analyzer's classification.

### Existing Agents to Leverage

- `generic-android-to-ios-migration-expert` — for complex cross-cutting translations
- `generic-android-to-ios-structure-expert` — for parity verification
- `generic-android-to-ios-build-expert` — for build system changes
- `generic-android-to-ios-environment-expert` — for build variants, xcconfig, schemes, BuildConfig → Info.plist, Firebase plist switching
- `generic-android-to-ios-dependency-injection-expert` — for DI module translation (Hilt → protocol-based DI, DependencyContainer)
- All 10 domain-specific agents for their respective areas

---

## Tasks

### Phase 1: Foundation (MVP)
- [ ] Implement `--set-baseline` command (establish starting point after spec 002 migration)
- [ ] Design the Translation Plan schema (JSON manifest format)
- [ ] Build the Commit Analyzer skill (`mobile-android-commit-analyzer`)
- [ ] Build the file-path mapping engine (Android path -> iOS path)
- [ ] Build a single-file Kotlin-to-Swift translator using Claude API
- [ ] Test translation on 10 representative Android files

### Phase 2: Pipeline Assembly
- [ ] Build the Orchestrator skill (`mobile-translate-android` — the `/translate-android` command)
- [ ] Implement untranslated commit detection (baseline + iOS commit message scanning)
- [ ] Implement sequential and batch commit processing modes
- [ ] Wire up existing android-to-ios skills as translation backends
- [ ] Build the Build Validator skill (`mobile-ios-build-validator`) using local `xcodebuild`

### Phase 3: Quality & Reliability
- [ ] Implement the retry loop (translate -> build -> fix -> retry)
- [ ] Build the Drift Detector (`mobile-ios-drift-detector`)
- [ ] Add structural parity verification post-translation
- [ ] Implement the escape hatch logic (flagging untranslatable changes)
- [ ] Add translation logging (save plans, prompts, and results to `.translation-logs/`)

### Phase 4: Polish & Reliability
- [ ] Implement translation quality metrics (success rate, retry rate per file type)
- [ ] Add `--dry-run` flag to preview what would be translated without doing it
- [ ] Add `--drift-check` flag for on-demand parity verification
- [ ] Stress test with 10+ sequential untranslated commits
- [ ] Document common failure scenarios and recovery steps

---

## Dependencies

- **Spec 002** (Android-to-iOS Full Migration): iOS codebase must exist before the pipeline can operate
- **Gabriel's Mac** with Xcode and simulators installed
- **Claude Code CLI** with an active Anthropic API key
- **Both repositories cloned locally**: `~/Documents/WaonderApps/waonder-android` and `~/Documents/WaonderApps/waonder-ios`
- **Git push access** to both remotes

---

## Success Criteria

1. Running `/translate-android` translates untranslated commits and produces compiling iOS code
2. The iOS project compiles locally after every auto-translated commit
3. Majority of Android commits are translated without manual intervention
4. Commit histories are traceable between platforms (Android SHA referenced in iOS commits)
5. Structural parity is maintained (drift check shows 0 unmatched files)
6. Minimal iOS coding required for standard feature development

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| AI translation quality insufficient | Broken iOS builds | Build gate + retry loop + human review escape hatch |
| C++ native code changes | Cannot auto-translate | Skip + flag for manual review |
| Large refactors produce too many changes | Timeout or token limits | Chunk large commits, use full-file mode |
| Translation quality degrades over time | Subtle iOS bugs | Quality metrics tracking + periodic full-repo re-sync |
| Multiple untranslated commits pile up | Long translation session | Batch processing + skip-and-continue option |
| Translation drift accumulates | Subtle bugs | Weekly drift detection + full-sync recovery mode |

---

## Notes

- This pipeline is the logical next step after spec 002 completes the initial migration
- The existing 63 android-to-ios skills and 8 agents are the foundation — the pipeline orchestrates them
- Start with MVP (single-file translation + manual trigger) before automating the full loop
- The "similar enough" commit history is acceptable — exact SHA matching is not required
- Consider recording translation decisions as a knowledge base to improve future translations
