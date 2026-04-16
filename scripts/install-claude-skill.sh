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
rm -rf "${HOME}/.claude/plugins/cache/claude-plugins-official/wannabuild"

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

# Register namespace and plugin in all three JSON config files
python3 - "$NAMESPACE" "$MARKETPLACE_DIR" "$KNOWN_MARKETPLACES" "$PLUGIN_CACHE" "$INSTALLED" "$SETTINGS" <<'PY'
import json, sys
from pathlib import Path
from datetime import datetime, timezone

namespace, marketplace_dir, km_file, install_path, installed_file, settings_file = sys.argv[1:]

def load_json(path, default):
    p = Path(path)
    if p.exists():
        try:
            return json.loads(p.read_text())
        except Exception:
            pass
    return default

now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

km_path = Path(km_file)
km = load_json(km_file, {})
km[namespace] = {
    "source": {"source": "github", "repo": f"{namespace}/wannabuild"},
    "installLocation": marketplace_dir,
    "lastUpdated": now
}
km_path.write_text(json.dumps(km, indent=4))
print(f"Registered {namespace} in known_marketplaces.json")

installed_path = Path(installed_file)
data = load_json(installed_file, {"version": 2, "plugins": {}})
data.get("plugins", {}).pop("wannabuild@claude-plugins-official", None)
key = f"wannabuild@{namespace}"
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

settings_path = Path(settings_file)
settings = load_json(settings_file, {})
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
