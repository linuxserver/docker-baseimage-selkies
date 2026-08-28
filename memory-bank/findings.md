# Findings & Hurdles

**Project**: `slu-docker-rhel-selkies` — RHEL9 variant work (branch `rhel9`)
**Purpose**: Living registry of technical findings, verified facts, and hurdles discovered during RHEL9 research, plan vetting, and planning. One numbered entry per finding (`F01`…) with date, evidence, and status — referenceable as `findings.md#F16`. Full evidence lives in the memory bank (`memory-bank/`); this file is the cross-cutting tracker. New findings: append at the end of the matching section, keep numbering monotonic.

**Status legend**: ✅ resolved | ⚠️ accepted degradation | 🚧 hurdle/constraint (workaround documented) | 🔓 open (needs decision or verification)

**Last updated**: 2026-08-27

---

## Hurdles at a Glance

| Hurdle | Entries |
|--------|---------|
| Image builds only on subscription-registered RHEL hosts (entitlement passthrough) | F03 |
| 100% Red Hat-supported content impossible — desktop layer is EPEL-only | F04 |
| RHEL9 package/tooling deltas break Fedora/master-derived assumptions (names, pins, flags) | F31-F35 |
| No Xorg DDX drivers / VA-API GPU drivers in RHEL9 → GPU is phase 2 | F06, F07 |
| RHEL9 packaging deltas vs Fedora/master (pkg names, selkies pins, tic flag, dnf provenance) | F31-F35, F40 |
| Upstream CI = one branch per OS; our in-repo `Dockerfile.rhel9` deviates | F22 |
| NRP deployment must permit root (LSIO-parity image is rootful) | F26 |

---

## 1. Base Image & Repos

### F01 — `baseimage-el:9` is UBI9 + **Oracle Linux 9** repos, not registered RHEL
Its Dockerfile disables the subscription-manager dnf plugin and ships `oracle-linux-ol9.repo` (`yum.oracle.com`). Every `dnf install` in a derived image pulls **Oracle** packages, not RHEL content.
**Status**: ✅ resolved 2026-08-27 — rejected; PLAN v4 vendors an SLU-owned `base` stage `FROM registry.access.redhat.com/ubi9/ubi` with entitled RHEL repos.
**Evidence**: `memory-bank/tasks/2026-08/270827_rhel9-vetting-plan-v4.md#2`

### F02 — `docker-baseimage-el` is **deprecated and frozen**
GitHub README: "This image is deprecated… it will not be updated." Pinned tag `9-version-f81d91cc` already behind `9-version-5a65c068`; no future CVE updates.
**Status**: ✅ resolved — rejection driver for F01/F04 strategy.
**Evidence**: vetting doc §2

### F03 — Entitlement passthrough makes builds host-dependent
podman on a registered RHEL host auto-mounts entitlements into builds → a local build can silently resolve packages from real RHEL repos while a remote build resolves elsewhere (non-reproducible split).
**Status**: 🚧 hurdle — v4 makes entitled RHEL repos the *intended* source and captures per-package repo provenance (`dnf repoquery --installed --qf '%{name}|%{version}|%{reponame}'` → `package_versions_rhel9.txt`). Builds only on entitled RHEL hosts; runtime/NRP needs no entitlement.
**Evidence**: vetting doc §2.4, §6.4; `memory-bank/build-deployment.md`

### F04 — "Fully supported" ceiling: the desktop layer is EPEL-only
Verified absent from all RHEL9 repos: `openbox st xsettingsd nginx-mod-fancyindex xdotool xclip xsel exo breeze-cursor-theme`. 100% Red Hat-supported content is impossible for this stack.
**Status**: ⚠️ accepted — entitled RHEL BaseOS/AppStream/CRB wherever available + documented EPEL delta (provenance artifact is the evidence).
**Evidence**: vetting doc §2.4

### F05 — `rhel-guest-image` is not a container base
`registry.redhat.io/rhel9/rhel-guest-image:latest` = qcow2 VM disk delivery vehicle (rhel-guest-image-9.8-20260428.2, 12 files, empty content-sets).
**Status**: ✅ resolved (informational) — if a true RHEL9 container base is wanted later: `registry.redhat.io/rhel9/rhel-core:9` (subscription) vs UBI9 (free, current plan).
**Evidence**: `memory-bank/activeContext.md#Guest-image-note`

## 2. RHEL9 Package Availability (verified 2026-08-27 on subscribed RHEL 9.8 host, real cdn.redhat.com repos)

### F06 — No Xorg DDX drivers in RHEL9
AppStream has only `xorg-x11-drv-{dummy,evdev,fbdev,v4l,vmware,wacom}`; **no** intel/amdgpu/nouveau/qxl. Xorg rendering = modesetting driver only (kernel KMS + mesa DRI).
**Status**: 🚧 hurdle — GPU work deferred to phase 2 (see F16, F29).
**Evidence**: `memory-bank/activeContext.md#RHEL9-GPU-Facts`

### F07 — No `mesa-va-drivers`, no `intel-media-driver` in RHEL9
Intel VA-API encode = `libva-intel-hybrid-driver` (iHD, present ✅). `libva-nvidia-driver` (library only) present ✅; **no** nvidia driver packages/modules in enabled repos.
**Status**: 🚧 hurdle — phase 2; NVIDIA would need out-of-repo driver provisioning.
**Evidence**: `memory-bank/activeContext.md#RHEL9-GPU-Facts`

### F08 — ~~`cvt` binary absent on EL9~~ **CORRECTED: `cvt`/`gtf` ARE in RHEL9, in `xorg-x11-server-Xorg`**
Original vetting audit checked the Xvfb-only package set; the modeline binaries ship with the full Xorg server package (AppStream, entitled). Consequence: the original "accepted degradation" was actually a **hidden runtime break** (F41). Phase 1 now installs `xorg-x11-server-Xorg` (runs nothing — Xvfb stays the server) purely for `cvt`/`gtf`.
**Status**: ✅ resolved 2026-08-27 (BUILD) — `xorg-x11-server-Xorg` added; `cvt 1024 768` verified producing a modeline; boot modeline step now applies (xrandr: current 1024x768, mode list populated). Upstream el9 shipped the same pair.
**Evidence**: host `dnf provides cvt/gtf` → xorg-x11-server-Xorg; rebuild image 10bbd70e1502.
**Evidence**: `memory-bank/activeContext.md#Verified-EL9-gaps`; vetting doc §5

### F09 — `xdg-utils` **is** in RHEL9 AppStream (1.1.3)
Previously mis-listed as an EL9 gap (defect D6).
**Status**: ✅ resolved — added to v4 package list.
**Evidence**: vetting doc §3 (D6)

### F10 — EL9 CJK font package name differs from Fedora
Fedora: `google-noto-cjk-ttc-fonts` → EL9: `google-noto-sans-cjk-ttc-fonts` (defect D3). dnf strict mode would abort the build on the wrong name.
**Status**: ✅ resolved — renamed in v4.
**Evidence**: vetting doc §3 (D3)

### F11 — Core stack verified in entitled RHEL9 repos
`pulseaudio` 15.0 (AppStream), `python3.11` + `python3.11-pip` (AppStream), `xorg-x11-server-Xvfb/Xorg/Xwayland/Xephyr`, `mesa-dri-drivers` (all DRI incl. llvmpipe/swrast), `nginx`, `glibc-all-langpacks` + `glibc-locale-source`, fonts. pixelflux/pcmflux 2.0.0 cp311 `manylinux_2_28` wheels exist on PyPI → selkies `348bc4f` installs with `--system-site-packages` venv, **no rust needed**.
**Status**: ✅ verified.
**Evidence**: vetting doc §5

### F12 — rust 1.94.1 + cargo ARE in CS9 AppStream
Enables phase-2 DEV_MODE parity (fedora44 model: rust/cargo + ffmpeg-devel + x264-devel + nodejs).
**Status**: ✅ verified (not needed phase 1 — DEV_MODE gated off on non-Debian).
**Evidence**: ops-log research 2026-08-27; `memory-bank/techContext.md`

### F13 — No `sudo` group on EL9
Debian base ships it; EL9 does not → `usermod -aG sudo abc` fails (defect D4).
**Status**: ✅ resolved — `groupadd sudo` first; `%sudo … NOPASSWD` appended to `/etc/sudoers` main file (shared hardening sed targets that file).
**Evidence**: vetting doc §3 (D4)

### F31 — Fedora xorg package names don't exist in RHEL9
`xorg-x11-xkb-utils` and `xorg-x11-font-utils` (Fedora names, used in f44/el9) → RHEL9 ships **`xkbcomp`** and **`mkfontscale`** (both AppStream, standalone pkgs). dnf strict mode: "No match for argument" (build cycle 1).
**Status**: ✅ resolved — names fixed in `Dockerfile.rhel9`.
**Evidence**: build cycle 1 failure; host `dnf provides xkbcomp` / `dnf provides mkfontdir` (2026-08-27).

### F32 — selkies' C-extension deps require devel packages
`evdev` (needs Python.h) and python-`xkbcommon` (needs libxkbcommon headers) build from sdist — **no PyPI wheels** for either. RHEL9 names: `python3.11-devel` + `libxkbcommon-devel` (both AppStream). Upstream el9/f44 both ship *-devel packages; v4 plan list was missing them.
**Status**: ✅ resolved — added to `Dockerfile.rhel9` (build deps / runtime deps).
**Evidence**: build cycles 2–3 failures; upstream el9 `Dockerfile:71` (python3-devel), f44 `Dockerfile:188`.

### F33 — RHEL9 `/etc/sudoers` has no `%sudo` line
Only `%wheel` (RHEL convention) — verified in ubi9 + sudo 1.9.17p2: `%wheel ALL=(ALL) ALL` + commented NOPASSWD-wheel. Appending `%sudo … NOPASSWD: ALL` is collision-free.
**Status**: ✅ resolved (D4 approach confirmed safe).
**Evidence**: ubi9 container probe 2026-08-27.

### F34 — python-xkbcommon must be pinned `<1.5` on RHEL 9
RHEL 9 ships libxkbcommon **1.4** on every stream; python-xkbcommon ≥1.5 references `XKB_CONTEXT_NO_SECURE_GETENV` (added in libxkbcommon 1.5) → cffi build fails. Pin `xkbcommon<1.5` resolves to **1.0.1**, which builds + imports clean against 1.4 (verified in ubi9 container). Same approach as upstream el9's sed (their production resolution).
**Status**: ✅ resolved — third pyproject sed in `Dockerfile.rhel9` (rhel9-specific, documented inline).
**Evidence**: build cycle 3 failure + ubi9 probe; el9 `Dockerfile:171`.

### F35 — RHEL9 ncurses 6.2 `tic` has no `-i` flag
`-i` (ignore unknown capabilities) arrived in ncurses 6.3; `tic -i` dumps usage + exits 1. Plain `tic` on `st.info` exits 0 (unknown-cap warnings to stderr) and compiles the terminfo fine.
**Status**: ✅ resolved — `tic -i` → `tic` in `Dockerfile.rhel9`.
**Evidence**: build cycle 4 failure (usage dump); ubi9 container probe.

## 3. Boot-Critical Defects (vetting of PLAN v3, 2026-08-27)

### F14 — D1: `legacy-cont-init` stub would **break** boot, not fix it
s6-overlay 3.2.0.2 ships `legacy-cont-init` as a **builtin** of the `base` bundle (`/package/admin/s6-overlay-3.2.0.2/etc/s6-rc/sources/legacy-cont-init/` — verified in tarball). A user-level duplicate = s6-rc-compile failure at `/init`. This is why Debian master needs no stub for `svc-de`'s dependency.
**Status**: ✅ resolved — stub dropped from v4 entirely.
**Evidence**: vetting doc §3 (D1)

### F15 — D2: missing `dbus-x11` → svc-de crash-loop
Shared `startwm.sh` execs `dbus-launch`, which lives in `dbus-x11` on EL9 (AppStream 1.12.20). Upstream `el9` **and** `fedora44` both install it.
**Status**: ✅ resolved — added to v4 package list.
**Evidence**: vetting doc §3 (D2)

### F16 — D5: stock EL9 Xvfb rejects `-vfbdevice` → crash-loop when `/dev/dri` is visible
Shared `svc-xorg/run:13-17` passes `-vfbdevice` — an **LSIO-patched-Xvfb-only** flag. Upstream `el9` deleted the whole block from their svc-xorg; likely the true root cause of their "DRI3 is not supported on el9" death (never recorded in any commit). NRP GPU nodes **will** expose `/dev/dri`; local CPU tests pass only because no render node exists.
**Status**: ✅ resolved — `ENV DISABLE_DRI3=true` in `Dockerfile.rhel9` (existing gate at `svc-xorg/run:19` clears the flag; no shared-tree edit). Deliberate rhel9 divergence, documented.
**Evidence**: vetting doc §3 (D5); `memory-bank/decisions.md`

### F17 — D3/D4/D6 are build-breaking (not boot-breaking)
Wrong CJK pkg name (F10), missing sudo group (F13), missing `xdg-utils` + xkbcomp (RHEL9 pkg `xkbcomp`, not Fedora's `xorg-x11-xkb-utils` — see F31).
**Status**: ✅ resolved in v4 (xkbcomp name corrected at build time, F31).
**Evidence**: vetting doc §3; F31

## 4. X11 / Desktop / Audio

### F18 — `PIXELFLUX_WAYLAND=true` waits forever in phase 1
No labwc/wayland stack in rhel9 phase 1 → svc-de/svc-xorg block on a socket that never appears.
**Status**: ⚠️ documented limitation (optional guard echo).
**Evidence**: vetting doc §4; `memory-bank/testing-patterns.md`

### F19 — `svc-dbus` runs `dbus-daemon --system` as `abc`
EL9 `system.conf` `<user>dbus</user>` directive is ignored non-root — expected Debian-identical behavior, but **unverified on EL9**.
**Status**: ✅ resolved 2026-08-27 (BUILD smoke) — `dbus-daemon --system` running as `abc` in the booted rhel9 container; openbox launched via `dbus-launch` (D2 fix working).
**Evidence**: vetting doc §4

### F20 — EL nginx ships a default `:80` server block
Port unexposed; harmless.
**Status**: ⚠️ accepted (optional cleanliness sed).
**Evidence**: vetting doc §4

### F21 — EPEL openbox 3.6.1 matches upstream el9's layout
Ships `openbox-session` + Clearlooks theme dir; the rc.xml sed set is byte-identical to upstream el9 (`Dockerfile:201-210`). Auto-deps: `redhat-menus`, `python3-pyxdg` (dnf resolves).
**Status**: ✅ verified.
**Evidence**: vetting doc §5

### F22 — EPEL `st` ships no installed terminfo
Needs `tic -i /usr/share/doc/st/st.info` (+ `ncurses` for `tic`). Upstream el9 shipped st **without** the fix — likely broken there.
**Status**: ✅ resolved — fix in v4 step 7. **BUILD note**: RHEL9 ncurses 6.2 has no `tic -i` flag (see F35) — plain `tic` used; `st` booted from openbox autostart in the smoke test.
**Evidence**: vetting doc §5

### F23 — Audio: NRP image uses PipeWire; LSIO stack uses PulseAudio
pcmflux/selkies capture via pulse null sinks.
**Status**: ⚠️ decision recorded — keep PulseAudio for LSIO parity.
**Evidence**: `memory-bank/activeContext.md#E`

### F24 — `COPY --from=xvfb / /` Xvfb trick is Debian-image-specific
RPM variants `dnf install xorg-x11-server-Xvfb` directly (upstream el9 did the same).
**Status**: ✅ resolved in v4 model.
**Evidence**: `memory-bank/techContext.md`

### F36 — llvmpipe IS present on RHEL9 via mesa 25.2.7 libgallium
RHEL9 `mesa-dri-drivers` DRI dir is all symlinks to `libdril_dri.so` (no standalone `llvmpipe_dri.so`), BUT llvmpipe is compiled into `libgallium-25.2.7.so` and reachable via `GALLIUM_DRIVER=llvmpipe`. **Verified live in the built image** (C probe vs `Xvfb +iglx`): `GL_RENDERER: llvmpipe (LLVM 21.1.7, 256 bits)`, `GL_VERSION: 4.5` (MESA_GL_VERSION_OVERRIDE honored). The NRP llvmpipe trio works as designed on RHEL9.
**Status**: ✅ verified 2026-08-27 (BUILD).
**Evidence**: gl_probe C test (variants A/B) against image 1b3ad624966d.

### F37 — s6-overlay 3.2.0.2 ships s6-rc **0.5.5.0** (new command naming)
No `s6-rcstatus`/`s6-rc-kill` (0.1.x names): multicall `s6-rc` with `list|listall|diff|start|stop|change` (no `status` subcommand). Per-service state: `s6-svstat /run/service/<svc>`. Identical to upstream (baseimage-el used the same s6-overlay version).
**Status**: ✅ informational — smoke procedure uses s6-svstat.
**Evidence**: `ls /package/admin/s6-rc-0.5.5.0/command/` in built image.

### F38 — `s6-svc -i` does not restart `sleep infinity`-style services
SIGINT to the run-script bash is deferred while the foreground child (sleep) runs; use `s6-svc -t` (SIGTERM) for test restarts. Upstream pattern (svc-docker keep-alive) — not an image defect.
**Status**: ✅ informational.
**Evidence**: M6 dockerd-guard test 2026-08-27.

### F41 — selkies runtime resize REQUIRES `cvt`/`gtf` at client-connect time (first manual test blocker)
selkies 348bc4f's `gst_app_resize` path: when a client connects and reports its browser size (e.g. 960x948), selkies creates that X mode — `cvt W H` first, `gtf` fallback, then `xrandr --newmode/--addmode/--mode`. Missing both → `FATAL: Could not create extended mode ... No such file or directory: 'gtf'. Aborting.` → **video pipeline never starts → dashboard stuck on "Waiting for stream..."** (auth/clipboard/audio all worked; only video missing). Not caught by autonomous matrix because it triggers on the client handshake.
**Status**: ✅ resolved 2026-08-27 (BUILD cycle 5) — `xorg-x11-server-Xorg` installed (carries cvt+gtf on RHEL9; F08 corrected). Rebuilt image 10bbd70e1502. **User re-test #2 PASS: desktop renders ("I got a shell!")** — manual QA complete.
**Evidence**: selkies-rhel9-p1 logs 2026-08-27 ~19:20 (user manual test #1).

### F42 — RHEL9 X11-utility packaging: no `xorg-x11-apps`, no `mesa-tools`, no `dejavu-fonts`
Fedora names don't all exist on RHEL9: `dnf provides /usr/bin/xsetroot` → **`xorg-x11-server-utils`** (7.7-44.el9, AppStream); `glxinfo` → **`glx-utils`** (8.4.0, AppStream); `xterm` = separate AppStream pkg (already in phase 1); standard UI fonts = **`liberation-fonts`** (2.1.3, AppStream). `xorg-x11-apps`/`mesa-tools`/`dejavu-fonts` return no repo match on a 9.8 subscribed host.
**Status**: ✅ verified 2026-08-27 (GNOME task research).
**Evidence**: dnf provides/repoquery on RHEL 9.8 host.

### F43 — RHEL9 standard GNOME = gnome-shell 40.10 (GNOME 40 generation), AppStream; app set verified
Verified present in AppStream (2026-08-27): gnome-shell 40.10, gnome-session 40.1.1, gnome-settings-daemon 40.0.1, nautilus 40.2, gnome-terminal 3.40.3, gedit 40, gnome-calculator 40.1, gnome-screenshot 40, gnome-initial-setup 40.4, firefox (102/115/128/140 ESR generations; 140 latest). **`gnome-shell`'s resolved dep tree contains NO gnome-initial-setup/gdm/fonts** (repoquery --deps grep) → launching gnome-shell directly (F44 pattern) avoids the first-boot welcome screen. XFCE 4.18 is **EPEL-only** (xfce4-session 4.18.3, xfwm4 4.18.0, thunar 4.18.6, xfce4-panel 4.18.4, gucharmap 13.0.8, file-roller 3.40) → GNOME is the better-supported choice; user directed GNOME ("the standard Gnome WM rhel ships with").
**Status**: ✅ verified 2026-08-27.
**Evidence**: dnf repoquery on RHEL 9.8 host.

### F44 — NRP's proven GNOME launch recipe (UBI9, v4-llvmpipe, in production)
`slu-nrp-k8s-vm/selkies-rhel9-entrypoint.sh:233-234`: **`dbus-run-session -- /usr/bin/gnome-shell --x11 --sm-disable &`** — direct gnome-shell launch (NOT gnome-session), `--sm-disable` = no lock/resume. Env (their Dockerfile:27-36): `XDG_SESSION_TYPE=x11`, `XDG_SESSION_ID=<display#>`, `XDG_CURRENT_DESKTOP=GNOME`, `DESKTOP_SESSION=gnome` + llvmpipe trio. Cosmetic: `xsetroot -solid "#2d2d2d"` before compositor draws (line 221); GLX-ready wait via glxinfo (224-231); nautilus auto-start after delay (supervisord). **Delta vs us**: NRP runs Xorg-on-vt7; we plan gnome-shell on our Xvfb (F45: extension set matches; GNOME CI runs gnome-shell on Xvfb).
**Status**: ✅ extracted as PLAN v1 reference 2026-08-27.
**Evidence**: `selkies-rhel9-entrypoint.sh`, `Dockerfile.ubi9-selkies`, `supervisord-rhel9.conf`.

### F45 — Our Xvfb already enables every extension gnome-shell's X11 backend needs
`svc-xorg/run:42-50`: `+COMPOSITE +DAMAGE +GLX +RANDR +RENDER +MIT-SHM +XFIXES +XTEST +iglx +render` = exactly mutter/gnome-shell's X11 requirement set; GL under Xvfb+llvmpipe verified (F36: GL 4.5). No svc-xorg change needed for GNOME phase.
**Status**: ✅ verified 2026-08-27 (code review + F36).
**Evidence**: `root/etc/s6-overlay/s6-rc.d/svc-xorg/run:36-56`.

### F46 — GNOME prerequisites already in phase-1 image (live audit 2026-08-28)
Disposable run from `10bbd70e1502` (`podman run --rm --entrypoint` — live container `selkies-rhel9-p1` exited 137, SIGKILL): `/usr/bin/dbus-run-session` present — on EL9 it ships in **dbus-daemon** 1.12.20-8.el9 (not dbus-tools), already installed via dbus-x11 (D2) | `/usr/bin/xsetroot` present — xorg-x11-server-utils 7.7-44.el9, pulled by cycle-5's `xorg-x11-server-Xorg` (F41) | `glxinfo` **absent** → `glx-utils` is the only missing utility pkg | `rpm -qf` confirmed both providers.
**Status**: ✅ verified 2026-08-28.
**Evidence**: disposable-run probes against phase-1 image.

### F47 — Finalized GNOME package delta (12 pkgs, mirrors NRP's exact set)
`gnome-session gnome-session-xsession gnome-shell gnome-settings-daemon mutter nautilus gnome-terminal gedit gnome-calculator gnome-screenshot firefox glx-utils` — mirrors NRP `Dockerfile.ubi9-selkies:57-68,100` verbatim minus NRP-specific scope (libreoffice, pipewire*, coturn, dev toolchain, vulkan-tools — out of LSIO scope / already present / NRP-only). `mutter` = gnome-shell's hard compositor dep (explicit per NRP); `gnome-settings-daemon` kept for NRP parity (no logind in container → its power/idle plugins inert, acceptable); `gnome-session-xsession` harmless few-MB add. Resolution dry-run remains build step 1 (F31 lesson).
**Status**: ✅ finalized 2026-08-28.
**Evidence**: NRP Dockerfile.ubi9-selkies:57-68,99; phase-1 image audit (F46).

### F48 — XDG_RUNTIME_DIR must be fresh+ephemeral for the gnome dbus session
`init-selkies-config/run:41` sets `XDG_RUNTIME_DIR=/config/.XDG` — but `/config` is the **persistent VOLUME**: a stale `$XDG_RUNTIME_DIR/bus` socket from a previous container boot would make the new dbus-daemon fail to bind → broken gnome-shell session. NRP sidesteps this with per-boot `XDG_RUNTIME_DIR=/tmp/runtime-<user>` (their Dockerfile:40). **Decision**: startwm gnome branch exports `XDG_RUNTIME_DIR=/tmp/runtime-abc` + `mkdir -p && chmod 0700`, scoped to the gnome process tree only (rest of stack keeps `/config/.XDG` untouched).
**Status**: ✅ design decision 2026-08-28.
**Evidence**: `init-selkies-config/run:37-41` (VOLUME at `Dockerfile.rhel9` `VOLUME /config`), NRP Dockerfile.ubi9-selkies:40.

### F49 — Root-owned /config/.cache from base init hooks breaks GNOME app caches
LSIO base `init-mods-package-install` hook runs pip **as root** with `HOME=/config` (container ENV) at boot → leaves root-owned `/config/.cache/pip` (verified: 08:45 boot timestamp, root:root). GNOME apps (gnome-calculator currency cache, nautilus, firefox) then fail to write their `~/.cache/<app>` subtrees ("Permission denied"). Harmless in phase 1 (st/openbox don't use .cache). **Fix**: `init-selkies-config/run` (runs as root, after the base init chain per dependencies.d) normalizes `mkdir -p $HOME/.cache && chown -R abc:abc` — 6 lines, distro-neutral (no-op-equivalent on Debian).
**Status**: ✅ fixed + verified 2026-08-28 (post-fix boot: /config/.cache abc:abc incl. re-chowned pre-existing pip dir; calc warnings gone).
**Evidence**: container /config/.cache listings pre/post fix; `root-base/etc/s6-overlay/s6-rc.d/init-mods-package-install` chain position.

### F50 — nautilus 40 (RHEL9) has NO `-d` flag; NRP's exact invocation is `nautilus --no-desktop`
`-d` (manage-desktop daemonize) was removed in nautilus 3.x; `nautilus -d` → "Unknown option -d" on RHEL9 40.2. NRP's actual command (`supervisord-rhel9.conf:177`): `sleep 10; /usr/bin/nautilus --no-desktop 2>/dev/null || sleep infinity` — file-manager **window** (no desktop takeover). PLAN v2's "nautilus -d (desktop icons)" description was a misremembering of the NRP recipe; the flag itself was wrong. **Fix**: startwm gnome branch uses `nautilus --no-desktop 2>/dev/null &`.
**Status**: ✅ fixed + verified 2026-08-28 (nautilus "Home" window present at boot, screenshot-confirmed).
**Evidence**: NRP supervisord-rhel9.conf:177; live "Unknown option -d" error.

### F51 — EL9 dbus-run-session drops the session socket in a random /tmp path
With `XDG_RUNTIME_DIR=/tmp/runtime-abc` exported, `dbus-run-session -- gnome-shell` (cycle 1/2) still placed the session bus at `/tmp/dbus-glhhPJmPwp` (default session.conf `unix:tmpdir=/tmp` random), NOT `$XDG_RUNTIME_DIR/bus` → separately-launched apps (nautilus, autostart) cannot discover the bus. NRP avoids discovery (their nautilus env carries XDG_RUNTIME_DIR only + errors silenced). **Fix**: explicit `dbus-daemon --session --nofork --address="unix:path=$XDG_RUNTIME_DIR/bus" &` + exported `DBUS_SESSION_BUS_ADDRESS` in the startwm gnome branch — deterministic socket, all child apps inherit.
**Status**: ✅ fixed + verified 2026-08-28 (socket at /tmp/runtime-abc/bus; calc + nautilus connect on the real bus at boot).
**Evidence**: /tmp socket listings cycles 1-3; post-fix boot ps + working apps.

### F52 — RHEL9's `org.gnome.desktop.background` picture-options enum uses `spanned`, not Fedora's `span`
`gsettings set org.gnome.desktop.background picture-options span` → `The provided value is outside of the valid range` (rc=1) on RHEL9/GNOME 40; valid values: `none, wallpaper, centered, scaled, stretched, zoom, spanned` (older/Fedora naming differs: span/center/scale-down). A silent rejection inside startwm.sh (`|| true`) leaves the default `zoom` — visually identical at native 1920×1080, wrong at other resolutions. **Mechanism** (verified working): gnome-shell's background actor reads these gsettings keys directly (no gnome-settings-daemon needed); `gsettings set` from the startwm gnome branch (as abc, HOME=/config) writes the dconf user DB at `/config/.config/dconf/user` (volume-backed, abc-owned, 0600) — re-applied idempotently every boot, so no build-time dconf seeding is required.
**Status**: ✅ fixed + verified 2026-08-28 (c6 `0325190e` exposed the bad value; c7 `99da8c14` sets `spanned`; screenshot shows SLU wallpaper full-desktop).
**Evidence**: `gsettings range org.gnome.desktop.background picture-options` in-image; /tmp/opencode/wall-c7.png.

## 5. Upstream Observations

### F25 — Upstream OS variants = one git branch per OS
Each variant branch: own `Dockerfile`, `jenkins-vars.yml` (`release_tag` = `ls_branch` = branch name), own `root/` tree, feature-reduced where packaging demands (el9 = X11-only, no wayland files at all). CI builds only branches where branch name == `ls_branch` and `external_type: os` (`external_trigger_scheduler.yml:23-47`).
**Status**: 🚧 convention — our `Dockerfile.rhel9`-in-repo + shared `root/` tree deviates; acceptable for local podman builds, revisit if syncing with upstream or using LS Jenkins.
**Evidence**: `memory-bank/systemPatterns.md#7`; `memory-bank/decisions.md`

### F26 — Upstream `el9` lived for months, died of GPU, deprecated 2026-05
Worked with bot builds → deprecated after DRI3/mesa conflicts (`project_deprecation_status: true`, PR #159 + cstate #310). Used older selkies pin (`159656df`) with manual `pixelflux==1.4.7` pin and a python3.9 venv **without** `--system-site-packages`.
**Status**: ✅ lessons applied — we stay on master parity (selkies `348bc4f`, python3.11 + `--system-site-packages`, auto-resolved pixelflux).
**Evidence**: `memory-bank/activeContext.md#Upstream-lessons`; `memory-bank/techContext.md`

### F27 — `fedora44` is the current RPM-family reference
Same selkies pin `348bc4f` as master; root-tree deltas vs master = only 15 files (all EL-family adaptations: `init-nginx` conf.d swap, `startwm.sh` drops `dbus-launch`, dnf-ified DEV_MODE, custom `svc-dbus` deleted, intel VA block dropped from `init-video`).
**Status**: ✅ used as the v4 model base.
**Evidence**: `memory-bank/systemPatterns.md#8`

## 6. Production (NRP) Gates

### F28 — NRP's current image is non-root; LSIO-parity image is rootful
NRP runs `USER rheluser`; our image runs s6 `/init` as root with services dropping to `abc`. **Resolved per user direction (2026-08-28) — verified in NRP's own artifacts**: `runAsNonRoot`/`securityContext` is NOT an NRP deployment limitation. NRP's `selkies-rhel9.yaml.template` + `selkies-glx/egl.yaml.template` + `rhel9-vm.yaml.template` contain **no** securityContext, no runAsNonRoot, no PSA annotations; their non-root posture is an *image design choice* of their supervisord image (README-rhel9.md "Non-Root Execution": "runs as `rheluser` (UID 1000) by default, following the principle of least privilege"), and their push pipeline (build-rhel9-selkies.sh → ghcr.io/slu-nrp via GHCR_TOKEN) has no root restrictions. A rootful image drops into the existing template as-is.
**Status**: ✅ resolved 2026-08-28 (evidence above; no template change required). **Residual risk**: cluster-namespace-level Pod Security Admission (`pod-security.kubernetes.io/enforce=restricted`) cannot be inspected from this host — check the NRP namespace labels at first deploy; if enforced, options = baseline profile (still blocks root… actually restricted forbids root entirely) → would need `runAsUser` + our s6 chain to support non-root init (s6-overlay runs fine as non-root if the tree is owned — phase-2 candidate, NOT needed per templates today).
**Evidence**: NRP repo templates (grep securityContext/runAsNonRoot/allowPrivilegeEscalation/podSecurity = 0 hits), README-rhel9.md:284, RHEL9-SELKIES-IMPLEMENTATION-COMPLETE.md:113, build-rhel9-selkies.sh:16/148; nrp-accounting MCP exposes no deployment docs (accounting queries only — user suggested, checked)

### F29 — Phase-2 GPU: only RHEL-supported path is real Xorg + modesetting + DRI3
Not the Xvfb `-vfbdevice` trick that failed upstream (F16). Intel encode via `libva-intel-hybrid-driver`; NVIDIA needs out-of-repo driver.
**Status**: 🔓 open (phase 2, separate work item).
**Evidence**: `memory-bank/activeContext.md#RHEL9-GPU-Facts`; `memory-bank/decisions.md`

### F30 — SLU registry/tag naming for the rhel9 image
**User decision 2026-08-28 (dev phase)**: registry = user's own development registry, repo **`dgilli/selkies-rhel9`** (host assumed `ghcr.io` — NRP's production pattern is ghcr.io/slu-nrp per build-rhel9-selkies.sh:16; host to be confirmed at push). Tags: **deliberately deferred until production-ready** — dev pushes use `latest` (upstream "no latest" convention applies to the public LSIO lineage, not the SLU dev namespace). Production tag scheme = open until phase-2/production decision.
**Status**: 🔓 partially resolved — dev: `ghcr.io/dgilli/selkies-rhel9:latest` (pending host confirmation + rootless podman login on this host); production naming: still open.
**Evidence**: user directive 2026-08-28; `memory-bank/build-deployment.md`; NRP build-rhel9-selkies.sh:16

### F39 — UBI9 os-release has `ID=rhel`
DEV_MODE gate message renders "not supported on rhel"; the non-Debian gate works (M5 matrix test). Relevant for any future ID-based logic.
**Status**: ✅ informational.
**Evidence**: M5 test log, 2026-08-27.

### F40 — dnf does not record INSTALLFROM in container-mode builds
`dnf repoquery --installed --qf '%{reponame}'` returns `@System` for every package — the sm container-mode plugin does not write INSTALLFROM headers (tested `--setopt=installfrom=url:1` + dnf.conf, no effect). F03's provenance evidence is instead generated via **baseline diff vs vanilla ubi9/ubi (188 pkgs) + per-package GPG key** → 213 ubi9-base / 204 rhel9 / 24 epel.
**Status**: ✅ resolved — `package_versions_rhel9.txt` generated 2026-08-27 (method noted in the artifact).
**Evidence**: repo-root `package_versions_rhel9.txt`.

---

## Appendix: Local Test-Rig Facts (2026-08-27)
- Host: RHEL 9.8 (Plow), subscription-registered (real cdn.redhat.com repos — authoritative for RHEL9 package questions); EPEL/CRB/VSCode/Chrome repos enabled
- podman 5.8.2, rootless; cgroupv2 ✅; `mknod` gamepad nodes will fail → code's `touch` fallback handles it; sudo-podman/`--privileged` fallback documented
- Scratch audit data (disposable): `/tmp/cs9_*.html`, `epel_*.html`, `audit_cs9.txt`, `/tmp/opencode/{el9,f44}.Dockerfile`
