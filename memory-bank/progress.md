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
- [x] 2026-08-28 — **Roadmap R1 (proot-apps) steps 1–2 SHIPPED**: `/proot-apps` 0.3.2 bundled (upstream section ported, static) + RHEL9-guarded bwrap stub in `selkies-proot` (F54 fix). Fresh-volume verified via the dashboard chain: install → run → **FileZilla 3.68.1 rendered** (NotSandboxed fallback), update/idempotency (marker re-extract re-stubbed), dash app entry. c8 `5c835fb6a147`, commits `cc2c2b7` + `153290d`, revert tag `pre-r1-proot-apps` → `89f567a`; dev registry re-pushed (manifest `sha256:b70d42e3…`). Operational facts F56; step 3 (SLU catalog) pending. See: `tasks/2026-08/280828_r1-proot-apps.md`
- [x] 2026-08-28 — **Phase 1.5 (dev scope) DONE**: pushed `docker.io/dgilli/selkies-rhel9:latest` (first push OCI manifest `sha256:46246466…` = c7; **re-pushed same day with R1 c8 = manifest `sha256:b70d42e3…`, current**); verified pull-by-digest + cold-boot smoke (web 200 both ports, ws 101, wallpaper on fresh volume, certs auto-gen); NRP k8s mapping `deploy/nrp-selkies-rhel9.yaml` (single-port fit: ws same-origin via nginx `/websocket`); gates closed **F28** (NRP templates have no securityContext — rootful OK), **F30** (Docker Hub dev; production tag ceremony deferred by user), **F55** (docker default seccomp allows ptrace on kernel ≥4.8 — proot-apps R1 needs no seccomp override). See: `tasks/2026-08/280828_phase1-5-nrp-dev-push.md`

## In Progress
- (none — phase 1.5 dev scope closed 2026-08-28; production merge + R1 await scheduling)

## Next
1. NRP **production** merge (later work item): `deploy/nrp-selkies-rhel9.yaml` mapping → NRP's `@@template@@` system + `imagePullSecret` (Docker Hub private-by-default) + dnsPolicy/GPU placeholders; SLU production registry + tag scheme (F30 open half)
2. **R1 step 3 (separate decision, pending)**: SLU catalog — frontend `REPO_BASE_URL` patch → SLU metadata.yml/icons (offline-capable via own nginx), `disabled:` pruning, SLU apps as full OCI refs
3. Candidates: GPU/Zink phase 2 (Xorg path, F06/F07/F29) · libreoffice/extra apps on the GNOME desktop · Wayland
