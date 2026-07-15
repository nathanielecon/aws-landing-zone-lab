# Drill: misleading latency — downstream dependency

**Type:** Tabletop + lab  
**Misleading symptoms:** Yes — p99 latency and 503s look like an app or database problem.  
**Environment:** `continuityops-lab` + staging upstream allowlist  
**Related runbooks:** `kubectl-first-five.md`, `dns-tls-checks.md`, `lb-target-health.md`

## Scenario

Dashboards show API p99 latency above SLO and intermittent 503 responses on
`/api/smoke`. Error logs in app pods mention "upstream timeout." On-call assumes
the ContinuityOps lab app or its in-cluster database is saturated and prepares
to scale replicas.

## Hypothesis

**Initial (misleading):** Lab app is CPU-bound or an in-cluster dependency is
slow; scaling replicas will absorb load.

**Revised:** Outbound HTTPS to the allowlisted staging upstream
(`staging.continuityops.lab`) is degraded or timing out. In-cluster `/healthz`
and `/readyz` remain healthy; latency is introduced on code paths that call the
external API.

## First-five-minute checks

1. Compare in-cluster smoke (`http://continuityops-lab:8080/api/smoke`) vs
   paths that fan out upstream.
2. Check app pod CPU/memory — low utilization rules out local saturation.
3. Test upstream directly from an app pod (`wget`/`curl` to allowlisted host).
4. Confirm no recent Helm deploy on lab app (rules out bad release).
5. Check ingress/LB — external 503 may lag behind upstream slowness.

## Commands

```bash
# App pods healthy?
kubectl -n continuityops-lab get pods -l app.kubernetes.io/name=continuityops-lab
kubectl -n continuityops-lab top pod -l app.kubernetes.io/name=continuityops-lab 2>/dev/null

# In-cluster smoke (should be fast)
kubectl -n continuityops-lab run curl-lat --rm -it --restart=Never \
  --image=curlimages/curl:8.5.0 -- \
  curl -sS -o /dev/null -w "smoke:%{time_total}s %{http_code}\n" \
  http://continuityops-lab:8080/api/smoke

# Upstream from app network context
kubectl -n continuityops-lab exec deploy/continuityops-lab -- \
  wget -qO- --timeout=10 https://staging.continuityops.lab/healthz 2>&1 | tail -5

# Recent deploy?
helm -n continuityops-lab history continuityops-lab | tail -5

# Logs — upstream errors
kubectl -n continuityops-lab logs -l app.kubernetes.io/name=continuityops-lab --tail=80 | \
  grep -iE 'upstream|timeout|503' || true
```

## Timeline (example)

| Time (UTC) | Event |
| --- | --- |
| T+0 | Alert: p99 latency > SLO 15m |
| T+3 | IC opens SEV-2; hypothesis: app overload |
| T+7 | `top` shows low CPU; in-cluster smoke fast |
| T+12 | Upstream curl times out from pod |
| T+18 | Upstream owner engaged; lab app scaling cancelled |
| T+35 | Upstream restored; latency normalizes |
| T+45 | Incident resolved after verification |

## Ruled-out causes

- Lab Deployment crash or CrashLoop (pods Running/Ready)
- In-cluster DNS failure (`nslookup kubernetes.default` succeeds)
- NetworkPolicy blocking DNS (only HTTPS upstream affected)
- Bad lab release (no deploy in window; `/version` unchanged)
- Ingress total failure (in-cluster Service path still fast for local handlers)

## Root cause

Staging upstream dependency experienced elevated latency and timeout errors.
ContinuityOps lab app propagated timeouts to clients on `/api/smoke` and related
paths. Monitoring attributed delay to the lab service because traces terminated
at the app span without a separate upstream dependency segment.

## Recovery choice

**Chosen:** Do not scale lab replicas (would not fix upstream). Coordinate with
upstream owner; temporarily reduce outbound call timeout budget only after IC
approval; enable cached/fallback response if contract allows.

**Not chosen:** Horizontal scale lab Deployment — wastes resources, masks signal.

## Verification

- Upstream `/healthz` < 500 ms from app pod for 10 consecutive checks
- Lab `/api/smoke` p99 within SLO for 30 minutes
- No new `upstream timeout` log lines in 15-minute window
- Run `app-smoke.md` in-cluster and via ingress

## User impact draft

```text
Subject: Elevated errors on ContinuityOps lab API

Some requests to lab API endpoints that depend on external staging services
experienced slow responses or temporary failures between {start} and {end} UTC.
Core health endpoints remained available. No data loss occurred. Impact was
limited to lab/staging synthetic workloads.
```

## Follow-up

- Add upstream dependency span and alert on outbound error rate (S4)
- Document upstream owner contact in incident runbook
- Tabletop: practice "scale vs upstream" decision in first 10 minutes
- Update drill if allowlist CIDR or hostname changes
