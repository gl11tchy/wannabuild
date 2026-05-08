## Summary

<!-- One paragraph: what this PR does and why. Link to the issue. -->

Closes #

## Type of change

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] Feature (non-breaking new capability)
- [ ] Breaking change (fix or feature that changes existing contracts)
- [ ] Documentation only
- [ ] Refactor / chore
- [ ] Specialist agent prompt change
- [ ] Schema / artifact contract change

## Surfaces touched

<!-- Check all that apply. Each box implies certain reviewers per CODEOWNERS. -->

- [ ] AGENTS.md / operator contract
- [ ] skills/internal/build/SKILL.md (orchestrator spec)
- [ ] agents/wb-*.md (specialist prompts)
- [ ] scripts/ (validation or runtime helpers)
- [ ] schemas/ (artifact JSON schemas)
- [ ] adapters/ (host-specific packaging)
- [ ] docs/
- [ ] tests/
- [ ] .github/ (CI, governance)

## Verification

<!-- Check what you actually ran. -->

- [ ] `bash scripts/wannabuild-doctor.sh` passes locally
- [ ] `bash scripts/lint.sh` passes locally
- [ ] `bash tests/run.sh` passes locally
- [ ] `pre-commit run --all-files` passes locally
- [ ] If contract changed: validator updated and run against fixtures
- [ ] If schema changed: example artifacts updated
- [ ] CI is green

## Spec impact

<!-- If you changed orchestrator behavior, link the changed sections. -->

- [ ] No spec impact
- [ ] Updated AGENTS.md (sections: ___)
- [ ] Updated relevant SKILL.md (which: ___)
- [ ] Updated reference doc in skills/internal/build/references/ (which: ___)
- [ ] Updated schema in skills/internal/build/schemas/ (which: ___)
- [ ] Updated CHANGELOG via Conventional Commit

## Risk & rollout

<!-- Anything reviewers should know? Migration steps? Backward-compat concerns? -->

## Screenshots / output (optional)

<!-- For docs changes, attach rendered output. -->
