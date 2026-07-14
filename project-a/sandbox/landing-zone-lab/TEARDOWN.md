# Landing Zone lab — teardown and cost notes

Status: runbook only. This file does **not** claim a teardown was performed
in this Cloud Agent pod.

## Cost drivers (order-of-magnitude, interview-sized)

| Driver | Why it costs | Notes |
| --- | --- | --- |
| CloudTrail + S3 archive | Multi-region trail + SSE-KMS storage | Dominant ongoing cost for a quiet lab |
| VPC Flow Logs → archive | Continuous log delivery | Scale with traffic; lab is low |
| AWS Config recorder | Configuration items + delivery | One recorder per account/region |
| KMS | Key + request charges | Shared with trail/archive/state |
| NAT / public edge | **Not** in this baseline | Private-only lab |

## One-time bootstrap posture

- Preferred ongoing apply identity: GitHub OIDC → `project-a-lzlab-gha`
  (non-root), evidenced by apply run `29366105164`.
- Root / break-glass may be used **at most** for one-time `ci-bootstrap/` and
  `state-bootstrap/`. Subsequent plan/apply evidence must be non-root GHA OIDC.
- Cloud Agents do **not** hold lab apply creds (`NoCredentials` expected).

## Teardown order (manual / CI `workflow_dispatch` destroy when authorized)

1. Confirm non-root caller (`project-a-lzlab-gha` or operator) — never root for
   routine destroy.
2. `lab/` destroy (identity + network + audit composition) with remote state.
3. Empty/version-clean archive + tfstate buckets if `force_destroy` is false.
4. `state-bootstrap/` destroy only after lab state is gone.
5. `ci-bootstrap/` / OIDC provider last (breaks CI apply path).
6. `operator/` IAM last if no longer needed.

Record the destroy run URL and caller ARN in EVIDENCE if/when executed.
