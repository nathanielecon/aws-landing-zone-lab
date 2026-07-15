# Collapsed Landing Zone lab composition

Composes `identity` + `network` + `audit` in the single live account. No
cross-account providers. No organization module apply.

## Apply

```bash
export AWS_PROFILE=lzlab-operator
export AWS_REGION=us-east-1
# backend.hcl produced by ../state-bootstrap
terraform init -backend-config=backend.hcl -input=false
terraform apply -input=false -auto-approve
```

## Offline validate (no credentials / local backend)

```bash
terraform init -backend=false -input=false
terraform validate
```
