#!/bin/bash
# Downloads and installs Screaming Frog from the OFFICIAL servers at
# container start. Nothing is redistributed by the image itself.
#
# SF_VERSION is a MINIMUM version, not an exact pin:
# - installs only when nothing is installed or the installed version is older
# - never reinstalls the same version, never downgrades
# This plays nicely with the app's own in-app updater, and with the fact that
# Screaming Frog's download server redirects old version URLs to the latest
# release anyway.
#
# Note: the install lives in the container's writable layer. It survives
# container RESTARTS, but a container RE-CREATION (template edit, image
# update) triggers a reinstall — served from the cached .deb in /config
# when possible.
set -e

SF_VERSION="${SF_VERSION:-24.1}"
ARCH="$(dpkg --print-architecture)"   # amd64 or arm64
CACHE="/config/installers"
DEB="${CACHE}/screamingfrogseospider_${SF_VERSION}_${ARCH}.deb"
INSTALLED="$(dpkg-query -W -f='${Version}' screamingfrogseospider 2>/dev/null || echo 0)"
INSTALLED="${INSTALLED:-0}"

mkdir -p "$CACHE" /config/mcp-workdir /config/sf-configs /config/exports

if dpkg --compare-versions "$INSTALLED" ge "$SF_VERSION"; then
    echo "[sf-install] Installed version ${INSTALLED} satisfies minimum ${SF_VERSION} — nothing to do."
else
    echo "[sf-install] Installing Screaming Frog ${SF_VERSION} (${ARCH}); current: ${INSTALLED}"
    if [ ! -f "$DEB" ]; then
        curl -fL -o "$DEB" \
          "https://download.screamingfrog.co.uk/products/seo-spider/screamingfrogseospider_${SF_VERSION}_${ARCH}.deb"
    fi
    # Pre-accept the Microsoft fonts EULA (a dependency of the SF .deb)
    echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" \
        | debconf-set-selections
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$DEB"
    apt-get clean && rm -rf /var/lib/apt/lists/*
    # Keep only the current installer in the cache (each .deb is ~900 MB)
    find "$CACHE" -name 'screamingfrogseospider_*.deb' ! -name "$(basename "$DEB")" -delete
fi

# Memory allocation is configured in the app GUI (File > Settings > Memory
# Allocation) and persists in /config across restarts and re-creations.

# Autostart SF in the XFCE session — keeps the app (and its native MCP
# server, v24+) running whenever the container is up.
mkdir -p /config/.config/autostart
cat > /config/.config/autostart/screamingfrog.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Screaming Frog SEO Spider
Exec=screamingfrogseospider
X-GNOME-Autostart-enabled=true
EOF

chown -R abc:abc /config/.config /config/mcp-workdir /config/sf-configs \
    /config/exports 2>/dev/null || true