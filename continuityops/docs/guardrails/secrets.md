# Secrets guardrails (ContinuityOps lab)

Rules for handling credentials, tokens, and sensitive configuration in
ContinuityOps operations and agentic workflows.

## Never in repository or chat

- API keys, passwords, private keys, session tokens
- `.env` files with live values
- Terraform `tfvars` with secrets (use CI secrets manager or SSM parameters)
- Kubernetes `Secret` manifests with plaintext data in git

## Approved patterns

| Need | Pattern |
| --- | --- |
| App runtime secret | AWS Secrets Manager or SSM Parameter Store; IRSA for fetch |
| CI deploy | GitHub Actions encrypted secrets / OIDC — no stored AWS keys |
| Rotation | Automated rotation where supported; manual rotation via runbook + H4 |
| Local debug | SSO short-lived credentials; never commit output |

## Agentic rules

Aligned with `agentic/policies/prompt-safety.md`:

- **PS-SEC-01 / PS-SEC-02**: Reject proposals that request, echo, or embed secrets.
- Workers must direct operators to break-glass audited paths instead of chat paste.
- Evidence bundles redact secret-like strings before attachment.

## Detection hints

Automated scans and `Test-UnsafeProposals.ps1` flag:

- `api key`, `password`, `private key`, `AWS_SECRET`, `paste token`, `.env`
- Base64 blobs in proposals without provenance
- Commands that dump secret stores to stdout

## Incident response

If a secret is exposed:

1. Revoke/rotate immediately (operator action, not agent auto-exec).
2. Scrub logs/chat exports per retention policy.
3. Record timeline in incident evidence; no secret values in postmortem body.

## Lab boundary

Examples use placeholders only (`REDACTED`, `changeme` as negative-test fixtures).
No live credentials belong in `continuityops/`.
