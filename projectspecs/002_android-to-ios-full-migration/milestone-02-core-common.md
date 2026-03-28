# Milestone 02: Core Common & Extensions

**Status:** Not Started
**Dependencies:** Milestone 01
**Android Module:** `:core:common` + shared extensions from `:core:domain`
**iOS Target:** `CoreCommon`

---

## Objective

Migrate all shared utilities, extension functions, and base types that are used across every other module. This is the foundational layer with zero internal dependencies.

---

## Deliverables

### 1. Extensions (from `core/domain/src/.../core/extensions/`)
- [ ] Migrate all Kotlin extension functions to Swift extensions
- [ ] Organize into `Extensions/` folder with one file per extended type

### 2. Result Wrappers (from `core/domain/src/.../core/result/`)
- [ ] Migrate custom Result types to Swift
- [ ] Use Swift's native `Result<Success, Failure>` where appropriate
- [ ] Create custom result wrappers only where Android has domain-specific ones

### 3. Utility Types
- [ ] Any shared constants from `core/common/`
- [ ] Logger protocol definition (implementation in CoreDataLayer)

---

## File Mapping

| Android | iOS |
|---------|-----|
| `core/extensions/*.kt` | `Sources/CoreCommon/Extensions/*.swift` |
| `core/result/*.kt` | `Sources/CoreCommon/Result/*.swift` |
| `core/common/*.kt` | `Sources/CoreCommon/*.swift` |

---

## Verification

- [ ] `CoreCommon` target compiles
- [ ] All extension functions have Swift equivalents
- [ ] No external dependencies (pure Swift)
