# Drill: observability blind spot

**Type:** Tabletop  
**Misleading symptoms:** Yes — dashboards show "all green" while customers report
errors; alternatively, alerts fire but kubectl shows healthy pods.  
**Environment:** `continuityops-lab` + S4 observability  
**Related runbooks:** `kubectl-first-five.md`, `app-smoke.md`

## Scenario

**Variant A:** Support tickets cite failed `/api/smoke` calls. Grafana SLO
dashboard is green — metrics stopped arriving 20 minutes ago after collector
restart. On-call nearly closes as "false alarm."

**Variant B:** Pager fires on error-rate alert. Responder sees empty logs and
healthy pods; later discovers only canary traffic hits the broken `Ingress`
path while monitors scrape in-cluster Service.

## Hypothesis

**Initial (misleading):** No incident — monitoring says healthy; user reports
are stale or client-side.

**Revised:** Observability pipeline gap: missing scrape targets, wrong label
selector on ServiceMonitor, or external-only path broken while internal probes
succeed.

## First-five-minute checks

1. **Do not trust a single dashboard** — run manual `app-smoke.md` external +
   in-cluster.
2. Check metrics ingestion lag (`up` metric, last scrape timestamp).
3. Compare alert query labels to actual pod labels after last deploy.
4. Verify log pipeline (CloudWatch/agent) delivery in last 15 minutes.
5. Ask: "What path do users take vs what we measure?"

## Commands

```bash
# Ground truth — smoke (not metrics)
kubectl -n continuityops-lab run smoke-blind --rm -it --restart=Never \
  --image=curlimages/curl:8.5.0 -- sh -c '
    for path in /healthz /readyz /api/smoke; do
      curl -sS -o /dev/null -w "cluster $path %{http_code}\n" \
        "http://continuityops-lab:8080$path"
    done
  '

curl -sS -o /dev/null -w "external /api/smoke %{http_code}\n" \
  https://lab.continuityops.local/api/smoke

# Pod labels vs chart
kubectl -n continuityops-lab get pods -l app.kubernetes.io/name=continuityops-lab --show-labels
kubectl -n continuityops-lab get svc continuityops-lab -o yaml | grep -A5 selector

# Recent events / deploy
kubectl -n continuityops-lab get events --sort-by=.lastTimestamp | tail -15
helm -n continuityops-lab history continuityops-lab | tail -3

# SLO catalog reference (alert names and burn rules)
grep -E 'error|availability|burn' continuityops/observability/slo-catalog.json | head -30

# Logs exist?
kubectl -n continuityops-lab logs -l app.kubernetes.io/name=continuityops-lab --since=15m --tail=20
```

## Timeline (example)

| Time (UTC) | Event |
| --- | --- |
| T+0 | Customer reports errors; dashboard green |
| T+5 | Responder begins closing ticket — **stop** |
| T+8 | External smoke fails; in-cluster smoke passes |
| T+14 | Ingress path `/api/smoke` routes to wrong backend |
| T+18 | Misconfigured path fixed via Helm |
| T+25 | Metrics catch up; SLO panel shows brief dip |
| T+35 | Resolved; observability gap documented |

## Ruled-out causes

- Total pod failure (pods Ready; selective path failure)
- DLQ/worker issue (HTTP path isolated)
- DNS cluster-wide failure (in-cluster smoke works)
- "Users hallucinating" (reproducible external curl failure)

## Root cause

Monitoring scraped in-cluster Service `:8080` on `/healthz` only. User traffic
entered via ingress with a path rule that did not include `/api/smoke` after a
chart edit. Metrics showed availability; business path was broken. Secondary:
metrics collector outage hid error spike in Variant A.

## Recovery choice

**Chosen:** Fix ingress path routing to match `openapi-smoke.yaml`; restore
metrics collector; backfill SLO from logs where possible.

**Not chosen:** Lower alert threshold without fixing scrape path — more noise,
same blind spot.

## Verification

- External and in-cluster `app-smoke.md` all 200
- `up{job="continuityops-lab"}` or equivalent shows recent scrape
- Error-rate panel reflects test 500 during failure window (no flat line)
- Support tickets stop after 15 minutes stable

## User impact draft

```text
Subject: Lab API errors on specific endpoints

Some lab API checks failed between {start} and {end} UTC while basic health
monitoring appeared normal. We corrected routing and monitoring alignment.
Impact was limited to lab synthetic endpoints.
```

## Follow-up

- Add external synthetic check for `/api/smoke` (S4)
- Alert on `up == 0` or stale scrape > 5m
- Dashboard annotation: "healthz only — not business SLO"
- Update this drill when `slo-catalog.json` changes
