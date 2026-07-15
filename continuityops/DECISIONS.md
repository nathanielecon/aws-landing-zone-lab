# ContinuityOps decisions

## D-COP-001 — Own folder only; no Project A/C edits

- **Date:** 2026-07-15
- **Status:** accepted
- **Decision:** ContinuityOps is confined to `continuityops/`. Never modify
  `project-a/` or Project C. Lab artifacts are ContinuityOps-owned.

## D-COP-002 — Grok lead orchestrator

- **Date:** 2026-07-15
- **Status:** accepted
- **Decision:** Grok 4.5 High Fast is the ContinuityOps orchestrator.

## D-COP-003 — No human gates while building

- **Date:** 2026-07-15
- **Status:** accepted
- **Decision:** Build and accuracy loops do not wait on H0–H6 receipts.
  Product docs may still describe human-gated mutation as a designed control.

## D-COP-004 — Two-stage Ralphy model

- **Date:** 2026-07-15
- **Status:** accepted
- **Decision:**
  1. Stage 1: create the project via orchestration.
  2. Stage 2: after project complete, multi-threaded accuracy/no-error Ralphy
     loops until council score ≥ 9.5.
