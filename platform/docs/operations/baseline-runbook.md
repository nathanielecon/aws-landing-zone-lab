# Baseline runbook

## Provisioning-style failures

If a Terraform module fails validation, first check whether the failure is in
bootstrap, organization, identity, network, or audit scope. Confirm the module
inputs, environment intent, and referenced documentation before editing code.
Do not switch to `terraform apply`, add provider credentials, or flatten the
module boundary from this repository.

## Access-style failures

If an access assumption fails, first check the documented IAM trust path, the
permission boundary, and whether the request belongs in nonproduction or
production. Access changes that cross account boundaries, expand principals, or
weaken archive controls require human review before any separate deployment.

## Missing audit or logging evidence

If CloudTrail, Config, or flow-log evidence is missing, first check the approved
Log Archive S3 destination, the KMS key reference, and the expected delivery
prefix. Missing evidence is an escalation signal; do not silence it by removing
logging, shortening retention, or changing destinations without approval.

## Stop conditions

Stop and escalate when a proposed fix would:

- introduce provider credentials or cloud login into the repo workflow,
- remove environment separation between nonproduction and production,
- bypass the Log Archive destination or KMS protection,
- add a root module that could destroy after validation or deploy from this repo,
- implement any row in the offline [blocked-change catalog](blocked-change-catalog.md)
  (TGW/NFW/NAT/VPN/DX/RAM, live Identity Center lifecycle, live audit deploy,
  root SCP attach, `close_on_deletion`, shared state keys, credential-shaped
  examples).
