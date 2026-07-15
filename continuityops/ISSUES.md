# ContinuityOps issues

Append-only. Do not rewrite closed entries; open a superseding issue instead.

## OPEN-COP-001 — Project C pin unavailable

- **Opened:** 2026-07-15
- **Severity:** high (blocks S1/S2 immutable digest claims)
- **Slice:** S0 / integration
- **Summary:** `nathanielecon/project-c-cloud` returned HTTP 404 to the
  orchestrator identity. ContinuityOps cannot pin `commit_sha` or
  `image_digest` yet.
- **Disposition:** Record explicit unavailability in
  `integration/upstreams.lock.json`. Any lab image built from a pinned
  source SHA must be labeled a ContinuityOps lab artifact, not a Project C
  production release.
- **Status:** open

## OPEN-COP-002 — Human gate H0 unsigned

- **Opened:** 2026-07-15
- **Severity:** high (blocks Phase 1)
- **Slice:** S0
- **Summary:** Plan/spec/execution hashes are not human-approved. Phase 1
  validators must reject unauthorized execution.
- **Status:** open

## OPEN-COP-003 — Shared interface freeze pending

- **Opened:** 2026-07-15
- **Severity:** medium
- **Slice:** S0
- **Summary:** Concurrent Ralphy streams require frozen shared interfaces
  and a recorded merge queue before multi-stream implementation begins.
- **Status:** open
