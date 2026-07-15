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
| A-001 | `d77d069` | `evidence/platform/A-001.json` | `D61312FC9E5ED5A2115830FACF3F97B480C87C015112175B6B08EADB23CBF410` |
| A-002 | `c27c961` | `evidence/platform/A-002.json` | `28894F35F27FCFF35A023A4863099810DD28B351D83C5004F628FDB68854D7BC` |
| A-003 | `a3a74a7` | `evidence/platform/A-003.json` | `3D6AF7F703596DDB7DF1A5315F5F6C2DDC9EFCEFCE6503FC68BBCC197EE92ECC` |
| A-004 | `ce9b979` | `evidence/platform/A-004.json` | `9E67D5EB27B90ADAD54470AC1AA253354AD48D1C205DC776DB6067253139A342` |
| A-005 | `0158b9e` | `evidence/platform/A-005.json` | `F8D9B29C78AC6A33555292E115D874931C03C4A2F35B970D4A28FE2FA638A917` |
| A-006 | `81b2702` | `evidence/platform/A-006.json` | `15FF2EB7BF746D688BAFBA6FF48CEBDFAEBD5C89E5A88B483D174C39916C439E` |
| A-007 | `d8de68f` | `evidence/platform/A-007.json` | `B84061C7B87F79FE282D62736CD8CF21200179891B4FB3B59EA64513783AF8EF` |

**Historical note (A-007 evidence-index drift):** At task commit time,
`evidence/platform/A-007.json` recorded a `content_sha256` for
`platform/evidence-index.md` before a later harness commit appended the A-007
row to this index. That entry-level hash drift is **historical only** and is
**not** a live revalidation signal. The indexed `validation_digest`
`B84061C7B87F79FE282D62736CD8CF21200179891B4FB3B59EA64513783AF8EF` remains the
**binding** proof; this note does not re-run live tasks or mint new cloud
validation.

The Azure Government notes are translation-only, not implemented, and not cloud
validated. Reviewers should use [claims boundary](docs/portfolio/claims-boundary.md)
before making portfolio or interview statements.
