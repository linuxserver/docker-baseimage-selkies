# Quick Start

## Build (local)
```bash
# amd64 (Debian variant)
docker build -t baseimage-selkies:dev .

# aarch64 (Debian variant)
docker build -f Dockerfile.aarch64 --platform linux/arm64 -t baseimage-selkies:dev-arm64 .
```
RHEL9 variant — **builds only on a subscription-registered RHEL host** (entitlement passthrough):
```bash
# preflight (once per host): entitlement passthrough must work
podman run --rm registry.access.redhat.com/ubi9/ubi dnf repolist   # expect rhel-9-for-x86_64-*
podman build -f Dockerfile.rhel9 -t dgilli/baseimage-selkies:rhel9-p1-gnome .
# dev registry push (F30; rootless podman login docker.io as dgilli)
podman tag dgilli/baseimage-selkies:rhel9-p1-gnome docker.io/dgilli/selkies-rhel9:latest
podman push docker.io/dgilli/selkies-rhel9:latest    # OCI manifest; pin by registry digest
```
Current: c8 `5c835fb6a147` (GNOME default desktop + SLU wallpaper + R1 proot-apps). Build/verify history: `tasks/2026-08/270827_rhel9-build.md`, `280828_rhel9-gnome-desktop.md`, `280828_r1-proot-apps.md`.

## Run / smoke test
```bash
# RHEL9 variant (GNOME default; creds abc/baseimage123 baked for dev):
podman run -d --name selkies-rhel9-test -p 3000:3000 -p 3001:3001 -p 8082:8082 \
  -e TZ=America/Chicago -e USERNAME=abc -e PASSWORD=baseimage123 \
  dgilli/baseimage-selkies:rhel9-p1-gnome
# in another shell:
curl -s -o /dev/null -w '%{http_code}\n' -u abc:baseimage123 http://localhost:3000/   # 200
curl -sk -o /dev/null -w '%{http_code}\n' -u abc:baseimage123 https://localhost:3001/  # 200
podman exec -u abc selkies-rhel9-test pgrep -x gnome-shell                            # R1+ : also check $HOME/.local/bin/proot-apps
# selkies ws (same-origin through nginx; 8082 is internal):
curl -s -u abc:baseimage123 -o /dev/null -w '%{http_code}\n' --max-time 3 \
  -H 'Connection: Upgrade' -H 'Upgrade: websocket' -H 'Sec-WebSocket-Version: 13' \
  -H 'Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==' http://localhost:3000/websocket    # 101
# desktop screenshot (autonomous verify):
podman exec -u abc selkies-rhel9-test sh -c 'DISPLAY=:1 gnome-screenshot -f /tmp/s.png'
podman cp selkies-rhel9-test:/tmp/s.png /tmp/
```
Debian dev variant: `docker run -it --rm -p 3000:3000 -p 3001:3001 -e TZ=America/Chicago baseimage-selkies:dev` + same curls.
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
| Build (RHEL9) | `Dockerfile.rhel9` (+ vendored s6 tree `root-base/`) |
| Service tree | `root/etc/s6-overlay/s6-rc.d/` |
| Desktop defaults | `root/defaults/` (`startwm*.sh`, `autostart*`, `default.conf`, menus); SLU wallpaper `root/usr/share/backgrounds/slu-rhel.jpg` |
| NRP k8s mapping | `deploy/nrp-selkies-rhel9.yaml` |
| CI vars | `jenkins-vars.yml` (+ generated `Jenkinsfile`) |
| README source | `readme-vars.yml` |
| Patches | `labwc-ipc.patch`, `pixman-patch/pass.c` |
| Package inventory | `package_versions.txt` (Debian), `package_versions_rhel9.txt` (RHEL9) |
