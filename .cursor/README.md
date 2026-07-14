# Cursor Cloud environment (`cloud-harness`)

Cached toolchain for Cloud Agents on `nathanielecon/cloud`. Start-commit baseline:
**`main` at `6a8be57` or later** (must include this directory).

## Files

| Path | Role |
| --- | --- |
| [`Dockerfile`](Dockerfile) | Image layers: PowerShell 7, Node 24, Terraform 1.15.5, AWS CLI v2, Docker |
| [`environment.json`](environment.json) | Named env `cloud-harness`; light idempotent `install`; Docker `start` |

Do **not** `COPY` the repo into the Dockerfile — Cursor checks out the commit into `/workspace`.

## Resolution order (locked)

Cursor resolves env by repository / repo group using the first match:

1. **Repo** `.cursor/environment.json` (this file) — preferred for `nathanielecon/cloud`
2. Personal saved environment
3. Team saved environment

Do not rely on a personal/team wizard snapshot that skips this Dockerfile unless you are explicitly testing an override. For production agent runs on this repo, keep the repo config as the source of truth.

## Snapshot reuse

1. First agent after a Dockerfile / `environment.json` change may be slower (image build + layer cache populate).
2. After the first successful env build, save/reuse a VM snapshot from the Cursor Cloud Agents Environments dashboard.
3. `agentCanUpdateSnapshot` is `true` so agents may refresh the snapshot when appropriate.
4. Do **not** force a full rebuild every run. Rebuild only when `Dockerfile` or `.cursor/environment.json` changes (or the snapshot is invalid/expired — Cursor falls back and re-runs `install`).
5. Do not pin a stale `snapshot` id in git until a known-good dashboard snapshot exists for this Dockerfile; prefer build-from-Dockerfile then dashboard save.

## Install / start contract

- `install` (update command): **version checks only** — must stay lightweight and idempotent. Never inject `apt-get`, cold `npm install`, or other multi-minute toolchain installs into the orch startup path.
- `start`: start Docker daemon only (`sudo service docker start || true`).
- Tool installs belong in Dockerfile layers, not in `install`.

## Multi-repo agents

If orch launches a multi-repo Cloud Agent environment, **include `nathanielecon/cloud` in the environment repo group** so the same `cloud-harness` cached env / snapshot is reused across those runs.

## Secrets

AWS keys/roles and other credentials live in **Cursor Cloud Agents Secrets** and/or **IAM role assumption** — never bake secrets into the Dockerfile or commit them here. See Cursor docs: Cloud Environment Setup → Environment variables and secrets / Using AWS IAM Roles.

## Validation

| Run | Expected |
| --- | --- |
| First agent after env change | May build Dockerfile (slower); `install` prints tool versions and exits 0 |
| Second agent same env | Near clone+run; no cold apt/tool install in setup logs |
| Sanity | `pwsh`, `node`, `terraform`, `aws`, `docker` present without session-start reinstall |

## Harness boundaries (unchanged)

This environment does **not** alter harness sequential rules, approval pinning, or Codex sandbox (`workspace-write` only). See root [`AGENTS.md`](../AGENTS.md).
