# Audit negative tests

`audit.tftest.hcl` stays offline with a mocked AWS provider. Real
`expect_failures` cover too-short retention, a public-ACL attempt
(`allow_public_archive_acls = true`), missing customer-managed KMS
(`require_customer_managed_kms = false`), an empty/invalid KMS alias,
disabled CloudTrail log-file validation
(`enable_log_file_validation = false`), disabled archive versioning
(`enable_archive_versioning = false`), and enabling an organization trail
(`is_organization_trail = true`, interface-only in this baseline). A separate
happy-path run asserts Log Archive public-access block and KMS SSE when inputs
are valid. It does not call live log services or deploy the audit path.
