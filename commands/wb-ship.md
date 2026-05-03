---
description: Prepare the WannaBuild final handoff
argument-hint: [scope]
---

# /wb-ship

Use this toolbox command when the user wants final handoff.

Before phase work, enforce Mandatory Toolbox Bootstrap: if this is a concrete task in a git repo and the session is not already inside an isolated WannaBuild workspace, use the `wannabuild` workspace bootstrap contract or `scripts/wannabuild-workspace.sh --json`, then continue only in the isolated workspace.

1. Use the `wb-ship` skill.
2. Start or resume `.wannabuild` state.
3. Confirm review and QA evidence exists or clearly report what is missing.
4. Summarize changes, checks passed, risks, and remaining work.
5. Prepare commit or PR text only when requested.

Do not create commits, push branches, or open pull requests unless the user explicitly asks.
