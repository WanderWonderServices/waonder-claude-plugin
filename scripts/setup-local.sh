#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────
# setup-local.sh
#
# Registers the Waonder plugin globally for Claude Code using a cache
# symlink so every change (new skills, edits, git pull) is picked up on
# the next session restart — no version bump or reinstall needed.
#
# Usage:
#   cd waonder-claude-plugin
#   ./scripts/setup-local.sh
# ──────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Resolve plugin directory (parent of scripts/) ───────────────────
PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# ── Read plugin name, version, and marketplace name from manifests ───
if [ ! -f "$PLUGIN_DIR/.claude-plugin/plugin.json" ]; then
  echo "ERROR: .claude-plugin/plugin.json not found in $PLUGIN_DIR"
  exit 1
fi

if [ ! -f "$PLUGIN_DIR/.claude-plugin/marketplace.json" ]; then
  echo "ERROR: .claude-plugin/marketplace.json not found in $PLUGIN_DIR"
  exit 1
fi

PLUGIN_NAME=$(python3 -c "import json; print(json.load(open('$PLUGIN_DIR/.claude-plugin/plugin.json'))['name'])")
VERSION=$(python3 -c "import json; print(json.load(open('$PLUGIN_DIR/.claude-plugin/plugin.json'))['version'])")
MARKETPLACE_NAME=$(python3 -c "import json; print(json.load(open('$PLUGIN_DIR/.claude-plugin/marketplace.json'))['name'])")
PLUGIN_KEY="${PLUGIN_NAME}@${MARKETPLACE_NAME}"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

echo "Plugin:      $PLUGIN_NAME"
echo "Version:     $VERSION"
echo "Marketplace: $MARKETPLACE_NAME"
echo "Plugin key:  $PLUGIN_KEY"
echo "Source dir:  $PLUGIN_DIR"
echo ""

# ── Ensure ~/.claude/plugins exists ──────────────────────────────────
mkdir -p ~/.claude/plugins

# ── 1. Update ~/.claude/settings.json ────────────────────────────────
SETTINGS_FILE="$HOME/.claude/settings.json"
if [ ! -f "$SETTINGS_FILE" ]; then
  echo "{}" > "$SETTINGS_FILE"
fi

python3 -c "
import json, sys

with open('$SETTINGS_FILE') as f:
    settings = json.load(f)

settings.setdefault('enabledPlugins', {})
settings.setdefault('extraKnownMarketplaces', {})

settings['enabledPlugins']['$PLUGIN_KEY'] = True
settings['extraKnownMarketplaces']['$MARKETPLACE_NAME'] = {
    'source': {
        'source': 'directory',
        'path': '$PLUGIN_DIR'
    }
}

with open('$SETTINGS_FILE', 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')
"
echo "[OK] Updated $SETTINGS_FILE"

# ── 2. Update ~/.claude/plugins/known_marketplaces.json ──────────────
KM_FILE="$HOME/.claude/plugins/known_marketplaces.json"
if [ ! -f "$KM_FILE" ]; then
  echo "{}" > "$KM_FILE"
fi

python3 -c "
import json

with open('$KM_FILE') as f:
    km = json.load(f)

km['$MARKETPLACE_NAME'] = {
    'source': {
        'source': 'directory',
        'path': '$PLUGIN_DIR'
    },
    'installLocation': '$PLUGIN_DIR',
    'lastUpdated': '$NOW'
}

with open('$KM_FILE', 'w') as f:
    json.dump(km, f, indent=2)
    f.write('\n')
"
echo "[OK] Updated $KM_FILE"

# ── 3. Update ~/.claude/plugins/installed_plugins.json ───────────────
IP_FILE="$HOME/.claude/plugins/installed_plugins.json"
if [ ! -f "$IP_FILE" ]; then
  echo '{"version": 2, "plugins": {}}' > "$IP_FILE"
fi

python3 -c "
import json

with open('$IP_FILE') as f:
    ip = json.load(f)

ip.setdefault('version', 2)
ip.setdefault('plugins', {})

ip['plugins']['$PLUGIN_KEY'] = [{
    'scope': 'user',
    'installPath': '$PLUGIN_DIR',
    'version': '$VERSION',
    'installedAt': '$NOW',
    'lastUpdated': '$NOW'
}]

with open('$IP_FILE', 'w') as f:
    json.dump(ip, f, indent=2)
    f.write('\n')
"
echo "[OK] Updated $IP_FILE"

# ── 4. Create cache symlink (the critical step) ─────────────────────
CACHE_DIR="$HOME/.claude/plugins/cache/$MARKETPLACE_NAME/$PLUGIN_NAME"
CACHE_VERSION_DIR="$CACHE_DIR/$VERSION"

mkdir -p "$CACHE_DIR"

if [ -L "$CACHE_VERSION_DIR" ]; then
  CURRENT_TARGET=$(readlink "$CACHE_VERSION_DIR")
  if [ "$CURRENT_TARGET" = "$PLUGIN_DIR" ]; then
    echo "[OK] Cache symlink already correct: $CACHE_VERSION_DIR -> $PLUGIN_DIR"
  else
    rm "$CACHE_VERSION_DIR"
    ln -s "$PLUGIN_DIR" "$CACHE_VERSION_DIR"
    echo "[OK] Updated cache symlink: $CACHE_VERSION_DIR -> $PLUGIN_DIR"
  fi
elif [ -d "$CACHE_VERSION_DIR" ]; then
  rm -rf "$CACHE_VERSION_DIR"
  ln -s "$PLUGIN_DIR" "$CACHE_VERSION_DIR"
  echo "[OK] Replaced cache directory with symlink: $CACHE_VERSION_DIR -> $PLUGIN_DIR"
else
  ln -s "$PLUGIN_DIR" "$CACHE_VERSION_DIR"
  echo "[OK] Created cache symlink: $CACHE_VERSION_DIR -> $PLUGIN_DIR"
fi

# ── 5. Verify ────────────────────────────────────────────────────────
echo ""
SKILL_COUNT=$(ls -d "$CACHE_VERSION_DIR/skills/"*/ 2>/dev/null | wc -l | tr -d ' ')
AGENT_COUNT=$(ls "$CACHE_VERSION_DIR/agents/"*.md 2>/dev/null | wc -l | tr -d ' ')

echo "── Verification ──"
echo "Skills found: $SKILL_COUNT"
echo "Agents found: $AGENT_COUNT"
echo ""
echo "── Setup complete ──"
echo "Restart Claude Code to pick up the plugin."
echo "Skill prefix: $PLUGIN_NAME:<skill-name>"
echo ""
echo "Any changes to this repo (new skills, edits, git pull) will be"
echo "picked up on the next session restart — no version bump or"
echo "reinstall needed."
