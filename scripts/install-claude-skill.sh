#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAMESPACE="gl11tchy"

resolve_host_home() {
  if [[ -n "${WANNABUILD_HOST_HOME:-}" ]]; then
    printf '%s\n' "$WANNABUILD_HOST_HOME"
  elif [[ -n "${USERPROFILE:-}" && -d "${USERPROFILE:-}" ]]; then
    printf '%s\n' "$USERPROFILE"
  elif [[ "$ROOT" =~ ^/mnt/([A-Za-z])/Users/([^/]+)(/|$) ]]; then
    printf '/mnt/%s/Users/%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
  elif [[ "$ROOT" =~ ^/([A-Za-z])/Users/([^/]+)(/|$) ]]; then
    printf '/%s/Users/%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
  else
    printf '%s\n' "$HOME"
  fi
}

is_windows_mount_path() {
  [[ "$1" =~ ^/mnt/[A-Za-z]/ ]]
}

to_windows_path() {
  local path="$1"
  if [[ "$path" =~ ^/mnt/([A-Za-z])/(.*)$ ]]; then
    local drive="${BASH_REMATCH[1]}"
    local rest="${BASH_REMATCH[2]//\//\\}"
    printf '%s:\\%s\n' "${drive^^}" "$rest"
  elif [[ "$path" =~ ^/([A-Za-z])/(.*)$ ]]; then
    local drive="${BASH_REMATCH[1]}"
    local rest="${BASH_REMATCH[2]//\//\\}"
    printf '%s:\\%s\n' "${drive^^}" "$rest"
  elif command -v wslpath >/dev/null 2>&1; then
    wslpath -w "$path"
  elif command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$path"
  else
    printf '%s\n' "$path"
  fi
}

windows_powershell() {
  if command -v powershell.exe >/dev/null 2>&1; then
    printf '%s\n' "powershell.exe"
  elif command -v pwsh.exe >/dev/null 2>&1; then
    printf '%s\n' "pwsh.exe"
  else
    return 1
  fi
}

ps_literal() {
  local value="$1"
  value="${value//\'/\'\'}"
  printf "'%s'" "$value"
}

safe_remove_existing() {
  local path="$1"
  case "$path" in
    "${CLAUDE_HOME}/plugins/cache/"*) ;;
    *)
      echo "Refusing to remove path outside Claude plugin cache: $path" >&2
      return 1
      ;;
  esac

  if [[ ! -e "$path" && ! -L "$path" ]]; then
    return 0
  fi

  if is_windows_mount_path "$path"; then
    local win_path
    win_path="$(to_windows_path "$path")"
    local ps
    if ps="$(windows_powershell)"; then
      local ps_path
      ps_path="$(ps_literal "$win_path")"
      "$ps" -NoProfile -NonInteractive -Command \
        "if (Test-Path -LiteralPath $ps_path) { cmd.exe /C rmdir $ps_path; if (Test-Path -LiteralPath $ps_path) { Remove-Item -LiteralPath $ps_path -Force -Recurse } }" >/dev/null </dev/null && return 0
    elif command -v cmd.exe >/dev/null 2>&1; then
      cmd.exe /C "if exist \"$win_path\" rmdir \"$win_path\"" >/dev/null 2>&1 </dev/null && return 0
    fi
    echo "Failed to remove Windows junction/path safely: $path" >&2
    return 1
  fi

  if [[ -L "$path" ]]; then
    rm -f "$path"
  else
    rm -rf "$path"
  fi
}

create_plugin_link() {
  local source="$1"
  local dest="$2"

  if is_windows_mount_path "$source" && is_windows_mount_path "$dest"; then
    local win_source win_dest
    win_source="$(to_windows_path "$source")"
    win_dest="$(to_windows_path "$dest")"
    local ps
    if ps="$(windows_powershell)"; then
      local ps_source ps_dest
      ps_source="$(ps_literal "$win_source")"
      ps_dest="$(ps_literal "$win_dest")"
      "$ps" -NoProfile -NonInteractive -Command \
        "New-Item -ItemType Junction -Path $ps_dest -Target $ps_source | Out-Null" </dev/null
    else
      cmd.exe /C "mklink /J \"$win_dest\" \"$win_source\"" >/dev/null </dev/null
    fi
  elif [[ "${OSTYPE:-}" == msys* || "${OSTYPE:-}" == cygwin* ]]; then
    local win_source win_dest
    win_source="$(to_windows_path "$source")"
    win_dest="$(to_windows_path "$dest")"
    MSYS2_ARG_CONV_EXCL='*' cmd.exe /C "mklink /J \"$win_dest\" \"$win_source\"" >/dev/null
  else
    ln -sfn "$source" "$dest"
  fi
}

json_path_for_host() {
  local path="$1"
  if is_windows_mount_path "$path"; then
    to_windows_path "$path"
  else
    printf '%s\n' "$path"
  fi
}

HOST_HOME="$(resolve_host_home)"
CLAUDE_HOME="${CLAUDE_HOME:-${HOST_HOME}/.claude}"
PLUGIN_CACHE="${CLAUDE_HOME}/plugins/cache/${NAMESPACE}/wannabuild/local"
MARKETPLACE_DIR="${CLAUDE_HOME}/plugins/marketplaces/${NAMESPACE}"
KNOWN_MARKETPLACES="${CLAUDE_HOME}/plugins/known_marketplaces.json"
SETTINGS="${CLAUDE_HOME}/settings.json"
INSTALLED="${CLAUDE_HOME}/plugins/installed_plugins.json"
JSON_PLUGIN_CACHE="$(json_path_for_host "$PLUGIN_CACHE")"
JSON_MARKETPLACE_DIR="$(json_path_for_host "$MARKETPLACE_DIR")"

# Remove stale claude-plugins-official wannabuild entry if present.
safe_remove_existing "${CLAUDE_HOME}/plugins/cache/claude-plugins-official/wannabuild"

# Create marketplace directory (presence prevents Claude Code from re-fetching)
mkdir -p "${MARKETPLACE_DIR}/plugins/wannabuild"

# Create plugin symlink pointing to this repo
mkdir -p "$(dirname "$PLUGIN_CACHE")"
safe_remove_existing "$PLUGIN_CACHE"
create_plugin_link "$ROOT" "$PLUGIN_CACHE"
mkdir -p "$(dirname "$INSTALLED")" "$(dirname "$SETTINGS")"

# Register namespace and plugin in all three JSON config files
python3 - "$NAMESPACE" "$JSON_MARKETPLACE_DIR" "$KNOWN_MARKETPLACES" "$JSON_PLUGIN_CACHE" "$INSTALLED" "$SETTINGS" <<'PY'
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

if [[ ! -f "${PLUGIN_CACHE}/.claude-plugin/plugin.json" ]]; then
  echo "Install verification failed: plugin manifest not reachable at ${PLUGIN_CACHE}" >&2
  exit 1
fi
if [[ ! -f "${PLUGIN_CACHE}/hooks/hooks.json" ]]; then
  echo "Install verification failed: hooks manifest not reachable at ${PLUGIN_CACHE}" >&2
  exit 1
fi

echo ""
echo "Installed WannaBuild for Claude Code:"
echo "  Plugin path: $PLUGIN_CACHE -> $ROOT"
echo "  Namespace:   wannabuild@${NAMESPACE}"
echo "  Hooks:       SessionStart + UserPromptSubmit autorouting verified"
echo ""
echo "Run /reload-plugins in Claude Code, then type a natural feature request."
echo "Explicit shortcut remains available: /wannabuild"
