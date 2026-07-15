# Runbook: process and logs in container

Diagnose CrashLoopBackOff, OOMKilled, silent exits, and high restart counts
without mutating the workload first.

## Scope

Lab deployment `continuityops-lab` in namespace `continuityops-lab`. Applies to
any containerized ContinuityOps app process listening on port 8080.

## Do not do this yet

- **Do not** edit the live Deployment image or command until you have logs from
  the **previous** crashed container (`--previous`).
- **Do not** `kubectl exec` into a pod that is not `Running` — use `logs` and
  `describe` instead.
- **Do not** disable probes as a first fix — masks readiness failures and keeps
  bad replicas in rotation.
- **Do not** increase memory limits without checking for leaks or traffic spikes;
  document emergency bumps in a change record.

## First-five-minute checks

1. Pod phase and restart count (`kubectl get pods`).
2. Last termination reason (`OOMKilled`, `Error`, `Completed`).
3. Events on the pod (image pull, mount, probe failures).
4. Whether failure started after a Helm upgrade or ConfigMap change.
5. Compare current vs previous container logs for the same error signature.

## Commands

```bash
POD=$(kubectl -n continuityops-lab get pod \
  -l app.kubernetes.io/name=continuityops-lab \
  -o jsonpath='{.items[0].metadata.name}')

# State and probes
kubectl -n continuityops-lab describe pod "$POD" | sed -n '/Containers:/,/Conditions:/p'

# Current and previous logs
kubectl -n continuityops-lab logs "$POD" --tail=100
kubectl -n continuityops-lab logs "$POD" --previous --tail=100 2>/dev/null || true

# Resource pressure
kubectl -n continuityops-lab top pod "$POD" 2>/dev/null || true
kubectl -n continuityops-lab get pod "$POD" -o jsonpath='{.status.containerStatuses[0].lastState}'

# Config and mounts (names only)
kubectl -n continuityops-lab get deploy continuityops-lab -o yaml | \
  grep -E 'configMap|secret|env:|image:' | head -40
```

## Process inspection (when pod is Running)

```bash
kubectl -n continuityops-lab exec "$POD" -- ps aux
kubectl -n continuityops-lab exec "$POD" -- wget -qO- http://127.0.0.1:8080/healthz
kubectl -n continuityops-lab exec "$POD" -- wget -qO- http://127.0.0.1:8080/readyz
```

## Interpretation

| Pattern | Likely cause |
| --- | --- |
| `OOMKilled` | Memory limit too low or leak; check `top` and HPA |
| Exit code 1 immediately | Bad command, missing env, failed migration |
| Probe failures only | Wrong path, slow startup — check `startupProbe` |
| `CreateContainerConfigError` | Missing Secret key (`API_TOKEN` placeholder) |

## Stop / escalation

**Stop** and escalate when:

- Same crash signature on all replicas after rollback attempt
- Logs show panic in shared library — may need coordinated release (SEV-2)
- Suspected compromise (unexpected process, shell in container)
- Cannot obtain logs (`--previous` empty and no events) — node or runtime issue

Escalate to S2 owner with pod name, termination reason, last 50 log lines
(redacted), and Helm revision.

## Recovery pointers

- Config/Secret mismatch → fix ConfigMap/Secret, rollout restart
- Bad image → `helm rollback` (see drill `bad-release-rollback.md`)
- Probe too aggressive → adjust chart values via change record, not live patch in prod

Verify with `app-smoke.md` after pods reach Ready.
