# AWS Landing Zone Lab — agent notes

- Prefer the repo `.cursor/environment.json` image (PowerShell, Node 24, Terraform 1.15.5, AWS CLI, Docker) when present.
- **Landing Zone lab AWS apply** uses **GitHub OIDC → Terraform CI**
  (`.github/workflows/landing-zone-lab.yml`, role `project-a-lzlab-gha` from
  `platform/sandbox/landing-zone-lab/ci-bootstrap/`). Cloud Agents edit
  Terraform/PRs; they do **not** hold apply creds for this lab.
- **`NoCredentials` in Cloud Agent pods is expected** on Pro+ without a team
  External ID. `CURSOR_AWS_ASSUME_IAM_ROLE_ARN` / `CursorCloudAgent` may be
  present as a secret while **never assumed** (no injected
  `AWS_PROFILE=cursor-cloud-agent`). Do **not** block on finishing Cursor STS
  for the lab goal. Escalate live AWS to GHA OIDC or a local `aws login`
  bottleneck; continue repo-only in the Cloud seat.
- Proven apply path (repo renamed; use current name):

  ```bash
  gh workflow run landing-zone-lab.yml --repo nathanielecon/aws-landing-zone-lab -f action=plan
  # after plan OK:
  gh workflow run landing-zone-lab.yml --repo nathanielecon/aws-landing-zone-lab -f action=apply
  ```

  Needs `id-token: write` (in workflow) + role default / var
  `arn:aws:iam::283077380808:role/project-a-lzlab-gha`. After GitHub renames
  (2026-07-15+), OIDC trust must use **immutable** `sub`
  (`repo:OWNER@OWNER_ID/REPO@REPO_ID:...`) — see
  `ci-bootstrap/fix-oidc-trust-cloudshell.sh` and `BREAK_FIX_LOG.md`.
- Do **not** put long-lived access keys or root session tokens in Cloud
  secrets. That is not the lab fix path.
- The Ralphy smoke harness is a **sibling** repo:
  https://github.com/nathanielecon/ralphy-windows-harness — do not reintroduce
  sequential harness runners into this tree.

## Paste for stuck agents (BF-2026-010 / NoCredentials)

```text
NoCredentials is expected on Pro+ without team External ID. CursorCloudAgent has never been assumed.
Prior fix (2026-07-14/15): GitHub OIDC → project-a-lzlab-gha via landing-zone-lab.yml, or local aws login bottleneck.
Do not block on CURSOR_AWS_ASSUME_IAM_ROLE_ARN. Escalate live AWS to GHA or local; continue repo-only here.
```
