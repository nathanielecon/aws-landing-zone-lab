# ContinuityOps CI bootstrap (GitHub OIDC)

One-time root in account `<AWS_ACCOUNT_ID>`. Creates IAM role `continuityops-gha`
trusted by GitHub Actions via the existing OIDC provider
(`token.actions.githubusercontent.com`).

**Control plane:** Cloud Agents edit `continuityops/`; live AWS is
**GHA OIDC → `continuityops-gha`**, not CursorCloudAgent (BF-2026-010).

Trust uses immutable subject claims (post–2026-07-15 renames):
`repo:nathanielecon@177059064/*@1296742987:...`

## Apply once (AWS CloudShell / break-glass)

```bash
bash continuityops/terraform/ci-bootstrap/bootstrap-oidc-cloudshell.sh
# or:
cd continuityops/terraform/ci-bootstrap
terraform init -backend=false -input=false
terraform apply -input=false -auto-approve
terraform output gha_role_arn
```

Then dispatch **ContinuityOps Terraform** → `plan` on this repo.

## Do not

- Chase `CURSOR_AWS_ASSUME_IAM_ROLE_ARN` / CursorCloudAgent for ContinuityOps apply
- Reuse `project-a-lzlab-gha` for ContinuityOps roots
- Put long-lived access keys in Cloud secrets
