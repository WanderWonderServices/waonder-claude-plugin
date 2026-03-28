---
name: generic-waonder-projects
description: Use when building, debugging, or discussing any Waonder project — provides a quick reference of all Waonder repositories to understand the ecosystem, tech stack, and repo boundaries
type: generic
---

# generic-waonder-projects

## Context
Waonder is an AI-powered travel companion platform. The codebase is split across multiple repositories under the [WanderWonderServices](https://github.com/orgs/WanderWonderServices/repositories) GitHub organization. All projects are cloned locally under `~/Documents/WaonderApps/`. This skill provides a quick-reference map of every project so Claude can understand which repo owns what, the tech stack involved, where it lives on disk, and how the pieces connect.

Use this knowledge whenever the user mentions building, fixing, or discussing functionality in any Waonder project. It helps you route suggestions to the correct repo, use the right language/framework conventions, understand cross-project dependencies, and read or reference code from the correct local path.

## Instructions
When this skill is activated, use the project catalog below as context for the current conversation. Do not recite the catalog back to the user — instead, silently apply it to inform your answers, code suggestions, and architecture decisions.

If the user asks about a feature or component, match it to the correct project and tailor your response to that project's tech stack and conventions. When you need to explore or reference code from another Waonder project, use the local path from the catalog to read files directly.

## Project Catalog

### waonder-backend
| Field | Value |
|-------|-------|
| **Repo** | `WanderWonderServices/waonder-backend` |
| **Local path** | `~/Documents/WaonderApps/waonder-backend` |
| **Description** | Location-aware RAG API service for historical and cultural storytelling |
| **Language** | TypeScript |
| **Branch** | `main` |
| **Visibility** | Private |
| **Role** | Core backend API. Handles location-based queries, RAG pipeline for storytelling content, and serves data to all client apps. |

### waonder-android
| Field | Value |
|-------|-------|
| **Repo** | `WanderWonderServices/waonder-android` |
| **Local path** | `~/Documents/WaonderApps/waonder-android` |
| **Description** | Waonder Android mobile app |
| **Language** | Kotlin |
| **Branch** | `main` |
| **Visibility** | Private |
| **Role** | Native Android client. Consumes the backend API to deliver the AI travel companion experience on Android devices. |

### waonder-web-page
| Field | Value |
|-------|-------|
| **Repo** | `WanderWonderServices/waonder-web-page` |
| **Local path** | `~/Documents/WaonderApps/waonder-web-page` |
| **Description** | Waonder landing page — AI-powered travel companion |
| **Language** | HTML |
| **Branch** | `main` |
| **Visibility** | Private |
| **Role** | Marketing and landing page for the Waonder product. Public-facing website for user acquisition. |

### map-playground-web
| Field | Value |
|-------|-------|
| **Repo** | `WanderWonderServices/map-playground-web` |
| **Local path** | `~/Documents/WaonderApps/waonder-web-map-playground` |
| **Description** | Map playground for web |
| **Language** | TypeScript |
| **Branch** | `main` |
| **Visibility** | Private |
| **Role** | Web-based map experimentation and prototyping tool. Used for testing map features and interactions before integrating into the main apps. |

### waonder-images-generator
| Field | Value |
|-------|-------|
| **Repo** | `WanderWonderServices/waonder-images-generator` |
| **Local path** | `~/Documents/WaonderApps/waonder-images` |
| **Description** | AI images generator |
| **Language** | Python |
| **Branch** | `main` |
| **Visibility** | Private |
| **Role** | Generates AI images for Waonder content. Standalone service that produces visual assets used across the platform. |

### waonder-claude-plugin
| Field | Value |
|-------|-------|
| **Repo** | `WanderWonderServices/waonder-claude-plugin` |
| **Local path** | `~/Documents/WaonderApps/waonder-claude-pluggin/waonder-claude-plugging` |
| **Description** | Claude Code plugin exclusively for Waonder apps |
| **Language** | Shell / Markdown |
| **Branch** | `main` |
| **Visibility** | Public |
| **Role** | This plugin. Contains skills, agents, and hooks that help Claude Code work effectively across all Waonder projects. |

---

### Local-Only Projects (no GitHub repo)

These folders exist locally under `~/Documents/WaonderApps/` but are not published to the GitHub org. They are experimental, learning, or auxiliary projects.

| Local folder | Description |
|-------------|-------------|
| `iOS` | iOS app project |
| `iOS-learning` | iOS learning / experimentation |
| `test-waonder-maplibre` | MapLibre integration testing |
| `SDF-Generator` | SDF (Signed Distance Field) generator tool |
| `icons-geenrator` | Icon generation utility |
| `prompt-tunner` | Prompt tuning experiments |
| `agents-test` | Agent testing sandbox |
| `claude-setup` | Claude setup configuration |

## Architecture Overview

```
[waonder-web-page]  ──┐
[waonder-android]   ──┼──▶  [waonder-backend]  ──▶  [waonder-images-generator]
[map-playground-web]──┘          (RAG API)              (AI image generation)

[waonder-claude-plugin]  ──  Developer tooling (this plugin)
```

- **Clients** (android, web-page, map-playground-web) consume the **backend** API
- **waonder-backend** is the central API that orchestrates RAG-based storytelling and location services
- **waonder-images-generator** is a sidecar service called by the backend for AI image generation
- **waonder-claude-plugin** is developer tooling, not part of the runtime architecture

## Steps
1. Identify which Waonder project the user's request relates to
2. Load the relevant project details from the catalog above, including its local path
3. When you need to understand existing code, read files from the project's local path (`~/Documents/WaonderApps/...`)
4. Apply the correct tech stack conventions (TypeScript for backend, Kotlin for Android, Python for image generator, HTML for landing page)
5. When suggesting code or architecture changes, respect repo boundaries — do not mix concerns across repos
6. If a feature spans multiple repos (e.g., new API endpoint + Android client update), call out all affected repos and their local paths explicitly

## Constraints
- Do not dump the full project catalog unless the user explicitly asks for it
- When the user says "the backend", always assume `waonder-backend` unless context says otherwise
- When the user says "the app", assume `waonder-android` unless context says otherwise
- When the user says "the website" or "landing page", assume `waonder-web-page`
- Always use the **local path** from the catalog when reading or referencing files — do not guess paths
- Note that some local folder names differ from repo names (e.g., `waonder-images` locally vs `waonder-images-generator` on GitHub, `waonder-web-map-playground` locally vs `map-playground-web` on GitHub)
- Respect repo visibility — all repos except `waonder-claude-plugin` are private
- Local-only projects have no GitHub repo — do not attempt `gh` commands against them
- This catalog reflects the state as of 2026-03-15. If repos are added or renamed, this skill should be updated
