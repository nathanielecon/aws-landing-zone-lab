# SaaS tenant lifecycle (lab synthetic)

Decision record for ContinuityOps multi-tenant identity and lifecycle stages.
This document describes contracts and sequencing only; no production tenant data
or credentials appear in the repository.

## Tenant identity

| Field | Format | Notes |
| --- | --- | --- |
| `tenant_id` | `ten_` + ULID | Immutable primary key across queues, logs, and export manifests |
| `slug` | DNS-safe string | Human-facing subdomain; unique per environment |
| `status` | enum | `provisioning`, `active`, `suspended`, `exporting`, `deprovisioned` |
| `correlation_id` | UUID v4 | End-to-end trace for onboarding and offboarding runs |

Every lifecycle event enqueued to the worker MUST include `tenant_id` and SHOULD
include `correlation_id` as SQS message attributes. The worker logs both fields
in structured JSON for evidence binding.

## Onboarding

Synthetic lab sequence:

1. **Allocate identity** — create `tenant_id`, slug reservation, and empty
   configuration record (no secrets in repo).
2. **Emit `tenant.onboard`** — payload includes plan tier, data residency label,
   and owner contact reference (ticket id only).
3. **Worker provisioning** — idempotent handlers create namespace placeholders,
   default SLO bindings, and observability labels.
4. **Activate** — transition `status` to `active` after health checks pass;
   emit `tenant.activated` with the same `correlation_id`.

Duplicate `tenant.onboard` deliveries MUST be skipped via idempotency keys; lab
uses in-memory deduplication, production uses DynamoDB conditional writes.

## Suspension

Suspend when billing fails, policy violations occur, or continuity drills require
read-only mode.

1. Emit `tenant.suspend` with reason code (`billing`, `policy`, `drill`).
2. Worker revokes enqueue-capable integrations (feature flags, API keys managed
   outside this repo).
3. Read paths and export remain available unless legal hold dictates otherwise.
4. `status` becomes `suspended`; dashboards show banner state from tenant metadata.

Reactivation uses `tenant.resume` with a new `correlation_id` linked to the
suspension ticket in the change record.

## Export

Tenant-requested or compliance-driven export before deprovisioning.

| Artifact | Contents |
| --- | --- |
| `export-manifest.json` | `tenant_id`, `correlation_id`, object list, checksums |
| `config-snapshot.json` | Non-secret settings and integration metadata |
| `audit-trail.jsonl` | Redacted lifecycle and admin events |

1. Emit `tenant.export` — include requested format and retention window.
2. Worker writes artifacts to a scoped object prefix; lab uses synthetic empty
   objects with valid manifests only.
3. Notify requester via ticketing integration; store delivery receipt id.
4. `status` becomes `exporting` until manifest verification completes, then
   returns to `active` or proceeds to deprovisioning.

Exports are idempotent per `(tenant_id, export_job_id)`.

## Deprovisioning

Irreversible after cooling-off period and confirmed export.

1. Preconditions — `status` is `suspended` or `active` with signed export
   receipt; no open incidents on the tenant.
2. Emit `tenant.deprovision` — include `correlation_id` and approver ticket.
3. Worker tears down synthetic resources: queue subscriptions, dashboards,
   feature flags, and object prefixes per manifest.
4. Final `tenant.deprovisioned` event; `status` becomes `deprovisioned`.
5. Retain audit metadata per retention policy; purge PII on schedule documented
   in operations runbooks (outside this slice).

## Event catalog (worker contract)

| Event type | Idempotency scope |
| --- | --- |
| `tenant.onboard` | `tenant_id` |
| `tenant.suspend` | `tenant_id` + reason |
| `tenant.resume` | `tenant_id` |
| `tenant.export` | `tenant_id` + `export_job_id` |
| `tenant.deprovision` | `tenant_id` |

See `continuityops/serverless/worker.contract.json` for runtime bindings.
