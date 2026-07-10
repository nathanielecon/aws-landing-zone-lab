# Approved smoke plan

Plan ID: `ralphy-windows-smoke-v1`

This plan proves one sequential Ralphy process on native Windows. Ralphy uses
Codex through a launcher-scoped adapter. Terra attempts every task first. The
second smoke task deliberately triggers one Sol takeover. The adapter validates
and commits allowlisted changes only after deterministic gates pass.

## Tasks

1. `[TASK:S-001]` Create `smoke/terra.txt` as UTF-8 without a BOM, containing
   exactly `TERRA_SMOKE_OK` followed by one LF.
2. `[TASK:S-002]` Create the Terra takeover fixture, then allow the harness to
   force a Sol takeover. Final content must be `SOL_TAKEOVER_OK` plus one LF.

## Boundaries

- No worktrees, parallel execution, sandbox copies, branch-per-task, browser,
  GitHub, cloud credentials, or Project A code.
- Models must not commit. The adapter commits only gated, allowlisted paths.
- The synthetic takeover gate is valid only for `S-002` in this smoke plan.
