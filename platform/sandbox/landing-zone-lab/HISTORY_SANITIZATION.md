# History sanitization record

The repository's writable branch and tag history was sanitized before public release on September 6, 2026.

## Replacements

- Live AWS account number → `<AWS_ACCOUNT_ID>`
- Captured VPC and flow-log identifiers → redacted typed placeholders
- Captured KMS key UUID → `<KMS_KEY_ID>`
- Deliberately fake AWS access-key fixture → `AWS_ACCESS_KEY_ID_REDACTED`

An encrypted mirror was created before the rewrite. The bundle is protected with Windows Data Protection API (current-user scope); its encrypted SHA-256 checksum is `DB3CF0B16A097497E870D6A7675FAB2FB90B27D9625CF4F513E0C0BEBD47A38D`.

## Verification

- `git filter-repo` rewrote all affected writable branches and tags.
- Gitleaks 8.24.3 scanned 207 reachable rewritten commits and reported no leaks.
- `git fsck --full --no-reflogs` completed without errors.
- Exact-value searches returned zero results for every replacement target.

GitHub's internal pull-request refs are immutable to repository pushes. They contained test-only fake credentials and non-secret infrastructure identifiers, not usable secrets. GitHub documents that permanent pull-ref cache removal requires Support and is reserved for qualifying sensitive data. New work must start from a fresh clone of the rewritten history.
