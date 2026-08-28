# 280828_r1-proot-apps

## Objective
Roadmap R1 (steps 1–2; step 3 SLU catalog = separate pending decision): make the dashboard "Install/Update/Remove app" chain actually work in the RHEL9 image — ship `/proot-apps` and apply F54's verified bwrap-stub fix so glycin apps (e.g. FileZilla) run under proot instead of hanging.

## Outcome
- ✅ **c8** `dgilli/baseimage-selkies:rhel9-p1-gnome` = `5c835fb6a147` (revert tag `pre-r1-proot-apps` → `89f567a`); commit `cc2c2b7` (+ artifact follow-up `153290d`)
- ✅ Fresh-volume end-to-end (container `selkies-r1-verify` :3200): bootstrap wired `~/.local/bin` (proot-apps 0.3.2, abc-owned) → `/selkies-proot install filezilla` (dashboard chain, st window) → rootfs fetched from ghcr.io → `/selkies-proot run filezilla` → **bwrap stubbed, glycin `WARNING: Glycin running without sandbox.`, FileZilla 3.68.1 window rendered** → app dash entry created
- ✅ Idempotency: `update` (no-op at latest) left stub intact; marker-simulated re-extract was re-stubbed by the next `/selkies-proot get` invocation (loop-before-exec is intentional — re-extracts restore the real binary)
- ✅ Dev registry current: pushed `docker.io/dgilli/selkies-rhel9:latest` = manifest `sha256:b70d42e30c7bef93ca7f0a4bd6a46540d4dfd2eabff1eafadd1d82fbdec5d059` (config = c8)
- ⏳ Step 3 (SLU catalog: frontend `REPO_BASE_URL` patch → SLU metadata/icons, offline-capable, `disabled:` pruning, SLU apps as full OCI refs) — pending separate decision

## Files Modified
- `Dockerfile.rhel9` — +9 lines: upstream proot-apps section ported verbatim (latest `linuxserver/proot-apps` release tarball → `/proot-apps/` + `pversion`; static proot/jq/ncat, no dnf deps) at the upstream placement (after `user perms`)
- `root/selkies-proot` — +14 lines: RHEL9-guarded bwrap stub loop before `exec` (F54 fix: stub emits glycin's recognized `bwrap: No permissions to create a new namespace`, exit 1 → NotSandboxed fallback); re-applied every invocation
- `package_versions_rhel9.txt` — c8 header, `proot` bundle entries (4 static artifacts), fixed the misaligned `selkies` line (pip version string contains spaces)
- `memory-bank/` — F53 status flip, F56, this doc, roadmap/progress/toc/README/activeContext/ops-log
- **Not touched** (as designed): `init-selkies-config/run` (its variant-guarded bootstrap wires `~/.local/bin` once `/proot-apps` exists), selkies frontend (step 3), openbox/Debian/Fedora paths (guard = `/etc/redhat-release`)

## Patterns Applied
- **Distro-aware shared-tree no-op branching** (6th instance) — `if [ -f /etc/redhat-release ]` guard in the shared `selkies-proot`
- **Upstream section port, verbatim** — the proot-apps RUN block is upstream's own (self-contained static bundle; nothing RHEL9-specific)
- **Variant guard as extension point** — the shared bootstrap's `[ -d /proot-apps ]` was the designed hook; shipping the dir activates it

## Verification Detail
- Chain PIDs (single fresh chain, etimes-verified after clean kill): st 2955 → bash/proot-apps 2958 → proot 2964 running the filezilla rootfs `/entrypoint`
- proot command line: `proot -b /defaults:/defaults -b /usr/share/fonts:/usr/share/fonts -b /usr/share/fontconfig:/usr/share/fontconfig -b /etc/fonts:/etc/fonts -n -R /config/proot-apps/ghcr.io_linuxserver_proot-apps_filezilla/ /entrypoint`
- Cosmetic: `s/system.socket: No such file or directory.` in the st window (benign)
- Test-rig trap hit (F56): `pkill -f "proot-apps"` self-matched the verifying `sh -c` (killed my exec, output swallowed) — retry with bracket patterns

## Artifacts
- Commits: `cc2c2b7` (R1 code) + `153290d` (artifact) on `rhel9`; revert tag `pre-r1-proot-apps` → `89f567a`
- Images: local c8 `5c835fb6a147`; registry `docker.io/dgilli/selkies-rhel9:latest` = manifest `sha256:b70d42e3…`
- Live container: `selkies-r1-verify` :3200/:3201/:3282 (abc/baseimage123, FileZilla installed + running on its volume)
- Evidence: /tmp/opencode/{r1-fz.png (overview w/ welcome dialog), r1-fz2.png (direct desktop w/ rendered FileZilla)}
