#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

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
    "$TARGET"/*) ;;
    *)
      echo "Refusing to remove path outside Codex skills target: $path" >&2
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

create_skill_link() {
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
    ln -s "$source" "$dest"
  fi
}

HOST_HOME="$(resolve_host_home)"
CODEX_BASE="${CODEX_HOME:-${HOST_HOME}/.codex}"
TARGET="${CODEX_SKILLS_DIR:-${CODEX_BASE}/skills}"
RUNTIME_TARGET="${CODEX_RUNTIME_DIR:-${CODEX_BASE}/bin}"

mkdir -p "$TARGET" "$RUNTIME_TARGET"

installed=()
installed_runtime=""

install_repo_skill() {
  local name="$1"
  local source="$ROOT/skills/$name"
  local dest="$TARGET/$name"
  safe_remove_existing "$dest"
  create_skill_link "$source" "$dest"
  if [[ ! -f "$dest/SKILL.md" ]]; then
    echo "Install verification failed for $dest" >&2
    return 1
  fi
  installed+=("$TARGET/$name")
}

runtime_binary_source() {
  local source="$ROOT/target/debug/wb-runtime"
  if [[ -x "$source" ]]; then
    printf '%s\n' "$source"
  elif [[ -x "${source}.exe" ]]; then
    printf '%s\n' "${source}.exe"
  else
    return 1
  fi
}

install_codex_runtime() {
  local source name dest

  if ! command -v cargo >/dev/null 2>&1; then
    echo "Codex runtime install failed: cargo is required to build wb-runtime." >&2
    return 1
  fi

  cargo build --quiet --manifest-path "$ROOT/Cargo.toml" --bin wb-runtime
  source="$(runtime_binary_source)" || {
    echo "Codex runtime install failed: built wb-runtime binary was not found." >&2
    return 1
  }

  name="$(basename "$source")"
  dest="$RUNTIME_TARGET/$name"
  cp "$source" "$dest"
  chmod +x "$dest"
  if [[ ! -x "$dest" ]]; then
    echo "Codex runtime install verification failed for $dest" >&2
    return 1
  fi
  installed_runtime="$dest"
}

install_repo_skill "wannabuild"
install_repo_skill "using-wannabuild"

if [[ -d "$ROOT/skills" ]]; then
  while IFS= read -r skill_file; do
    install_repo_skill "$(basename "$(dirname "$skill_file")")"
  done < <(find "$ROOT/skills" -mindepth 2 -maxdepth 2 -type f -path '*/wb-*/SKILL.md' | LC_ALL=C sort)
fi

install_codex_runtime

echo "Installed Codex skills:"
for path in "${installed[@]}"; do
  echo "- $path"
done
echo
echo "Installed Codex runtime:"
echo "- $installed_runtime"
echo
echo "Verified Codex skills target:"
echo "  $TARGET"
echo
echo "Verified Codex runtime target:"
echo "  $RUNTIME_TARGET"
echo "Add this directory to PATH if Codex cannot find wb-runtime."
echo
echo "Restart Codex, then type a natural feature request."
echo "Explicit shortcut remains available: \$wannabuild"
