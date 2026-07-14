# Audit negative tests

`audit.tftest.hcl` stays offline with a mocked AWS provider. It rejects
retention below the review floor and asserts Log Archive protected-storage
posture (public ACL block + KMS SSE). It does not call live log services or
deploy the audit path.
