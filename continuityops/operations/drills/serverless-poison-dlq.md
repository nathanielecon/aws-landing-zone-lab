# Drill: serverless poison message and DLQ growth

**Type:** Tabletop + lab metrics  
**Misleading symptoms:** No  
**Environment:** S3 worker — queues `continuityops-events` / `continuityops-events-dlq`  
**Related runbooks:** See `continuityops/serverless/infra/sqs-dlq.md`

## Scenario

Alarm: `ApproximateNumberOfMessagesVisible > 0` on DLQ for 5+ minutes. Worker
`Errors` metric elevated. Some messages retry; one malformed payload repeats
until max receive count.

## Hypothesis

Poison message: non-JSON body or schema violation causes worker to mark
non-retryable failure; after `maxReceiveCount` (5) messages land in DLQ.
Separate from transient downstream timeout (retriable).

## First-five-minute checks

1. DLQ depth trend — growing vs stable single message.
2. Sample DLQ message attributes: `correlation_id`, `tenant_id`, `event_type`.
3. Worker logs for parse errors vs timeout errors.
4. Primary queue age p99 — backlog vs poison-only.
5. Recent worker deploy changing `parse.js` validation.

## Commands

```bash
# Queue depth (replace region/account; use lab profile)
aws sqs get-queue-attributes \
  --queue-url "https://sqs.REGION.amazonaws.com/ACCOUNT_ID/continuityops-events-dlq" \
  --attribute-names ApproximateNumberOfMessagesVisible ApproximateAgeOfOldestMessage

aws sqs get-queue-attributes \
  --queue-url "https://sqs.REGION.amazonaws.com/ACCOUNT_ID/continuityops-events" \
  --attribute-names ApproximateNumberOfMessagesVisible

# Sample one message (do not paste body into tickets — redact)
aws sqs receive-message \
  --queue-url "https://sqs.REGION.amazonaws.com/ACCOUNT_ID/continuityops-events-dlq" \
  --max-number-of-messages 1 \
  --attribute-names All \
  --message-attribute-names All

# Worker logs (CloudWatch log group name per environment)
aws logs filter-log-events \
  --log-group-name "/aws/lambda/continuityops-event-worker" \
  --filter-pattern "poison OR parse OR non-JSON" \
  --limit 20

# Code reference
grep -n "poison\|JSON\|parse" continuityops/serverless/src/worker/parse.js | head -20
```

## Timeline (example)

| Time (UTC) | Event |
| --- | --- |
| T+0 | DLQ alarm fires |
| T+5 | Depth 12 and rising |
| T+10 | Sample shows invalid JSON body from test producer |
| T+15 | Producers frozen for `event_type=test.bad` |
| T+22 | Poison archived to evidence bucket; purged from DLQ |
| T+30 | Retriable subset redriven after fix |
| T+60 | DLQ empty; producers unfrozen |

## Ruled-out causes

- Complete region outage (worker still processes valid messages)
- Primary queue permissions (messages reach worker)
- Idempotency bug (parse fails before idempotency layer)
- Lab Kubernetes issue (serverless path independent)

## Root cause

Test harness published a non-JSON body to `continuityops-events`. Worker
correctly classified it as poison per `sqs-dlq.md`; repeated receives exhausted
budget and filled DLQ. Additional valid messages also delayed behind batch
errors until poison isolated.

## Recovery choice

**Chosen:** Freeze affected `event_type`; archive poison with redaction; delete
or move poison from DLQ after sign-off; redrive retriable messages only.

**Not chosen:** Blind redrive all DLQ to primary — replays poison and refills DLQ.

## Verification

- DLQ `ApproximateNumberOfMessagesVisible` = 0 for 60 minutes
- Worker `Errors` < 1% and duration within SLO
- Sample replayed messages show idempotency skip or success in logs
- Producer freeze lifted with change record

## User impact draft

```text
Subject: Delayed background processing (lab)

Some lab background jobs were delayed between {start} and {end} UTC while we
cleared invalid test messages from a processing queue. No customer data was
modified. Processing has returned to normal.
```

## Follow-up

- Schema validation at producer enqueue time
- DLQ dashboard with `event_type` dimension
- Runbook link in `sqs-dlq.md` replay section
- Drill quarterly with S3 on-call
