# Lab remote-state bootstrap

Creates a versioned, KMS-encrypted, publicly blocked S3 bucket for the
`landing-zone-lab/lab` root. Uses native S3 lockfiles (`use_lockfile = true`).

Apply with the non-root operator after `../operator` exists:

```bash
export AWS_PROFILE=lzlab-operator
export AWS_REGION=us-east-1
terraform init -backend=false -input=false
terraform apply -input=false -auto-approve
terraform output -raw backend_hcl > ../lab/backend.hcl
```
