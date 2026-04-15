#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# claude-plugins-official is Claude Code's recognized marketplace namespace
PLUGIN_CACHE="${HOME}/.claude/plugins/cache/claude-plugins-official/wannabuild/local"
SETTINGS="${HOME}/.claude/settings.json"
INSTALLED="${HOME}/.claude/plugins/installed_plugins.json"

# Remove stale gl11tchy entry if present
OLD_CACHE="${HOME}/.claude/plugins/cache/gl11tchy"
[[ -e "$OLD_CACHE" ]] && rm -rf "$OLD_CACHE"

# Create plugin directory pointing to this repo
mkdir -p "$(dirname "$PLUGIN_CACHE")"
if [[ -e "$PLUGIN_CACHE" && ! -L "$PLUGIN_CACHE" ]]; then
  rm -rf "$PLUGIN_CACHE"
elif [[ -L "$PLUGIN_CACHE" ]]; then
  rm "$PLUGIN_CACHE"
fi
ln -sfn "$ROOT" "$PLUGIN_CACHE"
mkdir -p "$(dirname "$INSTALLED")" "$(dirname "$SETTINGS")"

# Register in installed_plugins.json (remove old gl11tchy key, add new)
python3 - "$PLUGIN_CACHE" "$INSTALLED" <<'PY'
import json, sys
from pathlib import Path
from datetime import datetime, timezone

install_path, installed_file = sys.argv[1:]
installed_path = Path(installed_file)

data = {"version": 2, "plugins": {}}
if installed_path.exists():
    try:
        data = json.loads(installed_path.read_text())
    except Exception:
        pass

# Remove stale entry
data.get("plugins", {}).pop("wannabuild@gl11tchy", None)

key = "wannabuild@claude-plugins-official"
now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
data.setdefault("plugins", {})[key] = [
    {
        "scope": "user",
        "installPath": install_path,
        "version": "local",
        "installedAt": now,
        "lastUpdated": now
    }
]
installed_path.write_text(json.dumps(data, indent=4))
print(f"Registered {key} in installed_plugins.json")
PY

# Enable in settings.json (remove old gl11tchy key, add new)
python3 - "$SETTINGS" <<'PY'
import json, sys
from pathlib import Path

settings_path = Path(sys.argv[1])
settings = {}
if settings_path.exists():
    try:
        settings = json.loads(settings_path.read_text())
    except Exception:
        pass

plugins = settings.setdefault("enabledPlugins", {})
plugins.pop("wannabuild@gl11tchy", None)
plugins["wannabuild@claude-plugins-official"] = True
settings_path.write_text(json.dumps(settings, indent=4))
print("Enabled wannabuild@claude-plugins-official in settings.json")
PY

echo ""
echo "Installed WannaBuild for Claude Code:"
echo "  Plugin path: $PLUGIN_CACHE -> $ROOT"
echo ""
echo "Run /reload-plugins in Claude Code, then invoke:"
echo "  /wannabuild"
