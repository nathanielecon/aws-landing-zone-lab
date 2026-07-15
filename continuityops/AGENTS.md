# ContinuityOps agent rules

Plan ID: `continuityops-cloud-reliability-v1`  
Former code name: Project F  
Primary orchestrator: Grok 4.5 High Fast  
Scope: **`continuityops/` only** — never edit `project-a/` or Project C.

## Authority

- All ContinuityOps work stays under `continuityops/`.
- Do not modify Project A or Project C. This project owns its own folder and
  lab artifacts.
- **No human gates while building.** Orchestrator may advance build and
  accuracy stages without H0–H6 receipts.
- Codex workers must not commit unless the ContinuityOps adapter/orchestrator
  explicitly owns the commit step for this track.
- Never widen Codex beyond `workspace-write`.
- Runtime state and verbose logs remain untracked and sanitized.
- Do not clean, reset, stash, or overwrite unexplained user changes.

## Ralphy operating model (ContinuityOps-specific)

Two stages only:

1. **Build orchestration** — create the full ContinuityOps project via the
   lead orchestrator (Grok) dispatching Codex `/fast` workers across disjoint
   ownership paths under `continuityops/`.
2. **Accuracy / no-error loops** — after the project is complete, run
   **multi-threaded** Ralphy accuracy loops (judge → nixer → fixer) until the
   council average is **≥ 9.5** with no judge below 9.0 and all must-haves
   pass. Loops continue until that bar is met; no early “good enough.”

Root-repo smoke/Project A harness rules (sequential-only) do **not** govern
ContinuityOps accuracy loops.

## Communication

- Worker instructions, status, handoffs, inter-agent communication:
  **Simplified Chinese only**.
- Recruiter-facing repository artifacts: **English only**.

## TypeScript

Pin stable TypeScript 7.x when used. Initial baseline: `typescript@7.0.2`.

## Cloud lab posture

- Isolated synthetic-data AWS lab claims only when evidenced.
- Cloud Agents may lack apply credentials (`NoCredentials` expected).
- No invented DNS, multi-account production, or 24/7 customer-SRE ownership
  claims.
