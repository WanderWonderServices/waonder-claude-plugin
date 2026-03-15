---
name: waonder-setup-locally
description: Register the Waonder plugin globally using a cache symlink for live development
type: generic
disable-model-invocation: true
---

# waonder-setup-locally

## Context
Sets up the waonder-claude-plugin globally so skills are available in every Claude Code session. Uses a cache symlink so that git pull, new skills, and edited skills are picked up on the next session restart.

## Instructions
Run the setup script from the plugin root directory.

## Steps
1. Verify the current directory contains `.claude-plugin/plugin.json`
2. Run `./scripts/setup-local.sh`
3. Confirm the symlink was created successfully
4. Instruct the user to restart Claude Code

## Constraints
- Must be run from the plugin root directory
- Requires python3 to be installed
- Only modifies ~/.claude/ configuration files
