#!/usr/bin/env bash
# Codex Cloud Environment — setup script (runs once per cache warm, with internet).
# Paste into: Codex → Environments → this repo → Setup script
# Or: bash .codex/cloud-setup.sh when the repo is already checked out.
#
# Goal: preinstall the same harness toolchain as .cursor/Dockerfile so agents
# skip apt/npm/tool downloads on every task. Codex caches the result ~12h.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export POWERSHELL_TELEMETRY_OPTOUT=1
export TF_IN_AUTOMATION=1

TERRAFORM_VERSION="${TERRAFORM_VERSION:-1.15.5}"
NODE_MAJOR="${NODE_MAJOR:-24}"
RALPHY_VERSION="${RALPHY_VERSION:-4.7.2}"

need_cmd() { command -v "$1" >/dev/null 2>&1; }

echo "== Codex cloud setup: OS packages =="
if need_cmd apt-get; then
  sudo apt-get update -qq
  sudo apt-get install -y --no-install-recommends \
    ca-certificates curl wget gnupg unzip jq git build-essential \
    apt-transport-https software-properties-common \
    docker.io docker-compose-v2 2>/dev/null || \
  sudo apt-get install -y --no-install-recommends \
    ca-certificates curl wget gnupg unzip jq git build-essential \
    apt-transport-https software-properties-common
fi

echo "== PowerShell 7 =="
if ! need_cmd pwsh; then
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    | sudo gpg --dearmor -o /usr/share/keyrings/microsoft.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/ubuntu/24.04/prod noble main" \
    | sudo tee /etc/apt/sources.list.d/microsoft.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y --no-install-recommends powershell
fi

echo "== Node.js ${NODE_MAJOR} =="
if ! need_cmd node || [[ "$(node -v 2>/dev/null | sed 's/^v//;s/\..*//')" != "$NODE_MAJOR" ]]; then
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | sudo -E bash -
  sudo apt-get install -y --no-install-recommends nodejs
fi

echo "== Terraform ${TERRAFORM_VERSION} =="
if ! need_cmd terraform || [[ "$(terraform version -json 2>/dev/null | jq -r .terraform_version)" != "$TERRAFORM_VERSION" ]]; then
  curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
    -o /tmp/terraform.zip
  sudo unzip -o /tmp/terraform.zip -d /usr/local/bin
  sudo chmod +x /usr/local/bin/terraform
  rm -f /tmp/terraform.zip
fi

echo "== AWS CLI v2 =="
if ! need_cmd aws; then
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  unzip -q /tmp/awscliv2.zip -d /tmp
  sudo /tmp/aws/install
  rm -rf /tmp/aws /tmp/awscliv2.zip
fi

echo "== Ralphy CLI ${RALPHY_VERSION} (harness) =="
if ! need_cmd ralphy || ! ralphy --version 2>/dev/null | grep -q "$RALPHY_VERSION"; then
  sudo npm install --global "ralphy-cli@${RALPHY_VERSION}" --ignore-scripts --no-audit --no-fund
fi

# Persist PATH hints for the agent phase (setup shell exports do not carry over).
if [[ -f "$HOME/.bashrc" ]] || touch "$HOME/.bashrc"; then
  grep -q 'TF_IN_AUTOMATION' "$HOME/.bashrc" 2>/dev/null || \
    echo 'export TF_IN_AUTOMATION=1 POWERSHELL_TELEMETRY_OPTOUT=1' >> "$HOME/.bashrc"
fi

echo "== Verify toolchain =="
git --version
node --version
npm --version
pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
terraform version
aws --version
ralphy --version 2>/dev/null || true
echo "Codex cloud setup complete."
