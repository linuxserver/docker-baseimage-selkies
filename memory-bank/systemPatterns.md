# System Patterns

## 1. Multi-Stage Docker Build (pattern for every image variant)
`Dockerfile` (amd64) / `Dockerfile.aarch64` (arm64v8) — **any change to one must be mirrored in the other** (aarch64 uses `arm64v8-`-prefixed base tags).

Stages (x86_64 line refs):
| Stage | FROM | Purpose |
|-------|------|---------|
| `xvfb` | `lscr.io/linuxserver/xvfb:debiantrixie` (`Dockerfile:2`) | Prebuilt Xvfb, copied into final image (`Dockerfile:575`) |
| `frontend` | `baseimage-alpine:3.22` (`Dockerfile:3`) | npm build of Selkies dashboards (pinned selkies commit `Dockerfile:19`), output `/buildout` → `/usr/share/selkies` (`Dockerfile:574`) |
| `wtype` | `baseimage-debian:trixie` (`Dockerfile:43`) | Builds `wtype` from `linuxserver/waylandtyper` |
| `wlroots` | `baseimage-debian:trixie` (`Dockerfile:69`) | `apt-get source libwlroots-0.18`, injects `pixman-patch/pass.c` (`Dockerfile:81-95`), builds patched `wl.deb` |
| `selkies-desktop` | `baseimage-debian:trixie` (`Dockerfile:97`) | Builds `selkies-desktop` binary (make) |
| `labwc-builder` | `baseimage-debian:trixie` (`Dockerfile:120`) | Builds labwc 0.9.7 from source + applies `labwc-ipc.patch` (`Dockerfile:284-295`) |
| runtime | `baseimage-debian:trixie` (`Dockerfile:298`) | Installs deps, selkies python venv `/lsiopy`, pelorus, interposer, proot-apps, dind, then `COPY /root /` etc. |

**Pattern**: build-from-source stages exist only for components needing a local patch or a version not in distro repos. A new distro variant repeats this pattern with that distro's package manager and source-build stages where needed.

## 2. s6-overlay Service Model
`root/etc/s6-overlay/s6-rc.d/` — one-shot `init-*` chain + long-running `svc-*` daemons. Ordering via `dependencies.d/` marker files; membership via `user/contents.d/`.

Boot chain (x86_64):
```
init-config → init-selkies (deps: init-os-end) → init-nginx (deps: init-selkies)
→ init-selkies-config (deps: init-nginx) → init-video (deps: init-selkies-config)
→ init-selkies-end (deps: init-video)
```
Services: `svc-dbus`, `svc-xorg`, `svc-nginx`, `svc-pulseaudio`, `svc-de` (deps: svc-nginx, svc-xorg, legacy-cont-init), `svc-selkies` (deps: svc-dbus, svc-nginx, svc-pulseaudio, svc-xorg), `svc-watchdog`, `svc-docker`, `svc-xsettingsd`.

Key scripts:
- `svc-de/run` — **dual-mode branch**: `PIXELFLUX_WAYLAND==true` → wait for wayland socket, run `/defaults/startwm_wayland.sh` (labwc+smithay); else wait for X (`xset q`), set xrandr resolution, run `/defaults/startwm.sh` (openbox). `root/etc/s6-overlay/s6-rc.d/svc-de/run:4-100`
- `init-nginx/run` — generates self-signed cert in `/config/ssl`, seds `/defaults/default.conf` (ports, subfolder, basic auth `.htpasswd`, dashboard copy, PWA manifest).
- `svc-selkies/run` — loads pulseaudio null sinks, optional `DEV_MODE` (pixelflux/core), then `exec selkies --addr=localhost --mode=websockets`.

## 3. Runtime Config / Defaults
- `root/defaults/` — `autostart` (user app entrypoint, default `st`), `autostart_wayland`, `default.conf` (nginx template), `menu.xml`/`menu_wayland.xml`, `labwc.xml`, `startwm.sh`, `startwm_wayland.sh`.
- `root/selkies-proot` — proot-app launcher.
- `root/usr/local/bin/dockerd-entrypoint.sh` — DinD entrypoint.
- Env vars are the config surface: SCREAMING_SNAKE with `${VAR:-default}` (full list in `readme-vars.yml`, rendered to `README.md`).

## 4. Patches (distro-agnostic artifacts, kept at repo root)
- `pixman-patch/pass.c` → replaces `render/pixman/pass.c` in the wlroots 0.18 build.
- `labwc-ipc.patch` → applied to labwc 0.9.7 source (adds IPC used by the desktop integration).

## 5. Generated Files (DO NOT HAND-EDIT)
- `README.md` ← `readme-vars.yml` (upstream builder renders it; see `CONTRIBUTING.md:15-27`).
- `Jenkinsfile` ← upstream pipeline builder.
- `package_versions.txt` — package inventory snapshot (NAME/VERSION/TYPE: deb, python, binary, go-module). Regenerated for each distro variant.

## 6. Pinned External Artifacts
- Selkies commit `348bc4f61da66198573e7e57db9a266aca1991d5` — pinned in **two** places: `Dockerfile:19` (frontend npm build) and `Dockerfile:470` (runtime tarball). Must be changed together.
- pelorus, proot-apps, dind script, themes — fetched at latest release from GitHub at build time (`Dockerfile:482-548`).
- Node 22 via NodeSource (`Dockerfile:335`), docker-ce via download.docker.com debian repo (`Dockerfile:333-334`).

## 7. OS Variants = Git Branches (upstream pattern)
Each supported OS is a **separate branch** of the repo; there is no per-distro file in one branch. Same filenames in every branch, different content:
- `Dockerfile` / `Dockerfile.aarch64` — different `FROM` base, package manager, package lists, and often **fewer build stages** (variants can be feature-reduced, not just re-packaged)
- `jenkins-vars.yml` — `release_tag` + `ls_branch` both set to the branch name (marks the branch as the live variant)
- `root/` — its own copy of the s6 tree + defaults (el9 branch has **no** wayland files at all)
- `readme-vars.yml`, `README.md`, `package_versions.txt` — per-variant

Upstream branches (linuxserver/docker-baseimage-selkies, checked 2026-08-27): `master` (debiantrixie), `el9`, `fedora42`, `fedora43`, `fedora44`, `alpine323`, `alpine324`, `arch`, `kali`, `ubuntunoble`, `ubunturesolute`, `dev`.

**CI detection**: schedulers iterate all remote branches and only build those where branch name == that branch's `jenkins-vars.yml#ls_branch` and `external_type: os` (`external_trigger_scheduler.yml:23-47`). Jenkins job per branch: `docker-baseimage-selkies/<branch>`; image tag = `release_tag`.

**Upstream `el9` variant (key reference for RHEL9 work)**:
- Base: `ghcr.io/linuxserver/baseimage-el:9` (public LS EL9 base, **not** UBI9)
- Only 2 stages: alpine frontend + EL9 runtime — **no** wtype/wlroots/selkies-desktop/labwc/xvfb build stages
- **X11-only**: openbox + `xorg-x11-server-Xorg` + `xorg-x11-drv-dummy` + `xorg-x11-server-Xvfb` (all dnf packages); `root/defaults` has no `*_wayland` files; no `svc-dbus`; `svc-de/run` is the short X11-only version
- dnf repos: `download.docker.com/linux/rhel/docker-ce.repo` only (+ base repos from the baseimage); `glibc-all-langpacks` + `glibc-locale-source` for locales
- sudo: `%wheel ALL=(ALL) NOPASSWD:ALL` via `/etc/sudoers.d/wheel` (EL convention, vs `%sudo` NOPASSWD on Debian)
- Selkies commit **newer**: `159656dfb3f045bf6e041042140bafaf1bbd9c61`; frontend core dir renamed `selkies-web-core` → `gst-web-core`; `pixelflux==1.4.7` installed as PyPI wheel (vs Debian building it in the selkies repo)
- No pelorus in el9; `DIST_IMAGE: fedora` (Jenkins build host)
- Conclusion: adding an RHEL9 variant to this fork can be **seeded from upstream `el9`** rather than written from scratch, then extended for SLU needs (Wayland parity, pelorus, etc.) if required.

## 8. Fedora44 = current EL-family reference (v2 model for rhel9)
`origin/fedora44` (same selkies pin `348bc4f` as master) shows the *current* upstream way of doing an RPM-family variant:
- Stages: `xvfb` (from `lscr.io/linuxserver/xvfb:fedora43`), `frontend` (alpine 3.23), `wtype`, `selkies-desktop`, `labwc-builder` (repo labwc + `wlroots0.19-devel` + patched labwc 0.9.7, `--libdir=lib`), runtime `FROM baseimage-fedora:44`
- Root-tree deltas vs master (only 15 files, all EL-family): `init-nginx/run` one-line `NGINX_CONFIG=/etc/nginx/conf.d/default.conf`; `startwm.sh` drops `dbus-launch` (direct `openbox-session`); `svc-selkies/run` DEV_MODE fully dnf-ified (rust, ffmpeg-devel, x264-devel, `CPATH=/usr/include/ffmpeg`, `+GBM_BACKEND` export) and `XCURSOR_THEME=Breeze_Light`; `init-video/run` drops the Intel i965 VA detection block; **custom `svc-dbus` deleted** (base image provides dbus)
- el9/fedora44 both delete the wayland pieces from `root/defaults` (no `*_wayland` files) — feature-reduced variant pattern (see §7)

**v2 rhel9 model** (proposed; **SUPERSEDED by PLAN v4** — `baseimage-el:9` rejected as deprecated + Oracle-repo-based, see `decisions.md` 2026-08-27 SLU-owned base ADR; current model: `activeContext.md#PLAN-v4`): fedora44 structure → `baseimage-el:9`, drop wayland stages + pelorus + proot + docker (phase 2), keep custom `svc-dbus` (baseimage-el has none — deliberate divergence), keep `dbus-launch` in startwm.sh (verify EL `dbus` pkg provides it; else adopt fedora44's drop), `conf.d` path via a small branch in `init-nginx/run` (stay debian-compatible).
