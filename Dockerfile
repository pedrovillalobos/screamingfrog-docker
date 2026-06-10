# Screaming Frog SEO Spider (unofficial) — browser GUI + native MCP server
#
# IMPORTANT: this image does NOT bundle or redistribute Screaming Frog.
# The official installer (.deb) is downloaded from screamingfrog.co.uk at
# container start, on the user's own machine, pinned by the SF_VERSION env.
# A paid licence (provided by the user) is required for crawls over 500 URLs
# and for MCP/headless features. See NOTICE for trademark/EULA details.
FROM lscr.io/linuxserver/webtop:ubuntu-xfce

LABEL org.opencontainers.image.source="https://github.com/pedrovillalobos/screamingfrog-docker" \
      org.opencontainers.image.title="Screaming Frog SEO Spider (unofficial)" \
      org.opencontainers.image.description="Screaming Frog SEO Spider in your browser (KasmVNC) with the native MCP server exposed. Unofficial; downloads the official installer at runtime. Optional Tailscale egress installed at runtime only if enabled." \
      org.opencontainers.image.licenses="MIT"

# Redistributable dependencies only:
# - socat: relays the MCP server (loopback-only) to the container network
# - common libs required by the SF embedded Chromium (JavaScript rendering)
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        socat curl ca-certificates debconf-utils \
        libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 \
        libxkbcommon0 libxcomposite1 libxdamage1 libxrandr2 libgbm1 \
        libasound2t64 fonts-liberation && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Init + service scripts (SF runtime install, MCP relay, optional Tailscale)
COPY root/ /
RUN chmod +x /custom-cont-init.d/* /custom-services.d/*

# 3000  = Webtop GUI (KasmVNC, HTTP)
# 11436 = MCP relay (socat -> 127.0.0.1:11435 inside the container)
# Host port mappings are defined by the user (Unraid template / compose),
# never hardcoded here.
EXPOSE 3000 11436
