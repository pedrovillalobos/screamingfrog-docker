# Screaming Frog SEO Spider — Docker / Unraid (unofficial)

[Screaming Frog SEO Spider](https://www.screamingfrog.co.uk/seo-spider/) running
in your browser (linuxserver.io Webtop + KasmVNC), with:

- **Full GUI in the browser** — identical to the desktop app, at `http://HOST:3000`
- **Native MCP server (v24+) exposed** to your LAN/tailnet for Claude Code,
  Claude Desktop, Cursor, or any MCP-compatible client
- **Optional Tailscale egress** (userspace, installed at runtime only if you
  enable it) — crawl traffic exits through a fixed-IP exit node via a local
  proxy, without touching GUI/MCP/LAN traffic
- **Update by variable**: change `SF_VERSION`, restart, done. Licence, configs
  and crawls persist in `/config`
- **JavaScript rendering** supported (embedded Chromium; needs `--shm-size=2g`)
- **Multi-arch**: `linux/amd64` and `linux/arm64`

> ## ⚠️ Licence required
> Screaming Frog SEO Spider is **paid, proprietary software**. The free tier is
> limited to 500 URLs per crawl, and **MCP, headless CLI, saving crawls and
> configuration files require a paid licence**, purchased directly from
> [Screaming Frog](https://www.screamingfrog.co.uk/seo-spider/licence/).
> Enter your licence once in the GUI (`Licence > Enter Licence`) — it persists
> in `/config`.

> ## Transparency / what this image is
> - This is an **unofficial community project**, not affiliated with or endorsed
>   by Screaming Frog Ltd. "Screaming Frog" is their trademark. See [NOTICE](NOTICE).
> - The image **does not bundle or redistribute** Screaming Frog. The official
>   installer is downloaded **from screamingfrog.co.uk on your machine** at
>   container start, pinned by `SF_VERSION`. Your use of the software is
>   governed by the Screaming Frog EULA.
> - Tailscale is also **not shipped in the image** — it is installed at runtime
>   only when `TS_ENABLED=true`.
> - Everything the container does at startup is in plain bash under
>   [`root/custom-cont-init.d`](root/custom-cont-init.d) and
>   [`root/custom-services.d`](root/custom-services.d).

## Security

The KasmVNC GUI and the MCP endpoint have **no built-in authentication**.
Keep these ports on your LAN, VPN or tailnet only. **Never publish them to the
internet.**

---

## Install on Unraid (Community Applications)

1. Search for **ScreamingFrog-SEO-Spider** in Apps (or add the template from
   [`unraid-template/`](unraid-template/)).
2. The install screen pre-fills everything; adjust if needed:
   - **WebUI port** (default `3000`) and **MCP port** (default `11435`)
   - **Appdata** (default `/mnt/user/appdata/screamingfrog` — keep it on your
     SSD/cache pool if you plan to use Database Storage mode)
   - **SF_VERSION** (default `24.0`)
   - **SF_MAX_MEMORY** (e.g. `12g` for large crawls; see [Memory](#memory))
3. Apply. First start downloads the official installer (~0.5–1 GB total with
   dependencies), then the GUI is available at `http://SERVER_IP:3000` with the
   SEO Spider already open.
4. Enter your licence, then set `File > Settings > Storage Mode` to
   **Database Storage** for large crawls.

## Install with plain Docker / Docker Compose

```yaml
services:
  screamingfrog:
    image: ghcr.io/pedrovillalobos/screamingfrog-docker:latest
    container_name: screamingfrog
    environment:
      - PUID=1000              # your user id (run: id -u)
      - PGID=1000              # your group id (run: id -g)
      - TZ=Etc/UTC
      - TITLE=Screaming Frog
      - SF_VERSION=24.0
      - SF_MAX_MEMORY=         # e.g. 12g; empty = controlled via the app GUI
      - TS_ENABLED=false
      - TS_AUTHKEY=
      - TS_EXIT_NODE=
    ports:
      - "3000:3000"            # GUI (KasmVNC, HTTP)
      - "11435:11436"          # MCP
    volumes:
      - ./appdata:/config      # licence, configs, crawls, exports
    shm_size: "2gb"            # required for JavaScript rendering
    security_opt:
      - seccomp=unconfined     # linuxserver recommendation for Chromium apps
    restart: unless-stopped
```

`docker compose up -d`, then open `http://HOST:3000`.

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `SF_VERSION` | `24.0` | Screaming Frog version to install. Change + restart to update; `/config` is never touched. |
| `SF_MAX_MEMORY` | *(empty)* | Java heap (`-Xmx`), e.g. `12g`. When set, it is reapplied on every start (source of truth). When empty, the GUI setting (`File > Settings > Memory Allocation`) applies. |
| `TS_ENABLED` | `false` | Installs and starts Tailscale (userspace) at runtime. |
| `TS_AUTHKEY` | *(empty)* | Tailscale auth key. Without it, authenticate once: `docker exec -it screamingfrog tailscale up`. |
| `TS_EXIT_NODE` | *(empty)* | Tailscale hostname/IP of the exit node for crawl egress. |
| `PUID` / `PGID` | `99` / `100` | File ownership for `/config` (Unraid defaults shown; use `1000`/`1000` on most Linux distros). |
| `TZ` | — | Timezone, e.g. `America/Sao_Paulo`. |
| `TITLE` | — | Browser tab title (Webtop). |

## Memory

`SF_MAX_MEMORY` sets the SEO Spider's Java heap. For large crawls, values like
`8g`–`16g` are common — Screaming Frog recommends leaving headroom below your
total RAM. **Do not set a Docker memory limit equal to the heap**: the app
needs heap + JVM overhead + Chromium rendering processes. If you want a
container limit, use roughly heap + 30–40% (e.g. heap `12g` → limit `16g`).

## MCP server (Claude Code, Cursor, etc.)

Requires SF v24+ and a paid licence.

1. In the SEO Spider: `Settings > MCP Server` → enable it and set the base
   directory to `/config/mcp-workdir` (visible on the host inside your appdata
   folder).
2. Register it in your client, e.g. Claude Code:
   ```
   claude mcp add --transport http screaming-frog http://HOST_IP:11435/mcp
   ```
3. The SEO Spider app must be running for the MCP server to respond — this
   container keeps it open in the Webtop session automatically.

The MCP server natively listens on loopback only; a small `socat` relay inside
the container exposes it on container port `11436` so it can be published.

## Tailscale / fixed-IP crawl egress (optional)

1. Set `TS_ENABLED=true` (plus `TS_AUTHKEY` and `TS_EXIT_NODE`, or authenticate
   manually: `docker exec -it screamingfrog tailscale up --exit-node=NODE`).
2. In the SEO Spider: `Config > System > Proxy` → host `localhost`, port `1056`.
   Crawl traffic now exits through your exit node; GUI, MCP and LAN access stay
   direct. State persists in `/config/tailscale`.
3. Remote access over your tailnet: `http://TAILSCALE_IP:3000` (GUI) and
   `http://TAILSCALE_IP:11436/mcp` (MCP).

Note: because Tailscale is installed at runtime (never shipped in the image),
enabling it re-downloads the package on each container re-creation (~30s).

## Updating Screaming Frog

Change `SF_VERSION` (e.g. `24.1`) and restart the container. The init script
downloads the new official `.deb` and installs it. Licence, configuration
files, crawls and exports in `/config` are preserved.

## Custom configurations

Put your `.seospiderconfig` files in `/config/sf-configs`. Load them via the
GUI (`File > Configuration > Load`), via headless CLI (`--config`), or
reference them in MCP crawl tools.

## Repository layout

```
Dockerfile                       # webtop base + socat + Chromium libs (no SF, no Tailscale)
root/custom-cont-init.d/         # runtime install of SF (SF_VERSION) and optional Tailscale
root/custom-services.d/          # tailscaled, tailscale-up, mcp-relay
unraid-template/                 # Community Applications template
.github/workflows/build.yml      # multi-arch build to GHCR (amd64 + arm64)
docker-compose.yml               # generic Docker example
```

## Building locally

```
git clone https://github.com/pedrovillalobos/screamingfrog-docker
cd screamingfrog-docker
docker build -t screamingfrog-docker .
```

## Licence

The code in this repository is [MIT](LICENSE). Screaming Frog SEO Spider
itself is proprietary software owned by Screaming Frog Ltd — see [NOTICE](NOTICE).
