# SQS worker queue, DLQ, redrive, and replay

Lab reference for the ContinuityOps event worker (`continuityops-event-worker`).
No live ARNs or secrets are stored in this repository.

## Primary queue

| Setting | Lab value | Notes |
| --- | --- | --- |
| Name | `continuityops-events` | One queue per environment |
| Type | Standard | Ordering not required for tenant lifecycle fan-out |
| Visibility timeout | 180s | ≥ 6× Lambda timeout (30s lab default) |
| Message retention | 4 days | Extend for recovery-lab drills |
| Receive message wait | 20s | Long polling reduces empty receives |
| Max receive count | 5 | After exhaustion, message moves to DLQ |

### Message attributes

| Attribute | Required | Purpose |
| --- | --- | --- |
| `correlation_id` | Recommended | Propagates through structured logs and export bundles |
| `tenant_id` | Recommended | Routes idempotency partition in DynamoDB (production) |
| `event_type` | Optional | Fast filter for replay subsets |

Body MUST be a JSON object. Non-JSON bodies are poison messages and are failed
after marking so they do not block the batch indefinitely.

## Dead-letter queue (DLQ)

| Setting | Lab value |
| --- | --- |
| Name | `continuityops-events-dlq` |
| Retention | 14 days |
| Encryption | SSE-SQS (lab) / SSE-KMS (staging+) |

Alarm when `ApproximateNumberOfMessagesVisible > 0` for 5 minutes. Page the
ContinuityOps on-call rotation for sustained DLQ depth.

## Redrive policy

Attach to the primary queue:

```json
{
  "deadLetterTargetArn": "<dlq-arn>",
  "maxReceiveCount": 5
}
```

Transient failures (downstream timeout, throttling) should succeed within the
receive budget. Poison payloads and schema violations exhaust receives quickly
because the worker marks them non-retryable at the application layer while still
returning `batchItemFailures` for that message only.

## Replay procedure

Use this sequence after fixing a consumer bug or downstream dependency.

1. **Freeze producers** — pause schedulers or feature flags that enqueue new
   events for the affected `event_type` or `tenant_id` cohort.
2. **Inspect DLQ** — sample messages; confirm `correlation_id`, `tenant_id`, and
   body schema. Separate poison from retriable failures.
3. **Triage poison** — for invalid JSON or permanent schema violations, archive
   to an evidence bucket with redacted payloads and discard from DLQ after
   sign-off. Do not replay poison messages.
4. **Redrive retriable** — use SQS redrive to the primary queue (console or
   `aws sqs start-message-move-task`) for messages that failed due to code or
   infra defects now resolved.
5. **Verify idempotency** — replays rely on `messageId` + payload hash (lab
   in-memory; production DynamoDB). Expect duplicate skips in logs; no duplicate
   side effects.
6. **Unfreeze producers** — restore enqueue paths and watch primary depth, DLQ
   depth, and worker `Errors`/`Duration` metrics for one hour.
7. **Record evidence** — attach replay ticket, counts moved, and sample
   `correlation_id` values to the incident or change record.

## CloudFormation sketch

See `template.md` for a minimal SAM/CloudFormation fragment wiring the queue,
DLQ, event source mapping, and alarm placeholders.
