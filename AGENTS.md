# AWS Landing Zone Lab — agent notes

- Prefer the repo `.cursor/environment.json` image (PowerShell, Node 24, Terraform 1.15.5, AWS CLI, Docker) when present.
- **Landing Zone lab AWS apply** uses **GitHub OIDC → Terraform CI**
  (`.github/workflows/landing-zone-lab.yml`, role `project-a-lzlab-gha` from
  `platform/sandbox/landing-zone-lab/ci-bootstrap/`). Cloud Agents edit
  Terraform/PRs; they do **not** hold apply creds for this lab.
  `NoCredentials` in Cloud Agent pods is expected. Do **not** chase
  `CURSOR_AWS_ASSUME_IAM_ROLE_ARN` for the lab goal.
- After renaming this GitHub repository from `cloud` to `aws-landing-zone-lab`,
  an operator must re-apply `ci-bootstrap` so the IAM OIDC trust matches the
  new repository name (see `platform/sandbox/landing-zone-lab/ci-bootstrap/README.md`).
- The Ralphy smoke harness is a **sibling** repo:
  https://github.com/nathanielecon/ralphy-windows-harness — do not reintroduce
  sequential harness runners into this tree.
