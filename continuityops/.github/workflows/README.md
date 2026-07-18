# Workflow sources for ContinuityOps

GitHub Actions loads workflows from the repository root `.github/workflows/`.

| Purpose | Path |
|---------|------|
| Validate (offline) | `.github/workflows/continuityops-validate.yml` |
| Plan/apply (OIDC live) | `.github/workflows/continuityops-terraform.yml` |
| Draft retained | `continuityops/.github/workflows/continuityops-plan.draft.yml` |

## Live AWS

1. Operator CloudShell once:
   `bash continuityops/terraform/ci-bootstrap/bootstrap-oidc-cloudshell.sh`
2. Create GitHub Environment `continuityops` (for apply) if missing.
3. Dispatch **ContinuityOps Terraform** → plan, then apply.

Role: `arn:aws:iam::283077380808:role/continuityops-gha`  
Optional repo variable: `AWS_ROLE_ARN_CONTINUITYOPS`.
