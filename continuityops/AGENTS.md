# ContinuityOps agent rules

Plan ID: `continuityops-cloud-reliability-v1`  
Former code name: Project F  
Primary orchestrator model: Grok 4.5 High Fast (Ralphy orchestrator, judge, nixer, fixer)

## Authority

- Run only work authorized for the current phase. Phase 1+ cloud mutation
  requires a human receipt bound to plan/execution hashes.
- Do not edit Project A (`project-a/`) or Project C. Consume pinned export
  contracts via `integration/upstreams.lock.json` only.
- Codex workers must not commit. The ContinuityOps adapter alone stages
  append-only evidence and authoritative state.
- Never widen Codex beyond `workspace-write`.
- Runtime state and verbose logs remain untracked and sanitized.
- Do not clean, reset, stash, or overwrite unexplained user changes.

## Operating model

- Lead orchestrator: Grok 4.5 High Fast in this supervisory session.
- Implementation workers: Codex 5.4 CLI Cloud Agents in `/fast` mode on
  bounded tasks.
- Worker instructions, status, handoffs, and inter-agent communication:
  **Simplified Chinese only**.
- Recruiter-facing repository artifacts: **English only**.
- Bottleneck specialists (auth, CI, cloud identity, Kubernetes,
  observability, browser, toolchain) must be dispatched in-session. Do not
  hand blockers back as “start a new conversation” when a safe specialist
  dispatch exists.
- Up to three concurrent disjoint Ralphy streams may run after shared
  interfaces are frozen. Each stream is sequential internally. Integration
  is serialized through a recorded merge queue.
- Root-repo smoke/Project A harness rules remain sequential and do not
  govern ContinuityOps stream concurrency.

## TypeScript

Where TypeScript is used, pin stable TypeScript 7.x. Initial verified
baseline: `typescript@7.0.2`. Strict checking and full affected-partition
revalidation are required for any compiler change.

## Cloud lab posture

- Isolated single-account AWS lab only unless a human gate expands scope.
- Cloud Agents edit Terraform/PRs; they do not hold apply credentials.
  `NoCredentials` in Cloud Agent pods is expected.
- Azure is governance/network companion only where separately authorized
  and evidenced.
- Do not invent DNS, multi-account production, or 24/7 customer ownership
  claims.

## Phase 0 boundary

Phase 0 is repo-only. No cloud credentials, live apply, or destructive
drills. Unauthorized Phase 1 execution must be rejected by validators.
