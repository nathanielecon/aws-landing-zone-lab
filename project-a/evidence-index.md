# Evidence index

Harness tasks `A-001`…`A-007` are repo-only and **not** cloud-validated. The
table below records deterministic validation for each harness task.

Separately, the single-account Landing Zone lab under
[`sandbox/landing-zone-lab/EVIDENCE.md`](sandbox/landing-zone-lab/EVIDENCE.md)
is **APPLIED** / cloud-validated for identity + private network + audit via
GitHub OIDC CI (role `project-a-lzlab-gha`, run `29366105164`). Multi-account
Organizations member creation remains **not** cloud-validated.

| Task | Commit | Evidence | Validation |
| --- | --- | --- | --- |
| A-001 | `d77d069` | `evidence/project-a/A-001.json` | `D61312FC9E5ED5A2115830FACF3F97B480C87C015112175B6B08EADB23CBF410` |
| A-002 | `c27c961` | `evidence/project-a/A-002.json` | `28894F35F27FCFF35A023A4863099810DD28B351D83C5004F628FDB68854D7BC` |
| A-003 | `a3a74a7` | `evidence/project-a/A-003.json` | `3D6AF7F703596DDB7DF1A5315F5F6C2DDC9EFCEFCE6503FC68BBCC197EE92ECC` |
| A-004 | `ce9b979` | `evidence/project-a/A-004.json` | `9E67D5EB27B90ADAD54470AC1AA253354AD48D1C205DC776DB6067253139A342` |
| A-005 | `0158b9e` | `evidence/project-a/A-005.json` | `F8D9B29C78AC6A33555292E115D874931C03C4A2F35B970D4A28FE2FA638A917` |
| A-006 | `81b2702` | `evidence/project-a/A-006.json` | `15FF2EB7BF746D688BAFBA6FF48CEBDFAEBD5C89E5A88B483D174C39916C439E` |
| A-007 | `d8de68f` | `evidence/project-a/A-007.json` | `B84061C7B87F79FE282D62736CD8CF21200179891B4FB3B59EA64513783AF8EF` |

Note on A-007 index drift: `evidence/project-a/A-007.json` recorded
`project-a/evidence-index.md` `content_sha256` at task commit time (before a
later harness commit appended the A-007 row to this index). The indexed
`validation_digest` `B84061C7B87F79FE282D62736CD8CF21200179891B4FB3B59EA64513783AF8EF`
remains the binding proof; this note does not re-run live tasks or mint new
cloud validation.

The Azure Government notes are translation-only, not implemented, and not cloud
validated. Reviewers should use [claims boundary](docs/portfolio/claims-boundary.md)
before making portfolio or interview statements.
