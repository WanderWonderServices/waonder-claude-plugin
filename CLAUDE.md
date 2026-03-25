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

## Never use
- The `ai` wrapper (`ai.sh`)
- The `/reload` command
- The `/setup-ai` skill
