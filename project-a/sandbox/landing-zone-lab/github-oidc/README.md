# GitHub OIDC bootstrap (one-time, local)

Creates the account GitHub Actions OIDC provider and IAM role
`GitHubActionsLZLab` trusted for `nathanielecon/cloud` (`main`,
`pull_request`, and environment `landing-zone-lab`).

This is the **primary** AWS control plane for the Landing Zone lab. Cloud Agent
`CURSOR_AWS_ASSUME_IAM_ROLE_ARN` is **not** used for this goal.

## One-time apply (local)

Requires a human AWS session (e.g. `aws login`) — not Cloud Agent assume-role:

```bash
export AWS_REGION=us-east-1
cd project-a/sandbox/landing-zone-lab/github-oidc
terraform init -backend=false -input=false
terraform apply -input=false -auto-approve
terraform output
```

Then set the GitHub repository variable (or confirm workflow default):

- Name: `AWS_LZLAB_ROLE_ARN`
- Value: `arn:aws:iam::283077380808:role/GitHubActionsLZLab`

Optionally create a GitHub Environment named `landing-zone-lab` with required
reviewers for apply jobs.

Next: apply [`../state-bootstrap`](../state-bootstrap/) once (same local
session), write `../lab/backend.hcl`, then let GitHub Actions plan/apply the
lab root.
