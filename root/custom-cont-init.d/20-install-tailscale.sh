#!/bin/bash
# Tailscale is NOT shipped in the image. It is installed at runtime, on the
# user's machine, only when TS_ENABLED=true. Users who don't enable it never
# download anything from Tailscale. Since image layers are not persisted,
# this re-installs on every container re-creation (~30s) — documented.
set -e

if [ "${TS_ENABLED,,}" != "true" ]; then
    echo "[tailscale-install] TS_ENABLED != true — skipping Tailscale install."
    exit 0
fi

if command -v tailscale >/dev/null 2>&1; then
    echo "[tailscale-install] Tailscale already present."
    exit 0
fi

echo "[tailscale-install] Installing Tailscale (TS_ENABLED=true)..."
curl -fsSL https://tailscale.com/install.sh | sh
mkdir -p /config/tailscale
