# Cloud agent base image for the Ralphy / Project A harness.
# Do not COPY the repo; Cursor checks out the commit into the workspace.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    POWERSHELL_TELEMETRY_OPTOUT=1 \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
    TF_IN_AUTOMATION=1

# --- Layer 1: OS packages (rarely changes) ---
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      wget \
      gnupg \
      apt-transport-https \
      software-properties-common \
      git \
      unzip \
      jq \
      build-essential \
      docker.io \
      docker-compose-v2 \
    && rm -rf /var/lib/apt/lists/*

# --- Layer 2: PowerShell 7 ---
RUN curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
      | gpg --dearmor -o /usr/share/keyrings/microsoft.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/ubuntu/24.04/prod noble main" \
      > /etc/apt/sources.list.d/microsoft.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends powershell \
    && rm -rf /var/lib/apt/lists/*

# --- Layer 3: Node.js 24 (matches harness/tool-versions.json) ---
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# --- Layer 3b: Codex CLI (Cursor Cloud Orchestrator → codex cloud exec) ---
# Orchestrators dispatch Codex Cloud workers; do not reinstall at task start.
RUN npm install -g @openai/codex \
    && codex --version

# --- Layer 4: Terraform 1.15.5 (matches project-a/harness/tool-versions.json) ---
ARG TERRAFORM_VERSION=1.15.5
RUN curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" -o /tmp/terraform.zip \
    && unzip /tmp/terraform.zip -d /usr/local/bin \
    && chmod +x /usr/local/bin/terraform \
    && rm /tmp/terraform.zip \
    && terraform version

# --- Layer 5: AWS CLI v2 (optional cloud validation; secrets via Cursor dashboard) ---
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip \
    && unzip /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install \
    && rm -rf /tmp/aws /tmp/awscliv2.zip \
    && aws --version

WORKDIR /workspace
