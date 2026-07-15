# Workflow sources for ContinuityOps

GitHub Actions only loads workflows from the repository root
`.github/workflows/`. ContinuityOps workflows are therefore published at:

| Purpose | Repo-root path |
|---------|----------------|
| Validate (offline contract) | `.github/workflows/continuityops-validate.yml` |
| Plan/apply (draft — promote when OIDC is wired) | See `continuityops-plan.draft.yml` in this directory |

## Draft vs published

Files in `continuityops/.github/workflows/` are **drafts** owned by the
ContinuityOps partition. Copy or adapt them to the repo root when OIDC roles
and backend placeholders are approved. Do not store secrets or account IDs in
drafts — use `REPLACE_ME` variables and GitHub environment configuration.

## Stage 1 delivery

- `continuityops-plan.draft.yml` — plan-only Terraform for staging/recovery-lab
  using GitHub OIDC `role-to-assume` placeholders.
- Apply jobs remain blocked until human approval and backend bootstrap complete.
