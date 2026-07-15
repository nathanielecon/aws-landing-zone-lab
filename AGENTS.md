# Harness rules

- Run only the approved manifest whose `PLAN.md` SHA-256 matches
  `harness/plan-approval.json`.
- Use one sequential Ralphy process. Never add parallel, sandbox, worktree,
  branch-per-task, browser, PR, or automatic merge flags.
- Codex must not commit. `scripts/Invoke-CodexAdapter.ps1` is the only task
  commit authority.
- Never widen Codex beyond `workspace-write`.
- Runtime state and verbose logs must remain untracked and sanitized.
- Do not clean, reset, stash, or overwrite unexplained user changes.

## Standing addendum (all projects)

Attach this block to any project prompt that may touch Cloud Agents, CI, cloud
infrastructure, or portfolio visuals.

**Project specifics vary.** The rules below (orchestrator, Cloud Agents, GitOps,
honest visuals) are standing. Names, workflows, roles, account IDs, regions,
pipeline stages, story cards, and claim footers are **fill-ins from the current
project’s repo and evidence** — do not copy another project’s identifiers or
architecture wholesale.

### 1. Orchestrator — bottleneck dispatch

If work stalls on auth, CI, cloud credentials, dashboards, or any tool the
current agent cannot reach, the **lead orchestrator must dispatch a bottleneck
agent** (local/shell, AWS, GitHub Actions, browser, etc.) **in this session**.
Do **not** leave the user to open a new conversation to unblock the same issue.
This is why the orchestrator exists: clear blockers without restarting chat.
Which bottleneck agent to dispatch depends on the project (local AWS CLI,
Actions run, dashboard browser, etc.).

### 2. Cloud Agents (Cursor and Codex CLI)

Applies to **Cursor Cloud Agents** and **Codex CLI / Codex Cloud** tasks.

- Cloud Agents run in isolated Linux pods. They **cannot** use the user’s local
  laptop session (`aws login`, PowerShell, browser cookies, desktop SSO).
- Granting local IDE/shell permissions does **not** inject credentials into a
  Cloud Agent.
- On individual Cursor plans, team **Settings → Advanced → External ID** is
  often missing, so `CURSOR_AWS_ASSUME_IAM_ROLE_ARN` alone commonly yields
  **NoCredentials** (secret set, no successful assume).
- **Speed — prefer a warm cached environment; do not reinstall toolchains every
  task:**
  - **Cursor Cloud:** prefer the repo `.cursor/environment.json` image
    (PowerShell, Node 24, Terraform 1.15.5, AWS CLI, Docker). Do not reinstall
    those tools with `apt-get` / `npm install` at session start unless the image
    lacks them.
  - **Codex Cloud:** Codex does not use the Cursor Dockerfile. Wire
    [`.codex/cloud-setup.sh`](.codex/cloud-setup.sh) as the Environment **setup
    script** and [`.codex/cloud-maintenance.sh`](.codex/cloud-maintenance.sh) as
    **maintenance** (see [`.codex/README.md`](.codex/README.md)). Codex caches
    that container ~12h; changing setup/secrets/env vars invalidates the cache.
    Warm once with a throwaway task, then rely on the cache.
- Cloud Agents **edit the repo** (IaC, workflows, docs, evidence). They are
  **not** the cloud apply control plane.
- If a Cloud Agent is stuck on NoCredentials: that is expected under GitOps.
  Escalate to the orchestrator → local or GitHub Actions bottleneck agent.
  Do **not** make Cloud Agent assume-role the primary path.

### 3. AWS / cloud apply (GitOps)

**Preferred control plane for any project** (adapt tools/providers to the
project — GitHub Actions, GitLab CI, etc.):

1. One-time bootstrap (local/break-glass): cloud OIDC (or equivalent) trust for
   CI + a dedicated apply role.
2. Repo variable/secret for the role ARN; workflow must allow OIDC token issue
   (e.g. `id-token: write`).
3. **Plan** on PR; **apply** on protected default branch / environment approval /
   explicit manual dispatch — whatever that project’s gates are.
4. Agents edit repo config only. Live cloud changes happen because **CI applied
   merged config**, not because an agent held cloud creds.
5. After a successful apply, update evidence/claims from CI artifacts — honestly
   scoped to what that project actually proved.

**Example fill — this repo’s Landing Zone lab only** (other projects use their
own workflow/role/bootstrap paths):

| Item | Value |
| --- | --- |
| Workflow | `.github/workflows/landing-zone-lab.yml` |
| CI role | `arn:aws:iam::<AWS_ACCOUNT_ID>:role/project-a-lzlab-gha` |
| Bootstrap | `project-a/sandbox/landing-zone-lab/ci-bootstrap/` |
| Repo variable | `AWS_ROLE_ARN_LZ_LAB` |
| GitHub Environment | `lab` (apply) |

For that lab: do **not** chase `CURSOR_AWS_ASSUME_IAM_ROLE_ARN` / External ID
for apply; do **not** recreate retired paths `github-oidc/` or role
`GitHubActionsLZLab`. Keep harness runs sequential and repo-only unless the
user explicitly asks for live cloud validation.

### 4. Portfolio visuals (when requested)

Create **ONE** polished landscape portfolio infographic (~16:9, high quality,
preferably 2560×1440 or 2048×1152) for a Cloud / Platform Engineer resume
package. **Title, subtitle, boxes, arrows, cards, and footer must match the
current project** — stages and services vary (GitHub-only vs Jenkins,
ECR/ECS vs other proof, or no live cloud strip if none exists).

**AUTH / TOOLING:** Use built-in image generation (gpt-image-2) on ChatGPT
subscription auth only. Do **not** use `OPENAI_API_KEY` or API SDK scripts.

**COMPOSITION (must include BOTH regions — architecture is primary, not a tiny
inset):**

1. **TOP / PRIMARY PANEL — Architecture flowchart** (large, readable boxes +
   arrows): the project’s real end-to-end delivery path. A common pattern
   (adapt or replace stages as needed): Developer branch → GitHub PR → CI
   validation → Protected main → (optional) controlled deploy pipeline →
   Registry / artifact → Staging verification → Human approval → Production
   verification.

   Also show when the project has them:

   - Pipeline → Evidence manifest
   - Production verification --failure--> Previous verified digest (rollback)
   - Secondary ephemeral cloud proof strip under staging (services and region
     as evidenced — e.g. ECR → ECS Fargate → ALB) with an honest pass/scope
     label

2. **BOTTOM / SECONDARY PANEL — Story chapters** as equal cards, mapped to
   **this** project’s real chapters (count and labels can vary; six is a
   common resume layout). Examples only: PR safety, build once / immutable
   digest, staging verify, named human approval, evidence + rollback, cloud
   staging proof.

**STYLE:** Modern professional tech poster (deep navy / teal / white); clean
typography; high contrast; subtle depth; not cartoonish; avoid purple-glow AI
cliché. Architecture flow dominates; story cards support.

**FOOTER (required, readable):**

- Local / production-like phases vs live cloud: state **this** project’s
  boundary honestly
- Honest claim boundary line for **this** project (e.g. staging proof, not
  production ops)

**RESUME INTENT:** Hiring manager instantly sees governed CI/CD judgment,
immutable artifact promotion (when used), human approval + evidence discipline,
and any real but honestly scoped cloud validation — **without** claiming
sustained production SRE ownership the evidence does not support.

**OUTPUT:** Save as a single PNG. If editing from a reference, preserve polished
corporate style while expanding the architecture panel to full readability.

**Example fill (Project C only — other projects substitute their own copy):**

- Title: `Project C — Controlled Delivery, Proven in Evidence`
- Subtitle: `From credential-free PR gates to digest-bound promotion, named
  approval, and an honest AWS staging proof`

## Harness validation (this repo)

- Fast validation order when touching harness code:
  1. `pwsh -NoLogo -NoProfile -File tests/Run-ProjectAHarnessTests.ps1`
  2. `pwsh -NoLogo -NoProfile -File tests/Run-ProjectASpecTests.ps1`
  3. `pwsh -NoLogo -NoProfile -File tests/Run-ContractTests.ps1`
- After editing `scripts/Invoke-ProjectAValidators.ps1`,
  `scripts/Harness.Common.psm1`, or `scripts/Start-ProjectAHarness.ps1`,
  recompute execution hashes and repin Project A approval JSON files before
  claiming the harness is green.
