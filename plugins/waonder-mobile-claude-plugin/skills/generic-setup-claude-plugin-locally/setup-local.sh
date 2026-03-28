#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────
# setup-local.sh
#
# Registers all plugins in this marketplace repository globally for
# Claude Code using cache symlinks so every change is picked up on
# the next session restart — no version bump or reinstall needed.
#
# Usage (from any directory):
#   bash /path/to/plugins/generic/skills/generic-setup-claude-plugin-locally/setup-local.sh
# ──────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Resolve repo root (4 levels up: <skill>/ → skills/ → <plugin>/ → plugins/ → repo/) ──
REPO_DIR="$(cd "$(dirname "$0")/../../../.." && pwd)"

MARKETPLACE_FILE="$REPO_DIR/.claude-plugin/marketplace.json"
if [ ! -f "$MARKETPLACE_FILE" ]; then
  echo "ERROR: .claude-plugin/marketplace.json not found in $REPO_DIR"
  exit 1
fi

MARKETPLACE_NAME=$(python3 -c "import json; print(json.load(open('$MARKETPLACE_FILE'))['name'])")
NOW=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

echo "Marketplace: $MARKETPLACE_NAME"
echo "Repo:        $REPO_DIR"
echo ""

mkdir -p ~/.claude/plugins

# ── 1. Update ~/.claude/settings.json ────────────────────────────────
SETTINGS_FILE="$HOME/.claude/settings.json"
[ ! -f "$SETTINGS_FILE" ] && echo "{}" > "$SETTINGS_FILE"

python3 -c "
import json

with open('$MARKETPLACE_FILE') as f:
    marketplace = json.load(f)

with open('$SETTINGS_FILE') as f:
    settings = json.load(f)

settings.setdefault('enabledPlugins', {})
settings.setdefault('extraKnownMarketplaces', {})

settings['extraKnownMarketplaces']['$MARKETPLACE_NAME'] = {
    'source': {
        'source': 'directory',
        'path': '$REPO_DIR'
    }
}

for plugin in marketplace.get('plugins', []):
    key = plugin['name'] + '@$MARKETPLACE_NAME'
    settings['enabledPlugins'][key] = True

with open('$SETTINGS_FILE', 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')
"
echo "[OK] Updated $SETTINGS_FILE"

# ── 2. Update ~/.claude/plugins/known_marketplaces.json ──────────────
KM_FILE="$HOME/.claude/plugins/known_marketplaces.json"
[ ! -f "$KM_FILE" ] && echo "{}" > "$KM_FILE"

python3 -c "
import json

with open('$KM_FILE') as f:
    km = json.load(f)

km['$MARKETPLACE_NAME'] = {
    'source': {
        'source': 'directory',
        'path': '$REPO_DIR'
    },
    'installLocation': '$REPO_DIR',
    'lastUpdated': '$NOW'
}

with open('$KM_FILE', 'w') as f:
    json.dump(km, f, indent=2)
    f.write('\n')
"
echo "[OK] Updated $KM_FILE"

# ── 3 & 4. Per-plugin: installed_plugins.json + cache symlink ────────
IP_FILE="$HOME/.claude/plugins/installed_plugins.json"
[ ! -f "$IP_FILE" ] && echo '{"version": 2, "plugins": {}}' > "$IP_FILE"

PLUGIN_COUNT=$(python3 -c "import json; print(len(json.load(open('$MARKETPLACE_FILE')).get('plugins', [])))")

for i in $(seq 0 $((PLUGIN_COUNT - 1))); do
  PLUGIN_NAME=$(python3 -c "import json; print(json.load(open('$MARKETPLACE_FILE'))['plugins'][$i]['name'])")
  PLUGIN_SOURCE=$(python3 -c "import json; print(json.load(open('$MARKETPLACE_FILE'))['plugins'][$i]['source'])")
  VERSION=$(python3 -c "import json; print(json.load(open('$MARKETPLACE_FILE'))['plugins'][$i]['version'])")
  PLUGIN_DIR="$(cd "$REPO_DIR/$PLUGIN_SOURCE" && pwd)"
  PLUGIN_KEY="${PLUGIN_NAME}@${MARKETPLACE_NAME}"

  echo ""
  echo "── $PLUGIN_NAME ($VERSION) ──"
  echo "   Dir: $PLUGIN_DIR"

  # Update installed_plugins.json
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
  echo "   [OK] Registered in installed_plugins.json"

  # Create cache symlink
  CACHE_DIR="$HOME/.claude/plugins/cache/$MARKETPLACE_NAME/$PLUGIN_NAME"
  CACHE_VERSION_DIR="$CACHE_DIR/$VERSION"
  mkdir -p "$CACHE_DIR"

  if [ -L "$CACHE_VERSION_DIR" ]; then
    CURRENT_TARGET=$(readlink "$CACHE_VERSION_DIR")
    if [ "$CURRENT_TARGET" = "$PLUGIN_DIR" ]; then
      echo "   [OK] Cache symlink already correct: $CACHE_VERSION_DIR -> $PLUGIN_DIR"
    else
      rm "$CACHE_VERSION_DIR"
      ln -s "$PLUGIN_DIR" "$CACHE_VERSION_DIR"
      echo "   [OK] Updated cache symlink: $CACHE_VERSION_DIR -> $PLUGIN_DIR"
    fi
  elif [ -d "$CACHE_VERSION_DIR" ]; then
    rm -rf "$CACHE_VERSION_DIR"
    ln -s "$PLUGIN_DIR" "$CACHE_VERSION_DIR"
    echo "   [OK] Replaced cache dir with symlink: $CACHE_VERSION_DIR -> $PLUGIN_DIR"
  else
    ln -s "$PLUGIN_DIR" "$CACHE_VERSION_DIR"
    echo "   [OK] Created cache symlink: $CACHE_VERSION_DIR -> $PLUGIN_DIR"
  fi
done

echo ""
echo "── Setup complete ──"
echo "Restart Claude Code to pick up all plugins."
echo ""
echo "Registered plugins:"
python3 -c "
import json
marketplace = json.load(open('$MARKETPLACE_FILE'))
for p in marketplace.get('plugins', []):
    print(f\"  {p['name']}@$MARKETPLACE_NAME  —  skill prefix: {p['name']}:<skill-name>\")
"
echo ""
echo "Any changes to this repo (new skills, edits, git pull) will be"
echo "picked up on the next session restart — no version bump or reinstall needed."
