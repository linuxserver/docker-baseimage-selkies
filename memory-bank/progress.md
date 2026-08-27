# Progress

**Last Updated**: 2026-08-27

## Done
- [x] 2026-08-27 — Memory Bank initialized (v1, seeded from Debian-variant analysis)
- [x] 2026-08-27 — RHEL9 PLAN v1 (Debian-port approach) drafted; user introduced upstream fedora branches → v1 superseded
- [x] 2026-08-27 — Full EL9/Fedora reference audit: upstream `el9` (deprecated), `fedora42/43/44` branches analyzed; CS9+EPEL9+RPMFusion-el9 package availability verified from live repo listings/repodata
- [x] 2026-08-27 — `rhel9` branch created from upstream master tip (`69f4fc9`); git remotes: origin=user fork (dGilli), upstream=linuxserver (push disabled)
- [x] 2026-08-27 — PLAN v2/v3 drafted (fedora44-modeled, NRP-integrated)
- [x] 2026-08-27 — **Rigorous vetting of PLAN v3** → found baseimage-el = deprecated + Oracle-repo-based (not registered RHEL) + 6 concrete defects (D1–D6, incl. 2 boot-breaking); evidence: `tasks/2026-08/270827_rhel9-vetting-plan-v4.md`
- [x] 2026-08-27 — **PLAN v4 approved** (user chose SLU-owned UBI9 base + entitled RHEL repos)
- [x] 2026-08-27 — **RHEL9 phase-1 BUILT + ALL TESTS PASS + COMMITTED**: image `dgilli/baseimage-selkies:rhel9-p1` (`10bbd70e1502`, 5 build cycles — F31–F35/F41 RHEL9 deltas); autonomous matrix + user manual test #2 ("I got a shell!"); commits `bd46cdb` (build) → `23964ff` (docs) → `24e1575` (close); revert tag `pre-rhel9-build` → `7b3af8b`
- [x] 2026-08-27 — **GNOME desktop research**: NRP proven launch recipe extracted (F44), RHEL9 AppStream GNOME app set verified (F42/F43), Xvfb extension set confirmed sufficient (F45)

## In Progress
- [ ] **RHEL9 GNOME desktop (task 2)** — **PLAN v1 presented 2026-08-27, awaiting user approval**
  - Standard RHEL GNOME (gnome-shell 40.10) as default X11 DE; openbox kept as fallback (`DESKTOP=openbox` knob)
  - NRP direct-launch pattern: `dbus-run-session -- gnome-shell --x11 --sm-disable` (bypasses gnome-session → no welcome screen/keyring/lock)
  - Packages (all AppStream-verified): `gnome-shell nautilus gnome-terminal gedit gnome-calculator gnome-screenshot firefox xorg-x11-server-utils glx-utils`
  - Touch points: `Dockerfile.rhel9` dnf list + `startwm.sh` gnome branch (5th distro-aware no-op shared-tree edit); `svc-watchdog`/`init-selkies-config` UNCHANGED (exact autostart string preserved for RESTART_APP)
  - See: `activeContext.md#Task-2`, `findings.md` F42–F45

## Next
1. On approval: build (budget 3 cycles, dnf dry-run first) → autonomous smoke (incl. `gnome-screenshot` visual check) → edge matrix → user manual browser test → commit + docs
2. Phase 1.5 (separate work item): registry push + NRP template env mapping (F28 rootful gate, F30 tag naming still open)
