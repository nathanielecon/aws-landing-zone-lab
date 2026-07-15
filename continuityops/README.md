# ContinuityOps

Lab-grade cloud reliability and recovery platform (former code name: Project F).

**Status:** `candidate-specification` — Phase 0 authority scaffold only.  
**Plan ID:** `continuityops-cloud-reliability-v1`  
**Orchestrator:** Grok 4.5 High Fast

## What this is

ContinuityOps consumes pinned Project A infrastructure contracts and a Project C
(or ContinuityOps lab) application artifact to prove Kubernetes, serverless,
observability, incident response, security, recovery, and FinOps skills in an
isolated AWS lab.

## What this is not

- Not enterprise production tenure or 24/7 customer ownership
- Not multi-account production Landing Zone proof
- Not Azure networking depth unless separately authorized and evidenced
- Not a Project A or Project C rewrite

## Phase 0 now

- Authority surfaces: `PLAN.md`, `AGENTS.md`, `STATUS.md`, `ISSUES.md`,
  `DECISIONS.md`, `BREAK_FIX_LOG.md`
- Upstream lock: `integration/upstreams.lock.json`
- Partition + validators under `harness/` and `scripts/`
- Human gate H0 required before Phase 1

## Validate (repo-only)

```powershell
pwsh -NoLogo -NoProfile -File continuityops/scripts/Invoke-ContinuityOpsPhase0.ps1
```

## Honest claim footer

Phase 0 proves repository authority, partitioning, and unauthorized-Phase-1
rejection only. No live Kubernetes, serverless, or recovery evidence exists yet.
