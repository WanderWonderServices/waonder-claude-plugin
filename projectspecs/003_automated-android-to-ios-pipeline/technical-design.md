# Technical Design: Automated Android-to-iOS Translation Pipeline

**Parent**: 003_automated-android-to-ios-pipeline/spec.md
**Created**: 2026-03-26

---

## 1. System Architecture

### 1.1 Component Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                     Gabriel's Mac (local execution)                   │
│                                                                      │
│  $ /translate-android                                                │
│                                                                      │
│  ┌─────────────────┐     ┌──────────────────────────────────────┐   │
│  │ waonder-android  │     │  Translation Orchestrator            │   │
│  │ ~/WaonderApps/   │────>│  (Claude Code skill)                │   │
│  │ waonder-android  │     │                                      │   │
│  └─────────────────┘     │  ┌────────────┐  ┌───────────────┐  │   │
│                           │  │ 1. Analyze │  │ 2. Plan       │  │   │
│                           │  │   Commits  │─>│   Translation │  │   │
│                           │  └────────────┘  └───────────────┘  │   │
│                           │         │                │           │   │
│                           │         ▼                ▼           │   │
│                           │  ┌─────────────────────────────┐    │   │
│                           │  │ 3. Translate (Sub-Agents)   │    │   │
│                           │  │  ┌─────────┐ ┌─────────┐   │    │   │
│                           │  │  │ File A  │ │ File B  │   │    │   │
│                           │  │  └─────────┘ └─────────┘   │    │   │
│                           │  └─────────────────────────────┘    │   │
│  ┌─────────────────┐     │         │                            │   │
│  │ waonder-ios      │<────│  ┌────────────┐ ┌──────────────┐   │   │
│  │ ~/WaonderApps/   │     │  │ 4. Build   │ │ 5. Commit    │   │   │
│  │ waonder-ios      │     │  │   & Test   │─│   & Push     │   │   │
│  └─────────────────┘     │  └────────────┘ └──────────────┘   │   │
│                           └──────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────┘
```

### 1.2 Data Flow

```
Android Commit (SHA: abc1234)
    │
    ▼
git diff abc1234~1..abc1234
    │
    ▼
Translation Plan (JSON)
    │
    ├── file_changes[0]: {
    │     android: "core/domain/.../ChatMessage.kt",
    │     ios: "Sources/CoreDomain/Models/Chat/ChatMessage.swift",
    │     type: "source_code",
    │     action: "modify",
    │     skill: "generic-android-to-ios-coroutines",
    │     diff: "... changed lines ..."
    │   }
    │
    ├── file_changes[1]: { ... }
    │
    └── file_changes[N]: { ... }
    │
    ▼
Per-file Claude API translation calls (parallel where independent)
    │
    ▼
Translated Swift files written to local ~/WaonderApps/waonder-ios/
    │
    ▼
xcodebuild (local Mac — same Xcode Gabriel uses daily)
    │
    ├── SUCCESS → git commit locally → ask Gabriel to confirm push
    └── FAILURE → retry with error context (up to 3x) → print error report
```

---

## 2. Translation Plan Schema

The Translation Plan is the central data structure. The Commit Analyzer produces it; the Orchestrator consumes it.

```json
{
  "version": "1.0",
  "source": {
    "repo": "waonder-android",
    "branch": "main",
    "commit_sha": "abc1234def5678...",
    "commit_message": "feat: add chat bubble animations",
    "author": "gabriel@waonder.app",
    "timestamp": "2026-03-26T14:30:00Z"
  },
  "analysis": {
    "total_files_changed": 5,
    "translatable": 4,
    "skippable": 1,
    "requires_review": 0
  },
  "file_changes": [
    {
      "id": "change-001",
      "action": "modify",
      "android_path": "core/domain/src/main/java/com/app/waonder/domain/models/chat/ChatMessage.kt",
      "ios_path": "Sources/CoreDomain/Models/Chat/ChatMessage.swift",
      "ios_module": "CoreDomain",
      "change_type": "source_code",
      "classification": "model",
      "skills_required": [],
      "diff_summary": "Added 'animationType' property to ChatMessage data class",
      "diff": "...",
      "dependencies": [],
      "translation_mode": "incremental",
      "priority": 1
    },
    {
      "id": "change-002",
      "action": "create",
      "android_path": "core/design/src/main/java/com/app/waonder/design/components/ChatBubbleAnimation.kt",
      "ios_path": "Sources/CoreDesign/Components/ChatBubbleAnimation.swift",
      "ios_module": "CoreDesign",
      "change_type": "source_code",
      "classification": "ui_component",
      "skills_required": ["generic-android-to-ios-compose", "generic-android-to-ios-composable"],
      "diff_summary": "New Composable for chat bubble entrance animation",
      "diff": "...",
      "dependencies": ["change-001"],
      "translation_mode": "full_file",
      "priority": 2
    },
    {
      "id": "change-003",
      "action": "skip",
      "android_path": "app/proguard-rules.pro",
      "ios_path": null,
      "change_type": "config",
      "classification": "android_only",
      "skip_reason": "ProGuard rules have no iOS equivalent"
    }
  ],
  "execution_order": ["change-001", "change-002"],
  "estimated_tokens": 15000,
  "estimated_files": 4
}
```

---

## 3. File Path Mapping Engine

### 3.1 Algorithm

```
Input:  Android file path (relative to repo root)
Output: iOS file path (relative to repo root) + iOS module name

Steps:
1. Extract Android module from path:
   "core/domain/src/main/java/com/app/waonder/domain/..." → module = ":core:domain"

2. Look up iOS module in mapping table:
   ":core:domain" → "CoreDomain"

3. Extract the package-relative path:
   ".../domain/models/chat/ChatMessage.kt" → "models/chat/ChatMessage.kt"

4. Apply folder naming conventions:
   "models/" → "Models/"
   "chat/" → "Chat/"

5. Apply file naming conventions:
   "ChatMessage.kt" → "ChatMessage.swift"
   (special cases: *Entity.kt → *Model.swift, *Dao.kt → *Store.swift, etc.)

6. Assemble iOS path:
   "Sources/CoreDomain/Models/Chat/ChatMessage.swift"
   OR
   "WaonderApp/..." (for app module files)
```

### 3.2 Module Mapping Table

Extracted from spec 002, encoded as a lookup:

```json
{
  ":waonder": { "ios_target": "WaonderApp", "path_prefix": "WaonderApp/" },
  ":core:common": { "ios_target": "CoreCommon", "path_prefix": "WaonderModules/Sources/CoreCommon/" },
  ":core:domain": { "ios_target": "CoreDomain", "path_prefix": "WaonderModules/Sources/CoreDomain/" },
  ":core:data": { "ios_target": "CoreDataLayer", "path_prefix": "WaonderModules/Sources/CoreDataLayer/" },
  ":core:design": { "ios_target": "CoreDesign", "path_prefix": "WaonderModules/Sources/CoreDesign/" },
  ":core:map-ui": { "ios_target": "CoreMapUI", "path_prefix": "WaonderModules/Sources/CoreMapUI/" },
  ":feature:onboarding": { "ios_target": "FeatureOnboarding", "path_prefix": "WaonderModules/Sources/FeatureOnboarding/" },
  ":feature:permissions": { "ios_target": "FeaturePermissions", "path_prefix": "WaonderModules/Sources/FeaturePermissions/" },
  ":feature:placedetails": { "ios_target": "FeaturePlaceDetails", "path_prefix": "WaonderModules/Sources/FeaturePlaceDetails/" },
  ":feature:remote-visit": { "ios_target": "FeatureRemoteVisit", "path_prefix": "WaonderModules/Sources/FeatureRemoteVisit/" },
  ":feature:settings": { "ios_target": "FeatureSettings", "path_prefix": "WaonderModules/Sources/FeatureSettings/" },
  ":feature:developer": { "ios_target": "FeatureDeveloper", "path_prefix": "WaonderModules/Sources/FeatureDeveloper/" },
  ":feature:errors": { "ios_target": "FeatureErrors", "path_prefix": "WaonderModules/Sources/FeatureErrors/" },
  ":feature:theme": { "ios_target": "FeatureTheme", "path_prefix": "WaonderModules/Sources/FeatureTheme/" },
  ":feature:session": { "ios_target": "FeatureSession", "path_prefix": "WaonderModules/Sources/FeatureSession/" },
  ":map_engine_v2": { "ios_target": "MapEngineV2", "path_prefix": "WaonderModules/Sources/MapEngineV2/" },
  ":fog-scene": { "ios_target": "FogScene", "path_prefix": "WaonderModules/Sources/FogScene/" },
  ":shared-rendering": { "ios_target": "SharedRendering", "path_prefix": "WaonderModules/Sources/SharedRendering/" }
}
```

### 3.3 File Naming Conventions (Encoded)

```json
{
  "file_suffix": { ".kt": ".swift" },
  "file_patterns": {
    "*Screen.kt": "*View.swift",
    "*Entity.kt": "*Model.swift",
    "*Dao.kt": "*Store.swift",
    "*Dto.kt": "*DTO.swift",
    "*ApiService.kt": "*API.swift"
  },
  "folder_patterns": {
    "model/": "Models/",
    "models/": "Models/",
    "repository/": "Repositories/",
    "usecase/": "UseCases/",
    "components/": "Components/",
    "di/": "DI/"
  }
}
```

---

## 4. Translation Engine Design

### 4.1 Skill Selection Algorithm

Given a file's classification and content, select the right Claude skill(s):

```
Input: file_change from Translation Plan
Output: list of skill identifiers to invoke

Rules (evaluated in order, first match wins):
1. If classification == "viewmodel" → ["generic-android-to-ios-viewmodel"]
2. If classification == "composable" → ["generic-android-to-ios-composable", "generic-android-to-ios-state-management"]
3. If classification == "screen" → ["generic-android-to-ios-compose", "generic-android-to-ios-navigation"]
4. If classification == "repository_interface" → ["generic-android-to-ios-repository"]
5. If classification == "repository_impl" → ["generic-android-to-ios-repository", "generic-android-to-ios-dependency-injection"] + agent: dependency-injection-expert
6. If classification == "usecase" → ["generic-android-to-ios-usecase"]
7. If classification == "room_entity" → ["generic-android-to-ios-room-database"]
8. If classification == "room_dao" → ["generic-android-to-ios-room-database"]
9. If classification == "retrofit_service" → ["generic-android-to-ios-retrofit"]
10. If classification == "data_source" → ["generic-android-to-ios-local-datasource"] or ["generic-android-to-ios-remote-datasource"]
11. If classification == "test" → ["generic-android-to-ios-unit-testing", "generic-android-to-ios-mocking"]
12. If classification == "navigation" → ["generic-android-to-ios-navigation"]
13. If classification == "di_module" → ["generic-android-to-ios-dependency-injection"] + agent: dependency-injection-expert
14. If classification == "build_config" or "build_variant" → ["generic-android-to-ios-build-variants"] + agent: environment-expert
15. If file contains coroutine patterns → add "generic-android-to-ios-coroutines"
16. If file contains Flow patterns → add "generic-android-to-ios-flows"
17. If file contains StateFlow → add "generic-android-to-ios-stateflow"
18. Default → ["generic-android-to-ios-migration-expert"] (general-purpose fallback)
```

### 4.2 Translation Prompt Template

Each file translation uses this structured prompt to Claude:

```
You are translating Android Kotlin code to iOS Swift for the Waonder app.

## Context
- Source repo: waonder-android
- Target repo: waonder-ios
- iOS minimum: iOS 17+
- Architecture: Clean Architecture + MVVM + Unidirectional Data Flow

## Architectural Decisions
[Insert binding decisions from spec 002, Section 2]

## Naming Conventions
[Insert naming mapping table from spec 002, Section 3]

## Source File
Path: {android_path}
Module: {android_module}

```kotlin
{full_kotlin_file_content}
```

## What Changed (diff)
```diff
{git_diff_for_this_file}
```

## Existing iOS File (if updating)
Path: {ios_path}
Module: {ios_module}

```swift
{existing_swift_file_content_or_"NEW FILE"}
```

## Instructions
{For incremental mode:}
Apply ONLY the changes shown in the diff to the existing iOS file. Do not re-translate unchanged code.

{For full-file mode:}
Translate the entire Kotlin file to Swift. Follow the architectural decisions and naming conventions exactly.

## Output
Return ONLY the complete Swift file content. No explanations, no markdown fences, no comments about the translation.
```

### 4.3 Incremental vs Full-File Translation

**Incremental** (default for `modify` actions):
- Send the diff + existing iOS file
- Ask Claude to apply only the delta
- Faster, preserves manual iOS adjustments
- Risk: context loss if the diff is complex

**Full-file** (for `create` actions or when incremental fails):
- Send the complete Kotlin file
- Ask Claude to produce the complete Swift file
- Slower, but more accurate
- Used as fallback when incremental produces build errors

### 4.4 Parallel Translation Strategy

Files are translated in parallel when they have no dependencies:

```
Translation Plan execution_order: [change-001, change-002, change-003]
Dependencies: change-002 depends on change-001

Execution:
  Batch 1 (parallel): [change-001, change-003]  ← no dependencies between them
  Batch 2 (after batch 1): [change-002]           ← depends on change-001
```

This is computed via topological sort on the dependency graph.

---

## 5. Build Validation Pipeline

### 5.1 Build Command (Local)

Runs on Gabriel's Mac using his local Xcode installation:

```bash
cd ~/Documents/WaonderApps/waonder-ios

# Build to catch all issues (incremental — faster since Gabriel builds regularly)
xcodebuild build \
  -project waonder-ios.xcodeproj \
  -scheme Waonder-Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0' \
  -quiet \
  2>&1 | tee .translation-logs/build.log

# If build succeeds, run tests
xcodebuild test \
  -project waonder-ios.xcodeproj \
  -scheme Waonder-Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0' \
  -quiet \
  2>&1 | tee .translation-logs/test.log
```

Note: We use incremental build (not `clean build`) because Gabriel's Mac has a warm build cache. This cuts build time from 5-8 minutes to 1-3 minutes for typical changes.

### 5.2 Error Recovery Loop

```
attempt = 0
max_attempts = 3

while attempt < max_attempts:
    translate(plan)
    result = build()

    if result.success:
        commit_and_push()
        break

    attempt += 1
    errors = parse_build_errors(result.log)

    for error in errors:
        file = error.file
        # Re-translate the failing file with error context
        re_translate(file, error_message=error.message, previous_attempt=file.content)

if attempt == max_attempts:
    print_error_report(plan, errors)
    ask_gabriel("Translation failed after 3 attempts. Skip this commit or fix manually?")
```

### 5.3 Build Error Classification

| Error Type | Recovery Strategy |
|-----------|-------------------|
| Missing import | Add import based on iOS module mapping |
| Type mismatch | Re-translate file with type context |
| Missing protocol conformance | Re-translate with protocol definition context |
| Ambiguous reference | Add module qualifier |
| Missing file | Check if the file should have been created |
| SPM dependency missing | Update Package.swift |

---

## 6. Local CLI Invocation Design

### 6.1 Slash Command: `/translate-android`

The primary entry point is a Claude Code skill invoked as a slash command.

**Usage:**
```bash
# Translate all untranslated commits
/translate-android

# Translate a specific commit
/translate-android abc1234

# Preview what would be translated (no changes)
/translate-android --dry-run

# Check structural parity between repos
/translate-android --drift-check

# Translate with full-file mode (no incremental)
/translate-android --full
```

### 6.2 Bootstrapping & Baseline

The Android repo has hundreds of existing commits. The iOS repo is created from scratch by spec 002. On first run, the pipeline needs to know: **where does the Android history start for translation purposes?**

**Setting the baseline (one-time, after spec 002 completes):**

```bash
/translate-android --set-baseline

# This does:
# 1. Reads the current HEAD of waonder-android
# 2. Creates a commit in waonder-ios:
#    "[auto-translate] Baseline: iOS codebase synced to Android state
#     Source: waonder-android@<current-android-HEAD>
#     Baseline: true"
# 3. All Android commits BEFORE this SHA are considered "already covered"
# 4. Only commits AFTER this SHA will be processed by future runs
```

Gabriel can also specify an explicit SHA if the iOS migration was done against an older Android state:

```bash
/translate-android --set-baseline abc1234
```

### 6.3 Untranslated Commit Detection

```bash
# 1. Pull latest on both repos
cd ~/Documents/WaonderApps/waonder-android && git pull
cd ~/Documents/WaonderApps/waonder-ios && git pull

# 2. Find the baseline SHA from iOS commit messages
BASELINE_SHA=$(git -C ~/Documents/WaonderApps/waonder-ios log --format='%b' main \
  | grep 'Baseline: true' -B1 \
  | grep 'Source: waonder-android@' \
  | head -1 \
  | sed 's/Source: waonder-android@//')

# 3. Get Android commits AFTER the baseline (chronological order)
ANDROID_SHAS=$(git -C ~/Documents/WaonderApps/waonder-android log --format='%H' --reverse ${BASELINE_SHA}..main)

# 4. Get already-translated SHAs from iOS commit messages (handles both single and range references)
TRANSLATED_SHAS=$(git -C ~/Documents/WaonderApps/waonder-ios log --format='%b' main \
  | grep 'Source: waonder-android@' \
  | sed 's/Source: waonder-android@//')
# For range references (abc..def), expand to all commits in range

# 5. Diff to find untranslated commits
UNTRANSLATED=$(comm -23 <(echo "$ANDROID_SHAS" | sort) <(echo "$TRANSLATED_SHAS" | sort))
```

### 6.4 Interactive Flow

Since the pipeline runs locally, Gabriel sees real-time output:

```
$ /translate-android

Pulling latest on waonder-android... done (at abc1234)
Pulling latest on waonder-ios... done (at def5678)
Baseline: waonder-android@aaa0000 (set 2026-03-20)

Found 5 untranslated commits:
  1. abc1230 add ChatBubble model (1 file)
  2. abc1231 add ChatBubbleRepo (1 file)
  3. abc1232 add ChatBubbleUseCase (1 file)
  4. abc1233 wire ChatBubble to VM (2 files)
  5. abc1234 add ChatBubbleScreen (2 files)

These 5 commits look like a related sequence. Batch into 1 iOS commit? [y/n/custom]
> y

Translating batch abc1230..abc1234 (7 total files)
  Analyzing combined diff... 7 files changed (6 translatable, 1 skip)
  Translating ChatBubble.swift... done (new file)
  Translating ChatBubbleRepositoryProtocol.swift... done (new file)
  Translating ChatViewModel.swift... done
  Skipping proguard-rules.pro (android-only)
  Building iOS project... SUCCESS
  Running tests... 12 passed, 0 failed
  Committing: [auto-translate] feat: add chat bubble animations

Translating commit 2/3: abc1232 fix: chat scroll position reset
  ...

All 3 commits translated successfully.
Push 3 commits to waonder-ios remote? [y/n]
```

### 6.4 Advantages of Local Execution

| Aspect | Local (chosen) | CI/CD (rejected) |
|--------|---------------|-----------------|
| Infrastructure cost | None | macOS runners required |
| Setup complexity | Minimal (repos already cloned) | High (secrets, runners, webhooks) |
| Feedback loop | Real-time in terminal | Check Actions tab after delay |
| Intervention | Can fix mid-translation | Must wait for failure, re-trigger |
| Xcode version | Always matches dev environment | Must be managed separately |
| Build cache | Warm (Gabriel builds iOS regularly) | Cold start every run |
| Secrets | Local API key already configured | Must manage in GitHub |

---

## 7. Claude Code Agent Design

### 7.1 Pipeline Orchestrator Agent

This is the master agent invoked by the `/translate-android` skill. It runs locally on Gabriel's Mac.

```markdown
# mobile-android-to-ios-pipeline-orchestrator

## Role
You are the automated translation pipeline orchestrator for the Waonder app.
You coordinate the end-to-end process of translating Android commits to iOS.
You run locally on the developer's Mac with direct access to both repos.

## Tools Available
- Read/Write/Edit for file operations on both local repos
- Bash for git commands and local xcodebuild
- Agent for spawning parallel translator sub-agents
- All android-to-ios skills for translation knowledge

## Repo Paths
- Android: ~/Documents/WaonderApps/waonder-android
- iOS: ~/Documents/WaonderApps/waonder-ios

## Workflow
1. Pull latest on both repos
2. Identify untranslated commits (compare Android log vs iOS commit messages)
3. For each untranslated commit (oldest first):
   a. Analyze the commit diff
   b. Produce a Translation Plan
   c. Execute translations (spawn parallel agents per file)
   d. Write translated files to local iOS repo
   e. Verify build with local xcodebuild
   f. If build fails, iterate (re-translate failing files with error context)
   g. Commit locally to iOS repo
4. Print summary and ask Gabriel to confirm push
```

### 7.2 File Translator Agent (spawned per file)

```markdown
# Spawned by orchestrator, one per file

## Input
- Android file path and content
- iOS target path
- Git diff for this file
- Existing iOS file content (if any)
- Skill context to apply

## Output
- Translated Swift file content
- Confidence score (high/medium/low)
- Any warnings or notes

## Process
1. Load the relevant android-to-ios skill context
2. Apply the translation prompt template
3. Validate the output (basic Swift syntax check)
4. Return the result
```

---

## 8. State Management

### 8.1 Translation State File

Persisted between runs to track pipeline state:

```json
{
  "version": "1.0",
  "baseline": {
    "android_sha": "aaa0000...",
    "set_at": "2026-03-20T10:00:00Z",
    "description": "iOS codebase created via spec 002 full migration"
  },
  "last_translated_android_sha": "abc1234...",
  "last_ios_commit_sha": "def5678...",
  "skipped_commits": [
    {
      "android_sha": "...",
      "reason": "Build error in ChatBubbleAnimation.swift — skipped by Gabriel",
      "attempts": 3,
      "skipped_at": "2026-03-25T14:30:00Z"
    }
  ],
  "batched_translations": [
    {
      "ios_commit_sha": "def5678...",
      "android_range": "abc1230..abc1234",
      "android_shas": ["abc1230", "abc1231", "abc1232", "abc1233", "abc1234"],
      "translated_at": "2026-03-25T15:00:00Z"
    }
  ],
  "statistics": {
    "total_translations": 127,
    "successful": 119,
    "skipped": 8,
    "total_files_translated": 483,
    "avg_files_per_translation": 3.8
  }
}
```

### 8.2 Where to Store State

The state file is **not strictly required** for local execution because the pipeline can always recompute untranslated commits by comparing Android and iOS commit histories. However, it is useful for:
- Tracking statistics (success rate, retry rate)
- Remembering failed translations that were skipped
- Quick startup without scanning all commit messages

**Storage**: `.translation-state.json` in the iOS repo (committed). Since the pipeline runs locally and sequentially, there are no race conditions.

---

## 9. MVP Scope (What to Build First)

### MVP = `/translate-android <sha>` for a single commit

1. Gabriel runs `/translate-android abc1234` in Claude Code
2. The skill reads the commit diff from the local Android repo
3. Identifies changed Kotlin files, maps to iOS paths
4. Translates each file using Claude API (Sonnet) via sub-agents
5. Writes translated files to the local iOS repo
6. Runs `xcodebuild` locally
7. If green: commits locally and asks Gabriel to confirm push
8. If red: prints the errors and asks Gabriel what to do

This is a single Claude Code skill (`mobile-translate-android`) that runs entirely locally. No infrastructure to set up beyond what Gabriel already has (Claude Code CLI + Xcode + both repos cloned).
