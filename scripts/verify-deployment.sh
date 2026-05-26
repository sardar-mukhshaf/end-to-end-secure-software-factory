#!/usr/bin/env bash
set -euo pipefail

# verify-deployment.sh
# Pre-deployment verification: image signature, scan results, SBOM existence

IMAGE="${1:-}"
SBOM_FILE="${2:-sbom.cdx.json}"

if [[ -z "$IMAGE" ]]; then
  echo "Usage: $0 <image-uri> [sbom-file]"
  exit 1
fi

echo "[VERIFY] Checking image signature for ${IMAGE}..."
cosign verify --key "awskms:///alias/cosign-key" "${IMAGE}"

echo "[VERIFY] Checking Trivy scan results..."
trivy image --severity HIGH,CRITICAL --exit-code 1 "${IMAGE}"

echo "[VERIFY] Checking SBOM exists: ${SBOM_FILE}..."
if [[ ! -f "${SBOM_FILE}" ]]; then
  echo "FAIL: SBOM not found"
  exit 1
fi

echo "[VERIFY] All checks passed. Deployment authorized."
