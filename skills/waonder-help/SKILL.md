---
name: waonder-help
description: Lists all available Waonder plugin skills grouped by domain
type: generic
---

# waonder-help

## Context
Quick reference for all skills available in the waonder-claude-plugin.

## Instructions
When invoked, list every skill in the `skills/` directory grouped by domain (generic, mobile, backend). For each skill show its name, one-line description, and whether it is user-invoked or auto-invoked.

## Steps
1. Read all `skills/*/SKILL.md` files in this plugin
2. Parse the frontmatter of each skill
3. Group skills by their `type` field (generic, mobile, backend)
4. Display a formatted table for each group with columns: Skill Name | Description | Invocation

## Constraints
- Only list skills that exist in this plugin (waonder-claude-plugin)
- Do not list skills from other plugins
