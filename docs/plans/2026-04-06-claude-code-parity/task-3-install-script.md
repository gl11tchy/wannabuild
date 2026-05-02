# Task 3 — Create `scripts/install-claude-skill.sh`

**Files:**

- Create: `scripts/install-claude-skill.sh`

This script installs WannaBuild as a local Claude Code plugin from the repo, equivalent to `install-codex-skill.sh` for Codex. It creates the plugin directory structure in the Claude Code plugin cache and registers it in settings.

## Step 1: Create the script

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_CACHE="${HOME}/.claude/plugins/cache/gl11tchy/wannabuild/local"
SETTINGS="${HOME}/.claude/settings.json"
INSTALLED="${HOME}/.claude/plugins/installed_plugins.json"

# Create plugin directory pointing to this repo
mkdir -p "$(dirname "$PLUGIN_CACHE")"
if [[ -L "$PLUGIN_CACHE" ]]; then
  rm "$PLUGIN_CACHE"
fi
ln -s "$ROOT" "$PLUGIN_CACHE"

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
```

## Step 2: Make it executable

```bash
chmod +x scripts/install-claude-skill.sh
```

### Step 3: Verify it looks right

```bash
head -5 scripts/install-claude-skill.sh
```

Expected: shebang and `set -euo pipefail`.

#### Step 4: Commit

```bash
git add scripts/install-claude-skill.sh
git commit -m "feat: add install-claude-skill.sh for local Claude Code plugin install"
```
