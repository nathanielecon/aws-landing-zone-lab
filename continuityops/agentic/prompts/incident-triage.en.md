# Incident triage workflow (recruiter-facing)

English description of the ContinuityOps S6 agentic incident triage flow. This
document is safe for portfolio and recruiter review. Worker execution uses the
Simplified Chinese prompt in `incident-triage.zh-CN.md`.

## Purpose

Demonstrate governed **AI-assisted incident response** where agents **gather
evidence** and **propose remediation** without default write authority. Mutation
remains a human-gated product control (gate H4), consistent with least-privilege
SRE practice.

## What the workflow does

| Phase | Agent behavior | Human role |
| --- | --- | --- |
| Triage | Confirms incident scope, severity, and affected services | IC validates boundaries |
| Evidence | Read-only correlation across metrics, logs, traces, deployments | Operators supply access |
| Hypothesis | Ranked root-cause candidates with confidence and counter-evidence | Technical lead challenges assumptions |
| Proposal | Written remediation plan with blast radius and rollback | On-call / IC approves mutations (H4) |
| Escalation | Recommends IC involvement when risk or evidence gaps exceed thresholds | IC owns comms and decisions |

## Safety properties

- **No default mutation** — policy encoded in `agentic/policies/mutation-policy.json`
- **Prompt injection resistance** — untrusted ticket/log text cannot override system policy
- **Forged evidence rejection** — claims must link to observable signals
- **Scope bounds** — proposals stay within the declared incident slice
- **No secrets in chat** — credentials use audited break-glass paths
- **Runbook freshness** — stale or draft runbooks cannot authorize mutation steps

## Lab claim boundary

This workflow is implemented and tested in an **isolated synthetic-data cloud
lab**. It shows operational maturity and agentic safety design; it is **not** a
claim of sustained customer-production SRE ownership or 24/7 on-call for external
tenants.

## Artifacts produced

1. Evidence summary with traceable citations  
2. Ranked hypotheses with confidence levels  
3. Remediation proposal (non-executing)  
4. Rollback plan  
5. Escalation recommendation when needed  

## Related files

| File | Role |
| --- | --- |
| `agentic/prompts/incident-triage.zh-CN.md` | Worker prompt (Simplified Chinese) |
| `agentic/policies/mutation-policy.json` | Default-deny write; H4 for mutation jobs |
| `agentic/policies/prompt-safety.md` | Injection, evidence, scope, secret, runbook rules |
| `agentic/tests/unsafe-proposal-cases.json` | Negative test cases |
| `agentic/tests/Test-UnsafeProposals.ps1` | Automated rejection assertions |
| `docs/guardrails/` | IAM/RBAC, secrets, supply-chain guardrails |

## Portfolio talking points

- Agents **propose**; humans **approve** mutations — aligns with enterprise change control.
- Automated tests reject unsafe proposals before they reach operators.
- Guardrail docs cover identity, secrets, and supply chain alongside agentic policy.
- Bilingual split: Mandarin for workers, English for recruiter surfaces (per project language policy).
