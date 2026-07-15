# Operator: finish GitHub rename + harness repo create

This cloud agent token can **push** to `nathanielecon/cloud` but cannot
**create** or **rename** repositories (GitHub App 403). Complete these steps
with an account that has admin on `nathanielecon/*`.

## 1. Merge the split PR into `main` on `cloud`

Ensure `platform/` layout and harness strip are on `main`.

## 2. Create the harness repo and push the export branch

The harness tree is published as orphan branch
`export/ralphy-windows-harness` on this repo (and also prepared under
`/tmp/ralphy-windows-harness` during the agent run).

```bash
# From a machine with admin gh auth:
gh repo create nathanielecon/ralphy-windows-harness --public \
  --description "Native-Windows Codex-first Ralphy smoke harness (sequential loop)"

git clone https://github.com/nathanielecon/cloud.git /tmp/cloud-split
cd /tmp/cloud-split
git fetch origin export/ralphy-windows-harness
git checkout export/ralphy-windows-harness
git remote add harness https://github.com/nathanielecon/ralphy-windows-harness.git
git push -u harness HEAD:main
```

Alternatively, if you still have `/tmp/ralphy-windows-harness` from the agent:

```bash
cd /tmp/ralphy-windows-harness
git remote set-url origin https://github.com/nathanielecon/ralphy-windows-harness.git
git push -u origin main
```

## 3. Rename `cloud` → `aws-landing-zone-lab`

```bash
gh repo rename aws-landing-zone-lab --repo nathanielecon/cloud --yes
```

GitHub redirects `nathanielecon/cloud` URLs after rename.

## 4. Re-apply OIDC trust (required)

```powershell
cd platform/sandbox/landing-zone-lab/ci-bootstrap
terraform init -backend=false -input=false
terraform apply -input=false -auto-approve -var="github_repository=aws-landing-zone-lab"
```

See [`platform/sandbox/landing-zone-lab/ci-bootstrap/README.md`](platform/sandbox/landing-zone-lab/ci-bootstrap/README.md).
