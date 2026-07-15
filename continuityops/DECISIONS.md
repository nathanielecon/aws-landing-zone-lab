# ContinuityOps decisions

## D-COP-001 — Host ContinuityOps beside Project A without editing A

- **Date:** 2026-07-15
- **Status:** accepted
- **Decision:** Place ContinuityOps under `continuityops/` in
  `nathanielecon/cloud`. Project A remains independently complete. No
  ContinuityOps task may modify `project-a/`.
- **Consequences:** Missing Project A exports become ContinuityOps-side
  adapters or recorded integration gaps.

## D-COP-002 — Grok is the default ContinuityOps orchestrator

- **Date:** 2026-07-15
- **Status:** accepted
- **Decision:** Ignore Sonnet/Opus supervisor language for this delivery
  track. Grok 4.5 High Fast is the lead orchestrator, judge, nixer, fixer,
  and bottleneck reasoning model. Codex `/fast` implements bounded tasks.
- **Consequences:** Worker handoffs remain Simplified Chinese; recruiter
  artifacts remain English.

## D-COP-003 — Candidate specification, not verified completion

- **Date:** 2026-07-15
- **Status:** accepted
- **Decision:** Existing or newly scaffolded files are candidates. Only
  judge-council certification against a candidate SHA and evidence
  manifest counts as verified.
- **Consequences:** Phase 0 must inventory, partition, freeze rubrics, and
  pin hashes before Phase 1 authorization.

## D-COP-004 — Project C digest explicitly unavailable at bootstrap

- **Date:** 2026-07-15
- **Status:** accepted
- **Decision:** Until Project C export evidence is reachable, pin
  `image_digest` as `REQUIRED_OR_EXPLICITLY_UNAVAILABLE` and open
  OPEN-COP-001.
- **Consequences:** Kubernetes/runtime claims cannot assert Project C
  production release provenance.
