# Storage performance — the details

This page explains *why* disk choice matters so much for this container, how to measure your disks, and what to do on each platform. For the short version, see the [README](../README.md#where-to-put-your-data-important).

## Why the app is so sensitive to disk choice

In Database Storage mode, the SEO Spider uses an embedded database (Apache Derby) that lives inside `/config` by default. Derby guarantees durability by issuing **synchronous writes (fsync)** constantly — and the app bootstraps a brand-new instance database on **every launch**.

This is not an Unraid problem and not a Docker problem. Bind mounts add no meaningful overhead; the cost comes entirely from the **sync-write latency of the underlying disk and filesystem**. The same hardware would behave the same on bare metal.

Slow sync writes show up as three symptoms:

1. **App startup takes minutes**, stuck on the "deleting unused backups" splash screen — that's the database bootstrap (thousands of small fsyncs).
2. **Crawls run slower** — every crawled URL is persisted to the database.
3. **Opening and saving large crawls takes long.**

## Measure your disks

Run this on each candidate path (host side):

```
dd if=/dev/zero of=/path/to/test/sync-test bs=4k count=1000 oflag=dsync
rm /path/to/test/sync-test
```

Reference values for the 1000 sync writes:

| Storage | Typical result |
|---|---|
| Local NVMe SSD | a few seconds |
| Decent SATA TLC SSD | tens of seconds |
| QLC SSD (e.g. Samsung QVO) on btrfs | **minutes** |
| Network-attached cloud volume (DO Volumes, EBS, etc.) | **minutes** |

Whatever wins this test is where the database should live.

## Unraid specifics

Two extra pitfalls on Unraid:

- **Never use `/mnt/user/...` paths for this container.** The `/mnt/user` FUSE layer adds overhead to every file operation, on top of whatever disk is underneath. Use the direct pool path instead (e.g. `/mnt/nvme_pool/appdata/screamingfrog`).
- **Cache pools are often btrfs on budget QLC SSDs** — the worst combination for fsync latency. If your appdata share lives on one of these, point this container's Appdata at your NVMe pool instead, or use the [fallback](#fallback-split-the-database-out) below.

## Cloud / VPS specifics (DigitalOcean, AWS, etc.)

Network-attached block storage (DigitalOcean Volumes, AWS EBS and similar) has high sync-write latency by nature. Keep `/config` (or at least `/database`) on the instance's **local disk**. If the local disk is too small for your crawls, expect the symptoms above when crawling to a network volume — it works, just slowly.

## Fallback: split the database out

If you can't put all of `/config` on the fast disk (small NVMe, very large crawls, or an established appdata layout you don't want to change):

1. Map a second volume: fast disk → container `/database` (the Unraid template ships an optional "Database directory" path; the compose example has a commented line for it).
2. In the app: `File > Settings > Storage Mode` → set the database location to `/database`. One-time setting; it persists in `/config`.

Licence, configuration and exports stay in `/config`; only the heavy database I/O moves to the fast disk.