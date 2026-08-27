# Tech Context

## Current Stack (Debian-trixie variant)
| Layer | Technology |
|-------|-----------|
| Runtime base | `ghcr.io/linuxserver/baseimage-debian:trixie` (s6-overlay init, user `abc` uid 1000, `HOME=/config`) |
| Frontend build base | `ghcr.io/linuxserver/baseimage-alpine:3.22` (nodejs/npm) |
| Xvfb | `lscr.io/linuxserver/xvfb:debiantrixie` stage copied whole into runtime |
| X11 desktop | xorg-xorg-core + drivers (intel/amdgpu/ati/nouveau/qxl), openbox, xsettingsd, x11-apps/utils, xkb-data |
| Wayland desktop | labwc 0.9.7 (source+patch) on wlroots 0.18 (patched deb), smithay (userspace compositor), wtype, wl-clipboard, wlr-randr |
| Streaming | selkies (python, venv `/lsiopy`, commit-pinned), pixelflux, pcmflux |
| Audio | pulseaudio + utils (null sinks for capture) |
| Web | nginx + `libnginx-mod-http-fancyindex`, basic auth (apr1 htpasswd), self-signed certs |
| Container-in-container | docker-ce/containerd.io from Docker Inc repo, `dind` script, `dockremap` subuid user, fuse-overlayfs |
| GPU/accel | mesa (dri/va/vulkan), vainfo, vulkan-tools, intel-media-va-driver, i965-va-driver-shaders, `libnvidia-egl-wayland1`, Zink/DRI3 env switches |
| Agentic | pelorus (`/pelorus` API + web UI, Wayland mode), proot-apps (`/proot-apps`) |
| Locales | `locales-all` + runtime `localedef` from `thelamer/lang-stash` list |

## aarch64 Variant
`Dockerfile.aarch64` mirrors `Dockerfile` with `arm64v8-`-prefixed base tags (`Dockerfile.aarch64:2-3,43,69,97,120,298`). Multiarch handled upstream by Jenkins (`MULTIARCH=true`, `jenkins-vars.yml:19`); repo keeps **separate per-arch Dockerfiles** (not buildx matrix).

## CI / Release
- Jenkins job `Docker-Pipeline-Builders/docker-baseimage-selkies/<branch>` driven by `jenkins-vars.yml` (`release_tag: debiantrixie`, `ls_branch: master`, `DIST_IMAGE: ubuntu`, `CI_WEB=true`, `CI_PORT=3001`, `CI_SSL=true`).
- Registries: `lsio/base/selkies` (DOCKERHUB_IMAGE `lsiobase/selkies`), `ghcr.io/linuxserver/baseimage-selkies`, GitLab, Quay. Dev/PR images: `lsiodev-` / `lspipepr-` prefixes (`Jenkinsfile:200-250`).
- GitHub workflows: package-check + external-trigger schedulers calling Jenkins (`.github/workflows/*_scheduler.yml`).

## RHEL9 Target Stack (plan v2 — fedora-based, 2026-08-27 audit)
| Concern | fedora44 (reference) | EL9 resolution (verified) |
|---------|---------------------|---------------------------|
| Base | baseimage-fedora:44 | `lscr.io/linuxserver/baseimage-el:9` (UBI9, s6-overlay 3.2.0.2, rpmfusion enabled, abc uid911, /lsiopy, docker-mods); tags `:9` / `:9-version-f81d91cc` |
| Xvfb | `COPY --from=xvfb / /` | `dnf install xorg-x11-server-Xvfb` (no copy trick; el9 did same) |
| X tools | standalone `xrandr`, `xrdb`, `cvt` pkgs | `xorg-x11-server-utils` (xrandr/xrdb/xset/xkill verified in rpm) + `xorg-x11-utils` (xprop/xdpyinfo); **`cvt` absent** (svc-de modeline no-ops; `libxcvt` pkg is lib-only) |
| nginx | nginx + nginx-mod-fancyindex (F44 repos) | nginx (AppStream) + **nginx-mod-fancyindex (EPEL9 0.6.0)** → `default.conf` unmodified |
| WM/DE | openbox, xsettingsd, st, xterm, xfconf | EPEL9 openbox 3.6.1 (ships openbox-session; same sed set), xsettingsd 1.0.2, st 0.9 (alternatives; **terminfo fix via `tic -i /usr/share/doc/st/st.info`** + ncurses), xterm (AppStream 366); xfconf not required by EPEL openbox |
| python | python3 (3.13 on F44) | python3.11 + python3.11-pip (AppStream); pixelflux/pcmflux 2.0.0 cp311 manylinux_2_28 wheels on PyPI ✅ |
| dev (DEV_MODE) | rust/cargo, ffmpeg-devel, x264-devel (F44/rpmfusion) | rust 1.94.1 + cargo (CS9 AppStream!), ffmpeg-devel + x264-devel (rpmfusion-free el9), nodejs 16 (AppStream, fine for nodemon) |
| locales | glibc-all-langpacks + glibc-locale-source + localedef loop | identical packages in CS9 (BaseOS/AppStream) → same loop as fedora44/debian |
| mesa | mesa-dri-drivers + mesa-va-drivers-freeworld | mesa-dri-drivers **kept** (llvmpipe GLX; el9 dropped it only for DRI3/GPU conflict = phase 2); VA-API GPU drivers = phase 2 |
| GPU drivers | xorg-x11-drv-{amdgpu,ati,intel,nouveau,qxl} | **not in CS9** (phase 2 with real RHEL9 repos); Xvfb core unaffected |
| sudoers | `%wheel NOPASSWD` via sudoers.d | append directly to `/etc/sudoers` so shared hardening sed works |
| dbus | dropped custom svc-dbus (base provides) | **keep custom svc-dbus** (baseimage-el has no svc-dbus); verify `dbus-launch` in EL dbus pkg |
| s6 dep | n/a | EL-only `legacy-cont-init` no-op oneshot stub in Dockerfile (baseimage-el user bundle lacks it; master PR #184 requires it for svc-de) |
| absent/accepted | — | breeze-cursor-theme (cursor fallback), dunst (nothing launches it), xdg-utils (exo covers exo-open) |

**Upstream el9 lessons** (deprecated 2026-05-10, `project_deprecation_status: true`): worked for months on baseimage-el:9; killed by DRI3/mesa-va conflicts (GPU scope — out of v1). Used older selkies pin (159656df) + python3.9 — we stay on master parity (348bc4f + py3.11).
