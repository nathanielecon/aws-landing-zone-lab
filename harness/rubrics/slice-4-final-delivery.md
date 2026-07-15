# Slice 4 rubric — final delivery

Status: frozen  
Scope: final delivery surface owned primarily by task `A-007` plus
orchestration/evidence packaging, including:

- `project-a/evidence-index.md`
- `evidence/project-a/A-001.json` … `A-007.json`
- `project-a/docs/portfolio/claims-boundary.md`
- `project-a/docs/review/pushback-and-handoff.md`
- `project-a/docs/azure-government/readiness.md`
- `project-a/docs/diagrams/aws-landing-zone-architecture.png` (and network diagram linkage)
- `project-a/graphify-out/GRAPH_REPORT.md`
- `project-a/docs/architecture/orchestration.md`
- frozen rubrics under `harness/rubrics/`
- PR / Windows CI readiness
  (`.github/workflows/harness-contracts.yml`, green remote checks)

Final merge and any future cloud-validation phase remain human decisions.

## must-have to pass slice

- Evidence index lists every A-001…A-007 evidence path with commit and
  validation digest references.
- Portfolio claims boundary explicitly states what is proven (repo-only design
  + deterministic gates) and what is not (production, senior ownership,
  enterprise ops, cloud validation).
- Review/handoff doc provides pushback language and escalation instructions.
- Azure Government note is translation/readiness only with explicit
  non-implementation language.
- Platform and network diagrams exist and are linked from README / architecture
  docs.
- Graphify output is present as a navigation/evidence aid and is never treated
  as a substitute for Terraform, policy, security, or human validation.
- Orchestration architecture doc records slice partitions, judge/nixer/fixer
  dispatch, ≥9.5 thresholds, approval/hash pinning, Windows CI gate, and
  local-vs-remote proof boundaries.
- Frozen slice rubrics exist under `harness/rubrics/` and are the only scoring
  authority for slice exit.
- Final repo validation / claims validators pass without cloud credentials.
- Windows CI contract workflow is the remote gate; local green alone does not
  declare delivery complete.

## needed for 9/10+

- Evidence digests are independently recomputable and match indexed values.
- Handoff points reviewers to evidence index, platform diagram, and claims
  boundary in one short path.
- BREAK_FIX / repair history for harness CI blockers is inspectable when
  delivery depends on CI hardening.
- PR description and branch state make allowlisted commits and claim boundaries
  obvious to reviewers.
- Spec, harness, and contract test suites all pass under CI-equivalent
  environment variables before merge claims.

## needed for 10/10

- Independent second-pass judge confirms ≥9 first try after bottleneck repair
  (no score inflation from the same conversation alone).
- Public, claim-safe portfolio wording that survives skeptical senior review
  without hedging contradictions.
- Complete link graph from README → architecture → evidence → review with zero
  orphans.
- Fresh-clone Windows one-command proof matching CI pin set and assertion
  counts recorded in execution approval.

## nice-to-have

- Recorded walkthrough video or annotated review checklist.
- Additional Azure Government mapping tables beyond readiness notes.
- Automated portfolio PDF export.
