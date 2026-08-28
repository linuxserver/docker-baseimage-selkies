# Active Context

**Last Updated**: 2026-08-28 | **State Machine**: `QA` (task 2: RHEL9 GNOME desktop — BUILD done (4 cycles, budget extension flagged), autonomous QA ALL PASS, awaiting user manual browser test + approval. Phase 1 COMPLETE: `bd46cdb` → `23964ff` → `24e1575`)

## Git Reality (changed 2026-08-27)
- `origin` = **user's fork** `git@github.com:dGilli/docker-baseimage-selkies.git` (commits/pushes allowed)
- `upstream` = `linuxserver/docker-baseimage-selkies` — **push DISABLED, never push there**
- Branch `rhel9` created from `master` (upstream tip `69f4fc9`, incl. PR #184 svc-de→legacy-cont-init fix)
- Old local baseline commits (`eb4e145`/`ed91a5a`) are gone (repo re-initialized as full upstream clone); memory-bank re-committed on `rhel9`
- User checked out `fedora42` first; `fedora43`/`fedora44` available on `upstream` refs — **fedora44 = reference** (same selkies pin 348bc4f as master)

## Task: Add RHEL 9 to the supported images
### User Decisions (recorded)
~~UBI9 base via `lscr.io/linuxserver/baseimage-el:9`~~ → **SLU-owned UBI9 base + entitled RHEL repos** (2026-08-27 vetting decision; baseimage-el deprecated + Oracle-repo-based, see vetting doc §2) | x86_64 first | `Dockerfile.rhel9` in-repo | local podman (5.8.2) | scope: **desktop + streaming first** (defer: DinD, GPU/Zink, proot-apps, pelorus, Wayland) | **NRP = production environment** (SLU k8s researcher desktops) | **phase-1 CPU must test locally** on this RHEL 9.8 host | fold NRP learnings into this repo's image

### PLAN v4 (final — vetted, SLU-owned base) — APPROVED 2026-08-27
Supersedes PLAN v3. Full vetting evidence: `tasks/2026-08/270827_rhel9-vetting-plan-v4.md`. Key v3→v4 deltas: **vendored SLU-owned base** (baseimage-el is deprecated + Oracle-repo-based), defect fixes D1–D6, expanded test matrix, provenance artifact.

**Model**: `Dockerfile.rhel9` = **fedora44's Dockerfile with EL9 substitutions** (NOT a Debian port), on an **SLU-owned UBI9 base stage with entitled RHEL repos**. Shared `root/` tree stays one codebase across debian/fedora/rhel9 variants. NRP production realities (llvmpipe, repos, k8s) folded in.

**A0. Base stage (NEW in v4 — replaces baseimage-el:9)**
Vendor the ~100-line deprecated `docker-baseimage-el` Dockerfile as stage `base`:
- `FROM registry.access.redhat.com/ubi9/ubi` (digest-pinned phase 1)
- **No Oracle repo file, no RPMFusion** (breeze-cursor-theme is EPEL; RPMFusion only needed for deferred phase-2 DEV_MODE ffmpeg)
- RHEL content via **entitlement passthrough** (podman on this registered 9.8 host auto-mounts entitlements). Preflight: `podman run --rm registry.access.redhat.com/ubi9/ubi dnf repolist` must show `rhel-9-for-x86_64-*`
- EPEL9: `dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm` (NRP-proven on UBI9)
- s6-overlay 3.2.0.2 tarballs (noarch + x86_64 + symlinks), base tools (`catatonit jq busybox…` — busybox is EPEL), `abc` (uid 911, /config, /bin/false), `mkdir /app /config /defaults /lsiopy`, docker-mods scripts, ENV (`S6_*`, `VIRTUAL_ENV=/lsiopy`, `PATH=/lsiopy/bin:$PATH`)
- **Build constraint**: image builds only on entitled RHEL hosts; runtime needs no entitlement (NRP just pulls)

**A. Dockerfile.rhel9 — runtime stages & steps**
1. Stage `frontend`: copy master's frontend stage verbatim (alpine 3.22, npm, selkies pin `348bc4f`, dashboards `selkies-dashboard selkies-dashboard-wish`)
2. Runtime: `FROM base` (stage A0)
3. ENV: LSIO set (`DISPLAY=:1 HOME=/config START_DOCKER=true PULSE_RUNTIME_PATH=/defaults SELKIES_INTERPOSER=/usr/lib/selkies_joystick_interposer.so NVIDIA_DRIVER_CAPABILITIES=all DISABLE_ZINK=false` **`DISABLE_DRI3=true`** `SELKIES_ENCODER="x264enc,jpeg" TITLE=Selkies`) **+ NRP llvmpipe trio** (`LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe MESA_GL_VERSION_OVERRIDE=4.5`). **DISABLE_DRI3=true is a deliberate rhel9 divergence (defect D5)**: stock EL9 Xvfb has no LSIO `-vfbdevice` patch — the env gate at `svc-xorg/run:19` prevents a crash-loop on any host/node exposing `/dev/dri` (NRP GPU nodes!)
4. (EPEL already in base — no repo step needed here)
5. RUN dnf install (verified against entitled RHEL 9.8 repos; provenance recorded at build end):
   - build: `gcc gcc-c++ make glibc-devel kernel-headers ncurses` (ncurses = `tic` for st terminfo)
   - X: `xorg-x11-server-Xvfb xorg-x11-server-utils xorg-x11-utils xorg-x11-xauth xorg-x11-xkb-utils xkeyboard-config xorg-x11-fonts-{75dpi,100dpi,misc}` (**+xkb-utils = xkbcomp for Xvfb keymaps, D6b**)
   - GL/mesa: `mesa-libGL mesa-libEGL mesa-libgbm mesa-dri-drivers mesa-vulkan-drivers libva` (KEEP mesa-dri-drivers — llvmpipe GLX)
   - desktop: `openbox xsettingsd st xdotool xclip xsel exo breeze-cursor-theme` (all EPEL9, verified) + `xterm xdg-utils` (AppStream; **xdg-utils IS available — D6**)
   - audio/web: `pulseaudio pulseaudio-utils nginx nginx-mod-fancyindex` (pulseaudio = AppStream 15.0 verified; fancyindex = EPEL9 → shared `default.conf` UNMODIFIED)
   - python: `python3.11 python3.11-pip python3.11-libs`
   - fonts/locales: `dejavu-sans-fonts google-noto-sans-fonts` **`google-noto-sans-cjk-ttc-fonts`** `google-noto-cjk-fonts-common google-noto-emoji-fonts glibc-all-langpacks glibc-locale-source` (**EL9 CJK pkg name — D3**; same `localedef` loop as fedora44/el9/master)
   - dbus/misc: `dbus dbus-daemon` **`dbus-x11`** `file procps-ng psmisc iproute kbd which tar curl openssl sudo shadow-utils util-linux` (**dbus-x11 = dbus-launch for shared startwm.sh — D2**)
6. RUN openbox tweaks (fedora44/el9-proven sed set — no `/debian-menu/d` line on EL): NLIMC→NLMC, maximized+position application, C-S-d ToggleDecorations keybind, desktops number 4→1, `/usr/bin/openbox-session` `--replace`
7. RUN st terminfo fix: `tic -i /usr/share/doc/st/st.info` (EPEL gap; verified file location)
8. RUN selkies: `python3.11 -m venv --system-site-packages /lsiopy`; fetch selkies `348bc4f` tarball; seds (`/"av>/d`, `/cryptography/d` — master parity); `pip install . && pip install setuptools` (pixelflux/pcmflux cp311 manylinux_2_28 wheels verified on PyPI; NO rust needed). Fallback if pip stumbles: `pip install -U pip` first
9. RUN interposer (`gcc -shared -fPIC -ldl` → `/usr/lib/selkies_joystick_interposer.so`) + fake-udev (`make` → `/opt/lib/libudev.so.1.0.0-fake`)
10. RUN icons (selkies-logo/favicon from docker-templates, master parity)
11. RUN user: `chpasswd abc:abc`; `usermod -s /bin/bash abc`; **`groupadd sudo` (D4 — group doesn't exist on EL9)**; `usermod -aG sudo abc`; append `%sudo ALL=(ALL:ALL) NOPASSWD: ALL` to `/etc/sudoers` (main file, not sudoers.d — shared hardening sed `s/NOPASSWD/CORRUPT_FILE/` targets `/etc/sudoers`)
12. ~~legacy-cont-init stub~~ **DELETED (D1)**: s6-overlay 3.2.0.2 ships `legacy-cont-init` builtin (base bundle, verified in tarball) — a user-level stub would be a duplicate definition and **break s6-rc-compile at boot**. Same reason Debian master needs no stub for svc-de's dep
13. RUN theme (Clearlooks openbox theme from lang-stash, master parity — EPEL openbox ships the theme dir)
14. `COPY /root /` + `COPY --from=frontend /buildout /usr/share/selkies`
15. RUN provenance + cleanup: `dnf repoquery --installed --qf '%{name}|%{version}|%{reponame}'` → basis for `package_versions_rhel9.txt` (RHEL-vs-EPEL evidence for the "supported" claim); `dnf clean all`, `rm -rf /tmp/* /var/cache/dnf/*`
16. `EXPOSE 3000 3001` + `VOLUME /config` (master parity; ws port 8082 runtime-dynamic like other variants)

**B. Shared `root/` tree — 4 distro-aware edits (each a no-op on Debian/Fedora)**
1. `init-nginx/run`: branch `NGINX_CONFIG` — `sites-available` if present (debian), else `mkdir -p /etc/nginx/conf.d && NGINX_CONFIG=/etc/nginx/conf.d/default.conf` (EL) [fedora44 did the hard swap; we branch to keep one tree]
2. `svc-selkies/run` DEV_MODE: **phase-1 = gate off on non-Debian** (`. /etc/os-release; [[ $ID == debian ]] || { echo "DEV_MODE not supported on $ID (phase 1)"; }` skip). Documented upgrade path = fedora44's dnf DEV_MODE (rust/cargo/nodejs verified in CS9) if dev parity is wanted later. *(micro-decision for user at approval)*
3. `init-selkies-config/run`: proot-apps block guarded by `[ -d /proot-apps ]` (absent in phase 1)
4. `svc-docker/run`: `command -v dockerd >/dev/null 2>&1 || { echo "docker not installed on this variant"; sleep infinity; }` (DinD = phase 2)

**C. Artifacts**
- `package_versions_rhel9.txt` (same NAME/VERSION/TYPE format; rpm -qa + pip freeze **+ per-package repo provenance** `%{name}|%{version}|%{reponame}` — RHEL-vs-EPEL evidence)
- `readme-vars.yml`: add rhel9 image row (source of truth; README.md stays builder-generated)

**D. Local phase-1 CPU test procedure (this RHEL 9.8 host, podman 5.8.2)**
0. **Preflight (v4)**: `podman run --rm registry.access.redhat.com/ubi9/ubi dnf repolist` shows `rhel-9-for-x86_64-*` (entitlement passthrough works)
1. `podman build -f Dockerfile.rhel9 -t dgilli/baseimage-selkies:rhel9-p1 .`
2. `podman run -d --name selkies-rhel9-p1 -p 3000:3000 -p 3001:3001 -p 8082:8082 -e TZ=America/Chicago -e PASSWORD=baseimage123 dgilli/baseimage-selkies:rhel9-p1`
   - rootless caveats: cgroupv2 ✅ on RHEL9; `mknod` gamepad nodes will fail → code's `touch` fallback handles it; if s6 cgroup issues appear, re-test with `sudo podman run` / `--privileged` (documented)
3. Verify: s6 chain reaches `init-selkies-end` (no flapping via `s6-rcstatus`); procs = Xvfb, openbox, `st` (autostart), selkies, nginx, pulseaudio; `curl -sI :3000` (200/301), `curl -skI :3001`, basic-auth with abc/baseimage123; 8082 listening; `pactl list sinks` shows output+input null sinks; GL sanity via browser; **dbus-daemon up as abc** (svc-dbus watch item)
4. Manual: browser → dashboard → connect → desktop renders, window + keyboard + audio work
5. Regression: `bash -n` on the 4 edited shared scripts; optional `podman build -f Dockerfile .` (debian) to prove no-ops
6. **Negative/edge matrix (v4)**: `--device /dev/dri/renderD128` run → Xvfb stays up (proves D5 fix) | `--privileged` → svc-docker guard message, no flapping | `-e HARDEN_DESKTOP=true` → sudoers sed round-trip + xdg-open/exo-open chmod 0000 | `-e PIXELFLUX_WAYLAND=true` → documented wait-forever behavior (no labwc phase 1) | `-e LC_ALL=de_DE.UTF-8` boot | `-e DEV_MODE=pixelflux` → gate message, default boot unaffected

**E. NRP production path (phase 1.5 — AFTER local approval, separate work item)**
- Push `dgilli/baseimage-selkies:rhel9-*` to the SLU registry NRP pulls from
- Update `slu-nrp-k8s-vm/selkies-rhel9.yaml.template` env mapping: `PASSWD→PASSWORD`, drop `BASIC_AUTH_*` (nginx does basic auth), `DISPLAY_SIZEW/H → SELKIES_MANUAL_WIDTH/HEIGHT`, ports 3000/3001 (+8082 ws) instead of 8080
- **Open production question for user**: NRP's current image runs non-root (`USER rheluser`); our LSIO-parity image is **rootful** (s6 `/init`, services drop to `abc`). NRP Deployment must permit root (no `runAsNonRoot: true`) — same as every LSIO image in a k8s desktop
- Audio divergence documented: NRP image uses PipeWire; LSIO stack uses PulseAudio (pcmflux/selkies capture via pulse null sinks) — keep PulseAudio for parity

**Risks**
| Risk | Mitigation |
|------|-----------|
| rootless podman + s6 quirks | graceful mknod fallback in code; sudo-podman/`--privileged` test fallback |
| entitled-host build constraint (v4) | documented in build-deployment.md; SLU builds on registered RHEL hosts; runtime/NRP unaffected |
| ubi9/ubi tag float | digest-pin phase 1 |
| pip vs selkies build backend | optional in-venv pip upgrade fallback |
| EPEL openbox rc.xml sed targets | proven on el9+fedora44 (openbox 3.6.x); smoke test catches openbox boot |
| EPEL openbox auto-deps (redhat-menus, python3-pyxdg) | dnf resolves; build surfaces conflicts |
| `cvt` absent on EL9 | svc-de modeline step no-ops (Xvfb screen size still honored) — documented degradation; verified graceful (empty MODELINE_NAME → grep matches all → block skipped) |
| svc-dbus `--system` as abc on EL9 | `<user>dbus</user>` directive ignored non-root (Debian-identical behavior expected); explicit smoke test |
| `PIXELFLUX_WAYLAND=true` waits forever (no labwc phase 1) | documented limitation; optional guard echo |
| EL nginx default `:80` server block remains | harmless (port unexposed); optional cleanliness sed |
| NRP rootful requirement | flagged to user (phase 1.5 gate) |

**Budget**: 4 cycles | ~90 min (base stage adds one layer; preflight adds 5 min)

### Verified EL9 gaps (accepted degradations, phase-2 candidates)
dunst | xorg-x11-drv-{intel,amdgpu,nouveau,qxl} + mesa-va-drivers (NOT in real RHEL9 either — verified on 9.8 host; GPU phase 2) | *(REMOVED from gaps by vetting: xdg-utils — IS in AppStream 1.1.3 (D6); breeze-cursor-theme — IS in EPEL9, RPMFusion not needed; cvt/gtf — IN xorg-x11-server-Xorg, installed, F08 corrected + F41)*

### Upstream lessons (from `origin/el9`, deprecated 2026-05)
- el9 worked for months (bot builds) → deprecated after DRI3/mesa conflicts + `project_deprecation_status: true` in readme-vars
- Their selkies pin was older (159656df) and they pinned `pixelflux==1.4.7` manually — we stay on 348bc4f (master parity) with auto-resolved pixelflux (cp311 wheel verified)
- They used `python3` (3.9!) venv without --system-site-packages — we use 3.11 + --system-site-packages (master parity)

## RHEL9 GPU Facts (verified 2026-08-27 on subscribed RHEL 9.8 host — real cdn.redhat.com repos)
- **No DDX drivers in RHEL9**: AppStream has only xorg-x11-drv-{dummy,evdev,fbdev,v4l,vmware,wacom}; NO intel/amdgpu/nouveau/qxl. Xorg rendering = modesetting driver only (kernel KMS + mesa DRI).
- **No `mesa-va-drivers`, no `intel-media-driver`** in RHEL9. Intel VA-API encode = `libva-intel-hybrid-driver` (iHD, present ✅). `libva-nvidia-driver` (library only) present ✅; **no nvidia driver packages/module in enabled repos**.
- `mesa-dri-drivers` (all DRI incl. llvmpipe/swrast) present ✅; xorg-x11-server-{Xorg,Xvfb,Xwayland,Xephyr} present ✅.
- Upstream el9's death ("DRI3 is not supported on el9", 4b42cad 2025-11-20) = the **Xvfb `-vfbdevice /dev/dri/renderD` DRI3 render-node path** (our svc-xorg GPU flow) failed on EL9; they stripped mesa-dri+mesa-va → GPU nonfunctional → deprecated 2026-05 (PR #159 + cstate #310). No commit records the deeper root cause.
- **Phase-2 GPU conclusion**: only RHEL-supported path is real **Xorg + modesetting + DRI3** (not Xvfb-vfbdevice). Intel encode via libva-intel-hybrid-driver; NVIDIA needs out-of-repo driver.
- Core (CPU) scope unaffected: Xvfb without render node + llvmpipe GLX works. NRP project proved the force-llvmpipe env trick on EL9 (`LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe MESA_GL_VERSION_OVERRIDE=4.5`) — **adopt as ENV in Dockerfile.rhel9** (GL fallback guarantee).

## NRP relationship (clarified 2026-08-27 by user)
1. **This repo, `rhel9` branch (PLAN v3)**: the image we build — LSIO baseimage fork (baseimage-el:9 + s6 + `abc` + openbox/Xvfb, parity with debian).
2. **NRP (`slu-nrp-k8s-vm/`)** = **the production environment** (SLU k8s researcher desktops; `nrp-workspace up --type desktop --variant rhel9`; yaml templates, coTURN, GPU node scheduling). Its current ad-hoc image (`Dockerfile.ubi9-selkies`, v2/v3/v4-llvmpipe) = UBI9 + supervisord + `rheluser` + GNOME-on-Xorg.
3. Direction: **this repo's image is the phase-1 CPU deliverable, tested locally, then deployed to NRP** (phase 1.5 = registry push + NRP template env mapping). NRP *learnings* folded into PLAN v3 (llvmpipe ENV, EPEL-on-UBI9 repo line, xorg container flags as phase-2 Xorg input); NRP's supervisord/GNOME architecture NOT adopted (LSIO parity kept).

## Guest image note
`registry.redhat.io/rhel9/rhel-guest-image:latest` = **qcow2 VM disk delivery vehicle** (rhel-guest-image-9.8-20260428.2, KubeVirt env), 12 files total — not executable, not a container base, empty content-sets. Version info: RHEL **9.8**. If a true RHEL9 *container* base is wanted later: `registry.redhat.io/rhel9/rhel-core:9` (subscription; this host can pull it) vs UBI9 (free, current plan).

## BUILD executed 2026-08-27 (user released the hold)

**Revert tag**: `pre-rhel9-build` (annotated, → `7b3af8b`) — everything built is after this tag.

**Image**: `dgilli/baseimage-selkies:rhel9-p1` = `10bbd70e1502` (cycle 5, +`xorg-x11-server-Xorg` for cvt/gtf — F41; x86_64; base pin ubi9@`03b3d228` amd64 manifest).

**New files**: `Dockerfile.rhel9` (3 stages: base/frontend/runtime, 15 steps), `root-base/` (vendored baseimage-el s6 tree, 68 files, Oracle repo+GPG excluded), `package_versions_rhel9.txt` (final: 213 ubi9-base / 211 rhel9 / 24 epel + 41 python), `readme-vars.yml` +RHEL row.

**Shared-tree edits (4, all no-ops on Debian)**: `init-nginx/run` (conf.d branch), `svc-selkies/run` (DEV_MODE non-Debian gate), `init-selkies-config/run` (`[ -d /proot-apps ]` guard), `svc-docker/run` (dockerd guard).

**Build cycles (5)**: c1 `xorg-x11-{xkb,font}-utils` don't exist on RHEL9 → `xkbcomp`+`mkfontscale` (F31) | c2 evdev missing Python.h → `python3.11-devel` (F32) | c3 xkbcommon cffi vs libxkbcommon 1.4 → `xkbcommon<1.5` pin + `libxkbcommon-devel` (F34) | c4 `tic -i` unsupported on ncurses 6.2 → plain `tic` (F35) | c5 **user manual test #1**: dashboard OK but "Waiting for stream..." → selkies runtime resize needs `cvt`/`gtf` (F41) → added `xorg-x11-server-Xorg` (F08 corrected). Full resolution dry-run (`--downloadonly`) added to catch name errors pre-build.

**Autonomous QA (ALL PASS)**:
- Boot: 10/10 user-bundle services up & stable (s6-svstat), init chain complete, no flapping
- Desktop: Xvfb `:1` (xdpyinfo OK), openbox `--replace` via dbus-launch (F19/D2 ✅), `st` from autostart (F22/F35 ✅), X socket abc-owned
- Web: 3000/3001 nginx + basic auth (401→200 w/ abc:baseimage123), dashboard HTML served, 8082 selkies ws listening, gamepad interposers up
- Audio: output+input null sinks (pactl)
- GL: llvmpipe probe — `llvmpipe (LLVM 21.1.7)` / GL 4.5 (F36)
- sudo: NOPASSWD as abc (F33/D4) | locale: de_DE.utf8 boots (LC_ALL matrix)
- Matrix: `--device /dev/dri/renderD128` → Xvfb no `-vfbdevice`, stable (D5/F16 ✅) | `SELKIES_MANUAL_WIDTH/HEIGHT=1280x720` → Xvfb `-screen 0 1280x720x24` ✅ | harden (`DISABLE_SUDO`+`DISABLE_OPEN_TOOLS`+`HARDEN_DESKTOP`) → CORRUPT_FILE sed + xdg-open/exo-open mode 0000 + nginx files block removed ✅ | `DEV_MODE=pixelflux` → gate msg "not supported on rhel", default boot ✅ (F39) | dockerd guard (simulated privileged via /dev/cpu_dma_latency + s6-svc -t) → "docker not installed… service idle", stable (F38)
- cvt fatal line in boot log = expected (F08 verified live; modeline skipped, size via Xvfb env)

**Needs MANUAL (user)**: browser → dashboard → connect → desktop renders + window drag + keyboard + audio. (Everything up to the browser handshake is verified autonomously.)

## Task 2: GNOME desktop as RHEL9 default X11 DE — **PLAN v2 FINALIZED** (2026-08-28, AWAITING user approval)
**User ask**: "get a GUI desktop working locally, not just a shell" → "the standard GNOME WM RHEL ships with" → "finalize your plan to get gnome-shell running as our window manager".

**Goal**: RHEL9 image's streamed X11 desktop boots **standard RHEL GNOME (gnome-shell 40.10)** instead of openbox+st-only. openbox stays as fallback (`DESKTOP=openbox` knob); LSIO autostart/`RESTART_APP` mechanism preserved.

**Key decision (NRP-proven pattern, F44)**: `startwm.sh` gnome branch runs `dbus-run-session -- /usr/bin/gnome-shell --x11 --sm-disable` — **direct gnome-shell launch, NOT gnome-session**. Bypasses: gnome-initial-setup welcome screen (not in gnome-shell's dep tree — F43), keyring prompts, logind dependency, blanking/lock. Matches NRP's production UBI9 recipe.

**Packages (FINAL — F46/F47)**: dnf list += `gnome-session gnome-session-xsession gnome-shell gnome-settings-daemon mutter nautilus gnome-terminal gedit gnome-calculator gnome-screenshot firefox glx-utils` (12). NOT needed: `xorg-x11-server-utils` (xsetroot already in image via F41's Xorg pkg) / `dbus-tools` (dbus-run-session ships in dbus-daemon on EL9, present).

**Changes (FINAL)**:
1. Revert tag `pre-gnome-desktop` → `24e1575` (create at BUILD start)
2. `Dockerfile.rhel9` runtime dnf list += the 12 pkgs — **dnf dry-run resolution first** (F31 lesson)
3. `root/defaults/startwm.sh` — **5th distro-aware no-op branch** (Debian path untouched; exact final code):
```bash
# Start DE
if [ -x /usr/bin/gnome-shell ] && [ "${DESKTOP}" != "openbox" ]; then
  # RHEL9 standard GNOME (gnome-shell 40.x): direct launch, NRP-proven pattern (F44/F47)
  export XDG_SESSION_TYPE=x11
  export XDG_SESSION_ID="${DISPLAY#:}"
  export XDG_CURRENT_DESKTOP=GNOME
  export DESKTOP_SESSION=gnome
  # fresh per-boot runtime dir: /config/.XDG is on the persistent volume and would
  # keep a stale dbus socket across container restarts (F48); NRP uses same pattern
  export XDG_RUNTIME_DIR=/tmp/runtime-abc
  mkdir -p "$XDG_RUNTIME_DIR" && chmod 0700 "$XDG_RUNTIME_DIR"
  xsetroot -solid "#2d2d2d" 2>/dev/null || true
  # wait for GLX readiness (mutter composites via software GL)
  for i in $(seq 1 30); do
    glxinfo 2>/dev/null | grep -q "OpenGL renderer string" && break
    sleep 1
  done
  dbus-run-session -- /usr/bin/gnome-shell --x11 --sm-disable &
  GNOME_PID=$!
  sleep 10
  nautilus -d 2>/dev/null || true
  # autostart app — exact command string svc-watchdog pgreps for RESTART_APP (F22)
  sh "$HOME/.config/openbox/autostart" &
  wait "$GNOME_PID"
else
  exec dbus-launch --exit-with-session /usr/bin/openbox-session > /dev/null 2>&1
fi
```
   Watchdog match proof: `HOME=/config` is container ENV → `sh "$HOME/.config/openbox/autostart"` cmdline = `sh /config/.config/openbox/autostart` = svc-watchdog `AUTOSTART_CMD` verbatim (`svc-watchdog/run:13`) → `RESTART_APP` works UNCHANGED. `wait $GNOME_PID` keeps svc-de alive; s6 kills the whole process group on service stop (clean gnome teardown).
4. `svc-xorg/run` — **no change** (F45)
5. `init-selkies-config/run` — **no change** (its `TERMINAL_NAMES` already lists `gnome-terminal` → `DISABLE_TERMINALS` hardening covers it, line 108)

**Tests**: autonomous = services 10/10 stable, `pgrep -u abc gnome-shell` (+nautilus), `glxinfo` renderer=llvmpipe, **`gnome-screenshot -f` → read PNG to visually confirm GNOME top bar**, launch gnome-calculator (window via xprop), autostart cmdline matches watchdog string. Edge = `DESKTOP=openbox` (old behavior intact) · `SELKIES_MANUAL_WIDTH/HEIGHT=1280x720` · `RESTART_APP=true` watchdog under GNOME (kill `sh /config/.config/openbox/autostart` → respawns) · existing hardening trio. **Manual (user)** = browser → GNOME desktop (Activities, app grid, firefox, nautilus, terminal, drag, clipboard).

**Risks**: gnome-shell-on-Xvfb (NRP proved on Xorg; extension set matches + GNOME CI precedent → low; **Plan B** = Xorg-in-gnome-mode in svc-xorg, NRP verbatim, one cycle) · +1.5–2 GB image (gnome+firefox) · gsd installed but logind-less → gsd power/idle inert, Settings app NOT installed (user configures via gsettings if ever needed).

**Budget**: 3 build cycles | **State**: awaiting approval ("approved"/"proceed" to start cycle 1).

### BUILD executed 2026-08-28 (approved; PLAN v2)
**Revert tag**: `pre-gnome-desktop` → `b4c199f`. **Final image**: `dgilli/baseimage-selkies:rhel9-p1-gnome` = `15f963f83b71` (c4).
**Cycles**: c1 `3c31e79a` — clean build; smoke found nautilus absent + dbus socket mismatch | c2 `5394646a` — F49 cache chown + dbus export attempt (still dbus-run-session) | c3 `a1ac52a0` — Dockerfile +`nautilus` (edit omission), explicit `dbus-daemon --address` (F51) | c4 `15f963f8` — `nautilus --no-desktop` (F50; **budget extension flagged to user, 1-line cached rebuild**).
**Files**: `Dockerfile.rhel9` (+12 gnome pkgs), `root/defaults/startwm.sh` (gnome branch, 41 lines), `root/etc/s6-overlay/s6-rc.d/init-selkies-config/run` (+6 lines .cache chown, F49).
**Autonomous QA (ALL PASS, 2026-08-28)**: services 13/13 (s6rc-fdholder down=by design) · gnome-shell 474 + nautilus + st from autostart + deterministic session bus `/tmp/runtime-abc/bus` · GLX llvmpipe 4.5 · web 200 w/ abc:baseimage123 both ports · ws 8082 listening · **screenshot-confirmed full GNOME desktop** (top bar Activities/clock, st, nautilus Home window, dash w/ running indicators) · calc launches on real bus (F49 verified) · `/config/.cache` abc-owned · **edge 4/4**: `DESKTOP=openbox` → openbox+st, no gnome-shell (dbus-launch path) · `SELKIES_MANUAL_WIDTH/HEIGHT=1280x720` → Xvfb `-screen 0 1280x720x24` + gnome-shell up · `RESTART_APP=true` → killed st respawns (PIDs 829/830 → 1616/1620, watchdog exact-string match) · `HARDEN_DESKTOP=true` → sudo/xdg-open/**gnome-terminal** 0000 + CORRUPT_FILE sudoers + gnome-shell still up.
**Live container**: `selkies-rhel9-p1-gnome` on :3000/:3001/:8082 — ready for user manual browser test.

## Working Context
- Branch `rhel9`; **working tree clean**; commits `bd46cdb` (phase-1 build) → `23964ff` (docs) → `24e1575` (close); revert tags: `pre-rhel9-build` → `7b3af8b`, next `pre-gnome-desktop` → `24e1575`
- Live container `selkies-rhel9-p1` (ports 3000/3001/8082, creds abc/baseimage123) = phase-1 image, still openbox default — **exited (137) 2026-08-28**; audit work done via disposable `podman run --rm --entrypoint` (F46); replaced by the GNOME build anyway
- Host: RHEL 9.8 (Plow), subscribed; /dev/dri/renderD128 present; podman 5.8.2 rootless
- Evidence: vetting `tasks/2026-08/270827_rhel9-vetting-plan-v4.md` · build `tasks/2026-08/270827_rhel9-build.md` · findings `findings.md` F01–F45
- NRP recipe source: `/home/its_admin/projects/slu-nrp-k8s-vm/{Dockerfile.ubi9-selkies,selkies-rhel9-entrypoint.sh,supervisord-rhel9.conf}`
- Scratch: /tmp/opencode/ref/{f44,el9}.Dockerfile, prov_attr.sh, ubi_base.txt, gl_probe.c, baseimage-el clone (disposable)
