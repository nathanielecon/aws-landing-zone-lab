# Supply chain guardrails (ContinuityOps lab)

Controls for dependencies, container images, and infrastructure modules consumed
by ContinuityOps.

## Container images

| Control | Requirement |
| --- | --- |
| Digest pinning | Deploy by immutable digest, not floating tags (`:latest` denied in policy) |
| Provenance | Build from known Dockerfile/CI job; record digest in release evidence |
| Base images | Prefer vendor-maintained minimal bases; track CVE cadence |
| Registry | Private ECR or trusted registry; no anonymous pulls in lab deploy paths |

Kubernetes policies under `kubernetes/policies/` enforce digest and non-root
constraints where chart values allow.

## Dependencies

| Layer | Practice |
| --- | --- |
| Node (serverless worker) | Lockfile committed; `npm audit` in CI |
| Terraform providers | `.terraform.lock.hcl` committed per environment |
| Helm charts | Pin chart version; review subchart transitive deps |

## CI integrity

- GitHub Actions workflows use pinned action SHAs or version tags where practical.
- OIDC federation for AWS — no long-lived CI keys in the repo.
- PR-required checks before merge to protected branches (product design; build
  may advance without human gate per D-COP-003).

## Agentic proposals

Reject or escalate proposals that:

- Pull unaudited container images or `curl | bash` installers
- Disable image signature or admission checks
- Introduce dependencies without lockfile or version pin
- Bypass `require-digest` / `deny-latest-tag` Kubernetes policies

## Evidence

Release and recovery drills should record:

- Image digest deployed
- Terraform provider lock checksums
- Helm chart `appVersion` / `version`

## Lab boundary

Supply-chain practices are demonstrated in the ContinuityOps lab portfolio; they
do not assert enterprise-wide SBOM or customer production attestation unless
backed by stored evidence artifacts.
