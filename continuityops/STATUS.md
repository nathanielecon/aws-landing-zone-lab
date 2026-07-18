# ContinuityOps status

| Field | Value |
| --- | --- |
| Plan ID | `continuityops-cloud-reliability-v1` |
| Status | `fresh-council-remediation` |
| Partitioning | Grok postbuild 9 capability partitions |
| Blind judging | Grok J1/J2/J3 — **no numeric thresholds in prompts** |
| Round 4 aggregate | see `evidence/manifests/fresh-council-aggregate.json` |
| Prior accuracy-final | **retracted** (threshold leak) |
| Human gates while building | none |
| Orchestrator | Grok 4.5 High Fast |
| Scope | `continuityops/` only |
| PR | https://github.com/nathanielecon/cloud/pull/19 |
| Last updated | `2026-07-15T15:20:00Z` |

## Threshold policy

- Judges must not receive pass-bar numbers.
- `orchestrator-gate.private.json` is orchestrator-only after blind scoring.
- `Invoke-ContinuityOpsAccuracyCouncil.ps1` (old) leaked bars — superseded by deterministic checks + fresh Grok judges.

## Live AWS (2026-07-18)

- Control plane: GitHub OIDC → `continuityops-gha` (`.github/workflows/continuityops-terraform.yml`)
- Bootstrap: `continuityops/terraform/ci-bootstrap/bootstrap-oidc-cloudshell.sh` (operator once)
- Cloud Agent: repo-only; `NoCredentials` expected (not CursorCloudAgent)
