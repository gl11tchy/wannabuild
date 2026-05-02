# Design

The demo keeps artifacts intentionally small. It exercises the same contracts as a real target project:

- `.wannabuild/state.json` is the resumable source of truth.
- `.wannabuild/loop-state.json` records review routing and verdict status.
- `.wannabuild/checkpoints/` records implementation evidence.
- `.wannabuild/review/` records reviewer verdicts.
- `.wannabuild/outputs/qa-summary.md` records QA evidence.
