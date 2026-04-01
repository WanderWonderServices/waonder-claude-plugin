# Project Rules

## Plugin Identity
- Plugin name: `waonder-claude-plugin`
- Marketplace name: `waonder-plugins`
- Skill prefix: `waonder-claude-plugin:<skill-name>`
- This plugin is exclusively for Waonder apps (mobile, backend, infrastructure)

## Skill Naming Convention
- Format: `<domain>[-<platform>]-<name>` in kebab-case
- Domains: `mobile` (ios, android, web), `backend` (services, infrastructure, database), `generic`
- Folder name must match the `name` field in SKILL.md frontmatter

## Waonder Android App
- Local path: `~/Documents/WaonderApps/waonder-android`
- GitHub: `https://github.com/WanderWonderServices/waonder-android`
- Language: Kotlin
- When users ask about "the app" or "the Android app", this is the target project
- Use `generic-android-waonder-app-info` skill for full reference

## String Localization — Mandatory on Both Platforms

**ZERO TOLERANCE for hardcoded user-facing strings in source code.** This is a code defect, not a style preference.

### Android Pattern (source of truth)
- All user-facing text MUST be in `strings.xml` (per-module or app-level)
- Code references via `stringResource(R.string.key)` in Compose
- Compile-time safety via `R.string.*` resource IDs

### iOS Pattern (must match Android)
- All user-facing text MUST be in `Localizable.strings` (or `.xcstrings` String Catalog when migrated)
- Code references via `String(localized: "key")` for programmatic strings
- SwiftUI `Text("key")` auto-resolves localization keys from `Localizable.strings`
- NEVER use `Text("Some hardcoded English text")` in a View — this is a defect
- NEVER use `Text(verbatim: "user-facing text")` — `verbatim:` is only for non-localizable content (IDs, codes)

### Enforcement Rules
- Every agent that creates or modifies iOS feature code MUST verify string localization
- `mobile-resource-parity-expert` MUST audit iOS source files for hardcoded strings, not just check `Localizable.strings` exists
- `mobile-ios-test-sync-expert` MUST reject any iOS feature code with hardcoded user-facing strings
- `generic-mobile-automation-test-sync` Phase 3 MUST include source code string audit, not just resource file parity

### String Key Convention
- Keys match across platforms: `onboarding_moment1_hero` in both `strings.xml` and `Localizable.strings`
- Prefix with feature area: `onboarding_`, `auth_`, `settings_`, `home_`
- Values MUST match exactly between platforms (same English text)

## Never use
- The `ai` wrapper (`ai.sh`)
- The `/reload` command
- The `/setup-ai` skill
