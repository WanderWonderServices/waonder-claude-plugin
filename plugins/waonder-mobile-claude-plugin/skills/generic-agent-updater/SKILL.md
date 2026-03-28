---
name: generic-agent-updater
description: Use when agents need a bulk health-check — scans the local agents folder, runs every agent in parallel to self-verify its data is still accurate, and removes or updates any stale references
type: generic
---

# generic-agent-updater

## Context
Over time, agent definition files in the `agents/` folder can drift from reality — files they reference get moved, projects change structure, external resources disappear, or conventions evolve. This skill performs a bulk health-check on every agent by spawning parallel verification runs, then reconciles any stale or broken data it finds.

Use this skill whenever you want to make sure all agents in the current plugin are still accurate and functional before a release, after a major refactor, or as a periodic maintenance pass.

## Instructions
When this skill is invoked, scan the `agents/` folder in the current project root, identify every `.md` agent file, and run a parallel self-verification pass on each one. For every agent, validate that:

1. **File references** — Any file paths, local paths, or repo paths mentioned in the agent still exist and are reachable.
2. **External references** — Any URLs, API endpoints, or external tool references are still valid (check with a HEAD request or equivalent when possible).
3. **Frontmatter integrity** — The `name` and `description` fields are present, non-empty, and the `name` matches the filename (minus `.md`).
4. **Content accuracy** — The factual claims, conventions, templates, or instructions inside the agent still align with the current state of the codebase and project structure. Cross-reference with the actual project files when needed.
5. **Section completeness** — The agent has the expected structural sections (Identity, Knowledge, Instructions, Constraints or equivalent).

After verification, take corrective action:

- **Stale file/path references**: Update to the correct current path, or remove if the resource no longer exists.
- **Broken URLs**: Remove or flag for the user if a replacement is unclear.
- **Outdated factual content**: Update the content to match current reality (read the relevant source files to confirm).
- **Missing sections**: Flag to the user but do not invent content — ask what should go there.
- **Agents that are entirely obsolete**: Flag for removal and explain why, but do not delete without user confirmation.

## Steps
1. Read the `agents/` directory in the project root and collect all `.md` files (skip `.gitkeep` and non-agent files).
2. For each agent file found, spawn a parallel verification agent (using the Agent tool) that:
   a. Reads the full agent file.
   b. Validates frontmatter fields (`name`, `description`) and checks the filename matches.
   c. Extracts all file paths, local paths, and URLs referenced in the agent content.
   d. Verifies each file path exists by attempting to read or glob it.
   e. Verifies each URL is reachable (HEAD request via WebFetch when possible).
   f. Cross-references factual claims against the current codebase (e.g., if the agent describes a project structure, verify it matches).
   g. Returns a structured report: agent name, status (healthy / needs-update / obsolete), list of issues found, and suggested fixes.
3. Collect all parallel verification reports.
4. For agents marked **needs-update**: apply the suggested fixes directly to the agent file. Show the user a summary of what changed.
5. For agents marked **obsolete**: present the reasoning to the user and ask for confirmation before deleting.
6. For agents marked **healthy**: report them as passing with no action needed.
7. Output a final summary table listing every agent, its status, and what actions were taken.

## Constraints
- Never delete an agent file without explicit user confirmation.
- Never invent content for missing sections — flag them and ask the user.
- Run all agent verifications in parallel to minimize wall-clock time.
- Do not modify agents that pass all checks — leave healthy agents untouched.
- Only verify agents in the `agents/` folder of the current project root — do not scan other plugin directories or external paths.
- If the `agents/` folder is empty or contains no `.md` files, report that clearly and exit without error.
- Do not attempt to run or execute agent logic — this skill only validates the static content of agent definition files.
- Respect the project's naming conventions: agent filenames must be kebab-case and match their `name` frontmatter field.
