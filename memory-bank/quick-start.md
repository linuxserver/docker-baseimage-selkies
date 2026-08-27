# Quick Start

## Build (local)
```bash
# amd64 (Debian variant)
docker build -t baseimage-selkies:dev .

# aarch64 (Debian variant)
docker build -f Dockerfile.aarch64 --platform linux/arm64 -t baseimage-selkies:dev-arm64 .
```
RHEL9 variant (PLAN v4 — **builds only on a subscription-registered RHEL host**):
```bash
# preflight (once per host): entitlement passthrough must work
podman run --rm registry.access.redhat.com/ubi9/ubi dnf repolist   # expect rhel-9-for-x86_64-*
podman build -f Dockerfile.rhel9 -t dgilli/baseimage-selkies:rhel9-p1 .
```
Full phase-1 test procedure (run, smoke checks, v4 negative matrix): `activeContext.md#PLAN-v4` section D.

## Run / smoke test
```bash
docker run -it --rm -p 3000:3000 -p 3001:3001 -e TZ=America/Chicago baseimage-selkies:dev
# in another shell:
curl -sI http://localhost:3000/          # expect 200/301 (dashboard)
curl -skI https://localhost:3001/        # self-signed TLS
docker logs <container> 2>&1 | tail -50  # s6 boot chain: init-* → svc-*
```
Checks that matter:
- s6 chain completes (`init-selkies-end` runs)
- `svc-xorg` up (X11 mode) or wayland socket appears (Wayland mode: `-e PIXELFLUX_WAYLAND=true`)
- `svc-nginx` serving the dashboard; `svc-selkies` exec'd selkies
- For privileged/DinD use: `docker run --privileged ...`

## Dev mode
- `-e DEV_MODE=pixelflux` — runs pixelflux backend under nodemon with a source checkout in `/config/src` (see `svc-selkies/run`).
- `-e DEV_MODE=<dashboard>` — frontend dev server for the named dashboard.

## Where things are
| Thing | Location |
|-------|----------|
| Build (amd64/arm64) | `Dockerfile`, `Dockerfile.aarch64` |
| Service tree | `root/etc/s6-overlay/s6-rc.d/` |
| Desktop defaults | `root/defaults/` (`startwm*.sh`, `autostart*`, `default.conf`, menus) |
| CI vars | `jenkins-vars.yml` (+ generated `Jenkinsfile`) |
| README source | `readme-vars.yml` |
| Patches | `labwc-ipc.patch`, `pixman-patch/pass.c` |
| Package inventory | `package_versions.txt` |
