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

## RHEL9 Stack (shipped c8 `5c835fb6a147` — 2026-08-28; origin: PLAN v4 vetted 2026-08-27, evidence `tasks/2026-08/270827_rhel9-vetting-plan-v4.md`)

**Post-build corrections to the vetting table below**: `cvt`/`gtf` are NOT absent on RHEL9 — they ship in `xorg-x11-server-Xorg`, which we install (F41; vetting's F08 was wrong, and the "svc-de modeline no-op" note is obsolete — modeline applies at client connect via `gst_app_resize`→cvt). WM/DE evolved past phase 1: **standard RHEL GNOME 40 (gnome-shell 40.10) is the default desktop** (task 2, direct launch — F44/F47–F52), openbox remains the `DESKTOP=openbox` fallback; **proot-apps 0.3.2** shipped (R1, F53/F56).
| Concern | fedora44 (reference) | EL9 resolution (verified) |
|---------|---------------------|---------------------------|
| Base | baseimage-fedora:44 | **SLU-owned `base` stage** in Dockerfile.rhel9: `registry.access.redhat.com/ubi9/ubi` (digest-pinned) + entitled RHEL repos (host passthrough) + EPEL9 + s6-overlay 3.2.0.2 + abc uid911 + /lsiopy + docker-mods. ~~baseimage-el:9~~ rejected: **deprecated/frozen + Oracle Linux repos** (yum.oracle.com), not registered RHEL content |
| Xvfb | `COPY --from=xvfb / /` | `dnf install xorg-x11-server-Xvfb` (no copy trick; el9 did same) |
| X tools | standalone `xrandr`, `xrdb`, `cvt` pkgs | `xorg-x11-server-utils` (xrandr/xrdb/xset/xkill verified in rpm) + `xorg-x11-utils` (xprop/xdpyinfo) + `glx-utils` (glxinfo, task 2) + **`cvt`/`gtf` via `xorg-x11-server-Xorg` (F41)** — runtime resize needs them at client connect |
| nginx | nginx + nginx-mod-fancyindex (F44 repos) | nginx (AppStream) + **nginx-mod-fancyindex (EPEL9 0.6.0)** → `default.conf` unmodified |
| WM/DE | openbox, xsettingsd, st, xterm, xfconf | **Default = standard RHEL GNOME 40 (task 2)**: gnome-shell 40.10 + mutter + gnome-session set + gnome-settings-daemon + nautilus 40.2 + gnome-terminal + gedit + gnome-calculator + gnome-screenshot + firefox 140 ESR (all AppStream, F43/F47); direct gnome-shell launch on deterministic session bus (F44/F51), SLU wallpaper via gsettings (F52). **Fallback = openbox** (`DESKTOP=openbox`): EPEL9 openbox 3.6.1 (ships openbox-session; same sed set), xsettingsd 1.0.2, st 0.9 (alternatives; **terminfo fix via `tic /usr/share/doc/st/st.info`** + ncurses), xterm (AppStream 366); xfconf not required by EPEL openbox |
| python | python3 (3.13 on F44) | python3.11 + python3.11-pip (AppStream); pixelflux/pcmflux 2.0.0 cp311 manylinux_2_28 wheels on PyPI ✅ |
| dev (DEV_MODE) | rust/cargo, ffmpeg-devel, x264-devel (F44/rpmfusion) | rust 1.94.1 + cargo (CS9 AppStream!), ffmpeg-devel + x264-devel (rpmfusion-free el9), nodejs 16 (AppStream, fine for nodemon) |
| locales | glibc-all-langpacks + glibc-locale-source + localedef loop | identical packages verified in entitled RHEL9 repos → same loop as fedora44/debian |
| fonts (CJK) | google-noto-cjk-ttc-fonts (Fedora name) | **`google-noto-sans-cjk-ttc-fonts`** (EL9 name, verified AppStream — D3) |
| mesa | mesa-dri-drivers + mesa-va-drivers-freeworld | mesa-dri-drivers **kept** (llvmpipe GLX; el9 dropped it only for DRI3/GPU conflict = phase 2); VA-API GPU drivers = phase 2 |
| GPU drivers | xorg-x11-drv-{amdgpu,ati,intel,nouveau,qxl} | **not in RHEL9** (verified); Xvfb core unaffected. **`ENV DISABLE_DRI3=true` required (D5)**: stock EL9 Xvfb lacks LSIO's `-vfbdevice` patch → crash-loop if `/dev/dri` visible |
| sudoers | `%wheel NOPASSWD` via sudoers.d | **`groupadd sudo` (D4)** then append `%sudo` directly to `/etc/sudoers` so shared hardening sed works |
| dbus | dropped custom svc-dbus (base provides) | **keep custom svc-dbus** (SLU base has no svc-dbus); **`dbus-x11` REQUIRED (D2)** — provides `dbus-launch` for shared startwm.sh (el9 + fedora44 both install it) |
| s6 dep | n/a | ~~legacy-cont-init stub~~ **NONE (D1)** — s6-overlay 3.2.0.2 ships `legacy-cont-init` builtin (base bundle, verified in tarball); a stub would be a duplicate definition and break boot |
| xkb | dep-pulled | `xorg-x11-xkb-utils` installed explicitly (xkbcomp for Xvfb keymaps — D6b) |
| absent/accepted | — | dunst (nothing launches it). **NOT gaps (vetting)**: xdg-utils (AppStream 1.1.3 — D6), breeze-cursor-theme (EPEL9, no RPMFusion needed). cvt/gtf resolved via Xorg package (F41) |
| Agentic | pelorus (Wayland mode), proot-apps | **proot-apps 0.3.2 shipped (R1)**: upstream release tarball → `/proot-apps` (static proot/jq/ncat + script, no dnf deps); `init-selkies-config` bootstrap → `~/.local/bin`; `selkies-proot` RHEL9-guarded bwrap stub (F54/F56); dashboard Install/Update/Remove + app-grid work. pelorus = deferred (not in c8) |

**Upstream el9 lessons** (deprecated 2026-05-10, `project_deprecation_status: true`): worked for months on baseimage-el:9; killed by DRI3/mesa-va conflicts (GPU scope — out of v1). Used older selkies pin (159656df) + python3.9 — we stay on master parity (348bc4f + py3.11).
