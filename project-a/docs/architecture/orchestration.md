# Orchestration architecture

This document records how Project A work is partitioned, scored, approved, and
proven. It does not authorize cloud calls. Project A remains repo-only:
`cloud_validated: false`, `aws_implemented: false`, `azure_implemented: false`.

Related architecture docs (preserved):

- [Platform overview](overview.md)
- [Accounts and OUs](accounts.md)
- [Network](network.md)
- [Logging and audit](logging.md)

Frozen rubrics live under [`harness/rubrics/`](../../../harness/rubrics/).
Break/fix history lives in [`BREAK_FIX_LOG.md`](../../../BREAK_FIX_LOG.md).
Goal-loop state is external (`cursor-goal`); verification command is
`gh pr checks 13`.

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

1. This file (`project-a/docs/architecture/orchestration.md`)
2. Source prompts:
   - `C:\Users\natha\.codex\attachments\7cc86f31-219a-46f1-b69a-acf3a88a3804\pasted-text.txt`
   - first Cursor resume prompt in transcript `7043d948-a2b3-42f9-9e0c-b0e169a61266`
   - planning context `C:\Users\natha\.codex\attachments\f5899230-6ad0-4e64-bb2c-ff021da6655b\pasted-text.txt`
3. [`BREAK_FIX_LOG.md`](../../../BREAK_FIX_LOG.md)
4. Frozen rubrics under [`harness/rubrics/`](../../../harness/rubrics/)
5. [`AGENTS.md`](../../../AGENTS.md) and [`overview.md`](overview.md)
6. `cursor-goal` status + live `gh pr checks 13` (GitHub MCP `user-github` when available)

Discard chat assumptions that conflict with those files.

### 2. Truth outside the chat

Durable sources of truth (must stay tracked / maintained):

| Artifact | Role |
| --- | --- |
| This orchestration doc | Partitions, dispatch, thresholds, local vs remote proof |
| `harness/rubrics/*.md` | Frozen per-slice scoring contracts |
| `BREAK_FIX_LOG.md` | Every remote/local break → fix → verification |
| `project-a/docs/architecture/*` | Platform architecture preservation |
| `project-a/harness/*-approval.json` | Spec/execution hash pins |
| `cursor-goal` state | Active objective + verification command |
| PR `#13` / Windows CI | Remote merge-readiness proof |

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
| 1 | [`slice-1-harness-core.md`](../../../harness/rubrics/slice-1-harness-core.md) | `scripts/`, `harness/`, `launcher/`, `.harness/bin/`, `tests/`, profiles, policy schemas, harness ops docs |
| 2 | [`slice-2-project-a-foundation.md`](../../../harness/rubrics/slice-2-project-a-foundation.md) | Foundation docs + bootstrap/organization modules (`A-001`, `A-002`) |
| 3 | [`slice-3-project-a-platform.md`](../../../harness/rubrics/slice-3-project-a-platform.md) | Identity, network, audit, environments, matching docs/tests (`A-003`…`A-006`) |
| 4 | [`slice-4-final-delivery.md`](../../../harness/rubrics/slice-4-final-delivery.md) | Evidence index, claims, review/handoff, diagrams, Graphify, orchestration, PR/CI readiness (`A-007` + packaging) |

Task stream inside Project A remains sequential: `A-001` → `A-007` under one
Ralphy process. Harness smoke tasks `S-001`/`S-002` prove Terra-first and Sol
takeover on the smoke profile only.

## Judge / nixer / fixer dispatch

Orchestration uses a frozen-rubric controller distinct from Terra/Sol model
roles inside the harness:

1. **Rubric setters** inspect the repo and freeze one checkable rubric per
   slice under `harness/rubrics/`. Rubrics change only for reproducible
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
- Items marked needed for 9/10+ and 10/10 inform scoring depth; they do not
  waive must-haves.
- Nice-to-have items never block slice exit.
- Local assertion counts and green local runs do not override a failing remote
  Windows CI gate for delivery claims.

## Approval and hash pinning

Smoke harness:

- `PLAN.md` SHA-256 must match `harness/plan-approval.json` (`plan_id`
  `ralphy-windows-smoke-v1`).

Project A:

- Spec/execution bundles are pinned in
  `project-a/harness/bundle-approval.json` and
  `project-a/harness/execution-approval.json`.
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

## Local vs remote: what each proves

| Proof | Proves | Does not prove |
| --- | --- | --- |
| Local fake-Codex harness suites | Deterministic gates, allowlists, takeover thresholds, approval binding, offline validators | GitHub runner environment parity, merge-ref CI, cloud behavior |
| Local Terraform fmt/validate/test | Syntax and internal consistency with isolated `TF_DATA_DIR` | Remote state, AWS APIs, account creation, live network/audit |
| Local smoke (`Start-Harness.ps1`) | One sequential Ralphy loop, Terra first, forced Sol takeover, clean tree | Project A task stream or CI |
| Execution approval `proven_with.fake_codex_only` | Bundle was proven without live models/cloud credentials | Live-model robustness |
| Windows CI workflow | Remote Windows contract/spec/harness assertions on the PR/push SHA | Production operations or cloud validation |
| Evidence index digests | Adapter-owned task evidence for repo-only commits | That AWS resources exist |

## Operator entry points

```powershell
./scripts/Start-Harness.ps1
./scripts/Start-ProjectAHarness.ps1 -DryRun
./scripts/Start-ProjectAHarness.ps1
./scripts/Approve-ProjectATask.ps1 -TaskId A-001
./scripts/Start-ProjectAHarness.ps1 -Resume
```

Double-click launcher: `launcher/Launch Project A Harness.cmd`.  
Operations detail: [`project-a/HARNESS.md`](../../HARNESS.md).
