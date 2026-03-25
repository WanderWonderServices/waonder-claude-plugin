---
name: generic-android-waonder-app-info
description: Quick reference for the Waonder Android application — local path, GitHub repo, tech stack, and project structure for migration and development tasks
type: generic
---

# generic-android-waonder-app-info

## Context

This skill provides the definitive reference for locating and understanding the Waonder Android application. Use it whenever questions relate to the Android app codebase, its structure, dependencies, or when performing Android-to-iOS migration tasks that need to reference the actual source code.

## Application Reference

| Field | Value |
|-------|-------|
| **Local path** | `~/Documents/WaonderApps/waonder-android` |
| **GitHub repo** | [WanderWonderServices/waonder-android](https://github.com/WanderWonderServices/waonder-android) |
| **Language** | Kotlin |
| **Default branch** | `main` |
| **Visibility** | Private |
| **Platform** | Android (native) |

## How to Access the Code

### Local (preferred for reading/editing)
```
~/Documents/WaonderApps/waonder-android
```
Use this path when reading files, exploring structure, or making changes. This is the primary working copy.

### Remote (for PRs, issues, CI, history)
```
https://github.com/WanderWonderServices/waonder-android
```
Use this URL with `gh` CLI commands for pull requests, issues, actions, and remote operations:
```bash
# View open PRs
gh pr list --repo WanderWonderServices/waonder-android

# View recent commits
gh api repos/WanderWonderServices/waonder-android/commits --jq '.[].commit.message' | head -10

# View open issues
gh issue list --repo WanderWonderServices/waonder-android
```

## Instructions

When this skill is activated:

1. **Set context** — The Waonder Android app lives at `~/Documents/WaonderApps/waonder-android` locally and at `https://github.com/WanderWonderServices/waonder-android` on GitHub
2. **Explore locally first** — Always read code from the local path for speed and accuracy
3. **Use GitHub for collaboration** — PRs, issues, CI status, and code reviews happen on GitHub
4. **Detect project structure** — On first use, explore the project to understand its module layout, build configuration, and architecture patterns
5. **Apply Android best practices** — Use the android-to-ios skills when migration questions arise, referencing actual code from this app

## Exploration Steps

When you need to understand the app structure, run these in order:

1. Read the root `build.gradle.kts` or `settings.gradle.kts` to understand modules
2. Check `app/src/main/AndroidManifest.xml` for components and permissions
3. Look at `app/build.gradle.kts` for dependencies (Compose, Room, Retrofit, Hilt, etc.)
4. Explore `app/src/main/java/` or `app/src/main/kotlin/` for package structure
5. Check for `libs.versions.toml` (version catalog) in the `gradle/` directory
6. Look for feature modules under the root directory

## Integration with Android-to-iOS Skills

When performing migration tasks:

1. Activate this skill to locate the Android source code
2. Read the relevant Android code from `~/Documents/WaonderApps/waonder-android`
3. Activate the corresponding `generic-android-to-ios-*` skill for migration guidance
4. Apply the migration patterns to produce iOS-equivalent code

Example workflow:
- User asks to migrate the networking layer → read Retrofit setup from the Android app → use `generic-android-to-ios-retrofit` skill → produce URLSession/Alamofire equivalent

## Constraints

- Always use the local path `~/Documents/WaonderApps/waonder-android` when reading files — do not guess subdirectories
- The repo is **private** — do not share code snippets outside the conversation
- When the user says "the app" or "the Android app" or "our app", assume this is the Waonder Android app
- If the local folder doesn't exist or is empty, fall back to the GitHub repo via `gh` commands
- Do not modify files in the Android repo unless explicitly asked — this skill is primarily for reference
