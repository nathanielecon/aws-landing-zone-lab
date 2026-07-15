# CH-backup-restore — lab backup and restore procedure

| Field | Value |
| --- | --- |
| Change ID | `CH-backup-restore` |
| Slice | S7 |
| Environment | `recovery-lab` |
| Data class | Synthetic drill data only |
| Owner | ContinuityOps resilience |

## Purpose

Document backup capture, restore execution, and post-restore verification for
ContinuityOps recovery-lab components. No production accounts, secrets, or
customer payloads are involved.

## Scope

| Asset | Backup mechanism | Restore owner |
| --- | --- | --- |
| Terraform state | Versioned remote backend snapshot | S1 platform |
| Helm release values + chart | Git commit SHA | S2 Kubernetes |
| Lambda deployment package | `serverless/build/worker.zip` artifact in Git CI | S3 serverless |
| SQS messages (DLQ cohort) | SQS retention + optional evidence export | S7 resilience |
| Synthetic tenant manifests | Evidence bucket prefix `synthetic-drill/` | S7 resilience |
| CloudWatch log excerpts | Export task to evidence bucket (redacted) | S4 observability |

## Preconditions

- [ ] Drill scheduled in change calendar; `recovery-lab` isolated from staging
- [ ] On-call notified; incident channel open for timeline
- [ ] Candidate SHA recorded (`git rev-parse HEAD`)
- [ ] No real tenant identifiers in seed data (use `ten_SYN_*` prefixes only)
- [ ] Approval for destructive steps per protected environment policy

## Backup procedure

### 1. Capture infrastructure state

```bash
# From repo root — plan-only; apply uses OIDC workflow in lab accounts
cd continuityops/terraform/environments/recovery-lab
terraform init
terraform plan -out=recovery-lab-pre-drill.tfplan
```

Record plan artifact hash and backend state version id in the change ticket.

### 2. Snapshot workload config

```bash
helm -n continuityops-lab get values continuityops-lab > /tmp/helm-values-snapshot.yaml
helm -n continuityops-lab get manifest continuityops-lab > /tmp/helm-manifest-snapshot.yaml
```

Store snapshots under evidence prefix `synthetic-drill/CH-backup-restore/{date}/`
with PII redaction applied before upload.

### 3. Export DLQ sample (optional)

When DLQ depth > 0 for drill realism:

1. Sample up to 10 messages via console or CLI (attributes only in evidence).
2. Archive message ids and `correlation_id` values — never raw bodies with
   synthetic PII fields in public tickets.
3. Leave messages in DLQ until restore phase completes.

### 4. Record backup manifest

Create a JSON sidecar listing:

- `candidate_sha`
- `backup_timestamp_utc`
- `components[]` with `artifact_uri` or `git_path`
- `synthetic_data_label: true`

## Restore procedure

### Scenario A — workload rollback (preferred)

1. Identify last known good Helm revision: `helm -n continuityops-lab history continuityops-lab`
2. Roll back: `helm -n continuityops-lab rollback continuityops-lab <revision>`
3. Wait for rollout: `kubectl -n continuityops-lab rollout status deployment/continuityops-lab`
4. Proceed to verification checklist below.

### Scenario B — queue redrive after worker fix

Follow `serverless/infra/sqs-dlq.md` replay procedure:

1. Freeze synthetic producers
2. Triage DLQ (poison vs retriable)
3. Redrive retriable messages to primary queue
4. Unfreeze and monitor for 60 minutes

### Scenario C — full environment rebuild

Use when Terraform state or cluster is corrupted:

1. Tear down per `CH-teardown.md` (lab only)
2. Re-apply from pinned commit via approved CI workflow
3. Reinstall Helm chart with pinned image digest
4. Reseed synthetic tenant fixtures from evidence bucket

## Verification checklist

Complete every item; mark N/A only with ticket justification.

| # | Check | Command / signal | Pass criteria |
| --- | --- | --- | --- |
| 1 | Cluster API healthy | `kubectl get nodes` | All nodes Ready |
| 2 | Workload ready | `kubectl -n continuityops-lab get pods` | All pods Running/Ready |
| 3 | Liveness | `curl -sf http://continuityops-lab:8080/healthz` (from cluster) | HTTP 200 |
| 4 | Readiness | `curl -sf http://continuityops-lab:8080/readyz` | HTTP 200 |
| 5 | Worker errors | CloudWatch `Errors` metric | Below alarm threshold |
| 6 | Primary queue depth | SQS `ApproximateNumberOfMessages` | Stable or draining |
| 7 | DLQ depth | SQS DLQ visible count | Zero or triaged |
| 8 | SLO spot check | Synthetic load per `tests/performance/load-scenario.md` | p95 ≤ 500 ms lab target |
| 9 | Evidence artifact | `restore-verification.schema.json` | Valid JSON, `result: pass` |
| 10 | RTO measurement | Wall clock incident start → check 9 pass | ≤ component RTO in `rto-rpo.md` |

## Rollback of restore

If verification fails after Scenario A:

1. Roll forward to previous revision again or redeploy from Git
2. Escalate per `docs/decisions/severity-model.md` if user-facing checks fail > 30 minutes
3. Attach failed verification JSON with `result: fail` and open follow-up ticket

## Evidence

- Bind `restore-verification` JSON to candidate SHA
- Link artifact from `evidence/slices/S7-resilience.md`
- Reference performance baseline comparison when check 8 runs

## Related documents

- `docs/decisions/rto-rpo.md` — targets by component
- `tests/recovery/README.md` — schema usage
- `operations/changes/CH-teardown.md` — destructive teardown inventory
