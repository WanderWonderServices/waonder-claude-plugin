# Review: Developer Experience & Operations

**Reviewer**: Developer Experience & Operations Analyst (AI Agent)
**Date**: 2026-03-26
**Status**: Complete

---

## 1. Day-in-the-Life Walkthrough

**The promised flow:** Gabriel writes Kotlin, pushes to main, iOS app updates automatically.

**What actually happens:**
- **Morning:** Push a commit. Pipeline triggers. ~10 minutes. Works.
- **Mid-morning:** Two quick commits in succession. Queue processes sequentially. ~20 minute lag.
- **Afternoon:** Translation fails. Gabriel gets a GitHub Issue. Must read Swift build errors (a language he's learning), decide whether to fix iOS code manually or adjust Android and re-push. **This is where the promise breaks.**
- **End of day:** 5 commits pushed. 4 succeeded. 1 stuck as a GitHub Issue. **Pipeline is now blocked** — iOS repo falls behind until the failure is resolved.

**Manual steps still required despite "full automation":**
- Reading/triaging GitHub Issues for failed translations
- Understanding xcodebuild errors in an unfamiliar language
- Manually fixing Swift code when retry loop exhausts
- Resolving blocked queue before normal flow resumes
- Weekly drift report review
- macOS runner maintenance (Xcode updates, disk space, simulator versions)

---

## 2. Failure Recovery UX

**Gabriel's experience when translation fails is poor:**
- GitHub Issue says "check the workflow run" but doesn't include the actual error or the file that failed.
- Must click through to Actions, find the right step, scroll through verbose xcodebuild logs.
- No "one-click retry" mechanism described.
- Translation Plan JSON exists only in `/tmp/` on ephemeral CI runner — gone after job ends.
- Cannot see what prompt was sent to Claude or what Claude generated.

**Can Gabriel get stuck?**
- Yes. The blocking queue policy means a single hard failure stops ALL iOS progress. If the failure requires understanding a Swift concept Gabriel doesn't know yet, he could be stuck for hours or days. No "skip and continue" option exists by design.

---

## 3. Observability Gaps

**Gabriel cannot tell at a glance if Android and iOS are in sync.** Missing:

- **Sync status badge** on both repos ("iOS sync: current" or "3 commits behind")
- **Positive notifications** on success (not just failure alerts)
- **Cost dashboard** — could burn API credits with no visibility
- **Pipeline health metrics** — success rate, translation time, retry rate, queue depth
- **Per-commit drift check** — weekly is too slow; should run after every translation

**Silent failure modes:**
- Tests always pass through (`continue-on-error: true`) — test suite could be completely broken and nobody knows.
- Webhook stops firing (secret expiry, misconfiguration) — commits stop translating with no alert.
- API key expires or hits rate limits — pipeline fails silently unless Actions tab is checked.

---

## 4. Onboarding & Learning Curve

**Initial setup is a full day minimum:**
- macOS CI runner with Xcode
- Claude API key with quota
- iOS repo token as GitHub secret
- iOS codebase from spec 002 must exist first
- Xcode project must build from CLI (scheme sharing, simulator config)
- SPM dependencies resolvable on CI

**9 distinct systems Gabriel must understand:**
GitHub Actions YAML, webhook/secret config, Claude Code CLI, xcodebuild flags, Translation Plan JSON schema, module mapping table, retry/failure flow, state file, drift detection.

**When things change:**
- New Android module: must manually update mapping table + create SPM target + add to Package.swift.
- New third-party dependency: pipeline translates Kotlin code referencing a framework that doesn't exist on iOS.

---

## 5. Edge Cases That Will Frustrate the Developer

**1. "Import hell" cascade.** AI generates wrong imports. Build fails. Retry adds both imports. Build succeeds but architectural purity degrades. Accumulates silently.

**2. "Big refactor" wall.** Renaming a package across 30 files. Exceeds timeout or produces inconsistent old/new names. Must manually rename 30 Swift files.

**3. "Context window bomb."** DependencyContainer.swift grows to 800+ lines. Exceeds practical context limits, produces degraded translations on the most critical file.

**4. "Test suite graveyard."** 3 months of `continue-on-error: true` = 47 failing tests nobody noticed. Stakeholder asks "do iOS tests pass?" — answer is no.

**5. "iOS-only bug."** ViewModel translates syntactically correct but SwiftUI observation behavior differs. UI doesn't update. Compiles, passes tests, ships broken.

**6. "Blocked queue snowball."** Friday failure + weekend commits = Monday morning with 3+ blocked translations that may cascade.

**7. "Xcode update breaks everything."** Apple releases new Xcode. Simulator names change. Every translation fails until CI config is updated.

---

## 6. Operations Burden

**Ongoing maintenance:**
- Xcode/simulator updates (2-3x/year, potentially breaking)
- Claude API model changes (prompt tuning may be needed)
- macOS runner maintenance (OS updates, disk cleanup, Xcode license)
- Secret rotation (API keys, repo tokens)
- Module mapping table updates (every new Android module)
- Cost monitoring (no dashboard in MVP)

**Needed runbooks not documented:**
1. Pipeline blocked — how to unblock
2. iOS N commits behind — how to catch up
3. xcodebuild fails on CI but works locally
4. Translation wrong — how to override manually
5. New Android module — what to update
6. API key expired — how to rotate
7. macOS runner disk full — how to clean
8. State file corrupted — how to reset

---

## 7. Top 5 DX Improvements

**1. Add "skip and reconcile" mode to the queue.**
Don't block the entire queue on one failure. Skip the failed commit, continue processing, flag for reconciliation. This prevents the Monday-morning snowball. The blocking design is the single biggest operational risk.

**2. Build a sync status CLI command and dashboard.**
`claude -p "sync status"` should show: last Android SHA, last iOS SHA, commits pending, commits failed, test pass rate, cost this month. Also a GitHub badge on both repos. Without this, Gabriel is flying blind.

**3. Persist all translation artifacts.**
Save Translation Plan JSON, Claude prompts, raw AI responses, build logs, and final Swift output as GitHub Actions artifacts. When debugging, Gabriel should see exactly what happened without re-running anything.

**4. Treat test failures as first-class signals.**
Remove `continue-on-error: true`. If tests fail, commit to a PR branch (not main), create a PR with test failures highlighted. Prevents the test graveyard.

**5. Automate new-module scaffolding end-to-end.**
When Commit Analyzer detects a new Gradle module: add to mapping table, create SPM target in Package.swift, create directory structure, add to Xcode project, then proceed with file translation. New modules shouldn't require manual intervention.
