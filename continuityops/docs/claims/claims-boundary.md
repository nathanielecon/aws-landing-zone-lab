# ContinuityOps claims boundary

## Supported claims (after Stage 1 scaffold + local tests)

- ContinuityOps is an independent lab project under `continuityops/`
- Terraform modules and staging/recovery-lab compositions exist and are
  structured for offline validate
- Helm chart renders with digest pin, non-root security context, HPA/PDB/NetworkPolicy
- Serverless worker implements idempotency + poison/DLQ handling with unit tests
- Observability catalogs (OTel, dashboards, alerts, SLOs) are defined
- Eight incident drills and runbooks with stop/escalation cautions exist
- Agentic workflow rejects unsafe proposals by policy test
- RTO/RPO, restore, load, FinOps, and teardown procedures are documented
  (synthetic baselines labeled as such)

## Not claimed

- Live EKS/Lambda apply in a customer production account from this agent session
- Multi-account Landing Zone ownership (Project A design remains separate)
- Project C production image provenance
- 24/7 SRE ownership or enterprise tenure
- Azure networking depth
- That synthetic load numbers are live production measurements
