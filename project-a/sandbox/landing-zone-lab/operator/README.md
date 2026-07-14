# Non-root operator IAM

Creates `project-a-lzlab-operator` IAM user + assumable role with lab-scoped
permissions. Deny attached for Organizations member-account creation so this
single-account lab cannot silently expand into Orgs apply.

Cloud Agents apply this stack with the Cursor-injected
`cursor-cloud-agent` profile (`CURSOR_AWS_ASSUME_IAM_ROLE_ARN` →
`arn:aws:iam::283077380808:role/CursorCloudAgent`). Do **not** create
long-lived access keys and do **not** use `aws login` / `code.txt`.

## Apply

```bash
export AWS_REGION=us-east-1
# AWS_PROFILE=cursor-cloud-agent when that profile is injected
terraform init -backend=false -input=false
terraform apply -input=false -auto-approve
aws sts get-caller-identity   # must not be account root
```

Prefer `../apply-lab.sh` for the full operator → state → lab sequence.
