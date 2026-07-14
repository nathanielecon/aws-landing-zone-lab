# Lightweight idempotent tool presence checks for cloud-harness.
# Keep this free of apt-get / npm / cold toolchain installs.
$ErrorActionPreference = 'Stop'
$required = @('git', 'node', 'pwsh', 'terraform', 'aws', 'docker')
foreach ($name in $required) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        Write-Error "missing required tool: $name (expected in cloud-harness image layers)"
        exit 1
    }
}
git --version
node --version
pwsh -Version
terraform version
aws --version
docker --version
