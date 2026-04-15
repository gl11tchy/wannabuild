#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAMESPACE="gl11tchy"
PLUGIN_CACHE="${HOME}/.claude/plugins/cache/${NAMESPACE}/wannabuild/local"
MARKETPLACE_DIR="${HOME}/.claude/plugins/marketplaces/${NAMESPACE}"
KNOWN_MARKETPLACES="${HOME}/.claude/plugins/known_marketplaces.json"
SETTINGS="${HOME}/.claude/settings.json"
INSTALLED="${HOME}/.claude/plugins/installed_plugins.json"

# Remove stale claude-plugins-official wannabuild entry if present
OLD_CACHE="${HOME}/.claude/plugins/cache/claude-plugins-official/wannabuild"
[[ -e "$OLD_CACHE" ]] && rm -rf "$OLD_CACHE"

# Create marketplace directory (presence prevents Claude Code from re-fetching)
mkdir -p "${MARKETPLACE_DIR}/plugins/wannabuild"

# Create plugin symlink pointing to this repo
mkdir -p "$(dirname "$PLUGIN_CACHE")"
if [[ -e "$PLUGIN_CACHE" && ! -L "$PLUGIN_CACHE" ]]; then
  rm -rf "$PLUGIN_CACHE"
elif [[ -L "$PLUGIN_CACHE" ]]; then
  rm "$PLUGIN_CACHE"
fi
ln -sfn "$ROOT" "$PLUGIN_CACHE"
mkdir -p "$(dirname "$INSTALLED")" "$(dirname "$SETTINGS")"

# Register namespace in known_marketplaces.json
python3 - "$NAMESPACE" "$MARKETPLACE_DIR" "$KNOWN_MARKETPLACES" <<'PY'
import json, sys
from pathlib import Path
from datetime import datetime, timezone

namespace, marketplace_dir, km_file = sys.argv[1:]
km_path = Path(km_file)

data = {}
if km_path.exists():
    try:
        data = json.loads(km_path.read_text())
    except Exception:
        pass

now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
data[namespace] = {
    "source": {"source": "github", "repo": f"{namespace}/wannabuild"},
    "installLocation": marketplace_dir,
    "lastUpdated": now
}
km_path.write_text(json.dumps(data, indent=2))
print(f"Registered {namespace} in known_marketplaces.json")
PY

# Register in installed_plugins.json (remove old claude-plugins-official wannabuild key, add new)
python3 - "$PLUGIN_CACHE" "$INSTALLED" "$NAMESPACE" <<'PY'
import json, sys
from pathlib import Path
from datetime import datetime, timezone

install_path, installed_file, namespace = sys.argv[1:]
installed_path = Path(installed_file)

data = {"version": 2, "plugins": {}}
if installed_path.exists():
    try:
        data = json.loads(installed_path.read_text())
    except Exception:
        pass

# Remove stale entry
data.get("plugins", {}).pop("wannabuild@claude-plugins-official", None)

key = f"wannabuild@{namespace}"
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

# Enable in settings.json (remove old claude-plugins-official wannabuild key, add new)
python3 - "$SETTINGS" "$NAMESPACE" <<'PY'
import json, sys
from pathlib import Path

settings_path, namespace = Path(sys.argv[1]), sys.argv[2]
settings = {}
if settings_path.exists():
    try:
        settings = json.loads(settings_path.read_text())
    except Exception:
        pass

plugins = settings.setdefault("enabledPlugins", {})
plugins.pop("wannabuild@claude-plugins-official", None)
plugins[f"wannabuild@{namespace}"] = True
settings_path.write_text(json.dumps(settings, indent=4))
print(f"Enabled wannabuild@{namespace} in settings.json")
PY

echo ""
echo "Installed WannaBuild for Claude Code:"
echo "  Plugin path: $PLUGIN_CACHE -> $ROOT"
echo "  Namespace:   wannabuild@${NAMESPACE}"
echo ""
echo "Run /reload-plugins in Claude Code, then invoke:"
echo "  /wannabuild"
