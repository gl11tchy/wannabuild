# Task 10 — End-to-end verification

## Step 1: Run the doctor script

```bash
./scripts/wannabuild-doctor.sh
```

Expected: passes without errors.

### Step 2: Verify no stale Codex-only syntax in Claude-facing files

```bash
grep -n '\$wannabuild' commands/wannabuild.md
```

Expected: no output.

#### Step 3: Verify no broken script paths in skill

```bash
grep -n '\.\./\.\./scripts' skills/wannabuild/SKILL.md
```

Expected: no output.

##### Step 4: Verify install script is executable

```bash
ls -la scripts/install-claude-skill.sh
```

Expected: `-rwxr-xr-x`

###### Step 5: Check all new/modified files exist

```bash
ls -1 \
  commands/wannabuild.md \
  skills/wannabuild/SKILL.md \
  scripts/install-claude-skill.sh \
  .claude/INSTALL.md \
  adapters/claude-code/README.md \
  docs/claude-code-getting-started.md \
  docs/host-capability-matrix.md
```

###### Step 6: Final commit if any loose ends

```bash
git status
```

If clean, done. If not, commit any remaining changes.
