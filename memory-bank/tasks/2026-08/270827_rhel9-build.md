# 270827_rhel9-build

## Objective
Build the RHEL9 variant image per approved PLAN v4 (SLU-owned UBI9 base + entitled RHEL repos, D1–D6 fixes), test it locally on the RHEL 9.8 host as far as possible autonomously, and produce the provenance artifact.

## Outcome
- ✅ Image `dgilli/baseimage-selkies:rhel9-p1` — final `10bbd70e1502` (5 build cycles)
- ✅ Autonomous smoke + full v4 negative/edge matrix: PASS
- ✅ User manual test #1: login/sidebar/clipboard/audio OK, video abort → **F41 found** (cvt/gtf missing)
- ✅ User manual test #2 after fix: **desktop renders — "I got a shell!"**
- ✅ Artifacts: `package_versions_rhel9.txt` (213 ubi9-base / 211 rhel9 / 24 epel + 41 python), `readme-vars.yml` RHEL row
- ✅ Commit `bd46cdb` on `rhel9`; revert tag `pre-rhel9-build` → `7b3af8b`

## Files Modified
- `Dockerfile.rhel9` (NEW) — 3 stages: `base` (SLU-owned UBI9 + s6-overlay 3.2.0.2 + docker-mods + EPEL9, amd64 digest pin), `frontend` (master verbatim, alpine 3.22, selkies `348bc4f`), runtime (15 steps; D1–D6 + F31–F35/F41 fixes; `DISABLE_DRI3=true` + llvmpipe trio; provenance capture)
- `root-base/` (NEW, 68 files) — vendored `docker-baseimage-el` s6-rc.d tree (Oracle repo + GPG key excluded per ADR)
- `root/etc/s6-overlay/s6-rc.d/{init-nginx,svc-selkies,init-selkies-config,svc-docker}/run` — 4 distro-aware no-op edits (nginx conf.d branch, DEV_MODE non-Debian gate, proot-apps dir guard, dockerd guard)
- `package_versions_rhel9.txt` (NEW), `readme-vars.yml` (+1 row)
- `memory-bank/`: `findings.md` (NEW registry F01–F41), `activeContext.md`, `progress.md`, `decisions.md` (2 new ADRs), `toc.md`, `ops-log.jsonl`

## Patterns Applied
- `systemPatterns.md#1` multi-stage build — extended with an in-image SLU-owned `base` stage (first variant to do so)
- `systemPatterns.md#7` in-repo variant deviation (`Dockerfile.rhel9` + shared `root/` tree vs upstream one-branch-per-OS) — F22
- **New pattern**: distro-aware shared-tree no-op branching — each of the 4 edits is a no-op on Debian/Fedora; future variants add conditions instead of forking the tree
- **New method**: provenance via vanilla-ubi9 baseline diff + per-package GPG key (F40) — dnf INSTALLFROM unavailable in container-mode builds

## Build Cycle Log
| Cycle | Failure | Fix | Finding |
|---|---|---|---|
| 1 | `xorg-x11-xkb-utils`/`-font-utils` "No match" | `xkbcomp` + `mkfontscale` (RHEL9 names) | F31 |
| 2 | `evdev` build: `Python.h` missing | +`python3.11-devel` | F32 |
| 3 | python-`xkbcommon` cffi: `XKB_CONTEXT_NO_SECURE_GETENV` undeclared (libxkbcommon 1.4) | +`libxkbcommon-devel`, pin `xkbcommon<1.5` (→1.0.1, verified in ubi9) | F34 |
| 4 | `tic -i`: usage dump (ncurses 6.2 has no `-i`) | plain `tic` (exit 0 verified) | F35 |
| 5 | **User manual test**: "Waiting for stream..." — `gst_app_resize` FATAL (no cvt/gtf) | +`xorg-x11-server-Xorg` (carries cvt+gtf on RHEL9; nothing runs it) | F41 (F08 corrected) |

Process note: full `dnf --downloadonly` resolution dry-run added after cycle 1 to catch name errors before rebuilds.

## Test Evidence
- **Smoke**: 10/10 user-bundle services up & stable (s6-svstat) · init chain complete · Xvfb `:1` (xdpyinfo) · openbox `--replace` via `dbus-launch` (F19/D2) · `st` from autostart (F22) · X socket abc-owned · nginx 3000/3001 auth 401→200 (`abc`/`baseimage123`) · 8082 selkies-ws · pactl output+input null sinks · llvmpipe GL probe: `llvmpipe (LLVM 21.1.7)`, GL 4.5 (F36) · sudo NOPASSWD (F33) · 869 locales, `de_DE.utf8` boot
- **Negative matrix (6/6)**: `--device /dev/dri/renderD128` → Xvfb no `-vfbdevice`, stable (D5/F16) · `SELKIES_MANUAL_WIDTH/HEIGHT=1280x720` → Xvfb `-screen 0 1280x720x24` · `DISABLE_SUDO`+`DISABLE_OPEN_TOOLS`+`HARDEN_DESKTOP` → CORRUPT_FILE sed + xdg-open/exo-open mode 0000 + nginx files block removed · `LC_ALL=de_DE.UTF-8` boot · `DEV_MODE=pixelflux` → gate msg "not supported on rhel", default boot (F39) · dockerd guard (simulated privileged) → "service idle", stable (F38)
- **Manual**: #1 → F41; #2 → pass (desktop + shell)

## Architectural Decisions
- `decisions.md` 2026-08-27: RHEL9 build-cycle deltas + xorg-x11-server-Xorg (F31–F35, F40, F41)
- SLU-owned base ADR unchanged (F08 corrected: cvt/gtf ARE on RHEL9, in Xorg pkg)

## Artifacts
- Commit `bd46cdb` (branch `rhel9`); revert tag `pre-rhel9-build`
- Image `10bbd70e1502` local podman only — SLU registry push + NRP template mapping = phase 1.5 (F28 rootful gate, F30 tag naming open)

## Remaining (phase 2 candidates)
GPU/Zink (F06/F07/F29) · Wayland/labwc · DinD (svc-docker guard in place) · proot-apps · pelorus · DEV_MODE dnf port (gate in place)
