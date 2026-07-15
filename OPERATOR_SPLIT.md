# Operator split status

## Completed

- Created [`nathanielecon/ralphy-windows-harness`](https://github.com/nathanielecon/ralphy-windows-harness) and pushed smoke harness `main`.
- Renamed [`nathanielecon/cloud`](https://github.com/nathanielecon/cloud) → [`nathanielecon/aws-landing-zone-lab`](https://github.com/nathanielecon/aws-landing-zone-lab) (GitHub redirects old URLs).

Note: `harness-contracts.yml` was deferred on the harness repo because the OAuth token lacked `workflow` scope. Re-add from branch `export/ralphy-windows-harness` on this repo (or from local history) after authorizing `workflow` scope, if you want CI on the harness.

## Still required (AWS)

Re-apply OIDC trust so Actions from the renamed repo can assume `project-a-lzlab-gha`:

```powershell
cd platform/sandbox/landing-zone-lab/ci-bootstrap
terraform init -backend=false -input=false
terraform apply -input=false -auto-approve -var="github_repository=aws-landing-zone-lab"
```

See [`platform/sandbox/landing-zone-lab/ci-bootstrap/README.md`](platform/sandbox/landing-zone-lab/ci-bootstrap/README.md).
