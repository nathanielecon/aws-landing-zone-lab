# Non-root operator IAM

Creates `project-a-lzlab-operator` IAM user + assumable role with lab-scoped
permissions. Deny attached for Organizations member-account creation so this
single-account lab cannot silently expand into Orgs apply.

**Primary apply path for the Landing Zone lab is GitHub OIDC →
`project-a-lzlab-gha`** (see `../ci-bootstrap/` and
`.github/workflows/landing-zone-lab.yml`). Cloud Agents edit Terraform/PRs;
they do **not** hold lab apply creds. Do **not** chase
`CURSOR_AWS_ASSUME_IAM_ROLE_ARN` for this lab. Do **not** create long-lived
access keys and do **not** use `aws login` / `code.txt`.

Break-glass local apply (non-root operator / one-time bootstrap only) may use
an injected profile when present; that is not the scored control plane.

## Apply

```bash
export AWS_REGION=us-east-1
# optional break-glass profile only; preferred path is GHA OIDC
terraform init -backend=false -input=false
terraform apply -input=false -auto-approve
aws sts get-caller-identity   # must not be account root
```

Prefer `../apply-lab.sh` for the full operator → state → lab sequence.
