# Progress

**Last Updated**: 2026-08-28

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
- [x] 2026-08-28 — **RHEL9 GNOME desktop (task 2) BUILT + TESTED + APPROVED + COMMITTED**: standard RHEL GNOME (gnome-shell 40.10) as default X11 desktop, NRP-proven direct launch, openbox fallback (`DESKTOP=openbox`), clean desktop (no auto-apps per user decision). 7 build cycles (QA fixes F49/F50/F51; SLU/RHEL wallpaper follow-up F52, user-provided `slu-rhel.jpg`); autonomous smoke + edge 4/4 ALL PASS; screenshot-verified; commits `11a8afd` + `06bc207`; current image `99da8c1475f5`; revert tag `pre-gnome-desktop` → `b4c199f`. See: `tasks/2026-08/280828_rhel9-gnome-desktop.md`, `findings.md` F42–F52, `decisions.md` (GNOME ADR)

## In Progress
- (none — task 2 closed 2026-08-28; phase 1.5 awaits scheduling)

## Next
1. Phase 1.5 (separate work item, when user schedules): registry push + NRP template env mapping (F28 rootful gate, F30 tag naming still open; F55 ptrace/unshare seccomp verification folds in here)
2. **Roadmap (deferred by user 2026-08-28, intel complete + fix verified — F53–F55)**: R1 proot-apps (dashboard app install/update actually working: ship `/proot-apps`, bwrap stub for glycin apps, optional SLU catalog) — full plan in `activeContext.md#Roadmap`
3. Candidates: GPU/Zink phase 2 (Xorg path, F06/F07/F29) · libreoffice/extra apps on the GNOME desktop · Wayland
