#!/usr/bin/env bats
#
# Regression: hooks/hooks.json must be wrapped under a top-level `hooks` key
# that maps to the event record Claude Code's plugin loader expects:
#
#   { "hooks": { "SessionStart": [...], "UserPromptSubmit": [...] } }
#
# Earlier WannaBuild releases (≤ 2.2.5) shipped the unwrapped shape because
# an older Claude Code accepted it. The current plugin loader rejects the
# unwrapped shape with `expected record, received undefined` at path `hooks`
# and a stray `"hooks": "./hooks/hooks.json"` declaration in marketplace.json
# crashes `/plugin` with `TypeError: v?.reduce is not a function`. See
# docs/runbooks/install-and-load-failures.md.

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

HOOKS_FILE="${REPO_ROOT}/hooks/hooks.json"

py() {
  python3 -c "$@"
}

@test "plugin hooks.json: file exists and parses as JSON" {
  [ -f "$HOOKS_FILE" ]
  py "import json; json.load(open('$HOOKS_FILE'))"
}

@test "plugin hooks.json: top level IS wrapped under a 'hooks' key" {
  run py "
import json,sys
d=json.load(open('$HOOKS_FILE'))
sys.exit(0 if list(d.keys())==['hooks'] and isinstance(d['hooks'],dict) else 1)
"
  [ "$status" -eq 0 ]
}

@test "plugin hooks.json: declares SessionStart event as an array of hook groups" {
  run py "
import json,sys
d=json.load(open('$HOOKS_FILE'))
v=d['hooks'].get('SessionStart')
sys.exit(0 if isinstance(v,list) and len(v)>=1 else 1)
"
  [ "$status" -eq 0 ]
}

@test "plugin hooks.json: declares UserPromptSubmit event as an array of hook groups" {
  run py "
import json,sys
d=json.load(open('$HOOKS_FILE'))
v=d['hooks'].get('UserPromptSubmit')
sys.exit(0 if isinstance(v,list) and len(v)>=1 else 1)
"
  [ "$status" -eq 0 ]
}

@test "plugin hooks.json: every event maps to an array of groups, each with a hooks array" {
  run py "
import json,sys
d=json.load(open('$HOOKS_FILE'))
for ev,groups in d['hooks'].items():
    assert isinstance(groups,list), f'{ev} not a list'
    for g in groups:
        assert isinstance(g,dict), f'{ev} group not a dict'
        assert 'hooks' in g and isinstance(g['hooks'],list), f'{ev} group missing hooks array'
        for h in g['hooks']:
            assert isinstance(h,dict), f'{ev} hook not a dict'
            assert 'type' in h and 'command' in h, f'{ev} hook missing type/command'
"
  [ "$status" -eq 0 ]
}
