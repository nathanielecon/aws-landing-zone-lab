# Offline terraform validate (lab + modules)

No AWS credentials required (`init -backend=false`).

## Roots

| Root | Command | Result (2026-07-14) |
| --- | --- | --- |
| `lab/` | `terraform init -backend=false -input=false` then `terraform validate` | Success! The configuration is valid. |
| `operator/` | same | Success! The configuration is valid. |
| `state-bootstrap/` | same | Success! The configuration is valid. |
| `ci-bootstrap/` | same | Success! The configuration is valid. |
| `project-a/terraform/identity/` | same | Success! The configuration is valid. |
| `project-a/terraform/network/` | same | Success! The configuration is valid. |
| `project-a/terraform/audit/` | same | Success! The configuration is valid. |

Durable CI signal: workflow `.github/workflows/landing-zone-lab.yml` job
`plan` runs `plan-lab.sh` on PRs touching those paths.

Re-run the table commands (with an isolated `TF_DATA_DIR` per root) to refresh
this record after Terraform edits.
