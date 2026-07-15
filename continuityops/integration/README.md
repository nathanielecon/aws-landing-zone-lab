# ContinuityOps upstream integration

ContinuityOps consumes Project A and Project C through pinned contracts only.

- Lock file: [`upstreams.lock.json`](upstreams.lock.json)
- Project A path prefix in this monorepo: `project-a/`
- ContinuityOps must not modify Project A or Project C source trees
- Missing exports become ContinuityOps-side adapters or recorded gaps in
  `ISSUES.md`

## Project A contracts currently referenced

| Contract | Evidence |
| --- | --- |
| Single-account LZ lab identity/OIDC | `project-a/sandbox/landing-zone-lab/EVIDENCE.md` |
| Private VPC + flow logs | same |
| Audit trail/archive | same |
| Claims boundary | `project-a/docs/portfolio/claims-boundary.md` |
| Blocked-change catalog | `project-a/docs/operations/blocked-change-catalog.md` |

## Project C

Pin unavailable at Phase 0 bootstrap (`OPEN-COP-001`). Do not invent digests.
