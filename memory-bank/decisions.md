# Decisions (ADR Log)

### 2026-08-27: Local git baseline for rollback
**Status**: Approved (user: "git init so we can revert if need be")
**Context**: Repo was a plain directory, not a git repository — no way to revert experiments.
**Decision**: `git init -b main` and commit the pristine pre-RHEL9 snapshot as baseline `eb4e145` ("Baseline: pre-RHEL9 snapshot of baseimage-selkies (debiantrixie)").
**Alternatives**: Copy the directory to a backup (less granular, no diff history).
**Consequences**: Every future change is diffable/revertible locally. No remote configured yet — pushing is a future decision.
**References**: `tasks/2026-08/README.md`

### 2026-08-27: Memory Bank initialization
**Status**: Approved (user: "init memory bank")
**Context**: No `memory-bank/` existed; AGENTS.md v2.2 requires it for session continuity.
**Decision**: Create the full MB structure (core + reference + `tasks/2026-08/` + `ops-log.jsonl`), seeded from analysis of `Dockerfile`, `s6-rc.d`, `jenkins-vars.yml`, `readme-vars.yml`. Skipped `database-schema.md` (no data layer in this project).
**Consequences**: MB files are committed to the repo (tracked in git) so they persist and are revertible with code.
**References**: `toc.md`

### 2026-08-27: GPU support on RHEL9 deferred — modesetting-only reality
**Status**: Approved (evidence-based, user inquiry)
**Context**: Upstream el9 was killed partly by the GPU gap ("DRI3 is not supported on el9", commit 4b42cad). Verified on a subscribed RHEL 9.8 host against real RHEL9 repos: RHEL9 ships no Xorg DDX drivers (intel/amdgpu/nouveau/qxl) and no mesa-va-drivers; rendering is modesetting+mesa-dri only; Intel VA-API exists via libva-intel-hybrid-driver; no NVIDIA driver packages in enabled repos.
**Decision**: Phase 1 (core) stays CPU-only (Xvfb, no render node, llvmpipe GL via forced env). Phase-2 GPU work will use real Xorg + modesetting + DRI3 (the only RHEL-supported path), not the Xvfb `-vfbdevice` trick that failed upstream. NVIDIA would require out-of-repo driver provisioning (separate work item).
**Alternatives**: Track UBI9+RPMFusion for a DRI3 Xvfb path (upstream proved it unstable on EL9); use rhel-core:9 base (subscription coupling — rejected for a distributable image).
**Consequences**: No GPU in v1; documented escalation path for phase 2.
**References**: `activeContext.md#RHEL9-GPU-Facts`

### 2026-08-27: NRP is production; phase-1 CPU tested locally; fold NRP learnings in
**Status**: Approved (user: "NRP will be our production environment but ideally we get to test phase-1 cpu locally")
**Context**: Two parallel RHEL9 efforts existed: this repo's LSIO-parity image (PLAN v2) and `slu-nrp-k8s-vm/Dockerfile.ubi9-selkies` (supervisord + GNOME + rheluser, v2/v3/v4-llvmpipe builds).
**Decision**: Keep LSIO-parity architecture (s6 + abc + openbox + Xvfb) as the image we build here; NRP (SLU k8s, `nrp-workspace`) is where it runs in production. NRP *learnings* adopted into PLAN v3: force-llvmpipe ENV trio, EPEL-on-UBI9 repo line, xorg container flags (phase-2 input). NRP's supervisord/GNOME architecture NOT adopted. Local podman on this RHEL 9.8 host is the phase-1 test rig; NRP template env-mapping + registry push = phase 1.5 (after local approval).
**Open production gate**: our image is rootful (s6); NRP's current image is non-root — NRP Deployment must permit root (same as all LSIO images).
**References**: `activeContext.md#NRP-relationship`

### 2026-08-27: PLAN v3 (final, NRP-integrated) supersedes PLAN v2
**Status**: Superseded by PLAN v4 (vetting found 1 strategic misalignment + 6 defects — see ADRs below and `tasks/2026-08/270827_rhel9-vetting-plan-v4.md`)
**Context**: PLAN v2 (fedora44-modeled) + NRP production clarification + RHEL 9.8 repo verification + user's llvmpipe instruction.
**Decision (proposed)**: Full plan in `activeContext.md#PLAN-v3-final--NRP-integrated--awaiting-user-approval`. Deltas vs v2: base pinned to `9-version-f81d91cc`; +llvmpipe ENV trio; +breeze-cursor-theme (rpmfusion, was mis-listed as gap); DEV_MODE phase-1 = gated off on non-Debian (dnf port deferred, micro-decision); 4 shared-tree edits unchanged; local podman test procedure + NRP phase-1.5 path added.
**References**: `activeContext.md#PLAN-v3`

### 2026-08-27: Adopt force-llvmpipe ENV in Dockerfile.rhel9
**Status**: Approved (user: "Yes take NRP learnings into account") — part of PLAN v3
**Context**: `slu-nrp-k8s-vm` RHEL9 builds (v2/v3/v4-llvmpipe) set `LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe MESA_GL_VERSION_OVERRIDE=4.5` to make GL compositing work without a GPU.
**Decision**: Add same ENV block to `Dockerfile.rhel9` runtime stage as the guaranteed CPU GL path (harmless when a GPU is present in phase 2 — revisit then).
**References**: `activeContext.md#RHEL9-GPU-Facts`

### 2026-08-27: RHEL9 support approach (proposed, not yet approved)
**Status**: Proposed — pending answers to open questions in `activeContext.md`
**Context**: Upstream image is Debian-trixie only; SLU needs a RHEL9-based variant.
**Proposal (draft)**: Add `Dockerfile.rhel9` (and later `Dockerfile.rhel9.aarch64`) reusing the existing stage architecture; UBI9 runtime base; dnf + EPEL9 + CRB/PowerTools + Docker rhel9 + NodeSource rhel9 repos; source-build wlroots 0.18 (pixman patch) and labwc 0.9.7 (ipc patch); keep the `root/` s6 tree shared with distro-aware branches where packaging differs.
**References**: `activeContext.md#Known-Risks`

### 2026-08-27: Upstream OS-variant convention = one git branch per OS (verified finding)
**Status**: Reference (investigation, in response to user question)
**Context**: User asked how upstream defines fedora/arch/ubuntu etc. with a single Dockerfile.
**Finding**: It doesn't — each OS variant is its own branch (`master`, `el9`, `fedora42-44`, `alpine323-324`, `arch`, `kali`, `ubuntu*`, `dev`), each with its own `Dockerfile`, `jenkins-vars.yml` (`release_tag`=`ls_branch`), and `root/` tree. CI gates on branch==`ls_branch` (`external_trigger_scheduler.yml:23-47`). Variants are also feature-reduced (el9 is X11-only vs master's X11+Wayland).
**Consequences**: Our recorded Decision #3 (`Dockerfile.rhel9` in-repo, single branch) deviates from upstream convention. Acceptable while builds are local podman (Decision #4); revisit if syncing with upstream `el9` or using LS Jenkins.
**References**: `systemPatterns.md#7-os-variants--git-branches-upstream-pattern`, `activeContext.md#Finding`

### 2026-08-27: PLAN v2 — RHEL9 variant modeled on fedora44 (supersedes v1 Debian-port)
**Status**: Superseded by PLAN v3 (2026-08-27), itself superseded by PLAN v4 (vetting ADRs below)
**Context**: User made upstream `fedora42-44` branches available ("base our rhel9 image on fedora much more closely than debian"). Investigation showed upstream has (a) a deprecated `el9` branch proving `baseimage-el:9` works for this stack, and (b) current `fedora44` with the same selkies pin (348bc4f) and the full set of EL-family adaptations.
**Decision (proposed)**: `Dockerfile.rhel9` = fedora44 structure with `FROM lscr.io/linuxserver/baseimage-el:9`; drop wayland stages (wtype/selkies-desktop/labwc-builder), pelorus, proot-apps, docker/dind (phase 2); keep frontend stage verbatim; shared `root/` tree gets only 4 minimal distro-aware edits (init-nginx conf-path branch, svc-selkies DEV_MODE→dnf port from fedora44, proot guard, dockerd guard). All EL9 package availability verified against live CS9/EPEL9/RPMFusion repodata (see `activeContext.md`).
**Alternatives**: v1 (Debian port — more package gaps, hand-rolled locale/sudoers handling); tracking upstream `el9` (deprecated, older selkies pin, python3.9).
**References**: `activeContext.md#PLAN-v2-fedora-based`, `systemPatterns.md#8`

### 2026-08-27: Git remote layout (user-managed)
**Status**: Recorded (user action)
**Context**: Repo re-initialized as full upstream clone; old local baseline commits lost (superseded by real upstream history).
**Decision**: `origin` = user's fork `dGilli/docker-baseimage-selkies` (commits + pushes OK); `upstream` = `linuxserver/docker-baseimage-selkies` (**push disabled, NEVER push**). Work branch `rhel9` cut from `master` (upstream tip `69f4fc9`, incl. PR #184).
**References**: `activeContext.md#Git-Reality`

### 2026-08-27: SLU-owned UBI9 base with entitled RHEL repos (supersedes baseimage-el:9 pin) — PLAN v4
**Status**: Approved (user selected during vetting Q&A)
**Context**: Vetting of PLAN v3 revealed: (1) `lscr.io/linuxserver/baseimage-el:9` is UBI9 with **Oracle Linux 9 repos** substituted (`oracle-linux-ol9.repo` → yum.oracle.com; subscription-manager plugin disabled) — the image would contain Oracle packages, not registered RHEL content; (2) `docker-baseimage-el` is **deprecated and frozen** (GitHub: "will not be updated") — no future CVE updates; (3) v3's package audit (CS9/EPEL/host) didn't match the actual resolution source (Oracle mirrors), and podman entitlement passthrough on registered hosts makes local vs remote builds silently diverge; (4) the desktop layer (`openbox st xsettingsd nginx-mod-fancyindex xdotool xclip xsel exo breeze-cursor-theme`) is EPEL-only — verified — so 100% Red Hat-supported content is impossible for this stack.
**Decision**: Vendor the ~100-line baseimage-el Dockerfile into `Dockerfile.rhel9` as an SLU-owned `base` stage `FROM registry.access.redhat.com/ubi9/ubi` (digest-pinned). Drop the Oracle repo file and RPMFusion. RHEL content resolves via entitlement passthrough from the registered build host; EPEL9 added for the desktop delta. Per-package repo provenance recorded in `package_versions_rhel9.txt` as the "supported" evidence.
**Alternatives**: keep baseimage-el (deprecated, Oracle content — rejected); registry.redhat.io base + subscription-manager in-image (credential coupling, redistribution constraints — rejected).
**Consequences**: Builds require an entitled RHEL host (documented in `build-deployment.md`); runtime/NRP unaffected. SLU owns base maintenance (s6-overlay version bumps etc.).
**References**: `tasks/2026-08/270827_rhel9-vetting-plan-v4.md#2`, `activeContext.md#A0`

### 2026-08-27: PLAN v3 defect corrections D1–D6 (folded into PLAN v4)
**Status**: Approved (evidence-based vetting; user approved v4)
**Context/Decision** (full evidence in `tasks/2026-08/270827_rhel9-vetting-plan-v4.md#3`):
- **D1**: DROP the `legacy-cont-init` stub — s6-overlay 3.2.0.2 ships it builtin (verified in tarball: `sources/base/contents.d/legacy-cont-init`); a user-level duplicate would break s6-rc-compile at boot. v3's claim that baseimage-el lacks it was wrong.
- **D2**: ADD `dbus-x11` — shared `startwm.sh` execs `dbus-launch`, which lives in dbus-x11 on EL9 (upstream el9 + fedora44 both install it); omission = svc-de crash-loop.
- **D3**: RENAME `google-noto-cjk-ttc-fonts` (Fedora name) → `google-noto-sans-cjk-ttc-fonts` (EL9 name, verified); dnf strict mode would abort the build.
- **D4**: `groupadd sudo` before `usermod -aG sudo abc` — group doesn't exist on EL9. Keep `%sudo … NOPASSWD` in `/etc/sudoers` main file (harden sed compatibility rationale stands).
- **D5**: Ship `ENV DISABLE_DRI3=true` — shared `svc-xorg/run` passes `-vfbdevice` (LSIO-patched-Xvfb-only flag); stock EL9 Xvfb rejects it → crash-loop whenever `/dev/dri` is visible (NRP GPU nodes!). Likely the true root cause of upstream el9's "DRI3 is not supported on el9" death. Env gate avoids any shared-tree edit.
- **D6**: ADD `xdg-utils` (wrongly listed as an EL9 gap — verified in AppStream 1.1.3) and `xorg-x11-xkb-utils` (xkbcomp for Xvfb keymaps, don't rely on dep-pull).
**References**: `tasks/2026-08/270827_rhel9-vetting-plan-v4.md#3`, `activeContext.md#PLAN-v4`
**Post-build correction (2026-08-27)**: D6's `xorg-x11-xkb-utils` is the Fedora name; RHEL9 ships `xkbcomp` (F31). cvt/gtf turn out to live in `xorg-x11-server-Xorg` (F41, next ADR) — the vetting audit (F08) was wrong that they're absent on EL9.

### 2026-08-27: RHEL9 build-cycle package deltas (F31–F35, F40) + xorg-x11-server-Xorg for cvt/gtf (F41)
**Status**: Approved (executed during the user-approved BUILD; findings recorded in `findings.md`)
**Context**: PLAN v4 was vetted against repo listings, but the first builds surfaced 4 RHEL9 deltas and the first manual test surfaced 1 hidden runtime dependency:
- **F31**: Fedora names `xorg-x11-xkb-utils`/`xorg-x11-font-utils` don't exist on RHEL9 → `xkbcomp`, `mkfontscale` (AppStream).
- **F32**: selkies' C-ext deps (`evdev`, python-`xkbcommon`) are sdist-only → need `python3.11-devel` + `libxkbcommon-devel` (upstream el9/f44 shipped these; v4 list missed them).
- **F34**: python-xkbcommon ≥1.5 needs libxkbcommon 1.5 (`XKB_CONTEXT_NO_SECURE_GETENV`); RHEL 9 ships 1.4 on every stream → pin `xkbcommon<1.5` (resolves 1.0.1 — builds clean; same production trick upstream el9 used).
- **F35**: RHEL9 ncurses 6.2 `tic` has no `-i` flag → plain `tic` (exit 0; unknown-cap warnings only).
- **F40**: dnf records no INSTALLFROM in container-mode builds (setopt tested, no effect) → provenance artifact generated by vanilla-ubi9 baseline diff + per-package GPG key instead of `repoquery --installed`.
- **F41**: selkies runtime resize (`gst_app_resize`) calls `cvt` (fallback `gtf`) at **client connect** to create the browser-sized X mode; missing both → `FATAL: Could not create extended mode` → video pipeline aborts ("Waiting for stream..." — user manual test #1). RHEL9 carries cvt/gtf in `xorg-x11-server-Xorg`; vetting's F08 ("cvt absent on EL9") was wrong.
**Decision**: Apply the fixes in `Dockerfile.rhel9`; install `xorg-x11-server-Xorg` in the CPU-only phase-1 image (nothing runs it — Xvfb remains the server) purely to carry cvt/gtf. Matches upstream el9, which shipped the Xorg+Xvfb pair.
**Consequences**: +7 rhel9 packages (Xorg 1.20.11-34 + deps); boot modeline step now actually applies (xrandr current 1024x768); F08 corrected; provenance method documented in `package_versions_rhel9.txt`.
**References**: `findings.md` F31–F35/F40/F41; commit `bd46cdb`; `tasks/2026-08/270827_rhel9-build.md`

### 2026-08-28: Standard RHEL GNOME (gnome-shell 40.10) as the rhel9 default X11 desktop — direct launch, no gnome-session
**Status**: Approved (user approved finalized PLAN v2 + clean-desktop adjustment at approval)
**Context**: User wanted "a GUI desktop, not just a shell" → "the standard GNOME WM RHEL ships with". NRP's production UBI9 image runs a proven recipe: `dbus-run-session -- gnome-shell --x11 --sm-disable` (F44). RHEL9 AppStream carries the full GNOME 40 generation + firefox 140 ESR (F43); XFCE is EPEL-only (worse supported posture).
**Decision**: 5th distro-aware no-op branch in `startwm.sh`: launch **gnome-shell directly** (no gnome-session → bypasses gnome-initial-setup welcome flow [not even in gnome-shell's dep tree], keyring prompts, logind dependency, blanking/lock — ideal for a streamed desktop), on a **deterministic session bus** (explicit `dbus-daemon --session --address=unix:path=$XDG_RUNTIME_DIR/bus` — F51: EL9's dbus-run-session drops a random `/tmp` socket sibling apps cannot discover), with **per-boot** `XDG_RUNTIME_DIR=/tmp/runtime-abc` (F48: the default `/config/.XDG` sits on the persistent VOLUME; stale `bus` socket would break post-restart sessions). +12 AppStream packages (F47). **No auto-launched apps** on the GNOME desktop (user decision — st/nautilus removed from autostart; apps via GNOME app grid). `DESKTOP=openbox` keeps the full LSIO autostart/RESTART_APP contract; `svc-xorg`/`svc-watchdog` unchanged (F45); `init-selkies-config` normalizes `/config/.cache` ownership (F49 — base init-mods pip hook leaves it root-owned).
**Alternatives**: full gnome-session (welcome flow + logind coupling — rejected); XFCE 4.18 (EPEL-only — rejected, user directed RHEL standard GNOME); dbus-run-session as-is (F51 discovery problem — rejected); auto-launched nautilus/st at boot (removed per user decision at approval).
**Consequences**: +315 packages / ~1.0 GB installed; final image `99da8c1475f5` (c7, incl. same-day SLU wallpaper follow-up `06bc207` — gsettings at boot, F52); `RESTART_APP` idles (harmless) under GNOME since there is no autostart target — the feature lives on in openbox mode; gnome-settings-daemon installed (NRP parity) but inert without logind; GPU/Zink phase-2 path unaffected (mutter composites via llvmpipe GLX on our Xvfb, F36/F45).
**References**: `findings.md` F42–F52; `tasks/2026-08/280828_rhel9-gnome-desktop.md`; commits `11a8afd` + `06bc207`; revert tag `pre-gnome-desktop` → `b4c199f`

### 2026-08-28: NRP production integration = template drop-in owned by OUR repo (slu-nrp-k8s-vm is the earlier attempt, reference only)
**Status**: Approved (user decisions 2026-08-28: tag "do what is cleanest" → `v4-llvmpipe`; repo stays **private**; `/config` **ephemeral** (emptyDir); **work stays in `/home/its_admin/projects/slu-docker-rhel-selkies` and its repo** — no edits to the NRP-side repos)
**Context**: Production NRP consumes desktop workspaces via placeholder templates + a fixed sed pipeline + `kubectl apply` (contract evidenced by the earlier `slu-nrp-k8s-vm` attempt, which the user designated reference-only). Its rhel9 template was written for their supervisord image and has three breaking mismatches vs ours: port 8080 (ours: 3000; ws same-origin), `PASSWD`/`BASIC_AUTH_*` (ours: `USERNAME`/`PASSWORD` — and missing PASSWORD = **no-auth UI**), `SELKIES_ENCODER=vp8enc` (ours: rejected by selkies 348bc4f; H.264 streams via the pixelflux wheel — F57).
**Decision**: Our repo owns `deploy/nrp/selkies-rhel9.yaml.template` — the drop-in production template for the current NRP system: uses only the standard placeholder set (renderer-compatible), omits the encoder placeholder (immune to their config value), hardcodes `imagePullSecrets: dockerhub-dgilli` (private repo; their sed set has no pull-secret placeholder), `/config`+`/dev/shm` emptyDirs (ephemeral per user), no securityContext (F28), Guaranteed QoS, GPU placeholders kept for phase 2. Image pinned `docker.io/dgilli/selkies-rhel9:v4-llvmpipe` (= c8 `5c835fb6a147`, manifest `sha256:b70d42e3…`); `:latest` tracks dev. NRP-side work is reduced to: swap the template file, create the pull secret (+ ensure `selkies-password` exists), check namespace PSA labels, run one workspace.
**Alternatives**: edit the NRP-side repos (rejected by user — separate workstream); accept vp8enc + fallback (rejected — invalid-value warning in every pod log, and it documents the wrong contract); make the repo public (rejected — image carries dev creds + SLU assets); PVC for /config (deferred — user chose standard ephemeral).
**Consequences**: production tag/registry question (F30) closed; known divergence documented: their 30fps/4Mbps cap intent is unenforceable via env on our build (client-side settings only); the earlier-attempt repo's `nrp-workspace` prints "Username: rheluser" for rhel9 workspaces (cosmetic — ours is `abc`).
**References**: `findings.md` F57 (contract + mismatches + verification), F28/F30/F55; `tasks/2026-08/280828_phase1-5-production-nrp.md`; commit `525f38d`
