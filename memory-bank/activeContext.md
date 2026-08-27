# Active Context

**Last Updated**: 2026-08-27 | **State Machine**: `PLAN` (RHEL9 v2 — fedora-based; presented, awaiting approval)

## Git Reality (changed 2026-08-27)
- `origin` = **user's fork** `git@github.com:dGilli/docker-baseimage-selkies.git` (commits/pushes allowed)
- `upstream` = `linuxserver/docker-baseimage-selkies` — **push DISABLED, never push there**
- Branch `rhel9` created from `master` (upstream tip `69f4fc9`, incl. PR #184 svc-de→legacy-cont-init fix)
- Old local baseline commits (`eb4e145`/`ed91a5a`) are gone (repo re-initialized as full upstream clone); memory-bank re-committed on `rhel9`
- User checked out `fedora42` first; `fedora43`/`fedora44` available on `upstream` refs — **fedora44 = reference** (same selkies pin 348bc4f as master)

## Task: Add RHEL 9 to the supported images
### User Decisions (recorded)
UBI9 base (via `lscr.io/linuxserver/baseimage-el:9`) | x86_64 first | `Dockerfile.rhel9` in-repo | local podman (5.8.2) | scope: **desktop + streaming first** (defer: DinD, GPU/Zink, proot-apps, pelorus, Wayland)

### PLAN v2 (fedora-based) — key re-architecture vs v1
**Model**: `Dockerfile.rhel9` = **fedora44's Dockerfile** with EL9 substitutions, NOT a Debian port.
- `FROM lscr.io/linuxserver/baseimage-el:9` (UBI9 + s6-overlay 3.2.0.2 + rpmfusion enabled + abc + /lsiopy + docker-mods) — proven by upstream's own (deprecated) `origin/el9` branch which used this exact base
- **No `COPY --from=xvfb / /`** — direct `dnf install xorg-x11-server-Xvfb` (el9 did same)
- Keep `frontend` stage verbatim (alpine, selkies 348bc4f)
- **Drop** wtype/selkies-desktop/labwc-builder stages + wayland pkgs + pelorus + proot-apps + docker/dind (phase 2)
- **Shared `root/` tree: nearly untouched** — fedora44 already showed the EL-family adaptations; v2 needs only:
  1. `init-nginx/run`: conf path branch (sites-available → conf.d when absent) [fedora44 did the one-line swap; we branch to stay debian-compatible]
  2. `svc-selkies/run`: adopt fedora44's dnf-based DEV_MODE (verified: rust 1.94.1 + cargo in CS9 AppStream; ffmpeg-devel + x264-devel in rpmfusion-free; nodejs 16 in AppStream = fine for nodemon)
  3. `init-selkies-config/run`: guard proot block `[ -d /proot-apps ]`
  4. `svc-docker/run`: `command -v dockerd || sleep infinity` guard
- **nginx**: `nginx` (AppStream) + `nginx-mod-fancyindex` (**EPEL9!**) → shared `default.conf` works **unmodified** (v1 planned to strip /files — no longer needed)
- **locales**: same `localedef` loop as fedora44/el9 — `glibc-all-langpacks` + `glibc-locale-source` verified in CS9 ✅
- **openbox**: EPEL9 3.6.1 = same as debian; fedora44/el9 sed set applies (no `/debian-menu/d` line); Clearlooks theme present in EPEL openbox ✅
- **st**: EPEL9 st (alternatives → /usr/bin/st) + `tic -i /usr/share/doc/st/st.info` terminfo fix (ncurses pkg); xterm (AppStream) as second terminal
- **python**: `python3.11` + `python3.11-pip` (AppStream) — pixelflux/pcmflux 2.0.0 cp311 manylinux_2_28 wheels exist on PyPI ✅ (no rust needed at runtime)
- **X tools**: `xorg-x11-server-utils` provides xrandr/xrdb/xset/xkill/xhost (verified in rpm); `xorg-x11-utils` provides xprop/xdpyinfo (openbox-session needs xprop); xorg-x11-xauth
- **sudoers**: append `%wheel ALL=(ALL) NOPASSWD: ALL` directly to `/etc/sudoers` (NOT only sudoers.d) so shared hardening sed (`sed /etc/sudoers NOPASSWD`) works on EL
- **legacy-cont-init stub** (EL-only, in Dockerfile, not shared tree): baseimage-el user bundle lacks it; master's PR #184 makes svc-de depend on it
- **mesa-dri-drivers**: KEEP (v1 was unsure). Upstream el9 dropped it only for the DRI3/GPU `-vfbdevice` conflict (out of our scope); CPU llvmpipe GLX needs it for browser/desktop GL apps

### Verified EL9 gaps (accepted degradations, phase-2 candidates)
`cvt` binary (svc-de modeline step no-ops — F44 has standalone cvt pkg, EL9 doesn't) | breeze-cursor-theme (default cursor fallback) | xorg-x11-drv-{intel,amdgpu,nouveau,qxl} (not in CS9 — real RHEL9 repos phase 2, GPU work) | dunst | xdg-utils | mesa-va-drivers (VA-API GPU only)

### Upstream lessons (from `origin/el9`, deprecated 2026-05)
- el9 worked for months (bot builds) → deprecated after DRI3/mesa conflicts + `project_deprecation_status: true` in readme-vars
- Their selkies pin was older (159656df) and they pinned `pixelflux==1.4.7` manually — we stay on 348bc4f (master parity) with auto-resolved pixelflux (cp311 wheel verified)
- They used `python3` (3.9!) venv without --system-site-packages — we use 3.11 + --system-site-packages (master parity)

## Working Context
- Branch: `rhel9` (from upstream master 69f4fc9) | tree = master + untracked memory-bank (commit pending)
- Scratch audit data: /tmp/cs9_*.html, epel_*.html, rff/rfn primary, audit_cs9.txt (disposable)
- Podman 5.8.2 on host (user confirmed)
