# ContinuityOps agentic policies

Policy artifacts for S6 agentic safety.

| File | Purpose |
| --- | --- |
| `mutation-policy.json` | Default-deny write; H4 human approval for mutation-capable jobs |
| `prompt-safety.md` | Rejection rules: injection, forged evidence, scope, secrets, stale runbooks |

Unsafe proposal rejection tests live in `../tests/unsafe-proposal-cases.json` and
`../tests/Test-UnsafeProposals.ps1`. Categories covered: prompt injection,
forged evidence, excessive scope, malicious commands, secret requests, and stale
runbooks.
