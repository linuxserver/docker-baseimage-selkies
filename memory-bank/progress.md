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
- [ ] **RHEL9 image (PLAN v4, SLU-owned base)** — approved; docs committed; awaiting go for build
  - Blockers: none technical — user hold on build

## Next Priorities (when user releases build hold)
1. Preflight: entitlement passthrough check (`ubi9/ubi dnf repolist` shows `rhel-9-for-x86_64-*`)
2. BUILD `Dockerfile.rhel9` (v4: vendored base stage + frontend + runtime w/ D1–D6 fixes)
3. 4 small shared-tree edits (init-nginx branch, svc-selkies DEV_MODE gate, proot guard, dockerd guard)
4. `podman build` + smoke test incl. v4 negative matrix (`--device /dev/dri`, `--privileged`, HARDEN_DESKTOP, LC_ALL, DEV_MODE gate)
5. `package_versions_rhel9.txt` (with repo provenance) + readme-vars.yml row
6. Commit to `rhel9` (origin push only if user asks)
