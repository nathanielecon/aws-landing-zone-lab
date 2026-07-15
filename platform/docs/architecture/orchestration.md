# Orchestration architecture

This document records how Project A work is partitioned, scored, approved, and
proven. It does not authorize cloud calls from harness task evidence.

**Claims carve-out:** Harness tasks `A-001`…`A-007` remain repo-only
(`cloud_validated: false`, `aws_implemented: false`, `azure_implemented: false`).
The separate single-account Landing Zone lab under `sandbox/landing-zone-lab/`
is **APPLIED** / cloud-validated for identity + private network + audit via
GitHub OIDC CI (role `project-a-lzlab-gha`, run `29366105164`) — see
`sandbox/landing-zone-lab/EVIDENCE.md`. Multi-account Organizations member
creation is still **not** cloud-validated.

Related architecture docs (preserved):

- [Platform overview](overview.md)
- [Accounts and OUs](accounts.md)
- [Network](network.md)
- [Logging and audit](logging.md)

Frozen rubrics live under [`docs/review/rubrics/`](../review/rubrics/).
Break/fix history lives in [`BREAK_FIX_LOG.md`](../../../BREAK_FIX_LOG.md).
Goal-loop state is external (`cursor-goal`). PR `#13` was squash-merged to
`main` as `1564c6b` on 2026-07-13; historical verification for that delivery
was `gh pr checks 13`.

## Context protocol (anti-rot fundamentals)

Chat history is **not** authoritative. Orchestrators must keep truth outside
the chat and refresh from durable artifacts on a schedule.

### 1. Scheduled re-read

Re-read, in order, on **every** one of these triggers:

- every `cursor-goal` checkpoint
- after each slice judge round
- after each CI break/fix cycle
- after any handoff or new orchestrator turn
- at least once every 30–45 minutes of active work

Required read set:

1. This file (`platform/docs/architecture/orchestration.md`)
2. Source prompts:
   - `C:\Users\natha\.codex\attachments\7cc86f31-219a-46f1-b69a-acf3a88a3804\pasted-text.txt`
   - first Cursor resume prompt in transcript `7043d948-a2b3-42f9-9e0c-b0e169a61266`
   - planning context `C:\Users\natha\.codex\attachments\f5899230-6ad0-4e64-bb2c-ff021da6655b\pasted-text.txt`
3. [`BREAK_FIX_LOG.md`](../../../BREAK_FIX_LOG.md)
4. Frozen rubrics under [`harness/rubrics/`](../review/rubrics/)
5. [`AGENTS.md`](../../../AGENTS.md) and [`overview.md`](overview.md)
6. `cursor-goal` status + live `gh pr checks 13` (GitHub MCP `user-github` when available)

Discard chat assumptions that conflict with those files.

### 2. Truth outside the chat

Durable sources of truth (must stay tracked / maintained):

| Artifact | Role |
| --- | --- |
| This orchestration doc | Partitions, dispatch, thresholds, local vs remote proof |
| `docs/review/rubrics/*.md` | Frozen per-slice scoring contracts |
| `BREAK_FIX_LOG.md` | Every remote/local break → fix → verification |
| `platform/docs/architecture/*` | Platform architecture preservation |
| `platform/harness/*-approval.json` | Spec/execution hash pins |
| `cursor-goal` state | Active objective + verification command |
| PR `#13` (merged) / Windows CI | Remote merge-readiness proof for the Project A delivery |

Never delete rubrics or architecture docs as “cleanup.”

### 3. Fresh short-contract subagents

Spawn bottleneck, judge, nixer, and fixer workers with **fresh context** and a
**short contract** only:

- goal of this worker
- owned files/scope
- exact failing assertion / rubric item IDs
- commands to run
- what to return (root cause, files touched, scores, whether parent should
  repin/push)

Do **not** paste the full orchestrator transcript into workers.

### 4. Prefer a new orchestrator turn over a longer chat

When context is large, stale, or post-handoff: start a **new orchestrator
turn** that loads the durable files above instead of extending an unbounded
chat. The new turn’s first actions are the scheduled re-read, then the next
deterministic loop step. Compressed CI-only handoffs must not replace the
source prompts or this document.

## Slice partitions

| Slice | Rubric | Scope |
| --- | --- | --- |
| 1 | [`slice-1-harness-core.md`](../review/rubrics/slice-1-harness-core.md) | `scripts/`, `harness/`, `launcher/`, `.harness/bin/`, `tests/`, profiles, policy schemas, harness ops docs |
| 2 | [`slice-2-project-a-foundation.md`](../review/rubrics/slice-2-project-a-foundation.md) | Foundation docs + bootstrap/organization modules (`A-001`, `A-002`) |
| 3 | [`slice-3-project-a-platform.md`](../review/rubrics/slice-3-project-a-platform.md) | Identity, network, audit, environments, matching docs/tests (`A-003`…`A-006`) |
| 4 | [`slice-4-final-delivery.md`](../review/rubrics/slice-4-final-delivery.md) | Evidence index, claims, review/handoff, diagrams, Graphify, orchestration, PR/CI readiness (`A-007` + packaging) |
| Cloud lab | [`slice-cloud-lab-single-account.md`](../review/rubrics/slice-cloud-lab-single-account.md) | Single-account collapsed LZ lab (`sandbox/landing-zone-lab`): live identity+network+audit via **GitHub OIDC CI**; Orgs interface only; honest claims |

### Single-account cloud lab (2026-07-14)

Exit criteria for the cloud lab slice are **not** multi-account Orgs must-haves.
**Control plane:** GitHub OIDC → Terraform CI (not Cursor Cloud Agent AWS
assume-role). Council workers (setters/judges/nixers/fixers) for this slice must
use **Grok 4.5** (`cursor-grok-4.5-high-fast`) or a less capable allowed model —
**not Composer**. Stretch: reopen multi-account track only when unique member
emails exist.

**Lesson (credentials / control-plane mismatch):** When stuck on AWS login,
Cursor External ID, or Cloud Agent `NoCredentials`, dispatch a bottleneck
agent early rather than waiting on a human for `aws login` / Cursor assume-role
injection — prefer the GitHub OIDC CI path (`project-a-lzlab-gha`, workflow
`landing-zone-lab.yml`). Do not recreate `github-oidc/` /
`GitHubActionsLZLab`; use `ci-bootstrap/`.

Task stream inside Project A remains sequential: `A-001` → `A-007` under one
Ralphy process. Harness smoke tasks `S-001`/`S-002` prove Terra-first and Sol
takeover on the smoke profile only.

## Judge / nixer / fixer dispatch

Orchestration uses a frozen-rubric controller distinct from Terra/Sol model
roles inside the harness:

1. **Rubric setters** inspect the repo and freeze one checkable rubric per
   slice under `docs/review/rubrics/`. Rubrics change only for reproducible
   security, integrity, or acceptance blockers.
2. **Judges** (at least two, preferably three) score only against the frozen
   rubric, report blocking must-have failures separately from improvements,
   and publish every score plus the round average.
3. If average **< 9.5/10** or any must-have fails: spawn **nixers** (find gaps)
   and **fixers** (apply disjoint repairs), then **repin** approval hashes if
   execution-bundle members changed, run full validation, and rejudge.
4. **Bottleneck mode** (narrow CI/regression blockers): one judge builds a
   checklist with exact file/line refs; nixer then fixer; return to the **same**
   judge until score 9 (**do not tell** the judge the threshold); then a **new**
   independent judge must hit 9 on first evaluation. Each of these agents gets
   a fresh short contract (§ Context protocol), not the full chat.
5. Do not yield while a deterministic next step exists:
   `judge → nixer → fixer → repin → full validation → next judge round`.
6. Bottleneck mode clears a live gate; it does **not** permanently replace the
   per-slice 9.5 multi-judge loop. After CI/launcher clearance, resume slice
   accounting if rubrics/exits are incomplete. Append every cycle to
   `BREAK_FIX_LOG.md`.

Harness-internal model dispatch (unchanged):

- **Terra** attempts every task first.
- **Sol** receives one implementation plus one repair pass after approved
  takeover thresholds (3 Terra attempts, 2 consecutive validation failures,
  same error twice, one no-diff repair, 25 active minutes, scope escape, or
  explicit policy gate).
- Deterministic validators are hard gates; humans own `H0`/`H1` receipts for
  `A-001`/`A-002`. Adapter alone commits.

## Thresholds

- Slice advance requires **average ≥ 9.5/10** and **all must-have items pass**.
  That comparison is **orchestrator-only** — never paste the numeric advance
  rule into judge/nixer/fixer prompts (see anti-leak prompt contract below).
- Items marked needed for 9/10+ and 10/10 inform scoring depth; they do not
  waive must-haves.
- Nice-to-have items never block slice exit.
- Local assertion counts and green local runs do not override a failing remote
  Windows CI gate for delivery claims.

## Anti-leak prompt contract (council workers)

Worker prompts (setter / judge / nixer / fixer) must be **fresh short
contracts** only. Do **not** paste the orchestrator transcript, prior judge
scores, or advance-threshold language into workers.

### Required judge return shape

Judges score **0–10** against the frozen rubric’s must-have / 9+ / 10
sections and return exactly:

- `score` (number 0–10)
- `must_haves_pass` (boolean)
- `failed_must_haves` (list; empty if none)
- `gaps` (top improvements, even when passing)

### Banned in judge / nixer / fixer prompts

Do not include any of:

- `9.5`, `≥9.5`, `>=9.5`, `needed_for_9.5`, `needed_for_9.5_plus`
- `advance`, `advance bar`, `exit bar`, `slice exit`, `merge_ready` as a
  threshold instruction
- Prior chat scores or “last round scored X”
- Parent orchestrator transcript

Orchestrator alone averages judge scores and applies the Thresholds rule.
Bottleneck mode may loop a same-judge repair cycle and then require a **new**
independent judge; still ask only for `score` + must-haves — do **not** name
the bottleneck target number in the prompt.

## Approval and hash pinning

Smoke harness:

- `PLAN.md` SHA-256 must match `harness/plan-approval.json` (`plan_id`
  `ralphy-windows-smoke-v1`).

Project A:

- Spec/execution bundles are pinned in
  `platform/harness/bundle-approval.json` and
  `platform/harness/execution-approval.json`.
- `Start-ProjectAHarness.ps1` recomputes hashes via
  `Get-ProjectASpecHash.ps1` / `Get-ProjectAExecutionHash.ps1` and fails closed
  on drift of:
  - `spec_bundle_sha256`
  - `execution_bundle_sha256`
  - `validator_implementation_sha256`
  - `execution_hash_implementation_sha256`
- After any execution-bundle member edit, recompute hashes, update both
  approval files, and re-run contract/spec/harness suites before claiming
  readiness.
- Human task receipts live outside the repo under
  `%LOCALAPPDATA%\RalphyHarness\cloud\approvals` and bind diff + validation
  digests. Agents cannot mint receipts.

## Windows CI gate

Remote proof path is `.github/workflows/harness-contracts.yml` on
`windows-latest`:

1. `tests/Run-ContractTests.ps1`
2. `tests/Run-ProjectASpecTests.ps1`
3. `tests/Run-ProjectAHarnessTests.ps1`

CI sets `CI=1` and `HARNESS_CONTRACT_ONLY=1`, installs pinned Ralphy `4.7.2`,
and must pass before merge-ready / final-delivery claims. Do not declare the
delivery surface green from local-only progress.

`HARNESS_CONTRACT_ONLY=1` is a **test/CI-only shortcut** (fake Codex/Ralphy
fixtures, kill-point injection). It is not the operator production path; live
`Start-ProjectAHarness.ps1` / `Start-Harness.ps1` runs leave it unset and rely
on pinned approvals plus the fixed sequential Ralphy argv (no
parallel/worktree/sandbox/branch-per-task flags).

## Local vs remote: what each proves

| Proof | Proves | Does not prove |
| --- | --- | --- |
| Local fake-Codex harness suites | Deterministic gates, allowlists, takeover thresholds, approval binding, offline validators | GitHub runner environment parity, merge-ref CI, cloud behavior |
| Local Terraform fmt/validate/test | Syntax and internal consistency with isolated `TF_DATA_DIR` | Remote state, AWS APIs, account creation, live network/audit |
| Local smoke (`Start-Harness.ps1`) | One sequential Ralphy loop, Terra first, forced Sol takeover, clean tree | Project A task stream or CI |
| Execution approval `proven_with.fake_codex_only` | Bundle was proven without live models/cloud credentials | Live-model robustness |
| Windows CI workflow | Remote Windows contract/spec/harness assertions on the PR/push SHA | Production operations or cloud validation |
| Evidence index digests | Adapter-owned task evidence for repo-only commits | That AWS resources exist |

## Delivery closeout — recorded process deviations (2026-07-13)

The Project A delivery on PR `#13` / `main` `1564c6b` met the stated advance
bar (must-haves + ≥9.5 per slice, Windows CI green, evidence A-001…A-007). The
following on-the-fly adjustments departed from the ideal multi-judge loop and
are recorded here so later orchestrators do not overclaim textbook process
fidelity:

1. **Rubrics restored mid-stream.** `docs/review/rubrics/` (formerly harness/rubrics) was missing when the
   final orchestrator turn began. Slice rubrics and this orchestration doc were
   recreated/frozen from the supervising prompt + repo state, then used for
   scoring. They were **not** frozen from the first commit of the Project A
   build branch.
2. **CI bottleneck before full slice accounting.** Live Windows failures
   (timestamps, forbidden-ops scan scope, Azure runner env allowlist, missing
   Terraform causing the completion-isolation fixture to exit before planting
   `.ralphy-worktrees`) were cleared first under bottleneck mode. Slice judge
   rounds resumed after remote green rather than running uninterrupted from
   Slice 1 day one of that turn.
3. **Often one judge per rejudge.** The contract prefers ≥2 judges (ideally 3)
   every round. After CI green, several advance rejudges used a **single**
   cloud judge per slice against the frozen rubric. Multi-judge averages were
   therefore not always produced on the final pass.
4. **Cloud workers + local orchestration.** Fixer/judge work was frequently
   dispatched to cloud subagents while the supervising orchestrator stayed in
   the Cursor chat, cherry-picked cloud commits onto `codex/project-a-build`,
   and pushed. Parallel draft branches (for example the divergent terraform
   fixture branch) were intentionally **not** merged when superseded by the
   already-green head.
5. **Evidence snapshot honesty.** A-007’s `changed_entries` `content_sha256`
   for `platform/evidence-index.md` drifted after a later harness commit
   appended the index row; the indexed `validation_digest` remains the
   authoritative binding. See `platform/evidence-index.md` and
   `BREAK_FIX_LOG.md`.
6. **Confidence boundary.** High confidence applies to the repo-only harness
   contract and stated claims boundary. The Terraform/architecture surface is
   an offline baseline, **not** cloud-validated production apply readiness.
   Items marked needed for 10/10 (deep fault injection, exhaustive negative
   matrices) were explicitly left short on that closeout. A later clean
   rejudge added `scripts/Invoke-HarnessReleaseValidation.ps1` +
   `HARNESS_STRICT_PINS=1` as the fresh-machine / CI-parity one-command path
   (see `platform/HARNESS.md` and `.github/workflows/harness-contracts.yml`).

Final recorded slice advance scores for that closeout: Slice 1 **9.6**, Slice 2
**9.6**, Slice 3 **9.5**, Slice 4 **9.6**. Technical break→fix cycles remain
in [`BREAK_FIX_LOG.md`](../../../BREAK_FIX_LOG.md).

**Process-audit note (2026-07-14):** Those closeout scores (and the earlier
cloud-lab rejudge on PR `#16`) are **contaminated** where judge prompts
received advance-threshold leakage. Clean no-leak multi-judge scores are
recorded in the table below after the dedicated clean rejudge pass.

## Clean no-leak rejudge scores (2026-07-14)

| Slice | Rubric | Clean scores | Average | Must-haves | Notes |
| --- | --- | --- | --- | --- | --- |
| 1 | `slice-1-harness-core.md` | 9.8 / 9.5 / 9.5 | **9.6** | PASS | Clean no-leak Grok round (post fixer r1–r9) |
| 2 | `slice-2-project-a-foundation.md` | 9.6 / 9.5 / 9.5 | **9.53** | PASS | Clean no-leak Grok round |
| 3 | `slice-3-project-a-platform.md` | 9.8 / 10 / 10 | **9.93** | PASS | Clean no-leak Grok round |
| 4 | `slice-4-final-delivery.md` | 9.6 / 9.5 / 9.5 | **9.53** | PASS | Clean no-leak Grok round |
| Cloud lab | `slice-cloud-lab-single-account.md` | 9.5 / 9.5 / 9.5 | **9.5** | PASS | Clean no-leak Grok round; TEARDOWN.md |

## Operator entry points

Fresh-clone Windows one-command proof matching CI:

```powershell
$env:HARNESS_STRICT_PINS = '1'
pwsh -NoLogo -NoProfile -File ./scripts/Invoke-HarnessReleaseValidation.ps1
```

Harness loop:

```powershell
./scripts/Start-Harness.ps1
./scripts/Start-ProjectAHarness.ps1 -DryRun
./scripts/Start-ProjectAHarness.ps1
./scripts/Approve-ProjectATask.ps1 -TaskId A-001
./scripts/Start-ProjectAHarness.ps1 -Resume
```

Double-click launcher: `launcher/Launch Project A Harness.cmd`.  
Operations detail: [`platform/HARNESS.md`](../../HARNESS.md).
