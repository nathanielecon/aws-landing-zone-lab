# Integration validation notes

These tests prove the `project-a` root remains a non-deploying composition shell
while offline validation still works. They do not provision cloud resources or
replace separate environment approval.

## Composition contract

The root `project-a` directory is an orchestration shell only. Composition
consistency means these interfaces stay present and aligned without a live
provider:

| Surface | Required offline contract |
| --- | --- |
| Identity module | `terraform/identity/{main,outputs,README}.tf` / `.md`; `audit_bucket_name` input; `workload_role_name` output |
| Network module | `terraform/network/{main,outputs,README}`; `flow_logs_destination_arn` input; `private_subnet_count` output |
| Audit module | `terraform/audit/{main,outputs,README}`; `aws_cloudtrail.audit`; `archive_bucket_name` / `cloudtrail_arn` outputs |
| Environments | Distinct `backend_key` and `audit_prefix` per env; shared `network_boundary = "private-only"`; matching outputs |

`root_composition.tftest.hcl` asserts those paths and locals/outputs contracts
with `fileexists` / content checks during `terraform test` (no AWS credentials).

## Minimal executable check

From `project-a/` (or via `scripts/validate-project-a.ps1`):

```bash
terraform init -backend=false -input=false
terraform test -no-color -test-directory=tests/integration
```

Expect all `root_composition` runs to pass. Failure means a module entry,
environment locals/outputs contract, or identity/network/audit interface was
removed or drifted—not that cloud resources changed.
