# AWS Landing Zone Lab Image2 provenance

The draw.io file is the editable content authority for architecture order, workflow order, CIDRs, and scope boundaries. The PNG is a presentation derivative and does not add infrastructure or expand the repository's claims.

## Generation record

- Generated: 2026-09-07, America/New_York.
- Workflow: user-directed Image2 generation through the Codex built-in OpenAI image-generation tool. The tool did not expose a backend model identifier.
- Intent: redraw the prior infographic from scratch with purpose-specific, logo-free illustrations and the verified retired-lab state.
- Content references:
  - prior PNG SHA-256: `c06c128d0f3c0d873c05a1c13a86a7af142325a60109e025bbc81f15a39b334b`;
  - pre-refresh draw.io SHA-256: `0aacdc75c2c92fbcaa3bf2b88f679da6f9057bb658df5d6ad4612e9cdc73fbee`.
- Retired-state draw.io content source SHA-256: `b9b88e4f7f1c7d17c4634ef5378fb8d1b802d390d16138e700d2c8c42b507567`.
- Approved PNG: `aws-landing-zone-lab.png`, 1024×1536 RGB, SHA-256 `a469c9518b3a777ec7b9c91e42cf4e9fa3022755b53c377775caa817dbcf54f4`.
- Prompt: [`aws-landing-zone-lab-image2-prompt.txt`](aws-landing-zone-lab-image2-prompt.txt).

## Validation record

- Pillow decode, dimensions, mode, and image-integrity checks passed.
- OCR detected the title, architecture labels, service names, CIDRs, and retirement language. Original-resolution review resolved one OCR-only `CI`/`Cl` ambiguity.
- The architecture and workflow orders match the draw.io content authority.
- The private network preserves `10.0.0.0/16`, `10.0.1.0/24`, `10.0.2.0/24`, two private subnets, and the closed-edge boundary.
- The final state says cloud-validated and retired, retained evidence remained readable, and all 17 enabled regions were checked.
- Multi-account Organizations interfaces remain design-only; the image claims validation in one AWS account only.
- No account ID, ARN, live identifier, vendor logo, watermark, invented service, or production claim appears.
- The full-resolution and 800-pixel README-width renders were inspected for clipping, malformed icons, and legibility.

Changing the PNG, prompt, draw.io content, evidence status, or public claim requires a new hash and parity review.
