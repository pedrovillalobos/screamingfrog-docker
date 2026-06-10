#!/bin/bash
# Downloads and installs Screaming Frog from the OFFICIAL servers at
# container start, pinned by the SF_VERSION env var. Exits quickly if the
# requested version is already installed. Nothing is redistributed by the
# image itself.
set -e

SF_VERSION="${SF_VERSION:-24.0}"
ARCH="$(dpkg --print-architecture)"   # amd64 or arm64
CACHE="/config/installers"
DEB="${CACHE}/screamingfrogseospider_${SF_VERSION}_${ARCH}.deb"
INSTALLED="$(dpkg-query -W -f='${Version}' screamingfrogseospider 2>/dev/null || echo none)"

mkdir -p "$CACHE" /config/mcp-workdir /config/sf-configs /config/exports

if [ "$INSTALLED" = "$SF_VERSION" ]; then
    echo "[sf-install] Screaming Frog ${SF_VERSION} already installed."
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
fi

# Java heap allocation (-Xmx). If SF_MAX_MEMORY is set (e.g. "12g"), it is
# the source of truth and is rewritten on every start. If empty, whatever
# was configured in the GUI (File > Settings > Memory Allocation) is kept.
# Note: do NOT set a container memory limit equal to this value — the app
# needs heap + JVM overhead + Chromium rendering processes. If you want a
# container limit, use roughly heap + 30-40%.
if [ -n "$SF_MAX_MEMORY" ]; then
    echo "-Xmx${SF_MAX_MEMORY}" > /config/.screamingfrogseospider
    echo "[sf-install] Java heap set to ${SF_MAX_MEMORY} via SF_MAX_MEMORY."
fi

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
    /config/exports /config/.screamingfrogseospider 2>/dev/null || true
