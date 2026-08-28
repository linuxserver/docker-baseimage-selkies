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
- [ ] **RHEL9 GNOME desktop (task 2)** — **BUILD done, autonomous QA ALL PASS, awaiting user manual browser test + approval** (2026-08-28)
  - 4 build cycles (extension flagged): final image `dgilli/baseimage-selkies:rhel9-p1-gnome` = `15f963f83b71`
  - Fixes found in QA: F49 (root-owned /config/.cache from base pip hook), F50 (nautilus `--no-desktop`, no `-d` in RHEL9), F51 (EL9 dbus-run-session random /tmp socket → explicit dbus-daemon --address)
  - Edge matrix 4/4: DESKTOP=openbox · 1280x720 · RESTART_APP respawn · HARDEN_DESKTOP (gnome-terminal disabled too)
  - Live container `selkies-rhel9-p1-gnome` on :3000/:3001/:8082 for manual test
  - See: `activeContext.md#Task-2`, `findings.md` F42–F51

## Next
1. User manual browser test → approval → commit + docs (task doc, ADR, package_versions refresh)
2. Phase 1.5 (separate work item): registry push + NRP template env mapping (F28 rootful gate, F30 tag naming still open)
