#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ADAPTER="${ROOT}/adapters/factory"
NAMESPACE="gl11tchy"
PLUGIN="wannabuild"
MARKETPLACE="${FACTORY_MARKETPLACE:-$(basename "$ROOT")}"

# Resolve a usable Python interpreter once, up front, so we fail fast with an
# actionable error instead of silently swallowing it inside a heredoc.
if command -v python3 >/dev/null 2>&1; then
  PYTHON="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON="python"
elif command -v py >/dev/null 2>&1; then
  PYTHON="py"
else
  cat >&2 <<'ERR'
install-factory-plugin: no Python interpreter on PATH.

WannaBuild's install script needs Python 3.x. Install one of:
  - macOS:   brew install python@3.11
  - Ubuntu:  sudo apt-get install python3
  - Windows: install from python.org and ensure python3 is on PATH

Then re-run this script.
ERR
  exit 1
fi

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
    "${PLUGIN_CACHE_PARENT}/"*) ;;
    "${DROIDS_DIR}/wb-"*) ;;
    *)
      echo "Refusing to remove path outside Factory install targets: $path" >&2
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

create_link() {
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
FACTORY_HOME="${FACTORY_HOME:-${HOST_HOME}/.factory}"
FACTORY_PLUGINS="${FACTORY_HOME}/plugins"
DROIDS_DIR="${FACTORY_DROIDS_DIR:-${FACTORY_HOME}/droids}"
PLUGIN_CACHE_PARENT="${FACTORY_PLUGINS}/cache/${MARKETPLACE}/${PLUGIN}"
PLUGIN_CACHE="${PLUGIN_CACHE_PARENT}/local"
KNOWN_MARKETPLACES="${FACTORY_PLUGINS}/known_marketplaces.json"
INSTALLED_PLUGINS="${FACTORY_PLUGINS}/installed_plugins.json"
VERSION="${WANNABUILD_FACTORY_VERSION:-$(git -C "$ROOT" rev-parse --short=12 HEAD 2>/dev/null || printf 'local')}"

ADAPTER_SYMLINK="$(find "$ADAPTER" -mindepth 1 -type l -print -quit 2>/dev/null || true)"
if [[ -n "$ADAPTER_SYMLINK" ]]; then
  echo "Install verification failed: Factory adapter must be self-contained; found symlink: ${ADAPTER_SYMLINK#"$ROOT/"}" >&2
  exit 1
fi

mkdir -p "$PLUGIN_CACHE_PARENT" "$DROIDS_DIR" "$(dirname "$KNOWN_MARKETPLACES")" "$(dirname "$INSTALLED_PLUGINS")"

safe_remove_existing "$PLUGIN_CACHE"
create_link "$ADAPTER" "$PLUGIN_CACHE"

# $PLUGIN_CACHE is a symlink to the Factory adapter (create_link above). The
# Factory hook resolves the Rust gate engine at parents[1]/target/debug/wb-runtime
# — i.e. target/debug *inside* the adapter the cache points to. The npx installer
# hands us the prebuilt binary via WB_RUNTIME_PREBUILT; place it there through the
# cache symlink (deriving the path from $PLUGIN_CACHE keeps the <marketplace>
# segment correct). Absent that binary, the hook falls back to the degraded
# Python mirror. Because the cache symlinks into the checkout, removing the
# checkout (e.g. `npx wannabuild uninstall --purge`) also removes this binary.
RUNTIME_BIN="${PLUGIN_CACHE}/target/debug/wb-runtime"
if [[ -n "${WB_RUNTIME_PREBUILT:-}" && -x "${WB_RUNTIME_PREBUILT}" ]]; then
  mkdir -p "${PLUGIN_CACHE}/target/debug"
  cp "$WB_RUNTIME_PREBUILT" "$RUNTIME_BIN"
  chmod +x "$RUNTIME_BIN"
fi

"$PYTHON" - "$NAMESPACE" "$MARKETPLACE" "$PLUGIN" "$VERSION" "$(json_path_for_host "$ROOT")" "$(json_path_for_host "$PLUGIN_CACHE")" "$KNOWN_MARKETPLACES" "$INSTALLED_PLUGINS" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

namespace, marketplace, plugin, version, marketplace_dir, install_path, known_file, installed_file = sys.argv[1:]

def load_json(path, default):
    p = Path(path)
    if p.exists():
        try:
            return json.loads(p.read_text())
        except Exception:
            pass
    return default

now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

known_path = Path(known_file)
known = load_json(known_file, {})
if namespace != marketplace:
    known.pop(namespace, None)
known[marketplace] = {
    "source": {"source": "local", "path": marketplace_dir},
    "installLocation": marketplace_dir,
    "lastUpdated": now,
    "autoUpdate": True,
}
known_path.write_text(json.dumps(known, indent=2))
print(f"Registered {marketplace} in known_marketplaces.json")

installed_path = Path(installed_file)
installed = load_json(installed_file, {"schemaVersion": 1, "plugins": {}})
installed.setdefault("schemaVersion", 1)
plugins = installed.setdefault("plugins", {})
if namespace != marketplace:
    plugins.pop(f"{plugin}@{namespace}", None)
key = f"{plugin}@{marketplace}"
plugins[key] = [
    {
        "scope": "user",
        "installPath": install_path,
        "version": version,
        "installedAt": now,
        "lastUpdated": now,
        "source": marketplace,
    }
]
installed_path.write_text(json.dumps(installed, indent=2))
print(f"Registered {key} in installed_plugins.json")
PY

"$PYTHON" - "$ROOT" "$DROIDS_DIR" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
droids_dir = Path(sys.argv[2])
droids_dir.mkdir(parents=True, exist_ok=True)

def parse_frontmatter(text):
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return {}, text
    end = None
    for idx in range(1, len(lines)):
        if lines[idx].strip() == "---":
            end = idx
            break
    if end is None:
        return {}, text
    meta = {}
    for line in lines[1:end]:
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        value = value.strip()
        if (value.startswith('"') and value.endswith('"')) or (value.startswith("'") and value.endswith("'")):
            value = value[1:-1]
        meta[key.strip()] = value
    return meta, "\n".join(lines[end + 1 :]).lstrip()

def parse_tools(value):
    if not value:
        return []
    value = value.strip()
    if value.startswith("[") and value.endswith("]"):
        try:
            return [str(item) for item in json.loads(value)]
        except Exception:
            pass
    return [part.strip().strip('"').strip("'") for part in value.split(",") if part.strip()]

def factory_tools(tools):
    mapped = []
    for tool in tools:
        if tool in {"Read", "Grep", "Glob"} and tool not in mapped:
            mapped.append(tool)
    if any(tool in {"Edit", "Write"} for tool in tools):
        mapped.append("Edit")
    if "Bash" in tools:
        mapped.append("Execute")
    return mapped

def quoted(value):
    return json.dumps(value)

generated = []
for source in sorted((root / "agents").glob("wb-*.md")):
    text = source.read_text()
    meta, body = parse_frontmatter(text)
    name = meta.get("name", source.stem)
    description = meta.get("description", f"WannaBuild specialist agent: {name}")
    tools = factory_tools(parse_tools(meta.get("tools", "")))
    tool_line = f"tools: {json.dumps(tools)}\n" if tools else ""
    note = ""
    if "Execute" in tools or "Edit" in tools:
        note = "Factory adapter note: use Factory `Execute` when this prompt refers to Bash, and Factory `Edit` when it refers to Write/Edit.\n\n"
    content = (
        "---\n"
        f"name: {name}\n"
        f"description: {quoted(description)}\n"
        "model: inherit\n"
        f"{tool_line}"
        "---\n\n"
        f"{note}"
        f"{body.rstrip()}\n"
    )
    target = droids_dir / f"{name}.md"
    target.write_text(content)
    generated.append(target)

advisor = root / ".factory" / "droids" / "wb-advisor.md"
if advisor.exists():
    target = droids_dir / "wb-advisor.md"
    target.write_text(advisor.read_text())
    generated.append(target)

for target in generated:
    print(f"Installed Factory droid: {target}")
PY

if [[ ! -f "${PLUGIN_CACHE}/.factory-plugin/plugin.json" ]]; then
  echo "Install verification failed: Factory plugin manifest not reachable at ${PLUGIN_CACHE}" >&2
  exit 1
fi
if [[ ! -f "${PLUGIN_CACHE}/skills/wannabuild/SKILL.md" ]]; then
  echo "Install verification failed: main WannaBuild skill not reachable at ${PLUGIN_CACHE}" >&2
  exit 1
fi
if [[ ! -f "${PLUGIN_CACHE}/commands/wannabuild.md" ]]; then
  echo "Install verification failed: WannaBuild command not reachable at ${PLUGIN_CACHE}" >&2
  exit 1
fi
if [[ ! -f "${DROIDS_DIR}/wb-architect.md" || ! -f "${DROIDS_DIR}/wb-integration-tester.md" || ! -f "${DROIDS_DIR}/wb-advisor.md" ]]; then
  echo "Install verification failed: expected Factory droids not installed in ${DROIDS_DIR}" >&2
  exit 1
fi
if [[ -n "${WB_RUNTIME_PREBUILT:-}" && ! -x "$RUNTIME_BIN" ]]; then
  echo "Install verification failed: wb-runtime not executable at ${RUNTIME_BIN}" >&2
  exit 1
fi

echo ""
echo "Installed WannaBuild for Droid:"
echo "  Plugin path: ${PLUGIN_CACHE} -> ${ADAPTER}"
echo "  Marketplace: ${MARKETPLACE} -> ${ROOT}"
echo "  Plugin:      ${PLUGIN}@${MARKETPLACE}"
echo "  Droids:      ${DROIDS_DIR}/wb-*.md"
if [[ -x "$RUNTIME_BIN" ]]; then
  echo "  Runtime:     ${RUNTIME_BIN}"
else
  echo "  Runtime:     MISSING (Python mirror fallback)"
fi
echo ""
echo "Restart Droid, then type a natural feature request."
echo "Explicit shortcuts remain available as plugin commands and skills."
