# CI bootstrap (GitHub OIDC)

One-time root in this account. Creates:

- IAM OIDC provider for `token.actions.githubusercontent.com`
- IAM role `project-a-lzlab-gha` for GitHub Actions plan/apply

Default trust pins GitHub **`repository_id=1296742987`** (this repo) and
**`repository_owner_id=177059064`** (`nathanielecon`), with `sub` patterns
`repo:nathanielecon/*:(main|pull_request|cursor/*|environment:lab)` so a GitHub
rename does not brick OIDC. Live AWS resource name prefixes such as
`project-a-lzlab-*` are unchanged.

## Apply once (local break-glass)

```powershell
cd platform/sandbox/landing-zone-lab/ci-bootstrap
terraform init -backend=false -input=false
terraform apply -input=false -auto-approve
terraform output gha_role_arn
```

Then set the repo variable `AWS_ROLE_ARN_LZ_LAB` to that ARN (or rely on the
workflow default if it matches).

## After renaming GitHub (OIDC outage)

If Actions fails at **Configure AWS credentials (OIDC)** after a rename,
self-heal from GHA cannot run (needs the role). Fix in **AWS CloudShell**
(Linux paths — do not use `C:\...`), account `283077380808`:

```bash
# No clone needed — paste in CloudShell:
curl -fsSL https://raw.githubusercontent.com/nathanielecon/aws-landing-zone-lab/cursor/oidc-trust-recovery-d314/platform/sandbox/landing-zone-lab/ci-bootstrap/fix-oidc-trust-cloudshell.sh | bash
```

Or from a repo checkout of this branch:

```bash
bash platform/sandbox/landing-zone-lab/ci-bootstrap/fix-oidc-trust-cloudshell.sh
# or: terraform apply in this directory (same trust shape)
```

Then dispatch **Landing Zone lab (Terraform)** → `plan` and confirm the OIDC
step is green. Cloud Agents do **not** hold apply credentials for this step.

The lab root **reads** this OIDC provider via a data source; it does not create
a second one.
