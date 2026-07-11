# IAM negative tests

`identity.tftest.hcl` uses a mocked AWS provider so it remains offline. It
asserts the proposed role name and contains a blocked-change test: a trust
request from any branch other than protected `main` must fail variable
validation. This is a test of repository policy shape, not cloud validation.
