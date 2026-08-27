# Progress

**Last Updated**: 2026-08-27

## Done
- [x] 2026-08-27 — Memory Bank initialized (v1, seeded from Debian-variant analysis)
- [x] 2026-08-27 — RHEL9 PLAN v1 (Debian-port approach) drafted; user introduced upstream fedora branches → v1 superseded
- [x] 2026-08-27 — Full EL9/Fedora reference audit: upstream `el9` (deprecated), `fedora42/43/44` branches analyzed; CS9+EPEL9+RPMFusion-el9 package availability verified from live repo listings/repodata
- [x] 2026-08-27 — `rhel9` branch created from upstream master tip (`69f4fc9`); git remotes: origin=user fork (dGilli), upstream=linuxserver (push disabled)

## In Progress
- [ ] **RHEL9 image (PLAN v2, fedora-based)** — presented, awaiting user approval
  - Blockers: none technical — approval only

## Next Priorities (after approval)
1. BUILD `Dockerfile.rhel9` (fedora44 structure, EL9 substitutions per activeContext)
2. 4 small shared-tree edits (init-nginx branch, svc-selkies DEV_MODE dnf, proot guard, dockerd guard)
3. `podman build` + smoke test (boot, nginx, openbox+st, selkies 8082, localedef, fancyindex nginx -t)
4. `package_versions_rhel9.txt` + readme-vars.yml row
5. Commit to `rhel9` (origin push only if user asks)
