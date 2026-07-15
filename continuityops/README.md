# ContinuityOps

Independent cloud reliability and recovery lab under `continuityops/`.

**Orchestrator:** Grok 4.5 High Fast  
**Human gates while building:** none  
**Ralphy model:** (1) orchestrate project creation → (2) multi-threaded accuracy loops until ≥ 9.5

## Scope

- All work stays in `continuityops/`
- Does **not** edit Project A or Project C
- Owns its own lab artifacts

## Layout

See `PLAN.md`. Prepared folders: terraform, kubernetes, serverless, observability,
operations, agentic, harness, evidence, docs, tests, scripts.

## Validate folder health

```powershell
pwsh -NoLogo -NoProfile -File continuityops/scripts/Invoke-ContinuityOpsValidate.ps1
```

## Claim footer

Isolated synthetic-data cloud lab with evidence-backed runtime and recovery
drills; not a claim of sustained customer-production SRE ownership.
