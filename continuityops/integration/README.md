# ContinuityOps integration

ContinuityOps is **self-contained** under `continuityops/`.

- Does **not** edit Project A or Project C
- Lab images/IaC here are ContinuityOps artifacts
- `upstreams.lock.json` records independence; adjacent projects are optional
  references only and are not build blockers
