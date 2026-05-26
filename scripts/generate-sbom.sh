#!/usr/bin/env bash
set -euo pipefail

# generate-sbom.sh
# Generates CycloneDX 1.5 SBOM using Syft and signs it with Cosign

PROJECT_NAME="${PROJECT_NAME:-secure-software-factory}"
OUTPUT_FILE="${OUTPUT_FILE:-sbom.cdx.json}"

echo "[SBOM] Generating CycloneDX 1.5 SBOM..."
syft packages dir:. -o cyclonedx-json="${OUTPUT_FILE}"

if command -v cyclonedx-cli >/dev/null 2>&1; then
  echo "[SBOM] Validating CycloneDX format..."
  cyclonedx-cli validate --input-file "${OUTPUT_FILE}" --input-version v1_5
fi

echo "[SBOM] Signing SBOM with Cosign..."
cosign sign-blob --key "awskms:///alias/cosign-key" "${OUTPUT_FILE}" --output-signature "${OUTPUT_FILE}.sig"

echo "[SBOM] Done: ${OUTPUT_FILE}"
