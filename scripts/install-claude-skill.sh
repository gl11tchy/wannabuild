#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_CACHE="${HOME}/.claude/plugins/cache/gl11tchy/wannabuild/local"
SETTINGS="${HOME}/.claude/settings.json"
INSTALLED="${HOME}/.claude/plugins/installed_plugins.json"

# Create plugin directory pointing to this repo
mkdir -p "$(dirname "$PLUGIN_CACHE")"
if [[ -e "$PLUGIN_CACHE" && ! -L "$PLUGIN_CACHE" ]]; then
  rm -rf "$PLUGIN_CACHE"
elif [[ -L "$PLUGIN_CACHE" ]]; then
  rm "$PLUGIN_CACHE"
fi
ln -sfn "$ROOT" "$PLUGIN_CACHE"
mkdir -p "$(dirname "$INSTALLED")" "$(dirname "$SETTINGS")"

# Register in installed_plugins.json
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

key = "wannabuild@gl11tchy"
now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
data.setdefault("plugins", {})[key] = [
    {
        "scope": "user",
        "installPath": install_path,
        "version": "local",
        "installedAt": now,
        "lastUpdated": now,
        "gitCommitSha": "local"
    }
]
installed_path.write_text(json.dumps(data, indent=4))
print(f"Registered {key} in installed_plugins.json")
PY

# Enable in settings.json
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

settings.setdefault("enabledPlugins", {})["wannabuild@gl11tchy"] = True
settings_path.write_text(json.dumps(settings, indent=4))
print("Enabled wannabuild@gl11tchy in settings.json")
PY

echo ""
echo "Installed WannaBuild for Claude Code:"
echo "  Plugin path: $PLUGIN_CACHE -> $ROOT"
echo ""
echo "Run /reload-plugins in Claude Code, then invoke:"
echo "  /wannabuild"
