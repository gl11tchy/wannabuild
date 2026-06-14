# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Beginning with the next release, this file is maintained automatically by
[release-please](https://github.com/googleapis/release-please) — do not edit
the auto-generated sections by hand.

## [2.7.2](https://github.com/gl11tchy/wannabuild/compare/v2.7.1...v2.7.2) (2026-06-14)


### Fixes

* **release:** use sha256sum fallback so the Windows binary packages ([#72](https://github.com/gl11tchy/wannabuild/issues/72)) ([21578f1](https://github.com/gl11tchy/wannabuild/commit/21578f1ae597c768eafc767963ff7c26020d08d4))

## [2.7.1](https://github.com/gl11tchy/wannabuild/compare/v2.7.0...v2.7.1) (2026-06-14)


### Fixes

* **release:** cross-compile Intel-macOS binary and skip harden-runner on Windows ([#70](https://github.com/gl11tchy/wannabuild/issues/70)) ([929f212](https://github.com/gl11tchy/wannabuild/commit/929f2124c37f8509a5d8d408d6220a637ded3485))

## [2.7.0](https://github.com/gl11tchy/wannabuild/compare/v2.6.0...v2.7.0) (2026-06-13)


### Features

* npx installer that ships the Rust wb-runtime to every host ([#68](https://github.com/gl11tchy/wannabuild/issues/68)) ([7536ef2](https://github.com/gl11tchy/wannabuild/commit/7536ef2c0d06f8041a43eba5aff48d1ea8447426))
* trust-hardening round — runtime-recorded evidence, red-team tests, trust-first positioning ([#66](https://github.com/gl11tchy/wannabuild/issues/66)) ([bd678ae](https://github.com/gl11tchy/wannabuild/commit/bd678ae18844e021b1d0aa1ad73f92fa334ceb0b))


### Fixes

* **devcontainer:** build kcov from source since noble dropped the package ([#63](https://github.com/gl11tchy/wannabuild/issues/63)) ([b4db8cc](https://github.com/gl11tchy/wannabuild/commit/b4db8cc154bb81b2fa71117eb208dc60c3d3807a))
* **release:** build binaries + publish npm via release-please needs-job; land [#67](https://github.com/gl11tchy/wannabuild/issues/67) evidence fix ([#69](https://github.com/gl11tchy/wannabuild/issues/69)) ([ba1c12d](https://github.com/gl11tchy/wannabuild/commit/ba1c12d61354034bee6f24a35a4539dfa860df4d))

## [2.6.0](https://github.com/gl11tchy/wannabuild/compare/v2.5.0...v2.6.0) (2026-06-10)


### Features

* rewrite contracts for frontier-class executors with Claude model tiering ([#60](https://github.com/gl11tchy/wannabuild/issues/60)) ([496e79a](https://github.com/gl11tchy/wannabuild/commit/496e79ad044b82abf3afe923fd7f414fce8b4d9f))


### Fixes

* **release:** drop package-name so release tagging matches PR component ([#62](https://github.com/gl11tchy/wannabuild/issues/62)) ([7b94f69](https://github.com/gl11tchy/wannabuild/commit/7b94f69201b9e3672619f773463c742fd647c603))

## [2.5.0](https://github.com/gl11tchy/wannabuild/compare/v2.4.0...v2.5.0) (2026-06-08)


### Features

* **discover:** fold grill-me into wb-discover as a mandatory grill pass ([#55](https://github.com/gl11tchy/wannabuild/issues/55)) ([1a4d489](https://github.com/gl11tchy/wannabuild/commit/1a4d48924a7e6d0f40722bf9093ad041e27a3b92))
* enforce strict, collaborative, deterministic doctrine across all skills, agents, and runtime gates ([#57](https://github.com/gl11tchy/wannabuild/issues/57)) ([28a6014](https://github.com/gl11tchy/wannabuild/commit/28a60143766b033da84a2dd64db8ef92f98f5cf2))
* make guided mode the default with per-boundary gating ([#52](https://github.com/gl11tchy/wannabuild/issues/52)) ([fbf69c5](https://github.com/gl11tchy/wannabuild/commit/fbf69c50c98ec03fa39b2ce5a85c007dedda7dcb))
* **plan:** adversarial plan options rendered to self-contained HTML ([#58](https://github.com/gl11tchy/wannabuild/issues/58)) ([1819946](https://github.com/gl11tchy/wannabuild/commit/1819946239cf68319f0c3bd8c1831d3b94f54dee))


### Fixes

* gate guided pauses to real phase boundaries and clear on approval ([#53](https://github.com/gl11tchy/wannabuild/issues/53)) ([d8780d0](https://github.com/gl11tchy/wannabuild/commit/d8780d0dd886a5d750b4e2eb1782525da2aac48d))


### Tests

* add codex install integration smoke ([#47](https://github.com/gl11tchy/wannabuild/issues/47)) ([972a44d](https://github.com/gl11tchy/wannabuild/commit/972a44d3621d0cc83ab31977b3ddf756ecbbb417))

## [2.4.0](https://github.com/gl11tchy/wannabuild/compare/v2.3.0...v2.4.0) (2026-05-16)


### Features

* enforce thorough discovery readiness ([#42](https://github.com/gl11tchy/wannabuild/issues/42)) ([ec74c08](https://github.com/gl11tchy/wannabuild/commit/ec74c086f3f648ee2efde515ed002a0e40b39627))
* harden WannaBuild contracts ([38e6b14](https://github.com/gl11tchy/wannabuild/commit/38e6b14c3f0d9a02608630978130522f6e2e9dfb))


### Fixes

* **claude-plugin:** align hooks schema with current Claude Code loader ([#45](https://github.com/gl11tchy/wannabuild/issues/45)) ([a2cb8d0](https://github.com/gl11tchy/wannabuild/commit/a2cb8d0301c315aecf32389be8ecd44004320216))
* **claude-plugin:** inline hooks definition in plugin.json ([9ee45e1](https://github.com/gl11tchy/wannabuild/commit/9ee45e1fd23a5f26af60ec65a18bd323746093bc))
* clean release PR title pattern ([ed0abe3](https://github.com/gl11tchy/wannabuild/commit/ed0abe33b233d440b4ec4d862825bf8c4355b206))
* **contracts:** align doctor + marketplace validator with inline hooks ([34027d7](https://github.com/gl11tchy/wannabuild/commit/34027d759dc56326fef4bd584b54552c72f628fb))
* harden release automation checks ([641bc31](https://github.com/gl11tchy/wannabuild/commit/641bc31a2cbd46a945f1adb22808899f33ccf5ad))

## [2.3.0](https://github.com/gl11tchy/wannabuild/compare/v2.2.5...v2.3.0) (2026-05-09)


### Features

* add automatic WannaBuild routing ([ecc87e4](https://github.com/gl11tchy/wannabuild/commit/ecc87e47f827c7d0e394c272fa8d62926891257e))
* add daily-use trust harness ([ae9afae](https://github.com/gl11tchy/wannabuild/commit/ae9afaec9f193bf097eded691fc40c8a17e1b382))
* add Factory adapter and runtime plan gate ([5058699](https://github.com/gl11tchy/wannabuild/commit/5058699a71ce1fa10cb7b1b08832f1ce1bbb822c))
* add friendly wannabuild skill display metadata ([9d14ad1](https://github.com/gl11tchy/wannabuild/commit/9d14ad14dbf3be23d49d9c030394bbb948bfdece))
* add WannaBuild toolbox mode ([cac5d88](https://github.com/gl11tchy/wannabuild/commit/cac5d881d267ebf881b41b0ca1b6bdb35d5b459f))
* add wb-runtime kernel ([c8b8d25](https://github.com/gl11tchy/wannabuild/commit/c8b8d2569fce77eb0a36f7ad4decb67514e22b37))
* add wb-runtime kernel ([12abd1f](https://github.com/gl11tchy/wannabuild/commit/12abd1febfd1fb71edc70f0ea3394715c77bcd43))
* make wannabuild skills natural-first ([b9e0dce](https://github.com/gl11tchy/wannabuild/commit/b9e0dce2ebad3b54f6879e5110f4be818cd59199))
* **router:** broaden classifier so repo-meta and complaint prompts wake WannaBuild ([7ad6adb](https://github.com/gl11tchy/wannabuild/commit/7ad6adb4f7f654da8f5aa486a3fdf69b3ef8c089))
* ship full Agent Readiness signal coverage ([df7d189](https://github.com/gl11tchy/wannabuild/commit/df7d1899736760e466cb9b9b28ac97520ef57f27))
* **using-wannabuild:** adopt superpowers-style hard-guard discipline ([0ae52af](https://github.com/gl11tchy/wannabuild/commit/0ae52af474cf5a09cb5a4d19fac12755cfc20a9b))


### Fixes

* correct philosophy reference link ([6efc2fe](https://github.com/gl11tchy/wannabuild/commit/6efc2fe941d724963e2566c32fa9580bb13b6420))
* enforce wannabuild runtime bootstrap ([65ea6ee](https://github.com/gl11tchy/wannabuild/commit/65ea6eea4b21691359ea18faee7ec6e8f4366c49))
* hide internal phase skills under skills/internal/ to stop slash-menu duplication ([636e299](https://github.com/gl11tchy/wannabuild/commit/636e299ffa8134af300478ca46499717c25800af))
* keep wannabuild worktrees under codex state ([038af18](https://github.com/gl11tchy/wannabuild/commit/038af189b10e2b16b788b21d93235b021c31b3c8))
* make wannabuild skill-first autonomous flow ([d77e1b5](https://github.com/gl11tchy/wannabuild/commit/d77e1b56753effc20629820998e8cfd84d9610fb))
* make wannabuild worktrees implementation-time only ([9e09121](https://github.com/gl11tchy/wannabuild/commit/9e091212417086dbec3ab4cc78999abd1d5c8d34))
* **skills:** demote 'The Rule' to H2 to satisfy MD025 single-h1 rule ([95ce0ea](https://github.com/gl11tchy/wannabuild/commit/95ce0ea39edf46df69205ad3706ebb0e40266bf9))
* stabilize wb-runtime CI ([753ea83](https://github.com/gl11tchy/wannabuild/commit/753ea83d54dc7023cb38096e097507807344be0f))
* unwrap plugin hooks.json so /reload-plugins doesn't crash ([#8](https://github.com/gl11tchy/wannabuild/issues/8)) ([7f862d9](https://github.com/gl11tchy/wannabuild/commit/7f862d97cc72eaea6e32a53d3f7f9171ff62be63))
* update doctor runtime guard check ([ab46dcb](https://github.com/gl11tchy/wannabuild/commit/ab46dcb24f15d82a5ef254e74f843c4be6c53e9d))
* use codeql-action commit SHA, not tag-object SHA ([#32](https://github.com/gl11tchy/wannabuild/issues/32)) ([276e81c](https://github.com/gl11tchy/wannabuild/commit/276e81c713caff6ff4cdee3574abc188025f7044))


### Docs

* add "verify your install is working" section ([#24](https://github.com/gl11tchy/wannabuild/issues/24)) ([8cafe65](https://github.com/gl11tchy/wannabuild/commit/8cafe65bbad46e4751d0ccaddefd1a45427716da))
* add Factory / Droid support to README ([#9](https://github.com/gl11tchy/wannabuild/issues/9)) ([6ea83c7](https://github.com/gl11tchy/wannabuild/commit/6ea83c725ee7c0c87cb41390b534381ff590c1e9))
* add OpenSSF Scorecard badge to README ([#33](https://github.com/gl11tchy/wannabuild/issues/33)) ([313c4ec](https://github.com/gl11tchy/wannabuild/commit/313c4ecbc3d4527bb16159c3c53532d7917232a4))
* add reading order + where-to-make-changes to CONTRIBUTING ([#17](https://github.com/gl11tchy/wannabuild/issues/17)) ([61104ea](https://github.com/gl11tchy/wannabuild/commit/61104ea5307213fbcb64b37035a05b319836ef4d))
* add working principles to agent guidance ([1e6da7b](https://github.com/gl11tchy/wannabuild/commit/1e6da7b76ba62e6733a553424f26bba50a49703a))
* install + plugin-load troubleshooting runbook ([#11](https://github.com/gl11tchy/wannabuild/issues/11)) ([00d363a](https://github.com/gl11tchy/wannabuild/commit/00d363afc391e93cac0281d33d64c21489dd6dc1))
* public roadmap ([#15](https://github.com/gl11tchy/wannabuild/issues/15)) ([18590fd](https://github.com/gl11tchy/wannabuild/commit/18590fd72a5f43cb05774c3a25d61e5ce1a63ed0))
* README quickstart + live CI badge ([#13](https://github.com/gl11tchy/wannabuild/issues/13)) ([95e1ead](https://github.com/gl11tchy/wannabuild/commit/95e1ead084d4c73cec126138aed5dab7add4d8ac))
* regenerate auto-generated docs ([938e3a3](https://github.com/gl11tchy/wannabuild/commit/938e3a3f7426c86f726bce64ebc87df7e286ec78))
* runbook entry for release-please PR-creation permission ([#19](https://github.com/gl11tchy/wannabuild/issues/19)) ([356bc13](https://github.com/gl11tchy/wannabuild/commit/356bc1322dc46042e2ba4f02ec2617e0b4752dc5))


### Chores

* doctor color + summary counts (P1.5/P3.3) ([#18](https://github.com/gl11tchy/wannabuild/issues/18)) ([c05380e](https://github.com/gl11tchy/wannabuild/commit/c05380e61227986fda728dc8622d9a3ce508fca7))
* enable dependabot docker ecosystem for devcontainer ([#21](https://github.com/gl11tchy/wannabuild/issues/21)) ([04f9864](https://github.com/gl11tchy/wannabuild/commit/04f9864de099e63a8d343bcff4d4cce42c264f08))
* install script UX — fail-fast prereqs + post-install verification ([#12](https://github.com/gl11tchy/wannabuild/issues/12)) ([1c11ad7](https://github.com/gl11tchy/wannabuild/commit/1c11ad7278d304c1ad64fe3889c118a7eebab064))
* narrow lychee.yml issues:write from top-level to job-level ([#31](https://github.com/gl11tchy/wannabuild/issues/31)) ([a9077d1](https://github.com/gl11tchy/wannabuild/commit/a9077d11d4ca50efc7dea0127192f8659e9cd15a))
* pin gitleaks-action to commit SHA (resolved TODO) ([#34](https://github.com/gl11tchy/wannabuild/issues/34)) ([512ab5d](https://github.com/gl11tchy/wannabuild/commit/512ab5daa692f5c90f29fb3c417638d39654d3db))
* scorecard-driven hardening (Token-Permissions, Pinned-Deps, Scorecard SHA) ([#30](https://github.com/gl11tchy/wannabuild/issues/30)) ([e8cca1d](https://github.com/gl11tchy/wannabuild/commit/e8cca1d58845e50ff1cf592287303ee815e9b576))
* sync action version comments to actual pinned SHAs ([#25](https://github.com/gl11tchy/wannabuild/issues/25)) ([1848bbf](https://github.com/gl11tchy/wannabuild/commit/1848bbfaef207a63b85085ea28be5cc6be0a5150))
* wire release-please extra-files for plugin/marketplace JSONs ([#10](https://github.com/gl11tchy/wannabuild/issues/10)) ([f4dc5bc](https://github.com/gl11tchy/wannabuild/commit/f4dc5bcd99981e5c89351cb7f3db5d2db7b60f20))


### Tests

* cross-host routing parity (P2.4) ([#16](https://github.com/gl11tchy/wannabuild/issues/16)) ([14a1e00](https://github.com/gl11tchy/wannabuild/commit/14a1e00c67f7f33361e39fba669ce9cda301d2f5))
* include factory in adapter context parity check ([#29](https://github.com/gl11tchy/wannabuild/issues/29)) ([79d68ae](https://github.com/gl11tchy/wannabuild/commit/79d68ae5a62963eed1ecc4444657b7b26c0fcde6))
* update runtime unavailable expectation ([601f787](https://github.com/gl11tchy/wannabuild/commit/601f7873ca9fdf851b7bb59464e4abba2c544e19))

## [Unreleased]

## [2.2.5] - 2026-05-06

### Fixes

- unwrap `hooks/hooks.json` so Claude Code's plugin loader can iterate hook groups without crashing `/reload-plugins` with `TypeError: X?.reduce is not a function`
- register gl11tchy as own marketplace namespace in install script (ebddcec)
- use claude-plugins-official namespace in install script (d74b330)

### Refactor

- consolidate python3 invocations and fix TOCTOU in install script (e0ba27b)

### Features

- add dry-run fixtures and checks for gates, advisor, and QA loop (467e600)

### Chores

- compress SKILL.md and fix contract gaps from session audit (5b88428)

## [2.2.3] - 2025-04-15

### Cleanup

- v2.2.4 cleanup: reconcile schemas, remove spark agents, add config+workspace
  validation (340e75b)

### Docs

- add advisor escalation workflow (89c3db3)
- align host positioning and contract consistency (3ca88ec)
- use single agent wording and prevent duplicate gate prompts (d3f6cce)
- add operator mental model and align workflow copy (b10c6c6)
- tighten AGENTS operator contract (adad0df)

### Chores

- standardize mode contracts and refresh dry-run fixtures (99ee4aa)
- ignore local worktrees directory (94d1296)
- bump claude plugin version and expand doctor coverage (6b74ab5)

### Fixes

- align claude workflow state contract and bootstrap flow (2358498)
- update using-wannabuild command for Claude Code parity (37d42b7)

## [2.2.2] - 2025-04-15

### Docs

- update positioning — Claude Code is co-primary, not compatibility packaging
  (ff9471e)
- elevate Claude Code install to co-primary in README (08599c4)
- elevate Claude Code to co-primary in host capability matrix (394229b)
- add claude-code-getting-started.md (85103c0)
- rewrite Claude Code adapter README as a proper install guide (d258386)
- add .claude/INSTALL.md for Claude Code getting-started (656ad58)

### Features

- add install-claude-skill.sh for local Claude Code plugin install (ca29312)

## [2.2.1] - 2025-04-15

### Fixes

- clarify timestamp format, variable substitution, verdict rules, and failure
  cleanup in wannabuild skill (9cf193c)
- replace script path references with inline equivalents in wannabuild skill
  (2db49fd)
- clarify workspace bootstrap ordering in wannabuild command (1375f24)
- rewrite wannabuild command for Claude Code — drop Codex $skill syntax
  (ddcf279)

### Docs

- add Claude Code co-primary parity implementation plan (e06d4b0)
- add Claude Code co-primary parity design (767c639)

## [Initial]

- Make WannaBuild usable now as a Codex-first workflow plugin (7e27a95)

[Unreleased]: https://github.com/gl11tchy/wannabuild/compare/v2.2.3...HEAD
[2.2.3]: https://github.com/gl11tchy/wannabuild/compare/v2.2.2...v2.2.3
[2.2.2]: https://github.com/gl11tchy/wannabuild/compare/v2.2.1...v2.2.2
[2.2.1]: https://github.com/gl11tchy/wannabuild/releases/tag/v2.2.1
