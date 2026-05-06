#!/usr/bin/env bash
#
# Validate the Claude Code marketplace contract from this repo.
#
# Simulates what a consumer of `/plugin marketplace add gl11tchy/wannabuild`
# experiences: parse the marketplace manifest, follow each plugin's
# `source` to its plugin.json, follow the plugin's `hooks` path to the
# hooks file, and verify each layer matches what Claude Code expects.
#
# Catches:
#   - marketplace.json missing or malformed
#   - declared plugin source paths that don't exist
#   - plugin.json missing required fields
#   - version mismatches between marketplace.json and plugin.json
#   - hooks file declared but missing
#   - hooks file in the wrapped (broken) shape
#
# Exit 0 = contract holds, non-zero = a real consumer would hit an error.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MARKETPLACE="${ROOT}/.claude-plugin/marketplace.json"

if [[ ! -f "$MARKETPLACE" ]]; then
  echo "FAIL: marketplace manifest not found at $MARKETPLACE" >&2
  exit 1
fi

python3 - "$ROOT" "$MARKETPLACE" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
manifest_path = Path(sys.argv[2])

errors = []

def fail(msg):
    errors.append(msg)

def required(d, key, where):
    if key not in d or d[key] in (None, ""):
        fail(f"{where}: missing required field '{key}'")

try:
    manifest = json.loads(manifest_path.read_text())
except Exception as e:
    print(f"FAIL: marketplace.json is not valid JSON: {e}", file=sys.stderr)
    sys.exit(1)

required(manifest, "name", "marketplace.json")
required(manifest, "plugins", "marketplace.json")

plugins = manifest.get("plugins") or []
if not isinstance(plugins, list) or not plugins:
    fail("marketplace.json 'plugins' must be a non-empty array")

for idx, entry in enumerate(plugins):
    where = f"marketplace.json plugins[{idx}]"
    if not isinstance(entry, dict):
        fail(f"{where}: must be an object")
        continue

    for key in ("name", "source", "version"):
        required(entry, key, where)

    source = entry.get("source") or "./"
    plugin_root = (root / source).resolve()
    if not plugin_root.exists():
        fail(f"{where}: source path does not exist: {plugin_root}")
        continue

    plugin_json = plugin_root / ".claude-plugin" / "plugin.json"
    if not plugin_json.exists():
        fail(f"{where}: plugin.json not found at {plugin_json}")
        continue

    try:
        plugin = json.loads(plugin_json.read_text())
    except Exception as e:
        fail(f"{where}: plugin.json invalid JSON: {e}")
        continue

    for key in ("name", "version"):
        required(plugin, key, str(plugin_json))

    if entry.get("name") != plugin.get("name"):
        fail(
            f"{where}: marketplace name '{entry.get('name')}' does not match "
            f"plugin.json name '{plugin.get('name')}'"
        )

    if entry.get("version") != plugin.get("version"):
        fail(
            f"{where}: marketplace version '{entry.get('version')}' does not "
            f"match plugin.json version '{plugin.get('version')}'"
        )

    hooks_field = plugin.get("hooks")
    if hooks_field:
        hooks_path = (plugin_root / hooks_field).resolve()
        if not hooks_path.exists():
            fail(f"{plugin_json}: hooks path does not exist: {hooks_path}")
        else:
            try:
                hooks_doc = json.loads(hooks_path.read_text())
            except Exception as e:
                fail(f"{hooks_path}: invalid JSON: {e}")
                continue
            if "hooks" in hooks_doc:
                fail(
                    f"{hooks_path}: double-wrapped under a 'hooks' key. "
                    f"Claude Code's plugin loader will reject this. "
                    f"Expected the file body to be the event map directly."
                )
            for ev in ("SessionStart", "UserPromptSubmit"):
                if ev in hooks_doc and not isinstance(hooks_doc[ev], list):
                    fail(f"{hooks_path}: '{ev}' must be an array of hook groups")

if errors:
    print("Claude marketplace contract violations:", file=sys.stderr)
    for e in errors:
        print(f"  - {e}", file=sys.stderr)
    sys.exit(1)

print("Claude marketplace contract OK")
PY
