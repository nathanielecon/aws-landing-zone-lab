# FinOps — recovery-lab cost model and controls

Decision record for ContinuityOps lab spending, alerts, right-sizing, and idle
resource detection. All dollar amounts are **synthetic estimates** for planning;
replace with Cost Explorer exports after account linkage.

## Principles

- Lab environments exist for drills, not sustained production load
- Cost anomalies trigger investigation before automatic teardown
- Right-size from measured utilization, not default instance catalogs
- No payer account credentials or CUR exports with secrets in Git

## Cost model (monthly, synthetic)

Estimates assume `recovery-lab` defaults from
`terraform/environments/recovery-lab/variables.tf` (single `t3.medium` node,
NAT disabled, one Lambda, SQS, minimal log retention).

| Service | Unit assumption | Synthetic USD/month | Driver |
| --- | --- | --- | --- |
| EKS control plane | 1 cluster | 73.00 | Per-cluster hourly fee |
| EC2 (EKS nodes) | 1 × `t3.medium` on-demand | 30.00 | 730 h × ~$0.0416 |
| NAT gateway | Disabled | 0.00 | `enable_nat_gateway = false` |
| Lambda | 1M invocations, 128 MB, 200 ms avg | 4.50 | Drill traffic only |
| SQS | 5M requests | 2.00 | Standard queue API |
| CloudWatch Logs | 5 GB ingest, 7-day retention | 3.50 | Observability module default |
| CloudWatch Alarms | 3 alarms | 0.90 | Baseline error + queue alarms |
| Data transfer | Minimal in-VPC | 1.00 | Synthetic buffer |
| **Total** | | **~115 USD/month** | Lab steady-state |

Staging composition may run concurrently; budget alerts use separate tags
(`Environment=staging` vs `Environment=recovery-lab`).

## Budget alert

| Field | Lab value |
| --- | --- |
| Monthly budget | 150 USD (recovery-lab tag) |
| Alert threshold 1 | 80% forecasted — email FinOps alias |
| Alert threshold 2 | 100% actual — page platform on-call |
| Alert threshold 3 | 120% actual — open teardown review (`CH-teardown.md`) |
| Granularity | Service + `Environment` tag |
| Tooling | AWS Budgets (configured outside repo) |

Budget notifications must not include account root email passwords or API keys.
Use SNS topic subscribed to team alias only.

## Right-sizing

### EKS nodes

| Check | Action |
| --- | --- |
| Avg node CPU < 30% for 14d | Consider smaller instance (`t3.small`) or fewer nodes |
| Avg node CPU > 70% for 7d | Scale node group or tune workload requests first |
| Memory pressure events | Increase pod memory requests before adding nodes |

Document changes in a change record and re-run `load-scenario.md`.

### Lambda worker

| Check | Action |
| --- | --- |
| Duration p99 ≪ timeout | Lower timeout to reduce stuck invocation cost |
| Memory maxed with high duration | Increase memory (CPU scales) only after profiling |
| Idle 30d (zero invocations) | Disable event source mapping in idle lab |

### Kubernetes pods

Align with `bottleneck-before-after.md` methodology:

1. Inspect throttling and HPA behavior under load
2. Adjust requests/limits before replica count
3. Record synthetic or measured before/after in performance results JSON

## Idle detection

Automatic **candidates** for teardown or scale-to-zero (human approval required):

| Resource | Idle signal | Lookback | Suggested action |
| --- | --- | --- | --- |
| EKS node group | No running user pods (system only) | 7 days | Scale desired size to 0 |
| Lambda | Zero invocations | 30 days | Disable event source mapping |
| SQS primary | Zero messages sent/received | 14 days | Flag for queue review |
| NAT gateway | If ever enabled: < 1 GB processed | 7 days | Disable NAT; use VPC endpoints |
| CloudWatch Logs | No ingest | 30 days | Lower retention to minimum |

Idle detection outputs a weekly synthetic report schema (future automation).
Until wired, operators run manual checks and log decisions in
`evidence/slices/S7-resilience.md`.

### Idle report fields (synthetic template)

```json
{
  "report_date": "2026-07-15",
  "environment": "recovery-lab",
  "synthetic_data_label": true,
  "idle_candidates": [
    {
      "resource_type": "eks_node_group",
      "resource_name": "continuityops-recovery-eks-nodes",
      "idle_days": 9,
      "recommended_action": "scale_to_zero",
      "estimated_monthly_savings_usd": 30.0
    }
  ],
  "notes": "Synthetic template — replace with Cost Explorer + CloudWatch metrics export."
}
```

## Tagging requirements

All lab resources must carry Terraform default tags:

- `Project=continuityops`
- `Environment=recovery-lab` or `staging`
- `ManagedBy=terraform`
- `Purpose=destructive-drill-synthetic-data` (recovery-lab)

Untagged resources are out of budget scope and flagged in monthly review.

## Review cadence

| Activity | Frequency |
| --- | --- |
| Budget vs actual | Weekly |
| Right-sizing review | Monthly |
| Idle candidate sweep | Weekly |
| FinOps decision record update | Quarterly or after major module change |

## Related documents

- `operations/changes/CH-teardown.md` — teardown after idle escalation
- `tests/performance/bottleneck-before-after.md` — workload right-sizing example
- `terraform/environments/recovery-lab/variables.tf` — default sizing knobs
