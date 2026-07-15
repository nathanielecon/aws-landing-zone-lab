# Smoke evidence

Task evidence is created by the adapter immediately before each gated commit.
`commit_sha` is recorded as `SELF`; resolve it with:

```powershell
git log -1 --format=%H -- evidence/S-001.json
```

The ignored runtime state and sanitized external run summary record the exact
resulting SHA after the commit succeeds.
