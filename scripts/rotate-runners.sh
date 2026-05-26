#!/usr/bin/env bash
set -euo pipefail

# rotate-runners.sh
# Gracefully rotates self-hosted runner pods to prevent poisoning

NAMESPACE="${RUNNER_NAMESPACE:-github-runners}"
DEPLOYMENT="${RUNNER_DEPLOYMENT:-arc-runner-set}"

echo "[ROTATE] Cordon and drain runner pods..."
kubectl rollout restart deployment/${DEPLOYMENT} -n ${NAMESPACE}
kubectl rollout status deployment/${DEPLOYMENT} -n ${NAMESPACE} --timeout=300s

echo "[ROTATE] Runner pods rotated successfully."
