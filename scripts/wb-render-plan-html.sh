#!/usr/bin/env bash
# wb-render-plan-html.sh — render N adversarial planned implementations from a
# plan-options.json into ONE self-contained HTML file, then best-effort open it.
#
# Usage:
#   wb-render-plan-html.sh --input <plan-options.json> [--out <file>] \
#       [--count <n>] [--no-open]
#
# Behavior:
#   * Output HTML is fully self-contained (inline CSS, no network references).
#   * Every interpolated field is HTML-escaped (Python html.escape).
#   * --count clamps to [2,5] (default 3) and renders the first min(count, plans).
#   * Browser open is best-effort: on $CI, --no-open, no opener, or a headless
#     Linux session it prints the absolute path + file:// URL instead. A failed
#     open is a warning, never a non-zero exit — rendering never blocks the phase.
#
# Environment:
#   CI            - when set (non-empty), auto-open is skipped (path is printed).
#   DISPLAY /
#   WAYLAND_DISPLAY - required for xdg-open on Linux; absent => print path.
set -euo pipefail

# shellcheck source=scripts/wb-log.sh
. "$(dirname -- "${BASH_SOURCE[0]}")/wb-log.sh"

usage() {
  cat <<'EOF'
Usage: wb-render-plan-html.sh --input <plan-options.json> [--out <file>] [--count <n>] [--no-open]
EOF
}

input=""
out=""
count=""
no_open=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)
      input="${2:-}"
      shift 2
      ;;
    --out)
      out="${2:-}"
      shift 2
      ;;
    --count)
      count="${2:-}"
      shift 2
      ;;
    --no-open)
      no_open=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      wb_log_error "unknown argument: $1"
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$input" ]]; then
  wb_log_error "--input <plan-options.json> is required"
  usage >&2
  exit 2
fi
if [[ ! -f "$input" ]]; then
  wb_log_error "input not found: $input"
  exit 2
fi
if [[ -z "$out" ]]; then
  out="$(dirname -- "$input")/adversarial-plans.html"
fi

mkdir -p "$(dirname -- "$out")"

# Render (parse JSON, clamp count, escape, emit self-contained HTML) in Python —
# same dependency the validator uses, and html.escape covers AC6 exactly.
if ! python3 - "$input" "$out" "$count" <<'PY'; then
import html
import json
import sys

input_path, out_path, count_raw = sys.argv[1], sys.argv[2], sys.argv[3]

with open(input_path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

# Render every plan in the artifact by default (the agent already produced exactly
# plan_adversarial_count plans). --count is an optional cap, clamped to [2,5], for
# callers that explicitly want fewer; it never silently hides configured plans.
plans = data.get("plans") or []
if str(count_raw).strip():
    try:
        count = int(count_raw)
    except ValueError:
        count = len(plans)
    count = max(2, min(5, count))
    shown = plans[: min(count, len(plans))]
else:
    shown = plans

recommended_id = data.get("recommended_id")
chosen_id = data.get("chosen_id")
goal = data.get("goal", "")


def esc(value):
    return html.escape(str(value), quote=True)


def list_items(items):
    return "".join("<li>{}</li>".format(esc(i)) for i in (items or []))


cards = []
for plan in shown:
    pid = plan.get("id")
    is_rec = pid == recommended_id
    is_chosen = chosen_id is not None and pid == chosen_id
    classes = "card"
    if is_rec:
        classes += " rec"
    if is_chosen:
        classes += " chosen"
    badges = ""
    if is_rec:
        badges += '<span class="badge rec">&#9733; Recommended</span>'
    if is_chosen:
        badges += '<span class="badge chosen">&#10003; Chosen</span>'
    if not badges:
        badges = '<span class="badge alt">Alternative</span>'
    cards.append(
        """    <section class="{classes}">
      {badges}
      <p class="stance">{stance}</p>
      <h2>{title}</h2>
      <p class="summary">{summary}</p>
      <div class="sec"><h3>Plan slices</h3><ul>{slices}</ul></div>
      <div class="sec"><h3>Impacted surfaces</h3><ul>{surfaces}</ul></div>
      <div class="sec"><h3>Verification</h3><ul>{verification}</ul></div>
      <div class="crit"><h3>&#9876; Critique of the others</h3><p>{critique}</p></div>
    </section>""".format(
            classes=classes,
            badges=badges,
            stance=esc(plan.get("stance", "")),
            title=esc(plan.get("title", plan.get("id", ""))),
            summary=esc(plan.get("summary", "")),
            slices=list_items(plan.get("slices")),
            surfaces=list_items(plan.get("impacted_surfaces")),
            verification=list_items(plan.get("verification")),
            critique=esc(plan.get("critique_of_others", "")),
        )
    )

doc = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>WannaBuild - Adversarial Plans</title>
<style>
  :root{{--bg:#0b0f17;--panel:#121826;--panel2:#0e1320;--ink:#e7ecf3;--muted:#9aa7bd;
    --line:#1f2940;--accent:#5b8cff;--rec:#34d399;--warn:#f4b860;--warn-soft:#2a210f;--chip:#1a2336}}
  *{{box-sizing:border-box}}
  html,body{{margin:0;background:var(--bg);color:var(--ink);line-height:1.5;
    font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif}}
  .wrap{{max-width:1280px;margin:0 auto;padding:32px 24px 64px}}
  .eyebrow{{font-size:12px;letter-spacing:.14em;text-transform:uppercase;color:var(--muted);font-weight:700}}
  h1{{font-size:26px;margin:6px 0 4px}}
  .goal{{color:var(--muted);max-width:80ch}}
  .grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:18px;margin-top:24px}}
  .card{{background:var(--panel);border:1px solid var(--line);border-radius:14px;
    padding:18px;display:flex;flex-direction:column;min-width:0}}
  .card.rec{{border-color:var(--rec);box-shadow:0 0 0 1px var(--rec),0 12px 40px -18px rgba(52,211,153,.5)}}
  .card.chosen{{border-color:var(--accent);box-shadow:0 0 0 1px var(--accent),0 12px 40px -18px rgba(91,140,255,.55)}}
  .badge{{align-self:flex-start;font-size:11px;font-weight:800;letter-spacing:.08em;text-transform:uppercase;
    padding:4px 9px;border-radius:999px;margin:0 6px 10px 0;background:var(--chip);color:var(--muted)}}
  .badge.rec{{background:var(--rec);color:#04241a}}
  .badge.chosen{{background:var(--accent);color:#04122e}}
  .stance{{font-size:13px;color:var(--accent);font-weight:700;margin:0 0 2px}}
  h2{{font-size:19px;margin:0 0 8px}}
  .summary{{color:var(--muted);font-size:14px;margin:0 0 14px}}
  .sec{{margin-top:12px}}
  .sec h3{{font-size:11px;letter-spacing:.1em;text-transform:uppercase;color:var(--muted);margin:0 0 6px;font-weight:700}}
  ul{{margin:0;padding-left:18px}}
  li{{margin:3px 0;font-size:13.5px}}
  .crit{{margin-top:14px;background:var(--warn-soft);border:1px solid #4a3a12;border-radius:10px;padding:11px 12px}}
  .crit h3{{color:var(--warn)}}
  .crit p{{margin:0;font-size:13px;color:#f0dcb4}}
</style>
</head>
<body>
<div class="wrap">
  <div class="eyebrow">WannaBuild - Plan phase - Adversarial planned implementations</div>
  <h1>Proposed plans</h1>
  <p class="goal">{goal}</p>
  <div class="grid">
{cards}
  </div>
</div>
</body>
</html>
""".format(goal=esc(goal), cards="\n".join(cards))

with open(out_path, "w", encoding="utf-8") as fh:
    fh.write(doc)
PY
  wb_log_error "failed to render plan HTML from $input"
  exit 1
fi

# Resolve absolute path + file:// URL for the fallback / status output.
abs="$(cd "$(dirname -- "$out")" && pwd)/$(basename -- "$out")"
url="file://$abs"

print_path() {
  printf '%s\n' "$abs"
  printf '%s\n' "$url"
}

# Best-effort open. Any failure prints the path and still exits 0.
if [[ "$no_open" -eq 1 || -n "${CI:-}" ]]; then
  wb_log_info "auto-open skipped; plan HTML at $abs"
  print_path
  exit 0
fi

opener=""
if command -v open >/dev/null 2>&1; then
  opener="open"
elif [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] && command -v xdg-open >/dev/null 2>&1; then
  opener="xdg-open"
elif command -v cmd.exe >/dev/null 2>&1; then
  opener="cmd.exe"
fi

if [[ -z "$opener" ]]; then
  wb_log_warn "no browser opener available; plan HTML at $abs"
  print_path
  exit 0
fi

if [[ "$opener" == "cmd.exe" ]]; then
  if cmd.exe /c start "" "$abs" >/dev/null 2>&1; then
    wb_log_info "opened plan HTML in browser"
    exit 0
  fi
elif "$opener" "$abs" >/dev/null 2>&1; then
  wb_log_info "opened plan HTML in browser"
  exit 0
fi

wb_log_warn "could not open browser; plan HTML at $abs"
print_path
exit 0
