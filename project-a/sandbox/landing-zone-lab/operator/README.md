# Non-root operator IAM

Creates `project-a-lzlab-operator` IAM user + assumable role with lab-scoped
permissions. Deny attached for Organizations member-account creation so this
single-account lab cannot silently expand into Orgs apply.

## Apply (bootstrap identity — temporary root/admin OK once)

```bash
export AWS_REGION=us-east-1
terraform init -backend=false -input=false
terraform apply -input=false -auto-approve
terraform output -json > /tmp/lzlab-operator-outputs.json   # keep untracked
```

Then configure the operator profile and **stop using root** for subsequent
lab/state applies:

```bash
aws configure set aws_access_key_id "$(jq -r .operator_access_key_id.value /tmp/lzlab-operator-outputs.json)" --profile lzlab-operator
aws configure set aws_secret_access_key "$(jq -r .operator_secret_access_key.value /tmp/lzlab-operator-outputs.json)" --profile lzlab-operator
aws configure set region us-east-1 --profile lzlab-operator
export AWS_PROFILE=lzlab-operator
aws sts get-caller-identity
```
