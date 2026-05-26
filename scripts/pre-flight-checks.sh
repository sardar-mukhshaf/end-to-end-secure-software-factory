#!/usr/bin/env bash
set -euo pipefail

echo "[PREFLIGHT] Secure Software Factory Pre-Flight Checks"
echo "======================================================"

# AWS Credentials
echo -n "[CHECK] AWS credentials... "
aws sts get-caller-identity >/dev/null 2>&1 || { echo "FAIL"; exit 1; }
echo "PASS"

# Required tools
TOOLS=(terraform kubectl helm kyverno cosign trivy syft trufflehog snyk)
for tool in "${TOOLS[@]}"; do
  echo -n "[CHECK] $tool... "
  command -v "$tool" >/dev/null 2>&1 || { echo "FAIL (not installed)"; exit 1; }
  echo "PASS"
done

# Service quotas (basic)
echo -n "[CHECK] EKS cluster quota... "
EKS_COUNT=$(aws eks list-clusters --query 'clusters | length(@)' --output text 2>/dev/null || echo "0")
if [[ "$EKS_COUNT" -lt 100 ]]; then echo "PASS"; else echo "WARN: many clusters"; fi

# GitHub accessibility
echo -n "[CHECK] GitHub API access... "
curl -s -o /dev/null -w "%{http_code}" https://api.github.com/meta | grep -q "200" || { echo "FAIL"; exit 1; }
echo "PASS"

echo "[PREFLIGHT] All checks passed."
