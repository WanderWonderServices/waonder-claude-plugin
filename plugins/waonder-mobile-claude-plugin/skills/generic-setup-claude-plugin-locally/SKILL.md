---
name: generic-setup-claude-plugin-locally
description: Use when setting up a local multi-plugin Claude Code marketplace repository globally — creates symlinks so changes are picked up on every session restart with no version bump or reinstall.
type: generic
---

# generic-setup-claude-plugin-locally

## Context
Use this skill when you need to register a local Claude Code marketplace repository as globally available **for active development**. This skill supports repositories that contain multiple plugins under a single marketplace.

**Why a symlink?** Claude Code always copies marketplace plugins into a version-stamped cache directory (`~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`). If you add or change skills without bumping the version, new sessions keep loading the stale cache. The symlink approach replaces each cache directory with a symbolic link to the plugin's source directory, so Claude Code reads live files every time.

Use this skill when:
- You are developing a plugin locally and want every change (new skills, edited skills, new agents) picked up on the next session restart — no version bump, no `plugin update`, no cache clearing.
- You want the plugin's skills available in every Claude Code session, regardless of the working directory.

Do **not** use this skill when:
- The plugin is already published to a remote marketplace and you just want to install it (use `claude plugin install` instead).
- You only need the plugin in a single project (use `claude --plugin-dir <path>` instead).

## Instructions

You are a Claude Code setup assistant. The setup process is automated by a `setup-local.sh` script that lives inside the repository. Your job is to validate prerequisites, run the script, and confirm the result.

## Repo structure

This skill expects a **multi-plugin marketplace repository** with the following layout:

```
<repo>/
  .claude-plugin/
    marketplace.json       ← marketplace name + list of plugins with source paths
  plugins/
    <plugin-a>/
      .claude-plugin/
        plugin.json        ← name, version, description for this plugin
      skills/
        ...
    <plugin-b>/
      .claude-plugin/
        plugin.json
      skills/
        ...
```

> **Note:** `setup-local.sh` lives inside this skill (in the `puzzle9900-claude-plugin` repo), not in the target repository. The skill passes the target repo path to the script at runtime.

## Steps

### 1. Determine the repo path
Use the **current working directory** (`$PWD`) as the target repo root. Only ask the user for a different path if the working directory clearly does not contain a `.claude-plugin/marketplace.json`.

Verify the repo root contains `.claude-plugin/marketplace.json`. If it does not, stop and ask the user to confirm the correct path.

### 2. Validate the marketplace manifest
Read `<repo>/.claude-plugin/marketplace.json` and ensure:
- `name` is a non-empty string
- `plugins` is a non-empty array where each entry has:
  - `name` — non-empty string
  - `version` — valid semver string (e.g. `"1.0.0"`)
  - `source` — relative path to the plugin directory (e.g. `"./plugins/generic/"`)

For each plugin entry, resolve `<repo>/<source>` and verify:
- The directory exists
- It contains `.claude-plugin/plugin.json`
- `plugin.json` has a non-empty `name` and valid `version`

If anything is missing or invalid, stop and tell the user what to fix before running setup.

### 3. Run the setup script
Execute the script, passing the target repo path as the first argument:

```bash
bash <path-to-this-skill>/setup-local.sh <repo-path>
```

For example, if the user is in `/Users/you/projects/my-marketplace`:
```bash
bash /path/to/puzzle9900-claude-plugin/skills/generic-setup-claude-plugin-locally/setup-local.sh /Users/you/projects/my-marketplace
```

The script automates all registration steps for **every plugin** listed in `marketplace.json`:
1. Reads marketplace name from `.claude-plugin/marketplace.json`
2. Updates `~/.claude/settings.json` — adds one `extraKnownMarketplaces` entry (per marketplace) and one `enabledPlugins` entry per plugin
3. Updates `~/.claude/plugins/known_marketplaces.json` — registers the marketplace source pointing to the repo root
4. For each plugin: updates `~/.claude/plugins/installed_plugins.json` and creates a cache symlink at `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` pointing to the plugin's source directory

Watch the script output for any `ERROR` lines. If the script exits with a non-zero status, report the error to the user and stop.

### 4. Verify the result
After the script completes, confirm it worked by running **all** of these checks:

#### 4a. Cache symlinks
For each plugin listed in `marketplace.json`:
```bash
ls -la ~/.claude/plugins/cache/<marketplace-name>/<plugin-name>/
```
Each version directory should be a symlink (`->`) pointing to the plugin's source directory (e.g. `<repo>/plugins/<plugin-name>/`).

#### 4b. Registered path points to the repo root
Read `~/.claude/plugins/known_marketplaces.json` and `~/.claude/settings.json` and verify that the `path` value for the marketplace matches the **repo root** (the directory containing `.claude-plugin/`).

If a path is wrong:
1. Tell the user which file has the wrong path and what it should be.
2. Re-run the setup script — the fixed script will overwrite stale values.
3. If the script itself produced the wrong path, the bug is in the `REPO_DIR` resolution at the top of `setup-local.sh`. The correct line is:
   ```bash
   REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
   ```
   because the script lives three levels deep (`<plugin>/skills/<skill>/`) inside the plugin directory, and the plugin directory itself lives one level below the repo root (`plugins/<plugin>/`), totalling four levels from the repo root. Adjust if your plugin directory is nested differently.

#### 4c. Marketplace file is reachable
Verify that `<registered-path>/.claude-plugin/marketplace.json` actually exists. If it does not, the registered path is wrong — go back to step 4b.

Then tell the user:
- Each plugin key: `<plugin-name>@<marketplace-name>` (shown in the script output)
- The skill prefix for each plugin: `<plugin-name>:<skill-folder-name>`
- To **open a new Claude Code session** for the changes to take effect
- **Any change to the repo (new skills, edited skills, git pull) will be picked up on the next session restart — no version bump or reinstall needed**

## What the script does (reference)

| Step | File | What is written |
|------|------|-----------------|
| Settings | `~/.claude/settings.json` | One `extraKnownMarketplaces["<marketplace>"]` entry (repo root path) + one `enabledPlugins["<plugin>@<marketplace>"] = true` per plugin |
| Known marketplaces | `~/.claude/plugins/known_marketplaces.json` | Marketplace entry with `source`, `installLocation` (repo root), and `lastUpdated` |
| Installed plugins | `~/.claude/plugins/installed_plugins.json` | One plugin entry per plugin with scope `"user"`, version, and timestamps |
| Cache symlinks | `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` | Symlink to each plugin's source directory |

**Critical:** The `known_marketplaces.json` and cache symlink steps are the ones most manual setups miss. Without `known_marketplaces.json`, plugins silently fail to load in new sessions. Without the symlinks, Claude Code reads from a stale cache copy.

## Auto-update hook (optional)

To keep a project-scoped plugin up to date at session start, add a `SessionStart` hook to the **project's** `.claude/settings.json`:

```json
"SessionStart": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "claude plugin marketplace update <marketplace-id> && claude plugin update --scope project <plugin>@<marketplace-id>",
        "timeout": 60,
        "statusMessage": "Updating marketplace..."
      }
    ]
  }
]
```

**Two common mistakes to avoid:**

1. **Do not add a `matcher` field to `SessionStart`.** The `matcher` field only applies to tool events (`PreToolUse` / `PostToolUse`). Adding it to `SessionStart` causes a hook error and the command will not run.

2. **Always pass `--scope project` to `claude plugin update`.** The default scope is `user`. If the plugin was enabled in a project `settings.json` (i.e. `enabledPlugins` lives in `.claude/settings.json`, not `~/.claude/settings.json`), omitting `--scope project` causes: `Error: Plugin is not installed at scope user`.

## Constraints
- Do not perform the setup steps manually — always use `setup-local.sh`
- Do not modify any `env` fields in `settings.json`
- If any plugin's source directory is moved or deleted, that plugin will fail to load — warn the user not to move the repo without re-running setup
- Plugin versions in `marketplace.json` do not need to be bumped for local development — the symlinks bypass version-based cache invalidation entirely
