# Screaming Frog SEO Spider — Docker / Unraid (unofficial)

[Screaming Frog SEO Spider](https://www.screamingfrog.co.uk/seo-spider/) running in your browser (linuxserver.io Webtop + KasmVNC), with:

- **Full GUI in the browser** — identical to the desktop app, at `https://HOST:3001` (self-signed certificate)
- **Native MCP server (v24+) exposed** to your LAN/tailnet for Claude Code, Claude Desktop, Cursor, or any MCP-compatible client
- **Optional Tailscale egress** (userspace, installed at runtime only if you enable it) — **only crawl traffic** exits through a fixed-IP exit node via a local proxy, without touching GUI/MCP/LAN traffic
- **Easy updates**: `SF_VERSION` sets the minimum version; the in-app updater also works. Licence, configs and crawls persist in `/config`
- **JavaScript rendering** supported (embedded Chromium; needs `--shm-size=2g`)
- **Multi-arch**: `linux/amd64` and `linux/arm64`

> ## ⚠️ Licence required
> Screaming Frog SEO Spider is **paid, proprietary software**. The free tier is limited to 500 URLs per crawl, and **MCP, headless CLI, saving crawls and configuration files require a paid licence**, purchased directly from [Screaming Frog](https://www.screamingfrog.co.uk/seo-spider/licence/). Enter your licence once in the GUI (`Licence > Enter Licence`) — it persists in `/config`.

> ## Transparency / what this image is
> - This is an **unofficial community project**, not affiliated with or endorsed by Screaming Frog Ltd. "Screaming Frog" is their trademark. See [NOTICE](NOTICE).
> - The image **does not bundle or redistribute** Screaming Frog. The official installer is downloaded **from screamingfrog.co.uk on your machine** at container start. Your use of the software is governed by the Screaming Frog EULA.
> - Tailscale is also **not shipped in the image** — it is installed at runtime only when `TS_ENABLED=true`.
> - Everything the container does at startup is in plain bash under [`root/custom-cont-init.d`](root/custom-cont-init.d) and [`root/custom-services.d`](root/custom-services.d).

## Security

The KasmVNC GUI and the MCP endpoint have **no built-in authentication**. Keep these ports on your LAN, VPN or tailnet only. **Never publish them to the internet.**

---

## Install on Unraid (Community Applications)

1. Search for **ScreamingFrog-SEO-Spider** in Apps (or add the template from [`unraid-template/`](unraid-template/)).
2. The install screen pre-fills everything; adjust if needed:
   - **WebUI port** (default `3001`, HTTPS) and **MCP port** (default `11435`)
   - **Appdata**: default `/mnt/user/appdata/screamingfrog` — change it to a direct path on your fastest pool, ideally NVMe (e.g. `/mnt/nvme_pool/appdata/screamingfrog`). See [Where to put your data](#where-to-put-your-data-important).
   - **SF_VERSION** (minimum version, see [Updating](#updating-screaming-frog))
3. Apply. First start downloads the official installer (~900 MB), then the GUI is available at `https://SERVER_IP:3001` — the certificate is self-signed, so accept the browser warning. The SEO Spider opens automatically. (Plain HTTP on container port 3000 is refused by the web client, which requires a secure context.)
4. Enter your licence, then set `File > Settings > Storage Mode` to **Database Storage** and adjust `File > Settings > Memory Allocation` (see [Memory](#memory)).
5. **Important**: make sure your data lives on a fast disk — see [Where to put your data](#where-to-put-your-data-important).

> **Unraid's built-in Tailscale toggle**: do **not** combine this container with Unraid's per-container Tailscale option using an **Exit Node**. In that mode all container traffic — including replies to your LAN — is routed through the exit node, which breaks LAN access to the GUI and MCP ports. For fixed-IP crawl egress use the [`TS_ENABLED`](#tailscale--fixed-ip-crawl-egress-optional) variables of this image instead, which route **only crawl traffic** through the exit node. Unraid's toggle *without* an exit node (remote access only) works fine.

## Install with plain Docker / Docker Compose

```yaml
services:
  screamingfrog:
    image: ghcr.io/pedrovillalobos/screamingfrog-docker:latest
    container_name: screamingfrog
    environment:
      - PUID=1000              # your user id (id -u)
      - PGID=1000              # your group id (id -g)
      - TZ=Etc/UTC
      - TITLE=Screaming Frog
      - SF_VERSION=24.3        # minimum version, see "Updating" below
      - TS_ENABLED=false       # see "Tailscale" below before enabling
      - TS_EXIT_NODE=
    ports:
      - "3001:3001"            # GUI (HTTPS, self-signed cert)
      - "11435:11436"          # MCP
    volumes:
      - ./appdata:/config      # licence, configs, crawls, exports
    shm_size: "2gb"            # required for JavaScript rendering
    security_opt:
      - seccomp=unconfined     # linuxserver recommendation for Chromium apps
    restart: unless-stopped
```

`docker compose up -d`, then open `https://HOST:3001` (accept the self-signed certificate warning).

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `SF_VERSION` | `24.3` | **Minimum** Screaming Frog version. Installs only if nothing is installed or the installed version is older — never reinstalls the same version, never downgrades. Raise it + restart to force an update. |
| `TS_ENABLED` | `false` | Installs and starts Tailscale (userspace) at runtime. Read [Tailscale](#tailscale--fixed-ip-crawl-egress-optional) before enabling. |
| `TS_EXIT_NODE` | *(empty)* | Tailscale hostname/IP of the exit node for crawl egress. |
| `PUID` / `PGID` | `99` / `100` | File ownership for `/config` (Unraid defaults shown; use `1000`/`1000` on most Linux distros). |
| `TZ` | — | Timezone, e.g. `America/Sao_Paulo`. |
| `TITLE` | — | Browser tab title (Webtop). |

## Memory

Set how much memory the app can use in `File > Settings > Memory Allocation` (e.g. 8–16 GB for large crawls). The setting is stored in `/config` and **persists across restarts, re-creations and updates**.

**Do not set a Docker memory limit equal to that value**: the app needs extra memory on top of it for its own runtime and the embedded browser used for JavaScript rendering. If you want a container limit, set it roughly 30–40% above the app's memory allocation (e.g. allocation 12 GB → limit 16 GB).

## MCP server (Claude Code, Cursor, etc.)

Requires SF v24+ and a paid licence.

1. In the SEO Spider: `Settings > MCP Server` → enable it and set the base directory to `/config/mcp-workdir` (visible on the host inside your appdata folder).
2. Register it in your client, e.g. Claude Code:
   ```
   claude mcp add --transport http screaming-frog http://HOST_IP:11435/mcp
   ```
3. The SEO Spider app must be running for the MCP server to respond — this container keeps it open in the Webtop session automatically.

The MCP server natively listens on loopback only; a small `socat` relay inside the container exposes it on container port `11436` so it can be published.

## Tailscale / fixed-IP crawl egress (optional)

Use this when crawls must originate from a fixed, whitelisted IP (a Tailscale exit node), while the GUI and MCP stay directly reachable on your LAN.

How it works: `tailscaled` runs in **userspace networking** mode inside the container and exposes a local outbound HTTP proxy on `localhost:1056` (SOCKS5 on `1055`). Only traffic the SEO Spider sends through that proxy leaves via the exit node — everything else (GUI, MCP, LAN) is untouched. This is why it does not suffer from the asymmetric-routing problem that kernel-mode exit nodes cause on bridge networks.

Authentication is **manual by design** — this image deliberately does not accept Tailscale auth keys via environment variables, since env vars are visible in container inspect output, templates and logs. You log in once and the session persists in `/config/tailscale`.

1. Set `TS_ENABLED=true` (and optionally `TS_EXIT_NODE` so the exit node is re-applied automatically after container re-creations).
2. Authenticate once:
   ```
   docker exec -it screamingfrog tailscale up --exit-node=NODE
   ```
   Open the printed URL in your browser to approve the device. Afterwards, in the Tailscale admin console (Machines), consider enabling "Disable key expiry" for this device so it never needs re-authentication.
3. Verify the egress IP:
   ```
   docker exec screamingfrog curl -s -x http://localhost:1056 https://ifconfig.me
   ```
   It must return your exit node's public IP.
4. In the SEO Spider: `Config > System > Proxy` → host `localhost`, port `1056`.
5. Remote access over your tailnet: `https://TAILSCALE_IP:3001` (GUI) and `http://TAILSCALE_IP:11436/mcp` (MCP).

State persists in `/config/tailscale`. Because Tailscale is installed at runtime (never shipped in the image), enabling it re-downloads the package on each container re-creation (~30s).

**Changing preferences later**: use `tailscale set`, never `tailscale up` — `tailscale up` resets every preference you don't pass explicitly, including `--accept-dns=false`, which this container relies on (in userspace mode, accepting Tailscale DNS points the container's resolv.conf at an unreachable resolver and breaks name resolution). The container re-applies the safe DNS setting automatically whenever Tailscale connects.

## Updating Screaming Frog

`SF_VERSION` is a **minimum version**, and updates can happen two ways:

- **Bump the variable**: set e.g. `SF_VERSION=24.2` and restart the container.
- **In-app updater**: when the app offers a new version, accepting it works too — the init script never downgrades an installed version.

Implementation detail worth knowing: the install lives in the container's writable layer, so it survives **restarts** but is redone after a **re-creation** (template edit, image update). The downloaded installer is cached in `/config/installers` to make that fast. Licence, configuration, crawls and exports in `/config` are never touched.

## Custom configurations

Put your `.seospiderconfig` files in `/config/sf-configs`. Load them via the GUI (`File > Configuration > Load`), via headless CLI (`--config`), or reference them in MCP crawl tools.

## Where to put your data (important)

The app keeps its crawl database inside `/config`, and it is very sensitive to disk speed. **Put `/config` on the fastest local disk you have — ideally an NVMe SSD.** On a slow disk the app takes minutes to open, crawls run slower, and saved crawls take long to load.

- **Unraid**: point the Appdata path at your NVMe pool using the direct path (e.g. `/mnt/nvme_pool/appdata/screamingfrog`) — never a `/mnt/user/...` path.
- **Cloud / VPS (DigitalOcean, AWS, ...)**: use the server's local disk, not a network-attached volume.
- **Can't move everything to the fast disk?** Map just the database: add a volume from the fast disk to `/database`, then in the app set `File > Settings > Storage Mode` → database location to `/database` (one-time setting).

Why this matters, how to benchmark your disks, and platform details: [docs/STORAGE.md](docs/STORAGE.md).

## Troubleshooting

**dbus "Permission denied" messages in the container log** (`org.freedesktop.login1` / `org.freedesktop.PolicyKit1`): harmless and expected in linuxserver Webtop containers — there is no systemd/logind inside the container and the session runs as an unprivileged user. They are usually the last visible log lines while slower, silent work happens (the ~1 GB package unpack on first install, and the SEO Spider's own startup, which does not write to the container log).

**Slow first start / start after re-creation**: the install unpacks ~1 GB into the Docker image filesystem; on slower SSDs this takes a few minutes. Use `docker logs -t <container>` to see timestamps and find where time is actually spent. On Unraid, prefer a direct disk path such as `/mnt/cache/appdata/screamingfrog` over `/mnt/user/...` for `/config`.

**App takes 2+ minutes on the "deleting unused backups" splash on every launch, crawls are slow, or saved crawls take long to open**: your data is on a disk with poor sync-write latency — see [Where to put your data](#where-to-put-your-data-important) and [docs/STORAGE.md](docs/STORAGE.md).

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

The code in this repository is [MIT](LICENSE). Screaming Frog SEO Spider itself is proprietary software owned by Screaming Frog Ltd — see [NOTICE](NOTICE).