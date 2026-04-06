#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/wannabuild-workspace.sh [--label <name>] [--json]

Creates an isolated WannaBuild git worktree and branch for the current repo.
If the working tree is dirty, the current file content is snapshotted into the
isolated workspace so the original checkout is not modified further.
USAGE
}

label="run"
json=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --label)
      label="${2:-run}"
      shift 2
      ;;
    --json)
      json=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: not inside a git work tree" >&2
  exit 1
fi

root="$(git rev-parse --show-toplevel)"
current_branch="$(git branch --show-current)"
if [[ -z "$current_branch" ]]; then
  current_branch="detached"
fi

repo_name="$(basename "$root")"
slug="$(printf '%s' "$label" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//; s/-$//')"
if [[ -z "$slug" ]]; then
  slug="run"
fi

ts="$(date +%Y%m%d%H%M%S)"
rand="$(python3 - <<'PY'
import secrets
alphabet = "abcdefghijklmnopqrstuvwxyz0123456789"
print("".join(secrets.choice(alphabet) for _ in range(6)))
PY
)"
workspace_id="${ts}-${slug}-${rand}"
parent_dir="$(dirname "$root")/.wannabuild-workspaces/${repo_name}"
workspace_path="${parent_dir}/${workspace_id}"
branch_name="wannabuild/${workspace_id}"

mkdir -p "$parent_dir"

dirty=false
if [[ -n "$(git status --porcelain)" ]]; then
  dirty=true
fi

git worktree add -b "$branch_name" "$workspace_path" HEAD >/dev/null

if [[ "$dirty" == true ]]; then
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete \
      --exclude '.git' \
      --exclude '.wannabuild' \
      --exclude 'node_modules' \
      --exclude '.next' \
      --exclude '.turbo' \
      --exclude 'dist' \
      --exclude 'build' \
      --exclude 'coverage' \
      --exclude '.omx' \
      "$root"/ "$workspace_path"/
  else
    (
      cd "$root"
      tar \
        --exclude='.git' \
        --exclude='.wannabuild' \
        --exclude='node_modules' \
        --exclude='.next' \
        --exclude='.turbo' \
        --exclude='dist' \
        --exclude='build' \
        --exclude='coverage' \
        --exclude='.omx' \
        -cf - .
    ) | (
      cd "$workspace_path"
      tar -xf -
    )
  fi
fi

mkdir -p "$workspace_path/.wannabuild"
cat > "$workspace_path/.wannabuild/workspace.json" <<EOF
{
  "workspace_id": "$workspace_id",
  "source_repo": "$root",
  "source_branch": "$current_branch",
  "workspace_path": "$workspace_path",
  "branch_name": "$branch_name",
  "dirty_snapshot": $dirty
}
EOF

if [[ "$json" == true ]]; then
  cat <<EOF
{"workspace_id":"$workspace_id","source_repo":"$root","source_branch":"$current_branch","workspace_path":"$workspace_path","branch_name":"$branch_name","dirty_snapshot":$dirty}
EOF
else
  echo "WannaBuild workspace created"
  echo "workspace_id: $workspace_id"
  echo "source_repo: $root"
  echo "source_branch: $current_branch"
  echo "branch_name: $branch_name"
  echo "workspace_path: $workspace_path"
  echo "dirty_snapshot: $dirty"
  echo
  echo "Continue work in:"
  echo "  $workspace_path"
fi
