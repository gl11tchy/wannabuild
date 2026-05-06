#!/usr/bin/env bats
#
# Regression: hooks/hooks.json must be the unwrapped event-map shape that
# Claude Code's plugin loader expects. A previous wrapped shape made
# `/reload-plugins` crash with `TypeError: X?.reduce is not a function`
# because the loader iterated the inner object as if it were an array.

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

HOOKS_FILE="${REPO_ROOT}/hooks/hooks.json"

py() {
  python3 -c "$@"
}

@test "plugin hooks.json: file exists and parses as JSON" {
  [ -f "$HOOKS_FILE" ]
  py "import json; json.load(open('$HOOKS_FILE'))"
}

@test "plugin hooks.json: top level is NOT wrapped under a 'hooks' key" {
  run py "
import json,sys
d=json.load(open('$HOOKS_FILE'))
sys.exit(0 if 'hooks' not in d else 1)
"
  [ "$status" -eq 0 ]
}

@test "plugin hooks.json: declares SessionStart event as an array of hook groups" {
  run py "
import json,sys
d=json.load(open('$HOOKS_FILE'))
v=d.get('SessionStart')
sys.exit(0 if isinstance(v,list) and len(v)>=1 else 1)
"
  [ "$status" -eq 0 ]
}

@test "plugin hooks.json: declares UserPromptSubmit event as an array of hook groups" {
  run py "
import json,sys
d=json.load(open('$HOOKS_FILE'))
v=d.get('UserPromptSubmit')
sys.exit(0 if isinstance(v,list) and len(v)>=1 else 1)
"
  [ "$status" -eq 0 ]
}

@test "plugin hooks.json: every event maps to an array of groups, each with a hooks array" {
  run py "
import json,sys
d=json.load(open('$HOOKS_FILE'))
for ev,groups in d.items():
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
