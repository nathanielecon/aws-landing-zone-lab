#!/usr/bin/env bash
# Codex Cloud Environment — maintenance script (runs when a cached container resumes).
# Paste into: Codex → Environments → Maintenance script
# Keep this light so cache resumes stay fast; only re-verify / fill gaps.
set -euo pipefail

export TF_IN_AUTOMATION=1

ok=1
for cmd in git node pwsh terraform aws; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "missing $cmd — re-running setup"
    ok=0
    break
  fi
done

if [[ "$ok" -ne 1 ]]; then
  # Repo is already checked out at task branch when maintenance runs.
  if [[ -f .codex/cloud-setup.sh ]]; then
    bash .codex/cloud-setup.sh
  else
    echo "ERROR: toolchain missing and .codex/cloud-setup.sh not found" >&2
    exit 1
  fi
fi

# Optional: start Docker if the image provides it (ignore failures).
if command -v service >/dev/null 2>&1; then
  sudo service docker start 2>/dev/null || true
fi

echo "Codex cloud maintenance OK:"
node --version
pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
terraform version -json 2>/dev/null | head -c 120 || terraform version
aws --version | head -n 1
