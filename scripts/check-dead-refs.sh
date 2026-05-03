#!/usr/bin/env bash
# check-dead-refs.sh — find broken markdown links and unused shell functions.
#
# Two checks:
#   1. Every relative `[text](path)` link in *.md under the documented
#      surfaces resolves to an existing file in the repo.
#   2. Every function defined in scripts/*.sh is invoked from at least one
#      scripts/*.sh file (excluding its own definition).

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

if ! command -v rg >/dev/null 2>&1; then
  echo "ripgrep (rg) not installed" >&2
  exit 127
fi

dead_links=()
unused_funcs=()

# ----- 1. Markdown link check -----------------------------------------------

# Surfaces we treat as user-facing documentation.
md_dirs=(skills agents docs commands adapters)

# Match `](target)` while ignoring images and code-fenced blocks.
# rg's PCRE2 mode keeps the regex readable.
link_regex='(?<!\!)\[[^\]]+\]\(([^)#?\s]+)(?:[#?][^)]*)?\)'

while IFS=$'\t' read -r file target; do
  [[ -z "${file:-}" || -z "${target:-}" ]] && continue
  # Skip absolute URLs and mailto links.
  case "${target}" in
    http://* | https://* | mailto:* | ftp://* | tel:*) continue ;;
    /*) abs="${REPO_ROOT}${target}" ;; # repo-rooted path
    *) abs="$(dirname -- "${file}")/${target}" ;;
  esac

  # Skip placeholder targets (documentation examples like `[text](url)`):
  # purely alphanumeric with no path separator, dot, or extension.
  if [[ "${target}" =~ ^[A-Za-z][A-Za-z0-9_-]*$ ]]; then
    continue
  fi

  # Normalize ./
  abs="${abs#./}"
  if [[ -e "${abs}" ]]; then
    continue
  fi

  # Try resolving via repo root (some links are repo-relative).
  if [[ -e "${REPO_ROOT}/${target}" ]]; then
    continue
  fi

  dead_links+=("${file} -> ${target}")
done < <(
  rg --pcre2 --no-heading --no-line-number --only-matching \
    --replace $'\t$1' \
    -g '*.md' \
    "${link_regex}" \
    "${md_dirs[@]}" 2>/dev/null \
    | awk -F'\t' 'NF>=2 {
       split($1, a, ":"); file=a[1];
       # rejoin remainder of $1 in case the path contained colons
       for (i=2; i<length(a); i++) file=file ":" a[i];
       print file "\t" $2
     }'
)

# ----- 2. Unused shell function check ---------------------------------------

scripts_dir="${REPO_ROOT}/scripts"

# Files known to be sourced libraries (their functions are callable externally
# from sourced contexts and are therefore exempt from the unused-function
# check). Names match against basename in scripts/.
LIB_BASENAMES=(
  wb-log.sh
  wb-trace.sh
  wb-metrics.sh
)

is_lib_file() {
  local target="$1" base entry
  base="$(basename -- "${target}")"
  for entry in "${LIB_BASENAMES[@]}"; do
    [[ "${entry}" == "${base}" ]] && return 0
  done
  return 1
}

# Collect "file:funcname" pairs.
declare -a defs=()
while IFS= read -r match; do
  defs+=("${match}")
done < <(
  rg --no-heading --line-number \
    -g '*.sh' \
    '^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(\)[[:space:]]*\{' \
    "${scripts_dir}" \
    | sed -E 's/[[:space:]]*\(\).*$//' \
    | awk -F: '{print $1 ":" $NF}'
)

for def in "${defs[@]}"; do
  file="${def%%:*}"
  fn="${def##*:}"
  fn="$(echo "${fn}" | tr -d '[:space:]')"
  case "${fn}" in
    main | usage | help) continue ;; # conventional entrypoints
    "") continue ;;
  esac

  # Skip functions defined in sourced library files.
  if is_lib_file "${file}"; then
    continue
  fi

  # Look for invocations. The regex excludes the definition line because
  # `fn(` is not allowed by `[^A-Za-z0-9_(]`, so any match is an actual call.
  if rg --no-heading -q \
    -g '*.sh' \
    "(^|[^A-Za-z0-9_])${fn}([[:space:]]|$|[^A-Za-z0-9_(])" \
    "${scripts_dir}"; then
    continue
  fi

  unused_funcs+=("${file}: ${fn}")
done

# ----- Report ----------------------------------------------------------------

violations=0

if ((${#dead_links[@]} > 0)); then
  echo "check-dead-refs: ${#dead_links[@]} broken markdown link(s):" >&2
  printf '  %s\n' "${dead_links[@]}" >&2
  violations=$((violations + ${#dead_links[@]}))
fi

if ((${#unused_funcs[@]} > 0)); then
  echo "check-dead-refs: ${#unused_funcs[@]} unused shell function(s):" >&2
  printf '  %s\n' "${unused_funcs[@]}" >&2
  violations=$((violations + ${#unused_funcs[@]}))
fi

if ((violations > 0)); then
  exit 1
fi

echo "check-dead-refs: OK"
