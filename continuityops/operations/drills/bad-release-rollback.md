# Drill: bad release rollback

**Type:** Lab inject (`crashloop-inject.sh` or bad image digest)  
**Misleading symptoms:** No  
**Environment:** `continuityops-lab`  
**Related runbooks:** `kubectl-first-five.md`, `process-logs-in-container.md`, `app-smoke.md`

## Scenario

Helm upgrade deploys a bad image digest or failing command. New ReplicaSet pods
enter `CrashLoopBackOff`; rolling update stalls or endpoints drain. Alert on
error rate and probe failures.

## Hypothesis

Regression in container entrypoint or image — rollback to previous Helm revision
restores health faster than forward fix during incident.

## First-five-minute checks

1. `helm history` / `rollout history` — identify last good revision.
2. Pod logs `--previous` for panic or exit 1.
3. Compare `/version` on surviving old pod vs failing new pod.
4. Confirm change record and deploy pipeline artifact digest.
5. Assess data migration risk — lab app is stateless; rollback is low risk.

## Commands

```bash
# Inject failure (lab)
cd continuityops/kubernetes/scenarios && ./crashloop-inject.sh

kubectl -n continuityops-lab get pods -l app.kubernetes.io/name=continuityops-lab
kubectl -n continuityops-lab rollout status deployment/continuityops-lab --timeout=30s || true

helm -n continuityops-lab history continuityops-lab
kubectl -n continuityops-lab rollout history deployment/continuityops-lab

POD=$(kubectl -n continuityops-lab get pod \
  -l app.kubernetes.io/name=continuityops-lab \
  -o jsonpath='{.items[?(@.status.containerStatuses[0].state.waiting.reason=="CrashLoopBackOff")].metadata.name}' | awk '{print $1}')
kubectl -n continuityops-lab logs "$POD" --previous --tail=40 2>/dev/null

# Rollback
helm -n continuityops-lab rollback continuityops-lab
# Or: cd continuityops/kubernetes/scenarios && ./crashloop-restore.sh

kubectl -n continuityops-lab rollout status deployment/continuityops-lab --timeout=120s
```

## Timeline (example)

| Time (UTC) | Event |
| --- | --- |
| T+0 | Pipeline deploys revision N |
| T+2 | CrashLoop on new pods |
| T+6 | IC declares SEV-2; rollback authorized |
| T+8 | `helm rollback` to N-1 |
| T+12 | All pods Ready |
| T+20 | Smoke green; incident mitigated |
| T+1440 | Forward fix deployed via normal change |

## Ruled-out causes

- Config/Secret mount (would show `CreateContainerConfigError`)
- Resource quota (pods Pending, not CrashLoop)
- NetworkPolicy (process starts then network fails — different log pattern)
- HPA scaling issue (replicas stable, process exits)

## Root cause

Drill inject replaced container command with `exit 1`. Production analog:
CI promoted image with failing health check or wrong architecture digest.

## Recovery choice

**Chosen:** `helm rollback` to last known-good revision; verify endpoints before
closing. Forward fix tracked in separate change after postmortem.

**Not chosen:** `kubectl patch` command inline in prod without revision record —
hard to audit.

## Verification

- `helm history` shows rollback revision deployed
- All pods Ready; endpoints match replica count
- `app-smoke.md` full pass; `/version` matches N-1 build
- Error rate normal 30 minutes

## User impact draft

```text
Subject: Service restored after deployment rollback

We detected errors following a lab deployment at {time} UTC and rolled back to
the previous release. The service is operating normally. We are investigating the
faulty release before re-deploying.
```

## Follow-up

- Canary or automated smoke gate before full rollout
- Pin immutable digest in values; reject `latest` (admission policy)
- Postmortem on why bad artifact passed CI
- Link rollback steps in deploy runbook
