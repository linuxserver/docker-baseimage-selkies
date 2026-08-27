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

### 2026-08-27: Adopt force-llvmpipe ENV in Dockerfile.rhel9
**Status**: Proposed (from NRP project evidence; include in BUILD)
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
**Status**: Proposed — awaiting user approval
**Context**: User made upstream `fedora42-44` branches available ("base our rhel9 image on fedora much more closely than debian"). Investigation showed upstream has (a) a deprecated `el9` branch proving `baseimage-el:9` works for this stack, and (b) current `fedora44` with the same selkies pin (348bc4f) and the full set of EL-family adaptations.
**Decision (proposed)**: `Dockerfile.rhel9` = fedora44 structure with `FROM lscr.io/linuxserver/baseimage-el:9`; drop wayland stages (wtype/selkies-desktop/labwc-builder), pelorus, proot-apps, docker/dind (phase 2); keep frontend stage verbatim; shared `root/` tree gets only 4 minimal distro-aware edits (init-nginx conf-path branch, svc-selkies DEV_MODE→dnf port from fedora44, proot guard, dockerd guard). All EL9 package availability verified against live CS9/EPEL9/RPMFusion repodata (see `activeContext.md`).
**Alternatives**: v1 (Debian port — more package gaps, hand-rolled locale/sudoers handling); tracking upstream `el9` (deprecated, older selkies pin, python3.9).
**References**: `activeContext.md#PLAN-v2-fedora-based`, `systemPatterns.md#8`

### 2026-08-27: Git remote layout (user-managed)
**Status**: Recorded (user action)
**Context**: Repo re-initialized as full upstream clone; old local baseline commits lost (superseded by real upstream history).
**Decision**: `origin` = user's fork `dGilli/docker-baseimage-selkies` (commits + pushes OK); `upstream` = `linuxserver/docker-baseimage-selkies` (**push disabled, NEVER push**). Work branch `rhel9` cut from `master` (upstream tip `69f4fc9`, incl. PR #184).
**References**: `activeContext.md#Git-Reality`
