#!/usr/bin/env bash
set -euo pipefail

KYVERNO_VERSION="${KYVERNO_VERSION:-1.12.0}"
OS="$(uname | tr '[:upper:]' '[:lower:]')"
ARCH="amd64"

if [[ "$(uname -m)" == "arm64" || "$(uname -m)" == "aarch64" ]]; then
  ARCH="arm64"
fi

echo "[INSTALL] Kyverno CLI v${KYVERNO_VERSION} for ${OS}/${ARCH}"

curl -sL "https://github.com/kyverno/kyverno/releases/download/v${KYVERNO_VERSION}/kyverno-cli_v${KYVERNO_VERSION}_${OS}_${ARCH}.tar.gz" | tar -xz -C /tmp
mv /tmp/kyverno /usr/local/bin/kyverno 2>/dev/null || mv /tmp/kyverno "$HOME/.local/bin/kyverno"
chmod +x "$(command -v kyverno || echo "$HOME/.local/bin/kyverno")"
echo "[INSTALL] Done."
