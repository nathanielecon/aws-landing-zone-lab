# ContinuityOps issues

Append-only.

## OPEN-COP-007 — ContinuityOps GHA OIDC bootstrap (operator CloudShell)

- **Opened:** 2026-07-18
- **Summary:** Repo wiring for `continuityops-gha` + `continuityops-terraform.yml`
  is in place. Live role must be created via CloudShell
  `continuityops/terraform/ci-bootstrap/bootstrap-oidc-cloudshell.sh` before
  OIDC plan goes green. GitHub Environment `continuityops` required for apply.
- **Status:** open

## CLOSED-COP-001 — Project C pin not required

- **Opened:** 2026-07-15
- **Closed:** 2026-07-15
- **Summary:** Operator directed that ContinuityOps must not depend on or edit
  Projects A/C. ContinuityOps owns its folder and lab artifacts.
- **Status:** closed

## CLOSED-COP-002 — Human gates disabled during build

- **Opened:** 2026-07-15
- **Closed:** 2026-07-15
- **Summary:** Operator directed no human gates while building. H0–H6 receipts
  are not required to advance Stage 1 or Stage 2 accuracy loops.
- **Status:** closed

## CLOSED-COP-004 — Stage 1 implementation incomplete

- **Opened:** 2026-07-15
- **Closed:** 2026-07-15
- **Summary:** Stage 1 build across S1–S8 completed; prior accuracy council
  returned merge_ready (later invalidated — see OPEN-COP-005).
- **Status:** closed

## OPEN-COP-005 — Threshold leakage invalidated prior accuracy council

- **Opened:** 2026-07-15
- **Summary:** `evidence/manifests/accuracy-final.json` was produced while judge
  prompts embedded the 9.5 average and 9.0 floor thresholds. Fresh blind Grok
  judges (`fresh-judge-J1` ~7.8, `J2` ~7.9, `J3` ~8.18; avg ~7.96) scored
  without thresholds and did not endorse merge_ready. `STATUS.md` falsely
  claimed `complete` while `PLAN.md` / `plan-approval.json` still said
  `build-orchestration`.
- **Remediation:** Status aligned to `fresh-council-remediation`; retract
  merge_ready claims; fix doc/evidence drift; address fresh-judge findings.
- **Status:** open

## OPEN-COP-006 — Fresh council remediation in progress

- **Opened:** 2026-07-15
- **Summary:** Stage 2 accuracy loops must re-run under
  `harness/rubrics/JUDGE_PROMPT_NO_THRESHOLD.md` until orchestrator gate passes
  on blind scores only. Interim fixes: terraform README, claims README, synthetic
  S7 restore-verification lab event, baseline SHA binding.
- **Status:** open
