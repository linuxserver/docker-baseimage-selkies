# Tasks — 2026-08

## Housekeeping
### 2026-08-27: Memory Bank init + git reorganization
- Memory Bank created (v1, Debian-variant analysis) — re-committed on `rhel9` branch after user re-initialized the repo as full upstream clone
- Git: `origin` = user fork (dGilli), `upstream` = linuxserver (push disabled); branch `rhel9` cut from upstream master tip `69f4fc9`
- No task doc (housekeeping)

## Active
### [IN-PROGRESS] Add RHEL9 to supported images
- **Phase 1 (CPU desktop + streaming): DONE 2026-08-27** — built, tested (autonomous matrix + user manual x2), committed `bd46cdb`
- Phase 1.5 (SLU registry push + NRP template env mapping): pending — F28 rootful gate + F30 tag naming open
- Phase 2 (GPU/Zink, Wayland, DinD, proot-apps, pelorus, DEV_MODE dnf port): deferred
- History: v1 (Debian port) → v2/v3 (fedora44-modeled, baseimage-el:9) → **vetting** found baseimage-el deprecated + Oracle-repo-based + 6 defects → **v4** (SLU-owned UBI9 base + entitled RHEL repos, D1–D6 fixes) → **build** (5 cycles, F31–F35/F41 RHEL9 deltas)
- **Vetting/defect log: `270827_rhel9-vetting-plan-v4.md`** · **Build log: `270827_rhel9-build.md`**
- Key references: upstream `fedora44` (current RPM-family pattern), upstream `el9` (deprecated; proved the stack, and its svc-xorg/-vfbdevice deletion = D5 evidence), entitled RHEL 9.8 host repoquery (authoritative package audit)
- See: `memory-bank/activeContext.md#BUILD-executed-2026-08-27-user-released-the-hold`, `memory-bank/decisions.md` (4 ADRs), `memory-bank/findings.md` (F01–F41), `memory-bank/techContext.md`

## Completed
### 2026-08-28: RHEL9 GNOME desktop (task 2) — approved + committed
- Standard RHEL GNOME (gnome-shell 40.10) as default X11 desktop; NRP-proven direct launch; openbox fallback via `DESKTOP=openbox`; clean desktop (no auto-apps, user decision)
- Final image `dgilli/baseimage-selkies:rhel9-p1-gnome` = `f54738a5b9d4`; 5 build cycles (QA fixes F49/F50/F51)
- Autonomous smoke + edge matrix 4/4 ALL PASS; screenshot-verified; user approved
- Commit `11a8afd` on `rhel9`; revert tag `pre-gnome-desktop` → `b4c199f`
- See: [280828_rhel9-gnome-desktop.md](./280828_rhel9-gnome-desktop.md), `memory-bank/findings.md` F42–F51, `memory-bank/decisions.md` (GNOME ADR)

### 2026-08-27: RHEL9 phase-1 image built + tested + committed
- `Dockerfile.rhel9` (SLU-owned UBI9 base, digest-pinned) + `root-base/` vendored s6 tree + 4 shared-tree no-op edits
- Final image `dgilli/baseimage-selkies:rhel9-p1` = `10bbd70e1502`; 5 build cycles (F31–F35, F41)
- Full v4 negative matrix PASS + user manual test #2 PASS ("I got a shell!")
- Commit `bd46cdb` on `rhel9`; revert tag `pre-rhel9-build` → `7b3af8b`
- See: [270827_rhel9-build.md](./270827_rhel9-build.md)
