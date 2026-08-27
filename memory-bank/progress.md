# Progress

**Last Updated**: 2026-08-27

## Done
- [x] 2026-08-27 — Memory Bank initialized (v1, seeded from Debian-variant analysis)
- [x] 2026-08-27 — RHEL9 PLAN v1 (Debian-port approach) drafted; user introduced upstream fedora branches → v1 superseded
- [x] 2026-08-27 — Full EL9/Fedora reference audit: upstream `el9` (deprecated), `fedora42/43/44` branches analyzed; CS9+EPEL9+RPMFusion-el9 package availability verified from live repo listings/repodata
- [x] 2026-08-27 — `rhel9` branch created from upstream master tip (`69f4fc9`); git remotes: origin=user fork (dGilli), upstream=linuxserver (push disabled)
- [x] 2026-08-27 — PLAN v2/v3 drafted (fedora44-modeled, NRP-integrated)
- [x] 2026-08-27 — **Rigorous vetting of PLAN v3** → found baseimage-el = deprecated + Oracle-repo-based (not registered RHEL) + 6 concrete defects (D1–D6, incl. 2 boot-breaking); evidence: `tasks/2026-08/270827_rhel9-vetting-plan-v4.md`
- [x] 2026-08-27 — **PLAN v4 approved** (user chose SLU-owned UBI9 base + entitled RHEL repos); MB/docs updated — **no build performed yet, per user**

## In Progress
- [ ] **RHEL9 image (PLAN v4, SLU-owned base)** — **BUILT + ALL TESTS PASS 2026-08-27** (autonomous matrix + user manual test #2 "I got a shell!"); **awaiting explicit commit approval**
  - Final image `dgilli/baseimage-selkies:rhel9-p1` (`10bbd70e1502`); live container `selkies-rhel9-p1` on :3000/:3001/:8082
  - Revert tag `pre-rhel9-build` → `7b3af8b`
  - Build required 5 RHEL9-delta fixes beyond vetting: F31 (xkbcomp/mkfontscale names), F32 (python3.11-devel + libxkbcommon-devel), F34 (xkbcommon<1.5 pin), F35 (tic without -i), F41 (xorg-x11-server-Xorg for cvt/gtf — caught by user manual test #1)
  - All v4 negative/edge matrix items passed (D5 dri, manual-res, hardening, locale, DEV_MODE gate, dockerd guard)

## Next
1. On approval: commit `Dockerfile.rhel9` + `root-base/` + shared-tree edits + `package_versions_rhel9.txt` + `readme-vars.yml` + `findings.md` + MB updates to `rhel9` (origin push only if user asks)
2. Phase 1.5 (separate work item): registry push + NRP template env mapping (F28 rootful gate, F30 tag naming still open)
