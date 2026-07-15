# ContinuityOps agentic workflow (S6)

Security and agentic safety slice: read-mostly evidence gathering, remediation
**proposals only**, and automated rejection of unsafe agent output.

## Product posture

| Control | Setting |
| --- | --- |
| Default write | **Off** (`policies/mutation-policy.json`) |
| Mutation jobs | Require human approval (gate **H4**) |
| Build loop | No H4 enforcement during orchestration (see `PLAN.md` D-COP-003) |
| Worker language | Simplified Chinese prompts |
| Recruiter docs | English |

Agents **propose**; humans **approve** mutations. This is intentional product
design even when the build harness does not pause for receipts.

## Layout

```text
agentic/
  policies/
    mutation-policy.json    # default-deny write; H4 for mutation-capable jobs
    prompt-safety.md        # injection, evidence, scope, secret, runbook rules
    README.md
  prompts/
    incident-triage.zh-CN.md   # worker prompt (evidence + proposal only)
    incident-triage.en.md      # recruiter-safe workflow description
  tests/
    unsafe-proposal-cases.json
    Test-UnsafeProposals.ps1
  README.md
```

Cross-cutting guardrails: `docs/guardrails/` (IAM/RBAC, secrets, supply chain).

## Incident triage flow

1. **Triage** — confirm scope, severity, affected slice (S2–S5).
2. **Evidence** — read-only correlation (metrics, logs, traces, deployments).
3. **Hypothesis** — ranked root causes with confidence and counter-evidence.
4. **Proposal** — remediation plan with blast radius, rollback, H4 flag if mutating.
5. **Escalation** — IC when evidence gaps, stale runbooks, or cross-slice risk.

See `prompts/incident-triage.en.md` for the recruiter-facing narrative and
`prompts/incident-triage.zh-CN.md` for worker instructions.

## Safety enforcement

| Layer | Mechanism |
| --- | --- |
| Policy | `mutation-policy.json`, `prompt-safety.md` |
| Tests | `tests/Test-UnsafeProposals.ps1` + negative cases JSON |
| Guardrails | `docs/guardrails/iam-rbac.md`, `secrets.md`, `supply-chain.md` |

Rejection categories: prompt injection, forged evidence, excessive scope, secret
requests, stale runbooks, unauthorized mutation.

## Validation

```powershell
pwsh -NoLogo -NoProfile -File continuityops/agentic/tests/Test-UnsafeProposals.ps1
```

Run from repository root or any path; the script resolves `continuityops/` relative
to the test file location.

## Related slices

- **S5** (`operations/`) — runbooks and incident ops context for triage
- **S8** (`docs/claims/`) — portfolio claim boundaries

## Lab claim boundary

> Isolated synthetic-data cloud lab with evidence-backed runtime and recovery
> drills; not a claim of sustained customer-production SRE ownership.
