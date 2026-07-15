# Runbook: kubectl first five minutes

Cluster triage for any Kubernetes incident in ContinuityOps lab/staging. Read
this before patching, scaling, or deleting workloads.

## Scope

- Namespace default: `continuityops-lab`
- Chart label: `app.kubernetes.io/name=continuityops-lab`
- Pair with slice owner (S2) for chart or cluster changes

## Do not do this yet

- **Do not** `kubectl delete pod --all` or force-delete nodes — masks state and
  can worsen PDB violations.
- **Do not** `helm upgrade` or edit Deployments until you have pod events, recent
  deploy revision, and error rate from the last 15 minutes.
- **Do not** scale replicas to zero without IC approval — removes capacity during
  active customer traffic (staging).
- **Do not** paste Secret values into tickets or chat; reference Secret names only.

## First-five-minute checks

1. Confirm alert/dashboard matches user reports (not a single stale panel).
2. Identify blast radius: one pod, one AZ, all replicas, ingress only.
3. Note last deploy/Helm revision and any change record in the last 2 hours.
4. Check control plane reachability (`kubectl cluster-info`, API latency).
5. Assign roles: IC, technical lead, scribe (see severity model).

## Commands

```bash
# Context and namespace
kubectl config current-context
kubectl get ns continuityops-lab

# Workload health
kubectl -n continuityops-lab get deploy,sts,ds,pods -o wide
kubectl -n continuityops-lab get events --sort-by=.lastTimestamp | tail -30

# Recent rollout
kubectl -n continuityops-lab rollout history deployment/continuityops-lab
helm -n continuityops-lab history continuityops-lab 2>/dev/null || true

# Endpoints and services
kubectl -n continuityops-lab get svc,endpoints
kubectl -n continuityops-lab get ingress 2>/dev/null || true

# Quick probe from cluster
kubectl -n continuityops-lab run curl-first5 --rm -it --restart=Never \
  --image=curlimages/curl:8.5.0 -- \
  curl -sS -o /dev/null -w "%{http_code}\n" \
  http://continuityops-lab:8080/healthz
```

## Interpretation

| Signal | Likely direction |
| --- | --- |
| `CrashLoopBackOff` | Entrypoint, config, or probe path — see `process-logs-in-container.md` |
| Running, not Ready | Readiness probe or dependency — check `/readyz` |
| All pods Pending | Scheduling, quota, or image pull |
| Endpoints empty | No ready backends — ingress/LB will 503 |
| Events: `FailedMount` | Secret/ConfigMap missing or wrong key |

## Stop / escalation

**Stop triage and escalate** when:

- Multiple namespaces or node pools affected (possible control plane or CNI issue)
- `kubectl` commands hang or return 5xx from API server for > 2 minutes
- Suspected data loss, security breach, or cross-tenant impact
- No mitigation path after 30 minutes on SEV-1 or 60 minutes on SEV-2

Escalation: primary on-call → secondary → S2 Kubernetes owner → engineering
manager. Open `incidents/TEMPLATE.md` and page per `severity-model.md`.

## After triage

Route to specialized runbooks:

- DNS / TLS → `dns-tls-checks.md`
- LB / ingress → `lb-target-health.md`
- NetworkPolicy → `security-boundary-checks.md`
- Recovery validation → `app-smoke.md`
