# Slice 1 rubric — harness core

Status: frozen  
Scope: `scripts/`, `harness/`, `launcher/`, `.harness/bin/`, `tests/`, plus
associated profiles (`harness/profiles/`), policy schemas
(`platform/harness/policy.schema.json`), harness evidence contracts, and
harness operations docs (`platform/HARNESS.md`, `AGENTS.md`).

Judges score only against this rubric. Advance the slice only when the average
is **≥ 9.5/10** and every must-have item passes.

## must-have to pass slice

- Startup binds plan/execution approval, repository root, expected branch,
  tool versions (Terraform `1.15.5`, Ralphy `4.7.2`, Codex regex), and ChatGPT
  login presence without inventing cloud credentials.
- Adapters independently re-verify authorization facts from on-disk approval
  and policy files; they must not trust caller-supplied `HARNESS_*`
  environment variables as authority.
- Codex invocations stay at native `workspace-write`, with command network,
  web search, and apps disabled; model shells get a filtered credential-free
  environment.
- Human approval for gated tasks is interactive and diff-bound; receipts bind
  execution/validator/policy hashes, task, branch, commits, diff fingerprint,
  validation digest, nonce, and timestamp.
- Changed-path inventory is NUL-safe across tracked, staged, untracked, and
  ignored paths.
- Path gates reject traversal, `.git`, unsafe runtime artifacts, links,
  reparse points, submodules, case collisions, and unapproved executable-bit
  changes (`UNAPPROVED_EXECUTABLE_BIT` unless `allowed_executable_paths`).
- Only adapters commit allowlisted task artifacts plus adapter-owned evidence;
  models never commit.
- Validators are deterministic, machine-readable, timeout-bounded, and
  fail-closed on unknown IDs; they leave no tracked/untracked mutation.
- Model and validator hard timeouts include process-tree cleanup.
- Recovery, evidence, and manifest/state stay exactly bound to the approved
  execution bundle and task IDs.
- Resume ownership is strict: approval pause (exit 75) does not inflate retry
  counters; resume revalidates the unchanged diff without a new model call.
- Forbidden worktree / sandbox / branch-per-task / parallel Ralphy modes are
  rejected.
- Lifecycle-owned runtime exclusions use exact `ExcludedPaths` file paths only
  (no absolute paths, globs, or directory-prefix exclusions). Unknown
  `.harness/runtime` files fail closed in clean-tree/scope checks.
- Contract suites run fully offline with fake Codex/Ralphy fixtures
  (`tests/Run-ContractTests.ps1`, `tests/Run-ProjectAHarnessTests.ps1`,
  `tests/Run-ProjectASpecTests.ps1`).
- Documentation accurately states repo-only / non-cloud claims and the
  adapter-only commit authority.

## needed for 9/10+

- Strict runtime JSON / policy schema validation for task policies and
  approvals.
- Profile-driven single source of truth (`harness/profiles/smoke.json`,
  `harness/profiles/project-a.json`) for task IDs, branches, and gate kinds.
- Stable error envelopes with actionable recovery guidance in launcher and
  harness docs.
- Adversarial startup, path, timeout, output, and isolation-directory
  regression tests (including forbidden `.ralphy-worktrees` reconciliation).
- Independently recomputable evidence digests and execution/spec hashes
  (`Get-ProjectASpecHash.ps1`, `Get-ProjectAExecutionHash.ps1`).
- Pinned, least-privilege Windows CI
  (`.github/workflows/harness-contracts.yml`) with no cloud credentials.

## needed for 10/10

- Independent bundle verifier that any reviewer can recompute and compare to
  pinned approval hashes without trusting prior chat claims.
- Property-style and mutation tests beyond the current assertion suites.
- Full persistent-boundary fault injection across approval, resume, stop
  sentinel, and lock ownership.
- Public trust-boundary documentation that separates OS DPAPI receipt
  protection from legal identity signatures.
- One-command release-quality validation on a fresh Windows machine matching
  CI.

## nice-to-have

- Richer operator dashboards or HTML run summaries beyond
  `%LOCALAPPDATA%\RalphyHarness\cloud\<run-id>` logs.
- Cross-platform (non-Windows) harness ports.
- Automatic PR comments from CI beyond the contract workflow status.
- Optional Graphify of harness scripts themselves (not required for slice exit).
