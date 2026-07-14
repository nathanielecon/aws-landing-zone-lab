# Validation workflow

This repository supports offline validation only. Start with formatting, then
run root-level validation to prove there is no accidental deployment entry
point, then validate each Terraform module in isolation, and finally run the
integration tests that keep the composition shell intentionally non-deploying.

## Validation order

1. Run `terraform fmt -check -recursive project-a`.
2. Run `terraform -chdir=project-a init -backend=false -input=false -lockfile=readonly`.
3. Run `terraform -chdir=project-a validate -no-color`.
4. Run `terraform -chdir=project-a test -no-color`.
5. Run `terraform test -no-color -test-directory=project-a/tests/integration` from the
   repository root or use `project-a/scripts/validate-project-a.ps1`.

## What failures mean

- If provisioning assumptions fail, first check module inputs, expected account
  boundaries, and the intended environment before changing Terraform code.
- If access assumptions fail, first check IAM role trust, permission boundary
  links, and archive bucket ownership before widening permissions.
- If audit or logging evidence is missing, first check the Log Archive S3
  destination, CloudTrail trail name, Config recorder scope, and flow-log
  destination assumptions from earlier tasks.

Stop and escalate when the proposed fix would add live provider credentials,
introduce a deployable root module, collapse environment separation, or bypass
the approved validation order.

Replay blocked platform changes from the offline
[blocked-change catalog](operations/blocked-change-catalog.md) before widening
network, audit, Organizations, state-key, or credential-shaped examples.
