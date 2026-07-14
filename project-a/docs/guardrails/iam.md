# IAM guardrails

IAM roles grant permissions; SCPs and permission boundaries only cap them. The
identity module uses a least-privilege workload policy limited to audit-object
writes and a matching permission boundary. The trust policy requires the GitHub
Actions audience and an exact repository plus protected-branch subject.

No human IAM user, account ID, or credential is stored here. The OIDC provider
account portion is an explicit placeholder to be approved and supplied in a
separately controlled deployment.

## Break-glass access

Break-glass is an emergency-only, separately controlled role. It must require
MFA, short-lived sessions, named approvers, CloudTrail review, and a documented
incident ticket. It is not created by this module and has no standing workload
trust. H2 must approve the designated principals, allowed actions, session
duration, escalation path, and revocation procedure before it exists.

The included `deny_root_user.json` policy is a guardrail template for a
separately reviewed attachment. It is a deny-only policy and does not grant any
access.

## Related

- [Blocked-change catalog](../operations/blocked-change-catalog.md) (BC-IAM-01–04,
  BC-ID-01)
- [Policy validation](policy-validation.md)
- [Identity module](../../terraform/identity/README.md)
- [IAM negative tests](../../tests/iam/README.md)
