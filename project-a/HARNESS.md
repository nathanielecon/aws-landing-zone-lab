# Project A harness operations

Phase 4 now includes an explicit execution approval for the current proven
repo-only bundle. `project-a/harness/execution-approval.json` is currently
`execution_approved: true` for that exact bundle and must be re-approved if the
execution bundle or its pinned validator/hash implementations change.

## Commands

```powershell
./scripts/Start-ProjectAHarness.ps1 -DryRun
./scripts/Start-ProjectAHarness.ps1
./scripts/Approve-ProjectATask.ps1 -TaskId A-001
./scripts/Start-ProjectAHarness.ps1 -Resume
```

The double-click entry point is `launcher/Launch Project A Harness.cmd`.
Terraform 1.15.5 is required for live execution. If it is missing, the launcher
prints this recovery command and never elevates silently:

```powershell
choco install terraform --version=1.15.5 -y --no-progress
```

## Security boundary

- Codex runs with native `workspace-write`, command network access explicitly
  disabled, web search disabled, apps disabled, user configuration ignored, and
  approval escalation disabled.
- Codex model-launched shells receive a filtered core environment. Cloud,
  provider, proxy, GitHub, API-key, token, secret, password, and `CODEX_HOME`
  variables are excluded.
- The Codex process itself still requires the existing ChatGPT login. The
  launcher strips cloud credentials and redirects AWS/Azure configuration to
  empty per-run locations, but does not claim that Codex authentication is
  absent.
- Official Codex documentation describes local `workspace-write` as
  OS-sandboxed with command network access off unless explicitly enabled:
  <https://learn.chatgpt.com/docs/agent-approvals-security#network-access>.
- Human approval requests and receipts live under
  `%LOCALAPPDATA%\RalphyHarness\cloud\approvals`, outside the workspace. The
  broker creates a random HMAC key only after the model exits and protects it
  with Windows DPAPI for the current user.
- Receipts bind the execution/validator/policy hashes, task and gate, branch,
  starting commit, current HEAD, exact content diff, validation digest, nonce,
  and timestamp. Any changed byte invalidates the receipt. This is strong
  same-Windows-user tamper resistance, not a legal identity signature.
- Adapter-owned evidence is created only after validation and approval. Agents
  cannot include the evidence path in their task diff.

## Pause and resume

A-001 and A-002 exit with code 75 after deterministic validation. This is an
approval pause, not a model failure, and does not increment retry counters.
Approval followed by `-Resume` revalidates the unchanged diff and commits
without another model call. Under the approved autonomous revision, A-003
through A-007 commit after deterministic gates without human receipts. Any
failure remains terminal. An interruption can start a new Ralphy OS process,
but state preserves one sequential task stream with no concurrent task owner.

Verbose sanitized logs remain outside the repository under
`%LOCALAPPDATA%\RalphyHarness\cloud\<run-id>`.
