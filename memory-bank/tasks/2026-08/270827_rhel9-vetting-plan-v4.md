# RHEL9 Plan Vetting → PLAN v4 (2026-08-27)

**Scope**: Rigorous QA of PLAN v3 (`activeContext.md`) for the "fully supported and registered RHEL9 selkies image". Result: 1 strategic misalignment (base image), 6 concrete defects (2 boot-breaking, 2 build-breaking), several watch items. PLAN v4 supersedes v3.

## 1. Verification methodology (all findings evidence-based)

Sources checked on 2026-08-27:
- Shared `root/` tree of this repo (line-level read of every init/svc script the plan touches)
- `upstream/el9` and `upstream/fedora44` Dockerfiles + root trees (local git refs)
- `linuxserver/docker-baseimage-el` master source on GitHub (Dockerfile + `root/etc/yum.repos.d/`)
- s6-overlay **3.2.0.2 noarch tarball** (downloaded, contents listed)
- `lscr.io/linuxserver/baseimage-el` tag registry (podman search / manifest inspect)
- Entitled RHEL 9.8 host repoquery (`rhel-9-for-x86_64-{baseos,appstream}-rpms`, CRB, EPEL) — authoritative for RHEL9 package names/availability

## 2. Strategic finding — base image (drove PLAN v4)

1. **`baseimage-el:9` = UBI9 + Oracle Linux 9 repos, not RHEL.** Its Dockerfile disables the subscription-manager dnf plugin and ships `root/etc/yum.repos.d/oracle-linux-ol9.repo` (`el9_baseos_latest` / `el9_appstream` / `el9_codeready_builder` / `el9_distro_builder` → `yum.oracle.com`). Every `dnf install` in a derived image pulls **Oracle Linux packages**.
2. **`docker-baseimage-el` is DEPRECATED and frozen.** GitHub README: "This image is deprecated. We will not offer support for this image and it will not be updated." Pinned tag `9-version-f81d91cc` exists (verified via manifest inspect) but is already behind `9-version-5a65c068`; no further CVE updates will ever come.
3. **Audit-source mismatch.** v3's package audit was done against CS9/EPEL listings + the entitled host — but the actual build would resolve from Oracle mirrors. Additionally, podman on a registered RHEL host **auto-mounts entitlements into builds**, so local builds could silently resolve some packages from real RHEL repos while builds elsewhere resolve from Oracle → non-reproducible split the plan never mentioned.
4. **"Fully supported" ceiling.** Verified EPEL-only (no RHEL repo has them): `openbox st xsettingsd nginx-mod-fancyindex xdotool xclip xsel exo breeze-cursor-theme`. 100% Red Hat-supported content is impossible for this stack; best achievable = entitled RHEL BaseOS/AppStream/CRB wherever available + a *documented* EPEL delta.

**USER DECISION (2026-08-27)**: **SLU-owned base** — vendor the ~100-line baseimage-el Dockerfile into `Dockerfile.rhel9` as a `base` stage `FROM registry.access.redhat.com/ubi9/ubi`; drop the Oracle repo file **and RPMFusion** (breeze-cursor-theme is in EPEL; RPMFusion only mattered for deferred phase-2 DEV_MODE ffmpeg); RHEL content via entitlement passthrough from the registered build host; EPEL9 for the desktop delta. Rejected alternatives: keep baseimage-el (deprecated/Oracle), registry.redhat.io + subscription-manager in-image (credential coupling, bad practice).

**Build constraint (documented)**: image builds only on entitled RHEL hosts. Runtime needs no entitlement; NRP just pulls.

## 3. Concrete defects in PLAN v3 (all fixed in v4)

| # | Defect | Evidence | v4 fix |
|---|--------|----------|--------|
| D1 | `legacy-cont-init` stub (v3 step 12) would **break boot, not fix it** | s6-overlay 3.2.0.2 tarball ships `legacy-cont-init` as a builtin `base`-bundle s6-rc source (`/package/admin/s6-overlay-3.2.0.2/etc/s6-rc/sources/legacy-cont-init/`) — that's why Debian master needs no stub for `svc-de`'s dep. A duplicate user-level definition → s6-rc-compile failure at `/init` | **Drop step 12** entirely; revisit only if first boot shows an unresolved-dependency error |
| D2 | Missing `dbus-x11` → **svc-de crash-loop** | Shared `startwm.sh:11` execs `dbus-launch`; on EL9 it lives in `dbus-x11` (verified AppStream 1.12.20). Upstream `el9` (Dockerfile:79) **and** `fedora44` (Dockerfile:197) both install it. techContext's "verify dbus-launch" TODO was never closed | **Add `dbus-x11`** to package list |
| D3 | `google-noto-cjk-ttc-fonts` is the **Fedora** name → dnf strict-mode **build failure** | EL9 name verified on host: `google-noto-sans-cjk-ttc-fonts` (AppStream) | **Rename** package |
| D4 | `usermod -aG sudo abc` **fails on EL9** — no `sudo` group exists | Upstream el9 used `%wheel` + sudoers.d instead. Debian base ships the group | **`groupadd sudo` first**; keep `%sudo … NOPASSWD` appended to `/etc/sudoers` (v3 rationale stands: harden sed at `init-selkies-config/run:98` only touches `/etc/sudoers`) |
| D5 | `DISABLE_DRI3=false` default + stock Xvfb = **crash-loop whenever `/dev/dri` exists** | Shared `svc-xorg/run:13-17` passes `-vfbdevice` — an **LSIO-patched-Xvfb flag**; stock EL9 `xorg-x11-server-Xvfb` rejects it. Upstream el9 **deleted the whole block** from their svc-xorg (likely the real "DRI3 is not supported on el9" root cause the MB recorded as unexplained). Local CPU test passes only because no render node exists; **NRP GPU nodes will expose `/dev/dri`** | **`ENV DISABLE_DRI3=true`** in Dockerfile.rhel9 (existing gate at `svc-xorg/run:19` clears VFBCOMMAND incl. DRINODE path — no shared-tree edit needed); document as rhel9 divergence |
| D6 | `xdg-utils` wrongly listed as an "accepted gap" | Verified **present** in RHEL9 AppStream (1.1.3) and OL9 | **Add `xdg-utils`** (DISABLE_OPEN_TOOLS hardening becomes fully functional); also add **`xorg-x11-xkb-utils`** explicitly (xkbcomp for Xvfb keymaps — normally dep-pulled, don't rely on it) |

## 4. Watch items (added to risk table / smoke test, not fatal)

- `PIXELFLUX_WAYLAND=true` → svc-de/svc-xorg wait forever (no labwc in phase 1) — document, or add a guard echo
- `svc-dbus` runs `dbus-daemon --system` as `abc`: EL9 `system.conf` `<user>dbus</user>` directive is ignored when non-root — should behave like Debian, but smoke-test explicitly
- EL nginx keeps a default `:80` server block in `/etc/nginx/nginx.conf` (upstream el9 shipped it; harmless — port unexposed; optional cleanliness sed)
- ENV parity nit: v3's ENV list omitted `START_DOCKER=true` (master `Dockerfile:310`)
- EPEL-on-UBI9 `$releasever` quirk: NRP-proven working; re-verify inside the new vendored base
- Reproducibility: entitlement passthrough means repo mix depends on build host — mitigated by v4 making entitled RHEL repos the *intended* source + provenance artifact (below)

## 5. Validated v3 claims (kept unchanged in v4)

- `cvt` absence gracefully no-ops: `svc-de/run:33-40` — empty `MODELINE_NAME` → `grep -q ""` always matches → xrandr block skipped ✓
- `pulseaudio` IS in RHEL9 AppStream (15.0) — earlier doubt disproven; `python3.11`, `xorg-x11-server-Xvfb`, `mesa-dri-drivers`, `glibc-all-langpacks`, `glibc-locale-source`, `nginx`, fonts all verified in entitled repos ✓
- All **4 shared-tree distro-aware edits confirmed necessary**: unguarded `cp /proot-apps/*` (`init-selkies-config/run:258`), `apt-get` in DEV_MODE (`svc-selkies/run:25`), `sites-available` path (`init-nginx/run:4`), dockerd exec (`svc-docker/run`) ✓
- Selkies install = master parity: pyproject seds (`/"av>/d`, `/cryptography/d`), `--system-site-packages` venv, `pip install . && pip install setuptools` (master `Dockerfile:465-481`) ✓
- openbox 3.6.1 sed set proven byte-identical on upstream el9 (`Dockerfile:201-210`) ✓
- st terminfo `tic` fix needed (upstream el9 shipped st with **no** fix — likely broken there) ✓
- llvmpipe ENV trio, NRP rootful gate, pinned-base-then-unpin approach ✓ (pin target changes to a ubi9 digest)

## 6. PLAN v4 delta summary (canonical plan lives in `activeContext.md`)

1. **New vendored `base` stage** (§2 decision): ubi9/ubi + entitlement passthrough + EPEL9; s6-overlay 3.2.0.2; `abc` uid 911; `/lsiopy`; docker-mods scripts; LSIO ENV block. No Oracle, no RPMFusion, no baseimage-el.
2. **Defect fixes D1–D6** (§3) folded into the runtime stage steps.
3. **Expanded test matrix**: v3 procedure + `--device /dev/dri` (proves D5), `--privileged` (svc-docker guard), `HARDEN_DESKTOP=true` (sudoers sed round-trip, xdg/exo chmod), `PIXELFLUX_WAYLAND=true` behavior, `LC_ALL=de_DE.UTF-8` boot, explicit dbus smoke.
4. **Provenance artifact**: `dnf repoquery --installed --qf '%{name}|%{version}|%{reponame}'` captured into `package_versions_rhel9.txt` — the per-package RHEL-vs-EPEL evidence backing the "supported" claim.
5. **Preflight** (before any build): `podman run --rm registry.access.redhat.com/ubi9/ubi dnf repolist` on this host must show `rhel-9-for-x86_64-*` repos (entitlement passthrough sanity).

**Budget**: ~4 cycles / ~90 min (base stage adds one layer; preflight adds 5 min).

**Status**: PLAN v4 approved 2026-08-27 (base strategy user-selected). Docs/MB updated; **no build performed yet** per user instruction.
