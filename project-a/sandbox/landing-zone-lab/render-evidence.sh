#!/usr/bin/env bash
# Render EVIDENCE.md from capture-evidence.sh output after a successful apply.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
CAPTURE="${1:-$ROOT/EVIDENCE.capture.md}"
OUT="${2:-$ROOT/EVIDENCE.md}"
STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
CALLER="$(aws sts get-caller-identity --output json 2>/dev/null || echo '{}')"
ACCOUNT="$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo '<AWS_ACCOUNT_ID>')"

cat > "$OUT" <<EOF
# Single-account Landing Zone lab evidence

| Field | Value |
| --- | --- |
| Account | \`${ACCOUNT}\` |
| Region | \`us-east-1\` |
| Mode | Collapsed single-account lab |
| Status | \`APPLIED\` — cloud-validated via GitHub OIDC → Terraform CI |
| Captured | \`${STAMP}\` |
| Control plane | GitHub Actions OIDC role \`GitHubActionsLZLab\` (not Cursor assume-role) |

## Caller

\`\`\`json
${CALLER}
\`\`\`

## Prerequisites satisfied

- GitHub OIDC provider + \`GitHubActionsLZLab\` role (\`github-oidc/\`)
- Remote state bootstrap (\`state-bootstrap/\`)
- Lab composition applied (\`lab/\`: identity + network + audit)

## CLI capture

EOF

if [[ -f "$CAPTURE" ]]; then
  cat "$CAPTURE" >> "$OUT"
else
  echo "_Capture file missing: ${CAPTURE}_" >> "$OUT"
fi

cat >> "$OUT" <<'EOF'

## What this proves

- Non-root CI apply identity (GitHub OIDC assumed role, not account root)
- Live identity (OIDC provider + workload role + permission boundary)
- Live private VPC + flow logs to encrypted archive
- Live CloudTrail / Config / KMS Log Archive

## What this does not prove

- Multi-account Organizations member creation or cross-account assume-role
- Production / enterprise Landing Zone readiness
- Azure / Azure Government implementation
- That A-001…A-007 harness evidence is cloud-backed (those remain repo-only)
- Cursor Cloud Agent AWS apply (explicitly not the control plane for this lab)

## Organization interface

Member accounts were **not** created. See [`ORGS_INTERFACE.md`](ORGS_INTERFACE.md).

## Reconciliation with `aws-proof`

Prior audit-only resources under `project-a/sandbox/aws-proof` remain evidence of
the first live audit apply. This lab uses a distinct `project-a-lzlab-*` name
prefix so both can coexist until an approved teardown of the older sandbox.
EOF

echo "wrote $OUT"
