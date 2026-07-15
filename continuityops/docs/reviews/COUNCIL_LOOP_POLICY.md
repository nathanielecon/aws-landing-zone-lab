# ContinuityOps council loop policy (authoritative)

## Saved cohort until gate, then fresh validation

1. **Saved remediation cohort (sticky)**  
   Assign and **retain** the same judges, nixers, and fixers across rounds
   until the **orchestrator private gate** passes on their scores/fixes.  
   Do not rotate the cohort mid-remediation.

2. **Orchestrator gate (private)**  
   Numeric pass criteria live only in
   `continuityops/harness/policies/orchestrator-gate.private.json`.  
   **Never** place those numbers in judge/nixer/fixer prompts.

3. **Fresh validation council (after gate)**  
   Only after the saved cohort’s work clears the private gate, dispatch an
   **entirely fresh** judge set (no prior transcripts, scores, or cohort
   reports). Fresh judges are authoritative for certification.

4. **Fresh fail → continue loop**  
   If the fresh council fails, **retire** the old repair cohort, assign a
   **new** sticky cohort (judges/nixers/fixers), remediate again without
   threshold leakage, re-clear the private gate, then run **another** fresh
   council. Repeat until a fresh council passes.

5. **Models**  
   ContinuityOps subagents for this track: **Grok only**.  
   Do not use Composer (or Sonnet/Opus) for ContinuityOps judge/nix/fix/partition
   work unless the operator explicitly changes this rule.

6. **Operator communication**  
   Do not report “done” or progress-complete to the operator until a **fresh**
   council has passed after a private-gate clear (unless the operator asks a
   direct question).

## Related artifacts

- Mistake package: `docs/reviews/ORCHESTRATOR_MISTAKE_PACKAGE.md`
- Private gate: `harness/policies/orchestrator-gate.private.json`
- Blind judge prompt: `harness/rubrics/JUDGE_PROMPT_NO_THRESHOLD.md`
- Aggregate (post-score, orchestrator-only bar): `scripts/Invoke-FreshCouncilAggregate.ps1`
