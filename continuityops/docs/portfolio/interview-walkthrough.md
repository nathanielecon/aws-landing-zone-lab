# ContinuityOps interview walkthrough

1. Open `README.md` and `docs/architecture/overview.md`
2. Show independence: no Project A/C edits; lab artifacts owned here
3. Trace a request: ingress → service → SQS → worker (`observability/otel/instrumentation.md`)
4. Show a misleading-symptom drill (`operations/drills/misleading-latency-downstream.md`)
5. Show agentic safety (`agentic/tests/Test-UnsafeProposals.ps1`)
6. End on claims boundary — what is and is not proven
